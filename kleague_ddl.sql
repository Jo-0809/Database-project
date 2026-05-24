-- =====================================================
-- K리그 이적시장 기반 스토브리그 체험 DB 시스템
-- DDL (Data Definition Language)
-- ※ 재실행 시 기존 DB 삭제 후 새로 생성
-- =====================================================

DROP DATABASE IF EXISTS kleague_db;

CREATE DATABASE kleague_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE kleague_db;

-- =====================================================
-- 1. CLUB (구단)
-- =====================================================
CREATE TABLE CLUB (
    club_id          INT            NOT NULL AUTO_INCREMENT,
    name             VARCHAR(100)   NOT NULL,
    city             VARCHAR(80)    NOT NULL,
    founded_year     YEAR           NOT NULL,
    stadium_name     VARCHAR(120)   NOT NULL,
    stadium_capacity INT            NOT NULL,
    initial_budget   DECIMAL(15,2)  NOT NULL,
    current_budget   DECIMAL(15,2)  NOT NULL,

    PRIMARY KEY (club_id),

    CONSTRAINT chk_stadium_capacity CHECK (stadium_capacity > 0),
    CONSTRAINT chk_initial_budget   CHECK (initial_budget >= 0),
    CONSTRAINT chk_current_budget   CHECK (current_budget >= 0)
);

-- =====================================================
-- 2. MANAGER (감독)
-- =====================================================
CREATE TABLE MANAGER (
    manager_id  INT          NOT NULL AUTO_INCREMENT,
    club_id     INT          NOT NULL UNIQUE,
    name        VARCHAR(50)  NOT NULL,
    nationality VARCHAR(30)  NOT NULL,
    birth_date  DATE         NOT NULL,
    tactics     VARCHAR(20)  NOT NULL,
    rating      INT          NOT NULL,

    PRIMARY KEY (manager_id),
    FOREIGN KEY (club_id) REFERENCES CLUB(club_id),

    CONSTRAINT chk_manager_rating CHECK (rating BETWEEN 1 AND 99)
);

-- =====================================================
-- 3. PLAYER (선수)
-- =====================================================
CREATE TABLE PLAYER (
    player_id   INT          NOT NULL AUTO_INCREMENT,
    club_id     INT          NULL,
    name        VARCHAR(50)  NOT NULL,
    nationality VARCHAR(30)  NOT NULL,
    birth_date  DATE         NOT NULL,
    position    VARCHAR(10)  NOT NULL,
    height      INT          NULL,
    weight      INT          NULL,

    PRIMARY KEY (player_id),
    FOREIGN KEY (club_id) REFERENCES CLUB(club_id),

    CONSTRAINT chk_position CHECK (position IN ('GK', 'DF', 'MF', 'FW')),
    CONSTRAINT chk_height   CHECK (height BETWEEN 140 AND 220),
    CONSTRAINT chk_weight   CHECK (weight BETWEEN 40 AND 150)
);

-- =====================================================
-- 4. PLAYER_STATS (선수 능력치)
-- =====================================================
CREATE TABLE PLAYER_STATS (
    stat_id    INT           NOT NULL AUTO_INCREMENT,
    player_id  INT           NOT NULL UNIQUE,
    attack     INT           NOT NULL,
    defense    INT           NOT NULL,
    stamina    INT           NOT NULL,
    speed      INT           NOT NULL,
    overall    DECIMAL(5,2)  GENERATED ALWAYS AS
                   (ROUND((attack + defense + stamina + speed) / 4, 2)) STORED,

    PRIMARY KEY (stat_id),
    FOREIGN KEY (player_id) REFERENCES PLAYER(player_id),

    CONSTRAINT chk_attack  CHECK (attack  BETWEEN 1 AND 99),
    CONSTRAINT chk_defense CHECK (defense BETWEEN 1 AND 99),
    CONSTRAINT chk_stamina CHECK (stamina BETWEEN 1 AND 99),
    CONSTRAINT chk_speed   CHECK (speed   BETWEEN 1 AND 99)
);

-- =====================================================
-- 5. CONTRACT (계약)
-- =====================================================
CREATE TABLE CONTRACT (
    contract_id INT            NOT NULL AUTO_INCREMENT,
    player_id   INT            NOT NULL,
    club_id     INT            NOT NULL,
    start_date  DATE           NOT NULL,
    end_date    DATE           NULL,     -- NULL = 계약 종료일 미정
    salary      DECIMAL(12,2)  NOT NULL,
    status      VARCHAR(10)    NOT NULL DEFAULT 'active',

    PRIMARY KEY (contract_id),
    FOREIGN KEY (player_id) REFERENCES PLAYER(player_id),
    FOREIGN KEY (club_id)   REFERENCES CLUB(club_id),

    CONSTRAINT chk_contract_date   CHECK (end_date IS NULL OR end_date > start_date),
    CONSTRAINT chk_salary          CHECK (salary >= 0),
    CONSTRAINT chk_contract_status CHECK (status IN ('active', 'expired'))
);

