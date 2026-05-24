-- =====================================================
-- K리그 이적시장 기반 스토브리그 체험 DB 시스템
-- 통합 실행 파일 (Full Setup)
--
-- 이 파일 하나만 실행하면 전체 DB가 구축됩니다.
-- MySQL Workbench에서 열고 전체 실행(Ctrl+Shift+Enter)
--
-- 포함 순서:
--   1. kleague_ddl.sql          ← DB 구조 생성
--   2. kleague_dml_base.sql     ← 구단/감독/유저/이적시장 기본 데이터
--   3. kleague_dml_sample.sql   ← 선수 132명 데이터
--   4. kleague_extensions.sql   ← 시즌/감사로그/트리거/뷰/인덱스
--   5. kleague_procedures.sql   ← 프로시저 6개
-- =====================================================


-- ※ 이 파일을 실행하기 전에 csv_to_sql.py 를 먼저 실행하세요.
--   python csv_to_sql.py
--   → kleague_dml_base.sql, kleague_dml_sample.sql 자동 생성

-- =====================================================
-- [1/5] DDL — DB 구조 생성
-- =====================================================

SOURCE kleague_ddl.sql;


-- =====================================================
-- [2/5] DML BASE — 구단 / 감독 / 유저 / 이적시장
-- =====================================================

SOURCE kleague_dml_base.sql;


-- =====================================================
-- [3/5] DML SAMPLE — 선수 132명 (포지션/능력치/계약)
-- =====================================================

SOURCE kleague_dml_sample.sql;


-- =====================================================
-- [4/5] EXTENSIONS — 시즌·감사로그·트리거·뷰·인덱스
-- =====================================================

SOURCE kleague_extensions.sql;


-- =====================================================
-- [5/5] PROCEDURES — 영입/방출/대결/이적등록/취소/시즌전환
-- =====================================================

SOURCE kleague_procedures.sql;


-- =====================================================
-- 구축 완료 확인 쿼리
-- =====================================================

USE kleague_db;

SELECT '===== 테이블 현황 =====' AS info;
SELECT TABLE_NAME, TABLE_ROWS
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'kleague_db' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT '===== 뷰 현황 =====' AS info;
SHOW FULL TABLES WHERE Table_type = 'VIEW';

SELECT '===== 트리거 현황 =====' AS info;
SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = 'kleague_db';

SELECT '===== 프로시저 현황 =====' AS info;
SHOW PROCEDURE STATUS WHERE Db = 'kleague_db';

SELECT '===== 데이터 확인 =====' AS info;
SELECT
    (SELECT COUNT(*) FROM CLUB)              AS clubs,
    (SELECT COUNT(*) FROM PLAYER)            AS players,
    (SELECT COUNT(*) FROM PLAYER_STATS)      AS player_stats,
    (SELECT COUNT(*) FROM CONTRACT)          AS contracts,
    (SELECT COUNT(*) FROM TRANSFER_MARKET)   AS transfer_market,
    (SELECT COUNT(*) FROM APP_USER)          AS app_users,
    (SELECT season_name FROM SEASON WHERE status='active' LIMIT 1) AS active_season;

SELECT '===== 스쿼드 점수 순위 =====' AS info;
SELECT club_name, manager_name, tactics, avg_overall, squad_score
FROM V_SQUAD_SCORE ORDER BY squad_score DESC;
