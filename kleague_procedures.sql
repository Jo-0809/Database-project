-- =====================================================
-- K리그 이적시장 기반 스토브리그 체험 DB 시스템
-- STORED PROCEDURES
-- ※ 재실행 시 기존 프로시저 삭제 후 재생성
-- =====================================================

USE kleague_db;

DROP PROCEDURE IF EXISTS sp_buy_player;
DROP PROCEDURE IF EXISTS sp_release_player;
DROP PROCEDURE IF EXISTS sp_create_squad_battle;

-- =====================================================
-- PROCEDURE 1. sp_buy_player (선수 영입)
-- 호출 예시: CALL sp_buy_player(1, 9);
--   p_user_id    : 영입을 진행하는 유저 ID
--   p_listing_id : 구매할 매물 ID
--
-- 처리 순서:
--   1.  유저 구단 조회
--   2.  매물 정보 조회
--   3.  매물 available 확인
--   4.  자기 구단 선수 영입 방지
--   5.  구매 구단 예산 확인
--   6.  기존 CONTRACT expired 처리
--   7.  새 CONTRACT active 생성
--   8.  PLAYER.club_id 변경
--   9.  TRANSFER_HISTORY 기록  ← 예산 차감 전 먼저 실행 (트리거 충돌 방지)
--   10. 구매 구단 current_budget 감소
--   11. 판매 구단 current_budget 증가
--   12. TRANSFER_MARKET status = 'sold'
-- =====================================================
DELIMITER $$
CREATE PROCEDURE sp_buy_player(
    IN p_user_id    INT,
    IN p_listing_id INT
)
BEGIN
    DECLARE v_buyer_club_id  INT;
    DECLARE v_player_id      INT;
    DECLARE v_seller_club_id INT;
    DECLARE v_asking_fee     DECIMAL(15,2);
    DECLARE v_market_status  VARCHAR(10);
    DECLARE v_buyer_budget   DECIMAL(15,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. 유저의 구단 조회
    SELECT club_id INTO v_buyer_club_id
    FROM APP_USER WHERE user_id = p_user_id;

    IF v_buyer_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '존재하지 않는 유저입니다.';
    END IF;

    -- 2. 매물 정보 조회
    SELECT player_id, seller_club_id, asking_fee, status
    INTO v_player_id, v_seller_club_id, v_asking_fee, v_market_status
    FROM TRANSFER_MARKET WHERE listing_id = p_listing_id;

    IF v_player_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '존재하지 않는 매물입니다.';
    END IF;

    -- 3. 매물 available 상태 확인
    IF v_market_status <> 'available' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '이미 거래가 완료되었거나 취소된 매물입니다.';
    END IF;

    -- 4. 자기 구단 선수 영입 방지
    IF v_buyer_club_id = v_seller_club_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '자신의 구단 선수는 영입할 수 없습니다.';
    END IF;

    -- 5. 구매 구단 예산 확인
    SELECT current_budget INTO v_buyer_budget
    FROM CLUB WHERE club_id = v_buyer_club_id;

    IF v_buyer_budget < v_asking_fee THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '예산이 부족하여 영입이 불가능합니다.';
    END IF;

    -- 6. 기존 CONTRACT expired 처리
    UPDATE CONTRACT
    SET status = 'expired'
    WHERE player_id = v_player_id AND status = 'active';

    -- 7. 새 CONTRACT active 생성
    INSERT INTO CONTRACT (player_id, club_id, start_date, end_date, salary, status)
    VALUES (v_player_id, v_buyer_club_id, CURDATE(),
            DATE_ADD(CURDATE(), INTERVAL 3 YEAR), v_asking_fee * 0.1, 'active');

    -- 8. PLAYER.club_id 변경
    UPDATE PLAYER SET club_id = v_buyer_club_id WHERE player_id = v_player_id;

    -- 9. TRANSFER_HISTORY 기록 (예산 차감 전 먼저)
    --    → 트리거가 현재 예산 기준으로 체크하므로
    --      이 시점에 예산이 아직 차감되지 않아 트리거 정상 통과
    INSERT INTO TRANSFER_HISTORY
        (player_id, from_club_id, to_club_id, transfer_type, fee, transfer_date)
    VALUES
        (v_player_id, v_seller_club_id, v_buyer_club_id, 'transfer', v_asking_fee, CURDATE());

    -- 10. 구매 구단 예산 감소
    UPDATE CLUB SET current_budget = current_budget - v_asking_fee
    WHERE club_id = v_buyer_club_id;

    -- 11. 판매 구단 예산 증가
    UPDATE CLUB SET current_budget = current_budget + v_asking_fee
    WHERE club_id = v_seller_club_id;

    -- 12. 매물 상태 sold 변경
    UPDATE TRANSFER_MARKET SET status = 'sold' WHERE listing_id = p_listing_id;

    COMMIT;

    -- 영입 결과 확인
    SELECT
        p.name                  AS player_name,
        p.position,
        bc.name                 AS new_club,
        sc.name                 AS prev_club,
        FORMAT(v_asking_fee, 0) AS transfer_fee,
        FORMAT(bc.current_budget, 0) AS buyer_remaining_budget,
        FORMAT(sc.current_budget, 0) AS seller_remaining_budget
    FROM PLAYER p
    JOIN CLUB bc ON p.club_id        = bc.club_id
    JOIN CLUB sc ON v_seller_club_id = sc.club_id
    WHERE p.player_id = v_player_id;

END$$
DELIMITER ;


-- =====================================================
-- PROCEDURE 2. sp_release_player (선수 방출)
-- 호출 예시: CALL sp_release_player(1, 4);
--   p_user_id   : 방출을 진행하는 유저 ID
--   p_player_id : 방출할 선수 ID
--
-- 처리 순서:
--   1. 유저 구단 확인
--   2. 선수가 해당 구단 소속인지 확인
--   3. 기존 CONTRACT expired 처리
--   4. PLAYER.club_id = NULL
--   5. TRANSFER_HISTORY에 release 기록
--
-- ※ 방출 후 이적시장 등록은 하지 않음
--   (PLAYER.club_id = NULL이면 seller 트리거에서 차단)
-- =====================================================
DELIMITER $$
CREATE PROCEDURE sp_release_player(
    IN p_user_id   INT,
    IN p_player_id INT
)
BEGIN
    DECLARE v_club_id     INT;
    DECLARE v_player_club INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. 유저의 구단 조회
    SELECT club_id INTO v_club_id
    FROM APP_USER WHERE user_id = p_user_id;

    IF v_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '존재하지 않는 유저입니다.';
    END IF;

    -- 2. 선수가 해당 구단 소속인지 확인
    SELECT club_id INTO v_player_club
    FROM PLAYER WHERE player_id = p_player_id;

    IF v_player_club IS NULL OR v_player_club <> v_club_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '해당 구단 소속 선수가 아닙니다.';
    END IF;

    -- 3. 기존 CONTRACT expired 처리
    UPDATE CONTRACT
    SET status = 'expired'
    WHERE player_id = p_player_id AND status = 'active';

    -- 4. PLAYER.club_id = NULL (소속 없음)
    UPDATE PLAYER SET club_id = NULL WHERE player_id = p_player_id;

    -- 5. TRANSFER_HISTORY에 release 기록
    INSERT INTO TRANSFER_HISTORY
        (player_id, from_club_id, to_club_id, transfer_type, fee, transfer_date)
    VALUES
        (p_player_id, v_club_id, NULL, 'release', 0, CURDATE());

    COMMIT;

    -- 방출 결과 확인
    SELECT
        p.name    AS player_name,
        p.position,
        p.club_id AS current_club,  -- NULL이면 방출 완료
        p.nationality
    FROM PLAYER p WHERE p.player_id = p_player_id;

END$$
DELIMITER ;


-- =====================================================
-- PROCEDURE 3. sp_create_squad_battle (스쿼드 대결)
-- 호출 예시: CALL sp_create_squad_battle(1, 2);
--   p_home_club_id : 홈 구단 ID
--   p_away_club_id : 원정 구단 ID
--
-- 처리 순서:
--   1. 같은 구단끼리 대결 방지
--   2. fn_squad_score()로 양팀 점수 계산
--   3. 점수 비교 → result 결정
--   4. SQUAD_BATTLE에 저장
-- =====================================================
DELIMITER $$
CREATE PROCEDURE sp_create_squad_battle(
    IN p_home_club_id INT,
    IN p_away_club_id INT
)
BEGIN
    DECLARE v_home_score DECIMAL(6,2);
    DECLARE v_away_score DECIMAL(6,2);
    DECLARE v_result     VARCHAR(5);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. 같은 구단 대결 방지
    IF p_home_club_id = p_away_club_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '같은 구단끼리는 대결할 수 없습니다.';
    END IF;

    -- 2. 스쿼드 점수 계산
    SET v_home_score = fn_squad_score(p_home_club_id);
    SET v_away_score = fn_squad_score(p_away_club_id);

    -- 3. 결과 결정
    IF v_home_score > v_away_score THEN
        SET v_result = 'home';
    ELSEIF v_home_score < v_away_score THEN
        SET v_result = 'away';
    ELSE
        SET v_result = 'draw';
    END IF;

    -- 4. SQUAD_BATTLE에 저장
    INSERT INTO SQUAD_BATTLE
        (home_club_id, away_club_id, home_score, away_score, result, battle_date)
    VALUES
        (p_home_club_id, p_away_club_id, v_home_score, v_away_score, v_result, CURDATE());

    COMMIT;

    -- 대결 결과 확인
    SELECT
        hc.name      AS home_club,
        ac.name      AS away_club,
        v_home_score AS home_score,
        v_away_score AS away_score,
        v_result     AS result,
        CURDATE()    AS battle_date
    FROM CLUB hc, CLUB ac
    WHERE hc.club_id = p_home_club_id
      AND ac.club_id = p_away_club_id;

END$$
DELIMITER ;


-- =====================================================
-- 발표용 시연 순서
-- =====================================================

-- [STEP 1] 초기 상태 확인
SELECT '== 초기 스쿼드 점수 순위 ==' AS info;
SELECT * FROM V_SQUAD_SCORE ORDER BY squad_score DESC;

SELECT '== 초기 예산 현황 ==' AS info;
SELECT * FROM V_CLUB_BUDGET ORDER BY current_budget DESC;

SELECT '== 이적시장 매물 목록 ==' AS info;
SELECT * FROM V_TRANSFER_MARKET;

SELECT '== 계약 만료 임박 선수 ==' AS info;
SELECT * FROM V_EXPIRING_CONTRACTS;

-- [STEP 2] 영입 실행: 울산(user=1)이 양현준(listing=9) 영입
SELECT '== 영입 실행: 울산이 양현준(강원) 영입 ==' AS info;
CALL sp_buy_player(1, 9);

-- [STEP 3] 영입 후 상태 확인
SELECT '== 영입 후 예산 변화 ==' AS info;
SELECT name,
       FORMAT(initial_budget, 0)                        AS initial,
       FORMAT(current_budget, 0)                        AS current,
       FORMAT(initial_budget - current_budget, 0)       AS spent
FROM CLUB WHERE club_id IN (1, 9);

SELECT '== 영입 후 선수 소속 확인 ==' AS info;
SELECT player_id, name, club_id FROM PLAYER WHERE player_id = 36;

SELECT '== 계약 상태 변화 확인 ==' AS info;
SELECT contract_id, club_id, start_date, end_date, status
FROM CONTRACT WHERE player_id = 36 ORDER BY contract_id;

SELECT '== 이적 기록 확인 ==' AS info;
SELECT th.transfer_id, p.name AS player,
       fc.name AS from_club, tc.name AS to_club,
       th.transfer_type, FORMAT(th.fee, 0) AS fee, th.transfer_date
FROM TRANSFER_HISTORY th
JOIN  PLAYER p  ON th.player_id    = p.player_id
LEFT JOIN CLUB fc ON th.from_club_id = fc.club_id
LEFT JOIN CLUB tc ON th.to_club_id   = tc.club_id;

SELECT '== 매물 상태 변화 확인 ==' AS info;
SELECT * FROM TRANSFER_MARKET WHERE player_id = 36;

-- [STEP 4] 방출 실행: 울산(user=1)이 레오나르도(player=4) 방출
SELECT '== 방출 실행: 울산이 레오나르도 방출 ==' AS info;
CALL sp_release_player(1, 4);

SELECT '== 방출 후 선수 소속 확인 (NULL = 방출 완료) ==' AS info;
SELECT player_id, name, club_id FROM PLAYER WHERE player_id = 4;

SELECT '== 방출 후 이적 기록 확인 ==' AS info;
SELECT th.transfer_id, p.name AS player,
       fc.name AS from_club, tc.name AS to_club,
       th.transfer_type, FORMAT(th.fee, 0) AS fee, th.transfer_date
FROM TRANSFER_HISTORY th
JOIN  PLAYER p  ON th.player_id    = p.player_id
LEFT JOIN CLUB fc ON th.from_club_id = fc.club_id
LEFT JOIN CLUB tc ON th.to_club_id   = tc.club_id;

-- [STEP 5] 이미 거래된 매물 재영입 시도 (에러 시연)
SELECT '== 에러 시연: 이미 sold된 매물 재영입 시도 ==' AS info;
-- CALL sp_buy_player(1, 9);  -- 주석 해제하면 에러 메시지 확인 가능

-- [STEP 6] 스쿼드 대결: 울산(1) vs 전북(2)
SELECT '== 스쿼드 대결: 울산 vs 전북 ==' AS info;
CALL sp_create_squad_battle(1, 2);

-- [STEP 7] 최종 상태 확인
SELECT '== 최종 스쿼드 점수 순위 ==' AS info;
SELECT * FROM V_SQUAD_SCORE ORDER BY squad_score DESC;

SELECT '== 대결 결과 전체 ==' AS info;
SELECT hc.name AS home_club, ac.name AS away_club,
       sb.home_score, sb.away_score, sb.result, sb.battle_date
FROM SQUAD_BATTLE sb
JOIN CLUB hc ON sb.home_club_id = hc.club_id
JOIN CLUB ac ON sb.away_club_id = ac.club_id;