-- =====================================================
-- 6. TRANSFER_HISTORY (이적 기록)
-- =====================================================
CREATE TABLE TRANSFER_HISTORY (
    transfer_id   INT            NOT NULL AUTO_INCREMENT,
    player_id     INT            NOT NULL,
    from_club_id  INT            NULL,
    to_club_id    INT            NULL,
    transfer_type VARCHAR(15)    NOT NULL,
    fee           DECIMAL(15,2)  NOT NULL DEFAULT 0,
    transfer_date DATE           NOT NULL,

    PRIMARY KEY (transfer_id),
    FOREIGN KEY (player_id)    REFERENCES PLAYER(player_id),
    FOREIGN KEY (from_club_id) REFERENCES CLUB(club_id),
    FOREIGN KEY (to_club_id)   REFERENCES CLUB(club_id),

    CONSTRAINT chk_transfer_type CHECK (transfer_type IN
        ('transfer', 'loan', 'free_agent', 'rookie', 'release')),
    CONSTRAINT chk_fee       CHECK (fee >= 0),
    CONSTRAINT chk_diff_club CHECK (from_club_id != to_club_id)
);

-- =====================================================
-- 7. SQUAD_BATTLE (스쿼드 대결)
-- =====================================================
CREATE TABLE SQUAD_BATTLE (
    battle_id     INT           NOT NULL AUTO_INCREMENT,
    home_club_id  INT           NOT NULL,
    away_club_id  INT           NOT NULL,
    home_score    DECIMAL(6,2)  NOT NULL,
    away_score    DECIMAL(6,2)  NOT NULL,
    result        VARCHAR(5)    NOT NULL,
    battle_date   DATE          NOT NULL,

    PRIMARY KEY (battle_id),
    FOREIGN KEY (home_club_id) REFERENCES CLUB(club_id),
    FOREIGN KEY (away_club_id) REFERENCES CLUB(club_id),

    CONSTRAINT chk_diff_battle_club CHECK (home_club_id != away_club_id),
    CONSTRAINT chk_result           CHECK (result IN ('home', 'away', 'draw')),
    CONSTRAINT chk_home_score       CHECK (home_score >= 0),
    CONSTRAINT chk_away_score       CHECK (away_score >= 0)
);

-- =====================================================
-- 8. APP_USER (유저)
-- =====================================================
CREATE TABLE APP_USER (
    user_id   INT          NOT NULL AUTO_INCREMENT,
    username  VARCHAR(30)  NOT NULL,
    club_id   INT          NOT NULL,

    PRIMARY KEY (user_id),
    FOREIGN KEY (club_id) REFERENCES CLUB(club_id)
);

-- =====================================================
-- 9. TRANSFER_MARKET (이적시장 매물)
-- =====================================================
CREATE TABLE TRANSFER_MARKET (
    listing_id     INT            NOT NULL AUTO_INCREMENT,
    player_id      INT            NOT NULL,
    seller_club_id INT            NOT NULL,
    asking_fee     DECIMAL(15,2)  NOT NULL,
    listed_date    DATE           NOT NULL,
    status         VARCHAR(10)    NOT NULL DEFAULT 'available',

    PRIMARY KEY (listing_id),
    FOREIGN KEY (player_id)      REFERENCES PLAYER(player_id),
    FOREIGN KEY (seller_club_id) REFERENCES CLUB(club_id),

    CONSTRAINT chk_asking_fee    CHECK (asking_fee >= 0),
    CONSTRAINT chk_market_status CHECK (status IN ('available', 'sold', 'cancelled'))
);

-- =====================================================
-- VIEW 1. 구단별 예산 현황
-- =====================================================
CREATE VIEW V_CLUB_BUDGET AS
SELECT
    c.club_id,
    c.name,
    c.initial_budget,
    c.current_budget,
    c.initial_budget - c.current_budget AS total_spent
FROM CLUB c;

-- =====================================================
-- VIEW 2. 선수 정보 + 능력치 통합 조회
-- =====================================================
CREATE VIEW V_PLAYER_INFO AS
SELECT
    p.player_id,
    p.name          AS player_name,
    p.position,
    p.nationality,
    c.name          AS club_name,
    ps.attack,
    ps.defense,
    ps.stamina,
    ps.speed,
    ps.overall
FROM PLAYER p
LEFT JOIN CLUB         c  ON p.club_id   = c.club_id
LEFT JOIN PLAYER_STATS ps ON p.player_id = ps.player_id;

