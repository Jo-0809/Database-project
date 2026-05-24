-- =====================================================
-- K리그 DB 확장: ① 시즌(SEASON) 시스템 + ② 감사 로그(AUDIT_LOG)
-- =====================================================
-- 본 스크립트는 kleague_ddl.sql 실행 후 1회 적용합니다.
-- 재실행 시 기존 트리거/뷰는 DROP 후 재생성됩니다.
-- =====================================================

USE kleague_db;

-- =====================================================
-- ① SEASON 테이블
--    시간 차원을 도입하여 시즌별 성적/이적/우승을 분리 집계
-- =====================================================
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS SEASON_TMP;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE IF NOT EXISTS SEASON (
    season_id        INT          NOT NULL AUTO_INCREMENT,
    season_name      VARCHAR(20)  NOT NULL UNIQUE,
    start_date       DATE         NOT NULL,
    end_date         DATE         NULL,
    status           VARCHAR(10)  NOT NULL DEFAULT 'active',
    champion_club_id INT          NULL,

    PRIMARY KEY (season_id),
    FOREIGN KEY (champion_club_id) REFERENCES CLUB(club_id),
    CONSTRAINT chk_season_status CHECK (status IN ('active', 'ended'))
);

-- 초기 시즌 1개 보장 (이미 있으면 무시)
INSERT IGNORE INTO SEASON (season_name, start_date, status)
VALUES ('2024-25', '2024-07-01', 'active');

-- =====================================================
--    기존 테이블에 season_id 컬럼 추가 (멱등 처리)
-- =====================================================
-- SQUAD_BATTLE.season_id
SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'SQUAD_BATTLE'
      AND COLUMN_NAME  = 'season_id'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE SQUAD_BATTLE
        ADD COLUMN season_id INT NULL,
        ADD CONSTRAINT fk_battle_season FOREIGN KEY (season_id) REFERENCES SEASON(season_id)',
    'SELECT "SQUAD_BATTLE.season_id already exists" AS info'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- TRANSFER_HISTORY.season_id
SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'TRANSFER_HISTORY'
      AND COLUMN_NAME  = 'season_id'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE TRANSFER_HISTORY
        ADD COLUMN season_id INT NULL,
        ADD CONSTRAINT fk_transfer_season FOREIGN KEY (season_id) REFERENCES SEASON(season_id)',
    'SELECT "TRANSFER_HISTORY.season_id already exists" AS info'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 기존 NULL 데이터에 현재 시즌 할당
UPDATE SQUAD_BATTLE
SET season_id = (SELECT season_id FROM SEASON WHERE status='active' LIMIT 1)
WHERE season_id IS NULL;

UPDATE TRANSFER_HISTORY
SET season_id = (SELECT season_id FROM SEASON WHERE status='active' LIMIT 1)
WHERE season_id IS NULL;


-- =====================================================
-- ② AUDIT_LOG 테이블
--    PLAYER / CLUB / CONTRACT / TRANSFER_MARKET 변경을
--    트리거가 자동 기록 (행위자 = @app_user_id 세션 변수)
-- =====================================================
DROP TABLE IF EXISTS AUDIT_LOG;

CREATE TABLE AUDIT_LOG (
    audit_id   INT          NOT NULL AUTO_INCREMENT,
    table_name VARCHAR(30)  NOT NULL,
    action     VARCHAR(10)  NOT NULL,
    record_id  INT          NULL,
    old_value  TEXT         NULL,
    new_value  TEXT         NULL,
    changed_by INT          NULL,
    changed_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    note       VARCHAR(200) NULL,

    PRIMARY KEY (audit_id),
    CONSTRAINT chk_audit_action CHECK (action IN ('INSERT','UPDATE','DELETE'))
);

CREATE INDEX idx_audit_table_time ON AUDIT_LOG(table_name, changed_at DESC);
CREATE INDEX idx_audit_user_time  ON AUDIT_LOG(changed_by, changed_at DESC);


