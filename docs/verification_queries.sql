USE kleague_db;

-- =========================================================
-- 0) 기본 상태 확인
-- =========================================================
SELECT COUNT(*) AS club_count FROM clubs;
SELECT COUNT(*) AS player_count FROM players;
SELECT COUNT(*) AS listed_market_count FROM transfer_market WHERE status = 'listed';

SELECT club_id, club_name, current_budget_krw, total_spent_krw
FROM clubs
ORDER BY club_id
LIMIT 12;

-- =========================================================
-- 0-1) 금액 스케일 검증 (KRW)
--      참고: 급여는 players 테이블이 아니라 contracts.salary_krw에 저장됨
-- =========================================================
SELECT 
    MIN(p.market_value_krw) AS min_market_value_krw,
    AVG(p.market_value_krw) AS avg_market_value_krw,
    MAX(p.market_value_krw) AS max_market_value_krw
FROM players p
WHERE p.market_value_krw > 0;

SELECT 
    MIN(tm.asking_fee_krw) AS min_asking_fee_krw,
    AVG(tm.asking_fee_krw) AS avg_asking_fee_krw,
    MAX(tm.asking_fee_krw) AS max_asking_fee_krw
FROM transfer_market tm;

SELECT 
    MIN(ct.salary_krw) AS min_salary_krw,
    AVG(ct.salary_krw) AS avg_salary_krw,
    MAX(ct.salary_krw) AS max_salary_krw
FROM contracts ct
WHERE ct.status = 'active';

SELECT 
    p.player_name,
    p.market_value_krw,
    ct.salary_krw,
    ROUND(ct.salary_krw / NULLIF(p.market_value_krw, 0), 4) AS salary_to_value_ratio
FROM players p
JOIN contracts ct
  ON ct.player_id = p.player_id
 AND ct.status = 'active'
WHERE p.market_value_krw > 0
ORDER BY salary_to_value_ratio DESC
LIMIT 10;

-- =========================================================
-- 1) 정상 구매 시나리오
--    기준: listing_id=1, user_id=2
-- =========================================================
SET @buyer_user_id := 2;
SET @listing_id := 1;

SELECT listing_id, player_id, seller_club_id, asking_fee_krw, status
FROM transfer_market
WHERE listing_id = @listing_id;

SELECT au.club_id INTO @buyer_club_id
FROM app_users au
WHERE au.user_id = @buyer_user_id;

SELECT tm.player_id, tm.seller_club_id, tm.asking_fee_krw
INTO @player_id, @seller_club_id, @fee_krw
FROM transfer_market tm
WHERE tm.listing_id = @listing_id;

SELECT current_budget_krw, total_spent_krw
INTO @before_budget_krw, @before_spent_krw
FROM clubs
WHERE club_id = @buyer_club_id;

CALL sp_buy_player(@buyer_user_id, @listing_id);

-- =========================================================
-- 2) 구매 후 검증
--    - 선수 소속 변경
--    - 예산 차감
--    - total_spent_krw 증가
--    - transfer_history 기록
--    - transfer_market.status='sold'
-- =========================================================
SELECT player_id, club_id AS current_club_id
FROM players
WHERE player_id = @player_id;

SELECT listing_id, status
FROM transfer_market
WHERE listing_id = @listing_id;

SELECT transfer_id, player_id, from_club_id, to_club_id, fee_krw, transfer_date
FROM transfer_history
WHERE player_id = @player_id
ORDER BY transfer_id DESC
LIMIT 1;

SELECT c.club_id,
       c.current_budget_krw,
       c.total_spent_krw,
       @before_budget_krw - c.current_budget_krw AS budget_decrease,
       c.total_spent_krw - @before_spent_krw AS spent_increase,
       @fee_krw AS expected_fee_krw,
       CASE WHEN @before_budget_krw - c.current_budget_krw = @fee_krw THEN 'PASS' ELSE 'FAIL' END AS budget_delta_check,
       CASE WHEN c.total_spent_krw - @before_spent_krw = @fee_krw THEN 'PASS' ELSE 'FAIL' END AS spent_delta_check
FROM clubs c
WHERE c.club_id = @buyer_club_id;

-- =========================================================
-- 3) 이미 판매된 선수 재구매 실패 (예상: 오류)
-- =========================================================
-- EXPECTED ERROR: Listing is not listed
CALL sp_buy_player(@buyer_user_id, @listing_id);

-- =========================================================
-- 4) 없는 listing 구매 실패 (예상: 오류)
-- =========================================================
-- EXPECTED ERROR: Listing does not exist
CALL sp_buy_player(@buyer_user_id, 999999);

-- =========================================================
-- 5) 예산 부족 구매 실패 (예상: 오류)
--    테스트 후 원상복구
-- =========================================================
SET @budget_test_listing := (
    SELECT listing_id
    FROM transfer_market
    WHERE status = 'listed'
      AND seller_club_id <> @buyer_club_id
    ORDER BY listing_id
    LIMIT 1
);

SELECT asking_fee_krw INTO @budget_test_fee_backup
FROM transfer_market
WHERE listing_id = @budget_test_listing;

UPDATE transfer_market
SET asking_fee_krw = 999999999999
WHERE listing_id = @budget_test_listing;

-- EXPECTED ERROR: Not enough budget
CALL sp_buy_player(@buyer_user_id, @budget_test_listing);

UPDATE transfer_market
SET asking_fee_krw = @budget_test_fee_backup
WHERE listing_id = @budget_test_listing;