-- =====================================================
-- VIEW 3. 구단별 스쿼드 점수
-- (선수 overall 평균 80% + 감독 rating 20%)
-- =====================================================
CREATE VIEW V_SQUAD_SCORE AS
SELECT
    c.club_id,
    c.name                                             AS club_name,
    m.name                                             AS manager_name,
    m.tactics,
    ROUND(AVG(ps.overall), 2)                         AS avg_overall,
    m.rating                                           AS manager_rating,
    ROUND(AVG(ps.overall) * 0.8 + m.rating * 0.2, 2) AS squad_score
FROM CLUB c
JOIN PLAYER       p  ON p.club_id   = c.club_id
JOIN PLAYER_STATS ps ON p.player_id = ps.player_id
JOIN MANAGER      m  ON m.club_id   = c.club_id
GROUP BY c.club_id, c.name, m.name, m.tactics, m.rating;

-- =====================================================
-- VIEW 4. 계약 만료 임박 선수 (6개월 이내)
-- =====================================================
CREATE VIEW V_EXPIRING_CONTRACTS AS
SELECT
    p.name                                AS player_name,
    p.position,
    c.name                                AS club_name,
    ct.end_date,
    DATEDIFF(ct.end_date, CURDATE())      AS days_remaining
FROM CONTRACT ct
JOIN PLAYER p ON ct.player_id = p.player_id
JOIN CLUB   c ON ct.club_id   = c.club_id
WHERE ct.status = 'active'
  AND ct.end_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 6 MONTH)
ORDER BY days_remaining;

-- =====================================================
-- VIEW 5. 이적시장 매물 조회 (선수 정보 포함)
-- =====================================================
CREATE VIEW V_TRANSFER_MARKET AS
SELECT
    tm.listing_id,
    p.name          AS player_name,
    p.position,
    p.nationality,
    ps.overall,
    sc.name         AS seller_club,
    tm.asking_fee,
    tm.listed_date,
    tm.status
FROM TRANSFER_MARKET tm
JOIN PLAYER       p  ON tm.player_id      = p.player_id
JOIN PLAYER_STATS ps ON p.player_id       = ps.player_id
JOIN CLUB         sc ON tm.seller_club_id = sc.club_id
WHERE tm.status = 'available'
ORDER BY ps.overall DESC;

-- =====================================================
-- TRIGGER 1. 예산 초과 영입 차단
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_check_budget
BEFORE INSERT ON TRANSFER_HISTORY
FOR EACH ROW
BEGIN
    DECLARE v_budget DECIMAL(15,2);

    IF NEW.to_club_id IS NOT NULL THEN
        SELECT current_budget INTO v_budget
        FROM CLUB WHERE club_id = NEW.to_club_id;

        IF v_budget < NEW.fee THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '예산 초과로 인해 영입이 불가능합니다.';
        END IF;
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 2. 자기 팀 이적 차단
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_check_same_club
BEFORE INSERT ON TRANSFER_HISTORY
FOR EACH ROW
BEGIN
    IF NEW.from_club_id IS NOT NULL AND NEW.to_club_id IS NOT NULL THEN
        IF NEW.from_club_id = NEW.to_club_id THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '동일 구단 간 이적은 불가능합니다.';
        END IF;
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 3. 매물 중복 등록 차단
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_check_duplicate_listing
BEFORE INSERT ON TRANSFER_MARKET
FOR EACH ROW
BEGIN
    DECLARE v_count INT;

    SELECT COUNT(*) INTO v_count
    FROM TRANSFER_MARKET
    WHERE player_id = NEW.player_id
      AND status = 'available';

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '이미 이적시장에 등록된 선수입니다.';
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 4. 판매 구단과 선수 소속 구단 일치 확인
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_check_seller_club
BEFORE INSERT ON TRANSFER_MARKET
FOR EACH ROW
BEGIN
    DECLARE v_club_id INT;

    SELECT club_id INTO v_club_id
    FROM PLAYER
    WHERE player_id = NEW.player_id;

    IF v_club_id IS NULL OR v_club_id <> NEW.seller_club_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '선수의 현재 소속 구단과 판매 구단이 일치하지 않습니다.';
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- FUNCTION. 구단 스쿼드 점수 계산
-- =====================================================
DELIMITER $$
CREATE FUNCTION fn_squad_score(p_club_id INT)
RETURNS DECIMAL(6,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_avg_overall    DECIMAL(6,2) DEFAULT 0;
    DECLARE v_manager_rating INT          DEFAULT 0;
    DECLARE v_score          DECIMAL(6,2) DEFAULT 0;

    SELECT ROUND(AVG(ps.overall), 2) INTO v_avg_overall
    FROM PLAYER p
    JOIN PLAYER_STATS ps ON p.player_id = ps.player_id
    WHERE p.club_id = p_club_id;

    SELECT rating INTO v_manager_rating
    FROM MANAGER
    WHERE club_id = p_club_id;

    SET v_score = ROUND(v_avg_overall * 0.8 + v_manager_rating * 0.2, 2);

    RETURN v_score;
END$$
DELIMITER ;