-- =====================================================
--   감사 트리거 1. PLAYER (소속 변동 추적)
-- =====================================================
DROP TRIGGER IF EXISTS trg_audit_player_update;
DELIMITER $$
CREATE TRIGGER trg_audit_player_update
AFTER UPDATE ON PLAYER
FOR EACH ROW
BEGIN
    IF NOT (OLD.club_id <=> NEW.club_id) THEN
        INSERT INTO AUDIT_LOG
            (table_name, action, record_id, old_value, new_value, changed_by, note)
        VALUES (
            'PLAYER', 'UPDATE', NEW.player_id,
            CONCAT('club_id=', IFNULL(OLD.club_id, 'NULL')),
            CONCAT('club_id=', IFNULL(NEW.club_id, 'NULL')),
            @app_user_id,
            CONCAT(NEW.name, ' 소속 변경')
        );
    END IF;
END$$
DELIMITER ;

-- =====================================================
--   감사 트리거 2. CLUB (예산 변동 추적)
-- =====================================================
DROP TRIGGER IF EXISTS trg_audit_club_update;
DELIMITER $$
CREATE TRIGGER trg_audit_club_update
AFTER UPDATE ON CLUB
FOR EACH ROW
BEGIN
    IF OLD.current_budget <> NEW.current_budget THEN
        INSERT INTO AUDIT_LOG
            (table_name, action, record_id, old_value, new_value, changed_by, note)
        VALUES (
            'CLUB', 'UPDATE', NEW.club_id,
            CONCAT('current_budget=', FORMAT(OLD.current_budget, 0)),
            CONCAT('current_budget=', FORMAT(NEW.current_budget, 0)),
            @app_user_id,
            CONCAT(NEW.name, ' 예산 ',
                IF(NEW.current_budget > OLD.current_budget, '+', ''),
                FORMAT(NEW.current_budget - OLD.current_budget, 0), '원')
        );
    END IF;
END$$
DELIMITER ;

-- =====================================================
--   감사 트리거 3. CONTRACT (계약 생성/상태 변경)
-- =====================================================
DROP TRIGGER IF EXISTS trg_audit_contract_insert;
DROP TRIGGER IF EXISTS trg_audit_contract_update;
DELIMITER $$
CREATE TRIGGER trg_audit_contract_insert
AFTER INSERT ON CONTRACT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG
        (table_name, action, record_id, new_value, changed_by, note)
    VALUES (
        'CONTRACT', 'INSERT', NEW.contract_id,
        CONCAT('player_id=', NEW.player_id,
               ', club_id=', NEW.club_id,
               ', salary=', FORMAT(NEW.salary, 0)),
        @app_user_id,
        '신규 계약 체결'
    );
END$$

CREATE TRIGGER trg_audit_contract_update
AFTER UPDATE ON CONTRACT
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO AUDIT_LOG
            (table_name, action, record_id, old_value, new_value, changed_by, note)
        VALUES (
            'CONTRACT', 'UPDATE', NEW.contract_id,
            CONCAT('status=', OLD.status),
            CONCAT('status=', NEW.status),
            @app_user_id,
            CONCAT('계약 상태: ', OLD.status, ' → ', NEW.status)
        );
    END IF;
END$$
DELIMITER ;

-- =====================================================
--   감사 트리거 4. TRANSFER_MARKET (매물 등록/거래)
-- =====================================================
DROP TRIGGER IF EXISTS trg_audit_market_insert;
DROP TRIGGER IF EXISTS trg_audit_market_update;
DELIMITER $$
CREATE TRIGGER trg_audit_market_insert
AFTER INSERT ON TRANSFER_MARKET
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG
        (table_name, action, record_id, new_value, changed_by, note)
    VALUES (
        'TRANSFER_MARKET', 'INSERT', NEW.listing_id,
        CONCAT('player_id=', NEW.player_id,
               ', asking_fee=', FORMAT(NEW.asking_fee, 0)),
        @app_user_id,
        '이적시장 신규 등록'
    );
END$$

CREATE TRIGGER trg_audit_market_update
AFTER UPDATE ON TRANSFER_MARKET
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO AUDIT_LOG
            (table_name, action, record_id, old_value, new_value, changed_by, note)
        VALUES (
            'TRANSFER_MARKET', 'UPDATE', NEW.listing_id,
            CONCAT('status=', OLD.status),
            CONCAT('status=', NEW.status),
            @app_user_id,
            CONCAT('매물 상태: ', OLD.status, ' → ', NEW.status)
        );
    END IF;
END$$
DELIMITER ;


