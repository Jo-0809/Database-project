-- =====================================================
-- K리그 DB 구축 확인 쿼리
-- =====================================================

USE kleague_db;

-- ─────────────────────────────────────────────────
-- 1. 테이블 / 뷰 / 트리거 / 프로시저 목록
-- ─────────────────────────────────────────────────
SHOW TABLES;
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW TRIGGERS;
SHOW PROCEDURE STATUS WHERE Db = 'kleague_db';

-- ─────────────────────────────────────────────────
-- 2. 데이터 건수 확인
-- ─────────────────────────────────────────────────
SELECT COUNT(*) AS clubs          FROM CLUB;
SELECT COUNT(*) AS players        FROM PLAYER;
SELECT COUNT(*) AS player_stats   FROM PLAYER_STATS;
SELECT COUNT(*) AS contracts      FROM CONTRACT;
SELECT COUNT(*) AS market_items   FROM TRANSFER_MARKET;
SELECT COUNT(*) AS seasons        FROM SEASON;

-- ─────────────────────────────────────────────────
-- 3. 뷰 조회
-- ─────────────────────────────────────────────────
SELECT * FROM V_CLUB_BUDGET        ORDER BY current_budget DESC;
SELECT * FROM V_SQUAD_SCORE        ORDER BY squad_score DESC;
SELECT * FROM V_TRANSFER_MARKET    LIMIT 20;
SELECT * FROM V_EXPIRING_CONTRACTS LIMIT 20;
SELECT * FROM V_SEASON_STANDING;
SELECT * FROM V_CHAMPION_HISTORY;

-- ─────────────────────────────────────────────────
-- 4. 프로시저 테스트
--    user_id 1 = FC Seoul (club_id 1)
--    user_id 2 = Ulsan   (club_id 2)
--    listing 1~11  = FC Seoul 매물
--    listing 12~22 = Ulsan   매물
-- ─────────────────────────────────────────────────

-- 스쿼드 대결 (FC Seoul vs Ulsan)
CALL sp_create_squad_battle(1, 2);
SELECT * FROM SQUAD_BATTLE ORDER BY battle_id DESC LIMIT 3;

-- FC Seoul(user=1)이 Ulsan(club=2) 매물 12번 영입
CALL sp_buy_player(1, 12);

-- Ulsan(user=2)이 선수 방출 (Ulsan 소속 선수 player_id 확인 후 사용)
-- CALL sp_release_player(2, <player_id>);

-- FC Seoul(user=1) 선수를 이적시장에 등록
-- CALL sp_list_player_for_transfer(1, <player_id>, 500000);

-- 이적시장 등록 취소
-- CALL sp_cancel_listing(1, <listing_id>);

-- 시즌 종료 + 새 시즌 시작
-- CALL sp_start_new_season('2026 K리그1');

-- ─────────────────────────────────────────────────
-- 5. 감사 로그 확인
-- ─────────────────────────────────────────────────
SELECT * FROM V_AUDIT_RECENT LIMIT 20;