-- =====================================================
-- 시즌 관련 분석 뷰
-- =====================================================

-- 1) 현재 시즌 순위표 (승=3, 무=1, 패=0)
DROP VIEW IF EXISTS V_SEASON_STANDING;
CREATE VIEW V_SEASON_STANDING AS
SELECT
    c.club_id,
    c.name AS club_name,
    s.season_id,
    s.season_name,
    COUNT(sb.battle_id) AS played,
    SUM(CASE
        WHEN (sb.home_club_id = c.club_id AND sb.result = 'home')
          OR (sb.away_club_id = c.club_id AND sb.result = 'away') THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN sb.result = 'draw'
              AND (sb.home_club_id = c.club_id OR sb.away_club_id = c.club_id)
             THEN 1 ELSE 0 END) AS draws,
    SUM(CASE
        WHEN (sb.home_club_id = c.club_id AND sb.result = 'away')
          OR (sb.away_club_id = c.club_id AND sb.result = 'home') THEN 1 ELSE 0 END) AS losses,
    SUM(CASE
        WHEN (sb.home_club_id = c.club_id AND sb.result = 'home')
          OR (sb.away_club_id = c.club_id AND sb.result = 'away') THEN 3
        WHEN sb.result = 'draw'
         AND (sb.home_club_id = c.club_id OR sb.away_club_id = c.club_id) THEN 1
        ELSE 0 END) AS points
FROM CLUB c
CROSS JOIN SEASON s
LEFT JOIN SQUAD_BATTLE sb
    ON (sb.home_club_id = c.club_id OR sb.away_club_id = c.club_id)
   AND sb.season_id = s.season_id
WHERE s.status = 'active'
GROUP BY c.club_id, c.name, s.season_id, s.season_name;

-- 2) 시즌별 최다 이적료 TOP N (윈도우 함수 RANK 사용)
DROP VIEW IF EXISTS V_SEASON_TOP_TRANSFERS;
CREATE VIEW V_SEASON_TOP_TRANSFERS AS
SELECT
    s.season_name,
    p.name      AS player_name,
    fc.name     AS from_club,
    tc.name     AS to_club,
    th.fee,
    th.transfer_date,
    RANK() OVER (PARTITION BY th.season_id ORDER BY th.fee DESC) AS fee_rank
FROM TRANSFER_HISTORY th
JOIN SEASON s ON th.season_id = s.season_id
JOIN PLAYER p ON th.player_id = p.player_id
LEFT JOIN CLUB fc ON th.from_club_id = fc.club_id
LEFT JOIN CLUB tc ON th.to_club_id   = tc.club_id
WHERE th.transfer_type = 'transfer' AND th.fee > 0;

-- 3) 역대 우승 기록
DROP VIEW IF EXISTS V_CHAMPION_HISTORY;
CREATE VIEW V_CHAMPION_HISTORY AS
SELECT
    s.season_id,
    s.season_name,
    s.start_date,
    s.end_date,
    c.name AS champion_club
FROM SEASON s
LEFT JOIN CLUB c ON s.champion_club_id = c.club_id
WHERE s.status = 'ended'
ORDER BY s.end_date DESC;

-- 4) 감사 로그 조회 뷰 (사용자명 JOIN)
DROP VIEW IF EXISTS V_AUDIT_RECENT;
CREATE VIEW V_AUDIT_RECENT AS
SELECT
    al.audit_id,
    al.changed_at,
    IFNULL(u.username, '(system)') AS changed_by,
    al.table_name,
    al.action,
    al.record_id,
    al.note,
    al.old_value,
    al.new_value
FROM AUDIT_LOG al
LEFT JOIN APP_USER u ON al.changed_by = u.user_id
ORDER BY al.changed_at DESC, al.audit_id DESC;


-- =====================================================
-- ③ PLAYER(club_id) 인덱스 추가 (멱등 처리)
--    구단별 선수 목록 조회, 스쿼드 카운트 등 빈번한
--    WHERE club_id = ? 쿼리 성능 최적화
-- =====================================================
SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'PLAYER'
      AND INDEX_NAME   = 'idx_player_club'
);
SET @sql := IF(@idx_exists = 0,
    'CREATE INDEX idx_player_club ON PLAYER(club_id)',
    'SELECT "idx_player_club already exists" AS info'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
