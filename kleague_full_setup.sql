-- =====================================================
-- K리그 이적시장 기반 스토브리그 체험 DB 시스템
-- 통합 실행 파일 (Full Setup)
--
-- MySQL Workbench에서 이 파일 하나만 열고
-- 전체 실행(Ctrl+Shift+Enter)하면 DB 구축 완료
--
-- ※ 이 파일은 csv_to_sql.py 가 자동 생성합니다.
--   선수 데이터를 변경하려면 csv_to_sql.py 를 다시 실행하세요.
-- =====================================================

-- =====================================================
-- [1/5] DDL -- DB 구조 생성
-- =====================================================

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


-- =====================================================
-- [2/5] DML BASE -- CLUB / MANAGER / APP_USER
-- =====================================================

-- =====================================================
-- K리그 이적시장 기반 스토브리그 체험 DB 시스템
-- DML BASE -- CLUB / MANAGER / APP_USER
-- (csv_to_sql.py 자동 생성)
-- =====================================================

USE kleague_db;

-- =====================================================
-- 1. CLUB  (출처: data/cleaned_clubs.csv)
-- =====================================================
INSERT INTO CLUB
    (club_id, name, city, founded_year,
     stadium_name, stadium_capacity,
     initial_budget, current_budget)
VALUES
(1, 'FC Seoul', 'Seoul', 1983, 'Seoul World Cup Stadium', 66704, 16400000, 16400000),
(2, 'Ulsan HD FC', 'Ulsan', 1983, 'Ulsan Munsu Football Stadium', 44102, 18800000, 18800000),
(3, 'Jeonbuk Hyundai Motors', 'Jeonju', 1994, 'Jeonju World Cup Stadium', 42477, 18000000, 18000000),
(4, 'Gangwon FC', 'Gangneung', 2008, 'Gangneung High1 Arena', 22333, 13000000, 13000000),
(5, 'Pohang Steelers', 'Pohang', 1973, 'Pohang Steel Yard', 17443, 11200000, 11200000),
(6, 'Incheon United', 'Incheon', 2003, 'Incheon Football Stadium', 20891, 9100000, 9100000),
(7, 'FC Anyang', 'Anyang', 2013, 'Anyang Sports Complex', 17143, 8700000, 8700000),
(8, 'Jeju SK', 'Seogwipo', 1982, 'Jeju World Cup Stadium', 29791, 12200000, 12200000),
(9, 'Bucheon FC 1995', 'Bucheon', 2007, 'Bucheon Stadium', 34456, 8000000, 8000000),
(10, 'Daejeon Hana Citizen', 'Daejeon', 1997, 'Daejeon World Cup Stadium', 40903, 16900000, 16900000),
(11, 'Gimcheon Sangmu', 'Gimcheon', 2021, 'Gimcheon Sports Complex', 25000, 11000000, 11000000),
(12, 'Gwangju FC', 'Gwangju', 2010, 'Gwangju World Cup Stadium', 40245, 6000000, 6000000);

-- =====================================================
-- 2. MANAGER
-- =====================================================
INSERT INTO MANAGER (club_id, name, nationality, birth_date, tactics, rating) VALUES
(1, '안익수', '대한민국', '1968-05-18', '4-4-2', 80),
(2, '홍명보', '대한민국', '1969-02-01', '4-3-3', 88),
(3, '김상식', '대한민국', '1974-07-04', '4-2-3-1', 84),
(4, '윤종환', '대한민국', '1970-03-15', '4-3-3', 78),
(5, '김기동', '대한민국', '1972-01-05', '3-4-3', 79),
(6, '조성환', '대한민국', '1970-09-11', '4-1-4-1', 77),
(7, '류병훈', '대한민국', '1975-05-20', '4-3-3', 71),
(8, '남기일', '대한민국', '1971-06-07', '4-4-2', 76),
(9, '조덕제', '대한민국', '1968-09-30', '4-4-2', 70),
(10, '황선홍', '대한민국', '1968-07-14', '4-2-3-1', 83),
(11, '이병근', '대한민국', '1973-11-20', '4-3-3', 74),
(12, '이정효', '대한민국', '1979-12-03', '4-2-3-1', 72);

-- =====================================================
-- 3. APP_USER  (출처: data/app_users.csv)
-- =====================================================
INSERT INTO APP_USER (user_id, username, club_id) VALUES
(1, 'manager_fc_seoul', 1),
(2, 'manager_ulsan_hd_fc', 2),
(3, 'manager_jeonbuk_hyundai_motors', 3),
(4, 'manager_gangwon_fc', 4),
(5, 'manager_pohang_steelers', 5),
(6, 'manager_incheon_united', 6),
(7, 'manager_fc_anyang', 7),
(8, 'manager_jeju_sk', 8),
(9, 'manager_bucheon_fc_1995', 9),
(10, 'manager_daejeon_hana_citizen', 10),
(11, 'manager_gimcheon_sangmu', 11),
(12, 'manager_gwangju_fc', 12);


-- =====================================================
-- [3/5] DML SAMPLE -- PLAYER / PLAYER_STATS / CONTRACT / TRANSFER_MARKET
-- =====================================================

-- =====================================================
-- K리그 이적시장 기반 스토브리그 체험 DB 시스템
-- DML SAMPLE -- PLAYER / PLAYER_STATS / CONTRACT / TRANSFER_MARKET
-- (csv_to_sql.py 자동 생성)
-- =====================================================

USE kleague_db;

-- =====================================================
-- 1. PLAYER
--   기존 data/ : 132명 (12구단 x 11명)
--   DBPBL 추가 :  45명 (9구단 x  5명)
--   합계       : 177명
-- =====================================================
INSERT INTO PLAYER
    (player_id, club_id, name, nationality,
     birth_date, position, height, weight)
VALUES
(20200301, 1, 'Sungyun GU', 'South Korea', '1994-06-27', 'GK', 197, 95),
(20260048, 1, 'Juan Antonio ROS MARTINEZ', 'Spain', '1996-03-15', 'DF', 187, 78),
(20200041, 1, 'Jun CHOI', 'South Korea', '1999-04-17', 'DF', 177, 72),
(20170185, 1, 'Jinsu KIM', 'South Korea', '1992-06-13', 'DF', 177, 68),
(20240324, 1, 'YAZAN MOUSA MAHMOUD ALARAB', 'Jordan', '1996-01-31', 'DF', 187, 86),
(20170052, 1, 'Seungmo LEE', 'South Korea', '1998-03-30', 'MF', 185, 70),
(20260045, 1, 'Hrvoje BABEC', 'Croatia', '1999-07-28', 'MF', 187, 84),
(20260049, 1, 'JEONGBEOM SON', 'South Korea', '2007-09-28', 'MF', 184, 73),
(20180034, 1, 'Minkyu SONG', 'South Korea', '1999-09-12', 'FW', 179, 72),
(20160099, 1, 'Seungwon JEONG', 'South Korea', '1997-02-27', 'MF', 173, 68),
(20250331, 1, 'Patryk KLIMALA', 'Poland', '1998-08-05', 'FW', 180, 79),
(20130156, 2, 'Hyeonwoo JO', 'South Korea', '1991-09-25', 'GK', 189, 75),
(20200055, 2, 'Hyuntaek CHO', 'South Korea', '2001-08-02', 'DF', 182, 76),
(20180105, 2, 'Jaeik LEE', 'South Korea', '1999-05-21', 'DF', 185, 76),
(20150109, 2, 'Seunghyun JUNG', 'South Korea', '1994-04-03', 'DF', 188, 74),
(20240107, 2, 'Seokhyun CHOI', 'South Korea', '2003-01-13', 'DF', 178, 77),
(20150050, 2, 'Gyusung LEE', 'South Korea', '1994-05-10', 'MF', 174, 68),
(20230108, 2, 'Darijan BOJANIC', 'Sweden', '1994-12-28', 'MF', 183, 74),
(20180088, 2, 'Donggyeong LEE', 'South Korea', '1997-09-20', 'MF', 175, 68),
(20190171, 2, 'Huigyun LEE', 'South Korea', '1998-04-29', 'MF', 168, 63),
(20230315, 2, 'Yago CARIELLO RIBEIRO', 'Brazil', '1999-07-27', 'FW', 186, 82),
(20260244, 2, 'Benjamin Stanley MICHEL', 'United States', '1997-10-23', 'FW', 178, 77),
(20180025, 3, 'Bumkeun SONG', 'South Korea', '1997-10-15', 'GK', 194, 88),
(20140143, 3, 'YOUNGBIN KIM', 'South Korea', '1991-09-20', 'DF', 184, 79),
(20220174, 3, 'Wijae CHO', 'South Korea', '2001-08-25', 'DF', 189, 82),
(20230029, 3, 'Woojin CHOI', 'South Korea', '2004-07-18', 'DF', 175, 66),
(20100052, 3, 'Taehwan KIM', 'South Korea', '1989-07-24', 'DF', 177, 72),
(20150052, 3, 'Jingyu KIM', 'South Korea', '1997-02-24', 'MF', 177, 68),
(20230043, 3, 'Oberdan ALIONCO DE LIMA', 'Brazil', '1995-07-30', 'MF', 175, 69),
(20220276, 3, 'Sangyoon KANG', 'South Korea', '2004-05-31', 'MF', 171, 64),
(20180212, 3, 'Seungsub KIM', 'South Korea', '1996-11-01', 'FW', 177, 65),
(20230224, 3, 'Bruno RODRIGUES MOTA', 'Brazil', '1996-02-10', 'FW', 193, 87),
(20170121, 3, 'Dongjun LEE', 'South Korea', '1997-02-01', 'FW', 173, 65),
(20130134, 4, 'Cheonghyo PARK', 'South Korea', '1990-02-13', 'GK', 190, 78),
(20230270, 4, 'Junhyuk KANG', 'South Korea', '1999-10-20', 'DF', 177, 70),
(20210104, 4, 'Gihyuk LEE', 'South Korea', '2000-07-07', 'DF', 184, 72),
(20240097, 4, 'Minah SHIN', 'South Korea', '2005-09-15', 'DF', 186, 77),
(20170182, 4, 'Youhyeon LEE', 'South Korea', '1997-02-08', 'MF', 179, 74),
(20200077, 4, 'MINWOO SEO', 'South Korea', '1998-03-12', 'MF', 183, 75),
(20200066, 4, 'YOUNGJUN GOH', 'South Korea', '2001-07-09', 'MF', 169, 68),
(20230067, 4, 'Seungwon LEE', 'South Korea', '2003-03-06', 'MF', 174, 73),
(20160098, 4, 'DAEWON KIM', 'South Korea', '1997-02-10', 'FW', 171, 65),
(20170164, 4, 'Jaehyeon MO', 'South Korea', '1996-09-24', 'FW', 184, 74),
(20260043, 4, 'ABDALLAH HLEIHIL', 'Israel', '2001-01-11', 'FW', 185, 77),
(20160079, 5, 'INJAE HWANG', 'South Korea', '1994-04-22', 'GK', 187, 73),
(20210182, 5, 'Jeongwon EO', 'South Korea', '1999-07-08', 'DF', 175, 68),
(20200146, 5, 'ChanYong Park', 'South Korea', '1996-01-27', 'DF', 188, 80),
(20150067, 5, 'MINGWANG JEON', 'South Korea', '1993-01-17', 'DF', 187, 73),
(20060066, 5, 'Kwanghoon SHIN', 'South Korea', '1987-03-18', 'DF', 178, 73),
(20240062, 5, 'Seowong HWANG', 'South Korea', '2005-01-22', 'MF', 175, 67),
(20240063, 5, 'Dongjin KIM', 'South Korea', '2003-07-30', 'MF', 180, 71),
(20260024, 5, 'Kento NISHIYA', 'Japan', '1999-11-07', 'MF', 175, 68),
(20210161, 5, 'Hojae LEE', 'South Korea', '2000-10-14', 'FW', 191, 85),
(20230148, 5, 'Paulo Afonso ROCHA JUNIOR', 'Brazil', '1997-11-05', 'FW', 172, 64),
(20260021, 5, 'Jakob TRANZISKA', 'Germany', '2001-06-25', 'FW', 189, 82),
(20190064, 6, 'DONGHEON KIM', 'South Korea', '1997-03-03', 'GK', 186, 85),
(20140059, 6, 'JUYONG LEE', 'South Korea', '1992-09-26', 'DF', 180, 78),
(20260160, 6, 'Juan FERNANDEZ BLANCO', 'Spain', '1995-08-17', 'DF', 187, 80),
(20210305, 6, 'Myungsoon KIM', 'South Korea', '2000-07-17', 'DF', 177, 76),
(20250189, 6, 'Gyeongseop PARK', 'South Korea', '2004-07-02', 'DF', 188, 83),
(20220279, 6, 'Jaemin SEO', 'South Korea', '2003-09-16', 'MF', 178, 73),
(20120127, 6, 'MYUNGJOO LEE', 'South Korea', '1990-04-24', 'MF', 176, 74),
(20180127, 6, 'Huseong OH', 'South Korea', '1999-08-25', 'DF', 173, 64),
(20040081, 6, 'Chungyong LEE', 'South Korea', '1988-07-02', 'MF', 180, 69),
(20210223, 6, 'FERNANDES Gerso', 'Portugal', '1991-02-23', 'MF', 172, 62),
(20190131, 6, 'Dongryul LEE', 'South Korea', '2000-06-09', 'FW', 174, 70),
(20190375, 7, 'JEONGHOON KIM', 'South Korea', '2001-04-20', 'GK', 188, 80),
(20150080, 7, 'Taehee LEE', 'South Korea', '1992-06-16', 'DF', 181, 66),
(20140135, 7, 'Dongjin KIM', 'South Korea', '1992-12-28', 'DF', 177, 74),
(20130101, 7, 'Youngchan KIM', 'South Korea', '1993-09-04', 'DF', 189, 84),
(20130102, 7, 'Kyungwon KWON', 'South Korea', '1992-01-31', 'DF', 188, 83),
(20160073, 7, 'Kim Jeonghyun', 'South Korea', '1993-06-01', 'MF', 185, 74),
(20240078, 7, 'Matheus OLIVEIRA SANTOS', 'Brazil', '1997-09-28', 'MF', 177, 70),
(20240080, 7, 'KA RAM HAN', 'South Korea', '1998-02-09', 'MF', 177, 70),
(20200170, 7, 'GEONJU CHOI', 'South Korea', '1999-06-26', 'FW', 175, 64),
(20260091, 7, 'AIRTON MOISES SANTOS SOUSA', 'Brazil', '1999-02-02', 'FW', 179, 75),
(20240084, 7, 'Woon KIM', 'South Korea', '1994-11-15', 'FW', 181, 76),
(20160156, 8, 'Dongjun KIM', 'South Korea', '1994-12-19', 'GK', 189, 85),
(20210165, 8, 'Ryunseong KIM', 'South Korea', '2002-06-04', 'DF', 179, 70),
(20260221, 8, 'SEUNGRO LEE', 'France', '1997-07-24', 'DF', 192, 80),
(20250093, 8, 'MINGYU CHAN', 'South Korea', '1999-03-06', 'DF', 186, 78),
(20200103, 8, 'Insoo YU', 'South Korea', '1994-12-28', 'DF', 178, 70),
(20240323, 8, 'taehee Nam', 'South Korea', '1991-07-03', 'MF', 175, 73),
(20210108, 8, 'Jaehyeok OH', 'South Korea', '2002-06-21', 'MF', 174, 69),
(20160047, 8, 'Geonung KIM', 'South Korea', '1997-08-29', 'MF', 185, 83),
(20250095, 8, 'Junha KIM', 'South Korea', '2005-12-02', 'MF', 177, 66),
(20260228, 8, 'EMERSON RAMON BEZERRA OLIVEIRA', 'Brazil', '2000-11-24', 'FW', 173, 85),
(20130108, 8, 'CHANGHOON KWON', 'South Korea', '1994-06-30', 'MF', 174, 69),
(20160010, 9, 'Hyunggeun KIM', 'South Korea', '1994-01-06', 'GK', 188, 78),
(20160130, 9, 'Taehyun AN', 'South Korea', '1993-03-01', 'DF', 174, 70),
(20210174, 9, 'Sungwook HONG', 'South Korea', '2002-09-17', 'DF', 187, 77),
(20190161, 9, 'Jaewon SHIN', 'South Korea', '1998-09-16', 'DF', 183, 75),
(20140203, 9, 'Donggyu BAEK', 'South Korea', '1991-05-30', 'DF', 184, 71),
(20190194, 9, 'Sangjun KIM', 'South Korea', '2001-10-01', 'MF', 185, 75),
(20230141, 9, 'Kazuki TAKAHASHI', 'Japan', '1996-10-06', 'MF', 178, 73),
(20100079, 9, 'Bitgaram YOON', 'South Korea', '1990-05-07', 'MF', 178, 75),
(20220353, 9, 'ISIDIO JEFFERSON FERNANDO', 'Brazil', '1997-04-04', 'FW', 177, 71),
(20230333, 9, 'VITOR GABRIEL CLAUDINO REGO FERREIRA', 'Brazil', '2000-01-20', 'FW', 187, 76),
(20200048, 9, 'Minjun KIM', 'South Korea', '2000-02-12', 'FW', 183, 74),
(20120148, 10, 'changgeun LEE', 'South Korea', '1993-08-30', 'GK', 186, 75),
(20170122, 10, 'Moonhwan KIM', 'South Korea', '1995-08-01', 'DF', 173, 64),
(20160037, 10, 'Yoonsung KANG', 'South Korea', '1997-07-01', 'DF', 172, 65),
(20230239, 10, 'Seonggwon CHO', 'South Korea', '2001-02-24', 'DF', 182, 75),
(20230048, 10, 'Anton KRIVOTSYUK', 'Ukraine', '1998-08-20', 'DF', 186, 76),
(20210176, 10, 'Bongsoo KIM', 'South Korea', '1999-12-26', 'MF', 181, 74),
(20230326, 10, 'BOBSIN PEREIRA VICTOR', 'Brazil', '2000-01-12', 'MF', 183, 78),
(20180110, 10, 'Hyunsik LEE', 'South Korea', '1996-03-21', 'MF', 175, 64),
(20230105, 10, 'Gustav Erik LUDWIGSON', 'Sweden', '1993-10-20', 'MF', 182, 75),
(20130248, 10, 'Minkyu JOO', 'South Korea', '1990-04-13', 'FW', 183, 79),
(20250360, 10, 'Joao Victor LIMA FERREIRA', 'Brazil', '1999-02-25', 'FW', 176, 75),
(20190154, 11, 'Jongbum BAEK', 'South Korea', '2001-01-21', 'GK', 190, 82),
(20220139, 11, 'Cheolwoo PARK', 'South Korea', '1997-10-21', 'DF', 176, 68),
(20180324, 11, 'Taehwan KIM', 'South Korea', '2000-03-25', 'DF', 179, 73),
(20230198, 11, 'Jungtaek LEE', 'South Korea', '1998-05-23', 'DF', 183, 75),
(20200317, 11, 'Junsoo BYEON', 'South Korea', '2001-11-30', 'DF', 190, 88),
(20180096, 11, 'Taejun PARK', 'South Korea', '1999-01-19', 'MF', 175, 74),
(20170022, 11, 'Sangheon LEE', 'South Korea', '1998-02-26', 'FW', 178, 67),
(20190124, 11, 'Soobin LEE', 'South Korea', '2000-05-07', 'MF', 180, 70),
(20200164, 11, 'Kunhee LEE', 'South Korea', '1998-02-17', 'FW', 186, 78),
(20180123, 11, 'Jaehyeon GO', 'South Korea', '1999-03-05', 'FW', 180, 67),
(20200174, 11, 'Ingyun KIM', 'South Korea', '1998-07-23', 'FW', 175, 67),
(20140102, 12, 'Kyeongmin KIM', 'South Korea', '1991-11-01', 'GK', 190, 78),
(20190114, 12, 'Seungun HA', 'South Korea', '1998-05-04', 'FW', 177, 74),
(20260209, 12, 'Yonghyuk KIM', 'South Korea', '2007-01-11', 'DF', 187, 76),
(20220053, 12, 'Jinho KIM', 'South Korea', '2000-01-21', 'DF', 178, 74),
(20120116, 12, 'Youngkyu AHN', 'South Korea', '1989-12-04', 'DF', 185, 79),
(20240210, 12, 'Minseo MOON', 'South Korea', '2004-02-18', 'MF', 182, 74),
(20230080, 12, 'Jihun JUNG', 'South Korea', '2004-04-09', 'FW', 175, 60),
(20120151, 12, 'Sejong JU', 'South Korea', '1990-10-30', 'MF', 176, 72),
(20200029, 12, 'Seongyun GWON', 'South Korea', '2001-03-30', 'FW', 174, 65),
(20240209, 12, 'Hyeokjoo AN', 'South Korea', '2004-09-03', 'FW', 176, 70),
(20250366, 12, 'Holmbert Aron Briem FRIDJONSSON', 'Iceland', '1993-04-19', 'FW', 196, 86),
(238097, 1, '나상호 那尚昊', 'Korea Republic', '1996-08-12', 'MF', 173, 70),
(180283, 1, '기성용 寄诚庸', 'Korea Republic', '1989-01-24', 'MF', 189, 75),
(193847, 1, 'Osmar Ibáñez Barba', 'Spain', '1988-06-05', 'DF', 192, 86),
(210544, 1, 'Willyan da Silva Barbosa', 'Brazil', '1994-02-17', 'FW', 170, 69),
(244582, 1, 'Aleksandar Paločević', 'Serbia', '1993-08-22', 'MF', 180, 70),
(205401, 2, 'Valeri Qazaishvili', 'Georgia', '1993-01-29', 'MF', 174, 74),
(213189, 2, '주민규 朱文奎', 'Korea Republic', '1990-04-13', 'FW', 183, 79),
(246937, 2, 'Won Sang Um', 'Korea Republic', '1999-01-06', 'MF', 173, 63),
(201528, 2, '김영권 金英权', 'Korea Republic', '1990-02-27', 'DF', 186, 74),
(268097, 2, 'Martin Ádám', 'Hungary', '1994-11-06', 'FW', 191, 87),
(237424, 3, '백승호 Seung Ho Paik', 'Korea Republic', '1997-03-17', 'MF', 180, 78),
(227788, 3, '안현범 安铉范', 'Korea Republic', '1994-12-21', 'DF', 179, 72),
(243061, 3, 'Dong Jun Lee', 'Korea Republic', '1997-02-01', 'MF', 173, 65),
(238576, 3, '정태욱 Tae Wook Jeong', 'Korea Republic', '1997-05-16', 'DF', 194, 92),
(243673, 3, 'Jin Seob Park', 'Korea Republic', '1995-10-23', 'MF', 184, 80),
(233018, 4, '김대원 金大元', 'Korea Republic', '1997-02-10', 'FW', 171, 65),
(211004, 4, '한국영 Kook Young Han', 'Korea Republic', '1990-04-19', 'MF', 183, 76),
(222582, 4, '김영빈 金永斌', 'Korea Republic', '1991-09-20', 'DF', 184, 79),
(213878, 4, 'Welinton Júnior Ferreira dos Santos', 'Brazil', '1993-06-08', 'FW', 175, 64),
(270203, 4, 'Yago Cariello Ribeiro', 'Brazil', '1999-07-27', 'FW', 186, 82),
(209210, 5, 'Alexander Ian Grant', 'Australia', '1994-01-23', 'DF', 191, 82),
(268313, 5, 'Jose Joaquim de Carvalho', 'Brazil', '1997-03-06', 'FW', 190, 83),
(272733, 5, 'Oberdan Alionço de Lima', 'Brazil', '1995-07-30', 'MF', 175, 74),
(207730, 5, '백성동 Sung Dong Paik', 'Korea Republic', '1991-08-13', 'MF', 171, 66),
(255917, 5, 'Young Jun Goh', 'Korea Republic', '2001-07-09', 'MF', 169, 69),
(223994, 6, 'Stefan Mugoša', 'Montenegro', '1992-02-26', 'FW', 188, 78),
(202986, 6, '신진호 申振豪', 'Korea Republic', '1988-09-07', 'MF', 177, 72),
(209449, 6, 'Gerso Fernandes', 'Guinea Bissau', '1991-02-23', 'FW', 172, 62),
(241970, 6, 'Harrison Delbridge', 'Australia', '1992-03-15', 'DF', 190, 89),
(221643, 6, '김도혁 金道亨', 'Korea Republic', '1992-02-08', 'MF', 173, 70),
(212439, 8, '임채민 林查明', 'Korea Republic', '1990-11-18', 'DF', 188, 82),
(205156, 8, '최영준 财杨钧', 'Korea Republic', '1991-12-15', 'MF', 181, 76),
(211786, 8, 'Isnairo Reis Silva Morais', 'Brazil', '1993-01-06', 'FW', 175, 75),
(202749, 8, '김오규 Oh Gyu Kim', 'Korea Republic', '1989-06-20', 'DF', 182, 75),
(238763, 8, 'Vitor Coelho Yuri Jonathan', 'Brazil', '1998-06-12', 'FW', 185, 78),
(263034, 10, 'Anton Krivotsyuk', 'Azerbaijan', '1998-08-20', 'DF', 186, 76),
(238578, 10, '이진현 Jin Hyun Lee', 'Korea Republic', '1997-08-26', 'MF', 173, 70),
(208063, 10, '주세종 朱世钟', 'Korea Republic', '1990-10-30', 'MF', 176, 68),
(267825, 10, 'Orobó Tiago', 'Brazil', '1993-10-28', 'FW', 190, 75),
(223336, 10, 'Leandro Joaquim Ribeiro', 'Brazil', '1995-01-13', 'FW', 176, 68),
(209839, 12, 'Timo Letschert', 'Netherlands', '1993-05-25', 'DF', 188, 83),
(260492, 12, 'Ji Sung Eom', 'Korea Republic', '2002-05-09', 'MF', 178, 70),
(208073, 12, '안영규 安杨奎', 'Korea Republic', '1989-12-04', 'DF', 185, 81),
(263166, 12, 'Beka Mikeltadze', 'Georgia', '1997-11-26', 'FW', 185, 77),
(243422, 12, '두현석 Hyeon-Seok Doo', 'Korea Republic', '1995-12-21', 'DF', 169, 65);

-- =====================================================
-- 2. PLAYER_STATS
--   기존: shooting->attack, defending->defense, physical->stamina, pace->speed
--   DBPBL: shooting->attack, defending->defense, physic->stamina, pace->speed
-- =====================================================
INSERT INTO PLAYER_STATS (player_id, attack, defense, stamina, speed)
VALUES
(20200301, 25, 78, 76, 60),
(20260048, 48, 86, 83, 78),
(20200041, 42, 81, 78, 72),
(20170185, 42, 80, 77, 72),
(20240324, 45, 82, 79, 74),
(20170052, 85, 77, 78, 77),
(20260045, 81, 79, 80, 79),
(20260049, 64, 65, 66, 65),
(20180034, 94, 70, 86, 90),
(20160099, 71, 75, 76, 75),
(20250331, 91, 62, 78, 82),
(20130156, 25, 80, 78, 60),
(20200055, 42, 80, 77, 72),
(20180105, 42, 76, 73, 67),
(20150109, 48, 88, 85, 80),
(20240107, 42, 76, 73, 68),
(20150050, 71, 75, 76, 75),
(20230108, 71, 75, 76, 75),
(20180088, 88, 87, 88, 87),
(20190171, 69, 70, 71, 70),
(20230315, 94, 68, 84, 88),
(20260244, 72, 53, 69, 73),
(20180025, 25, 83, 81, 60),
(20140143, 45, 80, 77, 72),
(20220174, 48, 79, 76, 71),
(20230029, 42, 75, 72, 66),
(20100052, 42, 75, 72, 66),
(20150052, 81, 82, 83, 82),
(20230043, 81, 82, 83, 82),
(20220276, 73, 74, 75, 74),
(20180212, 80, 59, 75, 79),
(20230224, 86, 63, 79, 83),
(20170121, 88, 63, 79, 83),
(20130134, 25, 74, 72, 60),
(20230270, 42, 80, 77, 72),
(20210104, 42, 80, 77, 72),
(20240097, 42, 79, 76, 70),
(20170182, 69, 70, 71, 70),
(20200077, 71, 75, 76, 75),
(20200066, 68, 72, 73, 72),
(20230067, 61, 65, 66, 65),
(20160098, 94, 70, 86, 90),
(20170164, 90, 67, 83, 87),
(20260043, 92, 61, 77, 81),
(20160079, 25, 78, 76, 60),
(20210182, 42, 79, 76, 71),
(20200146, 42, 78, 75, 70),
(20150067, 42, 73, 70, 64),
(20060066, 42, 70, 67, 61),
(20240062, 63, 67, 68, 67),
(20240063, 65, 69, 70, 69),
(20260024, 66, 70, 71, 70),
(20210161, 94, 70, 86, 90),
(20230148, 81, 58, 74, 78),
(20260021, 74, 53, 69, 73),
(20190064, 25, 75, 73, 55),
(20140059, 42, 78, 75, 69),
(20260160, 48, 80, 77, 72),
(20210305, 42, 79, 76, 70),
(20250189, 42, 74, 71, 65),
(20220279, 71, 72, 73, 72),
(20120127, 72, 73, 74, 73),
(20180127, 45, 72, 69, 64),
(20040081, 70, 71, 72, 71),
(20210223, 77, 75, 76, 75),
(20190131, 82, 59, 75, 79),
(20190375, 25, 75, 73, 58),
(20150080, 42, 75, 72, 66),
(20140135, 45, 76, 73, 67),
(20130101, 45, 76, 73, 67),
(20130102, 42, 75, 72, 66),
(20160073, 66, 67, 68, 67),
(20240078, 88, 80, 81, 80),
(20240080, 58, 62, 63, 62),
(20200170, 84, 59, 75, 79),
(20260091, 89, 60, 76, 80),
(20240084, 79, 56, 72, 76),
(20160156, 25, 78, 76, 60),
(20210165, 45, 79, 76, 70),
(20260221, 45, 79, 76, 71),
(20250093, 45, 80, 77, 72),
(20200103, 42, 76, 73, 67),
(20240323, 70, 71, 72, 71),
(20210108, 65, 66, 67, 66),
(20160047, 61, 65, 66, 65),
(20250095, 71, 72, 73, 72),
(20260228, 91, 68, 84, 88),
(20130108, 64, 68, 69, 68),
(20160010, 25, 73, 71, 58),
(20160130, 42, 76, 73, 67),
(20210174, 42, 77, 74, 68),
(20190161, 45, 77, 74, 68),
(20140203, 42, 73, 70, 64),
(20190194, 63, 67, 68, 67),
(20230141, 65, 69, 70, 69),
(20100079, 64, 68, 69, 68),
(20220353, 89, 62, 78, 82),
(20230333, 80, 57, 73, 77),
(20200048, 74, 53, 69, 73),
(20120148, 25, 79, 77, 60),
(20170122, 42, 84, 81, 75),
(20160037, 42, 75, 72, 66),
(20230239, 42, 73, 70, 64),
(20230048, 42, 77, 74, 68),
(20210176, 74, 78, 79, 78),
(20230326, 66, 70, 71, 70),
(20180110, 64, 68, 69, 68),
(20230105, 77, 78, 79, 78),
(20130248, 83, 62, 78, 82),
(20250360, 73, 54, 70, 74),
(20190154, 25, 75, 73, 59),
(20220139, 45, 81, 78, 73),
(20180324, 42, 77, 74, 69),
(20230198, 42, 81, 78, 72),
(20200317, 45, 75, 72, 66),
(20180096, 74, 72, 73, 72),
(20170022, 75, 56, 72, 76),
(20190124, 62, 66, 67, 66),
(20200164, 85, 60, 76, 80),
(20180123, 91, 64, 80, 84),
(20200174, 74, 53, 69, 73),
(20140102, 25, 71, 69, 52),
(20190114, 74, 55, 71, 75),
(20260209, 42, 73, 70, 64),
(20220053, 42, 76, 73, 67),
(20120116, 42, 74, 71, 65),
(20240210, 73, 71, 72, 71),
(20230080, 72, 53, 69, 73),
(20120151, 64, 68, 69, 68),
(20200029, 72, 53, 69, 73),
(20240209, 73, 54, 70, 74),
(20250366, 78, 57, 73, 77),
(238097, 72, 36, 75, 89),
(180283, 63, 64, 75, 46),
(193847, 60, 73, 82, 34),
(210544, 68, 42, 50, 87),
(244582, 68, 53, 68, 59),
(205401, 72, 41, 69, 76),
(213189, 76, 44, 81, 65),
(246937, 68, 37, 67, 93),
(201528, 44, 72, 79, 69),
(268097, 76, 28, 79, 61),
(237424, 68, 64, 75, 69),
(227788, 61, 62, 75, 90),
(243061, 64, 40, 62, 90),
(238576, 31, 70, 81, 51),
(243673, 54, 71, 83, 68),
(233018, 68, 29, 67, 87),
(211004, 54, 67, 72, 63),
(222582, 28, 68, 78, 65),
(213878, 70, 22, 49, 77),
(270203, 67, 23, 70, 64),
(209210, 44, 72, 83, 53),
(268313, 69, 27, 79, 76),
(272733, 62, 65, 68, 64),
(207730, 63, 41, 58, 78),
(255917, 66, 34, 52, 85),
(223994, 74, 24, 77, 64),
(202986, 65, 62, 77, 63),
(209449, 64, 41, 53, 91),
(241970, 33, 70, 85, 51),
(221643, 61, 59, 76, 61),
(212439, 39, 73, 79, 68),
(205156, 57, 66, 77, 63),
(211786, 66, 33, 52, 81),
(202749, 41, 68, 79, 66),
(238763, 68, 34, 75, 59),
(263034, 36, 71, 77, 80),
(238578, 66, 53, 60, 78),
(208063, 54, 63, 69, 58),
(267825, 70, 27, 72, 78),
(223336, 63, 29, 58, 83),
(209839, 54, 70, 75, 52),
(260492, 64, 36, 61, 79),
(208073, 31, 69, 76, 61),
(263166, 66, 32, 67, 75),
(243422, 59, 61, 64, 82);

-- =====================================================
-- 3. CONTRACT
-- =====================================================
INSERT INTO CONTRACT (player_id, club_id, start_date, end_date, salary, status)
VALUES
(20200301, 1, '2026-01-16', NULL, 40000, 'active'),
(20260048, 1, '2026-01-23', NULL, 68000, 'active'),
(20200041, 1, '2024-01-05', NULL, 52000, 'active'),
(20170185, 1, '2025-01-17', NULL, 30000, 'active'),
(20240324, 1, '2024-07-16', NULL, 72000, 'active'),
(20170052, 1, '2023-06-23', '2026-12-31', 36000, 'active'),
(20260045, 1, '2026-01-16', '2028-12-31', 64000, 'active'),
(20260049, 1, '2026-01-16', NULL, 30000, 'active'),
(20180034, 1, '2026-01-21', NULL, 72000, 'active'),
(20160099, 1, '2025-01-17', NULL, 44000, 'active'),
(20250331, 1, '2025-06-02', NULL, 40000, 'active'),
(20130156, 2, '2020-01-20', NULL, 56000, 'active'),
(20200055, 2, '2020-01-10', NULL, 40000, 'active'),
(20180105, 2, '2025-01-17', NULL, 30000, 'active'),
(20150109, 2, '2025-07-09', NULL, 96000, 'active'),
(20240107, 2, '2024-01-03', NULL, 30000, 'active'),
(20150050, 2, '2021-01-18', '2027-12-31', 40000, 'active'),
(20230108, 2, '2023-01-01', '2027-12-31', 64000, 'active'),
(20180088, 2, '2018-01-01', NULL, 128000, 'active'),
(20190171, 2, '2025-01-17', NULL, 30000, 'active'),
(20230315, 2, '2024-07-09', NULL, 80000, 'active'),
(20260244, 2, '2026-02-14', NULL, 32000, 'active'),
(20180025, 3, '2025-01-17', NULL, 80000, 'active'),
(20140143, 3, '2025-01-17', NULL, 32000, 'active'),
(20220174, 3, '2026-01-16', NULL, 32000, 'active'),
(20230029, 3, '2025-02-01', NULL, 30000, 'active'),
(20100052, 3, '2024-01-14', '2026-12-31', 32000, 'active'),
(20150052, 3, '2022-03-16', '2026-12-31', 96000, 'active'),
(20230043, 3, '2026-01-16', NULL, 96000, 'active'),
(20220276, 3, '2022-03-15', NULL, 44000, 'active'),
(20180212, 3, '2026-01-16', NULL, 44000, 'active'),
(20230224, 3, '2026-01-16', '2026-12-31', 48000, 'active'),
(20170121, 3, '2023-01-01', NULL, 44000, 'active'),
(20130134, 4, '2024-01-23', NULL, 30000, 'active'),
(20230270, 4, '2025-01-17', NULL, 30000, 'active'),
(20210104, 4, '2024-01-20', '2027-12-31', 48000, 'active'),
(20240097, 4, '2024-01-09', NULL, 48000, 'active'),
(20170182, 4, '2025-01-17', NULL, 30000, 'active'),
(20200077, 4, '2020-01-06', NULL, 52000, 'active'),
(20200066, 4, '2026-01-16', '2026-12-31', 36000, 'active'),
(20230067, 4, '2023-01-01', NULL, 36000, 'active'),
(20160098, 4, '2021-02-08', NULL, 56000, 'active'),
(20170164, 4, '2025-06-17', '2027-12-31', 60000, 'active'),
(20260043, 4, '2026-01-24', NULL, 30000, 'active'),
(20160079, 5, '2020-01-03', NULL, 40000, 'active'),
(20210182, 5, '2024-01-02', NULL, 30000, 'active'),
(20200146, 5, '2022-01-02', NULL, 60000, 'active'),
(20150067, 5, '2019-01-04', NULL, 30000, 'active'),
(20060066, 5, '2021-01-04', NULL, 30000, 'active'),
(20240062, 5, '2024-01-01', NULL, 30000, 'active'),
(20240063, 5, '2024-01-01', NULL, 30000, 'active'),
(20260024, 5, '2026-01-16', '2026-12-31', 48000, 'active'),
(20210161, 5, '2021-01-01', '2027-12-31', 64000, 'active'),
(20230148, 5, '2025-01-17', NULL, 30000, 'active'),
(20260021, 5, '2026-01-16', NULL, 30000, 'active'),
(20190064, 6, '2019-01-04', NULL, 44000, 'active'),
(20140059, 6, '2025-01-17', NULL, 30000, 'active'),
(20260160, 6, '2026-01-30', '2026-12-31', 30000, 'active'),
(20210305, 6, '2025-01-17', '2027-12-31', 30000, 'active'),
(20250189, 6, '2025-01-17', NULL, 30000, 'active'),
(20220279, 6, '2026-01-16', NULL, 30000, 'active'),
(20120127, 6, '2022-01-30', NULL, 30000, 'active'),
(20180127, 6, '2026-01-16', NULL, 30000, 'active'),
(20040081, 6, '2026-02-11', NULL, 30000, 'active'),
(20210223, 6, '2023-01-10', NULL, 44000, 'active'),
(20190131, 6, '2025-01-17', NULL, 30000, 'active'),
(20190375, 7, '2026-01-16', '2028-12-31', 32000, 'active'),
(20150080, 7, '2023-02-07', NULL, 30000, 'active'),
(20140135, 7, '2022-01-01', NULL, 30000, 'active'),
(20130101, 7, '2024-01-09', NULL, 30000, 'active'),
(20130102, 7, '2025-07-04', NULL, 32000, 'active'),
(20160073, 7, '2023-01-04', '2026-12-31', 30000, 'active'),
(20240078, 7, '2024-01-10', NULL, 64000, 'active'),
(20240080, 7, '2024-01-11', '2026-12-31', 30000, 'active'),
(20200170, 7, '2026-01-22', NULL, 30000, 'active'),
(20260091, 7, '2026-02-20', NULL, 30000, 'active'),
(20240084, 7, '2024-01-11', NULL, 30000, 'active'),
(20160156, 8, '2022-01-11', NULL, 44000, 'active'),
(20210165, 8, '2025-01-17', '2027-12-31', 30000, 'active'),
(20260221, 8, '2026-01-23', NULL, 30000, 'active'),
(20250093, 8, '2025-01-17', '2026-12-31', 40000, 'active'),
(20200103, 8, '2025-01-20', NULL, 30000, 'active'),
(20240323, 8, '2024-07-25', NULL, 36000, 'active'),
(20210108, 8, '2025-01-17', NULL, 30000, 'active'),
(20160047, 8, '2023-07-18', NULL, 36000, 'active'),
(20250095, 8, '2025-01-17', NULL, 30000, 'active'),
(20260228, 8, '2026-01-16', NULL, 80000, 'active'),
(20130108, 8, '2026-01-16', NULL, 30000, 'active'),
(20160010, 9, '2024-01-08', NULL, 30000, 'active'),
(20160130, 9, '2026-01-16', NULL, 30000, 'active'),
(20210174, 9, '2023-01-11', NULL, 30000, 'active'),
(20190161, 9, '2026-01-16', NULL, 30000, 'active'),
(20140203, 9, '2025-06-17', NULL, 30000, 'active'),
(20190194, 9, '2026-01-16', NULL, 30000, 'active'),
(20230141, 9, '2023-01-01', '2026-12-31', 30000, 'active'),
(20100079, 9, '2026-01-16', '2027-12-31', 32000, 'active'),
(20220353, 9, '2025-01-25', NULL, 30000, 'active'),
(20230333, 9, '2026-01-16', NULL, 40000, 'active'),
(20200048, 9, '2026-01-16', NULL, 30000, 'active'),
(20120148, 10, '2022-01-11', NULL, 48000, 'active'),
(20170122, 10, '2024-06-20', '2027-12-31', 64000, 'active'),
(20160037, 10, '2023-06-28', NULL, 32000, 'active'),
(20230239, 10, '2026-01-16', '2027-12-31', 30000, 'active'),
(20230048, 10, '2023-02-21', '2027-12-31', 56000, 'active'),
(20210176, 10, '2025-06-11', NULL, 80000, 'active'),
(20230326, 10, '2025-01-17', NULL, 48000, 'active'),
(20180110, 10, '2021-01-12', NULL, 36000, 'active'),
(20230105, 10, '2026-01-16', NULL, 68000, 'active'),
(20130248, 10, '2025-01-17', '2026-12-31', 56000, 'active'),
(20250360, 10, '2026-01-16', NULL, 30000, 'active'),
(20190154, 11, '2025-04-07', '2026-10-06', 30000, 'active'),
(20220139, 11, '2025-04-07', '2026-10-06', 30000, 'active'),
(20180324, 11, '2025-04-07', '2026-10-06', 30000, 'active'),
(20230198, 11, '2025-04-07', '2026-10-06', 30000, 'active'),
(20200317, 11, '2026-01-19', '2027-07-18', 40000, 'active'),
(20180096, 11, '2025-06-02', '2026-12-01', 30000, 'active'),
(20170022, 11, '2025-11-17', '2027-05-16', 56000, 'active'),
(20190124, 11, '2025-04-07', '2026-10-06', 30000, 'active'),
(20200164, 11, '2025-04-07', '2026-10-06', 30000, 'active'),
(20180123, 11, '2025-04-07', '2026-10-06', 48000, 'active'),
(20200174, 11, '2025-06-02', '2026-12-01', 30000, 'active'),
(20140102, 12, '2022-01-09', NULL, 30000, 'active'),
(20190114, 12, '2022-01-10', NULL, 30000, 'active'),
(20260209, 12, '2026-01-16', NULL, 30000, 'active'),
(20220053, 12, '2024-01-23', '2026-12-31', 32000, 'active'),
(20120116, 12, '2022-01-06', NULL, 30000, 'active'),
(20240210, 12, '2024-01-08', '2026-12-31', 30000, 'active'),
(20230080, 12, '2023-01-01', '2027-12-31', 30000, 'active'),
(20120151, 12, '2025-02-28', NULL, 30000, 'active'),
(20200029, 12, '2025-01-17', NULL, 30000, 'active'),
(20240209, 12, '2024-01-01', NULL, 30000, 'active'),
(20250366, 12, '2025-08-06', NULL, 30000, 'active'),
(238097, 1, '2024-01-01', NULL, 8000, 'active'),
(180283, 1, '2024-01-01', NULL, 8000, 'active'),
(193847, 1, '2024-01-01', NULL, 5000, 'active'),
(210544, 1, '2024-01-01', NULL, 7000, 'active'),
(244582, 1, '2024-01-01', NULL, 6000, 'active'),
(205401, 2, '2024-01-01', NULL, 12000, 'active'),
(213189, 2, '2024-01-01', NULL, 12000, 'active'),
(246937, 2, '2024-01-01', NULL, 9000, 'active'),
(201528, 2, '2024-01-01', NULL, 9000, 'active'),
(268097, 2, '2024-01-01', NULL, 10000, 'active'),
(237424, 3, '2024-01-01', NULL, 10000, 'active'),
(227788, 3, '2024-01-01', NULL, 9000, 'active'),
(243061, 3, '2024-01-01', NULL, 9000, 'active'),
(238576, 3, '2024-01-01', NULL, 7000, 'active'),
(243673, 3, '2024-01-01', NULL, 7000, 'active'),
(233018, 4, '2024-01-01', NULL, 6000, 'active'),
(211004, 4, '2024-01-01', NULL, 5000, 'active'),
(222582, 4, '2024-01-01', NULL, 4000, 'active'),
(213878, 4, '2024-01-01', NULL, 4000, 'active'),
(270203, 4, '2024-01-01', NULL, 3000, 'active'),
(209210, 5, '2024-01-01', NULL, 6000, 'active'),
(268313, 5, '2024-01-01', NULL, 5000, 'active'),
(272733, 5, '2024-01-01', NULL, 5000, 'active'),
(207730, 5, '2024-01-01', NULL, 5000, 'active'),
(255917, 5, '2024-01-01', NULL, 3000, 'active'),
(223994, 6, '2024-01-01', NULL, 7000, 'active'),
(202986, 6, '2024-01-01', NULL, 5000, 'active'),
(209449, 6, '2024-01-01', NULL, 6000, 'active'),
(241970, 6, '2024-01-01', NULL, 5000, 'active'),
(221643, 6, '2024-01-01', NULL, 5000, 'active'),
(212439, 8, '2024-01-01', NULL, 6000, 'active'),
(205156, 8, '2024-01-01', NULL, 5000, 'active'),
(211786, 8, '2024-01-01', NULL, 6000, 'active'),
(202749, 8, '2024-01-01', NULL, 4000, 'active'),
(238763, 8, '2024-01-01', NULL, 4000, 'active'),
(263034, 10, '2024-01-01', NULL, 5000, 'active'),
(238578, 10, '2024-01-01', NULL, 5000, 'active'),
(208063, 10, '2024-01-01', NULL, 6000, 'active'),
(267825, 10, '2024-01-01', NULL, 6000, 'active'),
(223336, 10, '2024-01-01', NULL, 5000, 'active'),
(209839, 12, '2024-01-01', NULL, 4000, 'active'),
(260492, 12, '2024-01-01', NULL, 2000, 'active'),
(208073, 12, '2024-01-01', NULL, 3000, 'active'),
(263166, 12, '2024-01-01', NULL, 3000, 'active'),
(243422, 12, '2024-01-01', NULL, 2000, 'active');

-- =====================================================
-- 4. TRANSFER_MARKET  (기존 132명 + DBPBL 추가 45명)
-- =====================================================
INSERT INTO TRANSFER_MARKET
    (listing_id, player_id, seller_club_id, asking_fee, listed_date, status)
VALUES
(1, 20200301, 1, 500000, '2026-06-01', 'available'),
(2, 20260048, 1, 850000, '2026-06-01', 'available'),
(3, 20200041, 1, 650000, '2026-06-01', 'available'),
(4, 20170185, 1, 350000, '2026-06-01', 'available'),
(5, 20240324, 1, 900000, '2026-06-01', 'available'),
(6, 20170052, 1, 450000, '2026-06-01', 'available'),
(7, 20260045, 1, 800000, '2026-06-01', 'available'),
(8, 20260049, 1, 100000, '2026-06-01', 'available'),
(9, 20180034, 1, 900000, '2026-06-01', 'available'),
(10, 20160099, 1, 550000, '2026-06-01', 'available'),
(11, 20250331, 1, 500000, '2026-06-01', 'available'),
(12, 20130156, 2, 700000, '2026-06-01', 'available'),
(13, 20200055, 2, 500000, '2026-06-01', 'available'),
(14, 20180105, 2, 250000, '2026-06-01', 'available'),
(15, 20150109, 2, 1200000, '2026-06-01', 'available'),
(16, 20240107, 2, 250000, '2026-06-01', 'available'),
(17, 20150050, 2, 500000, '2026-06-01', 'available'),
(18, 20230108, 2, 800000, '2026-06-01', 'available'),
(19, 20180088, 2, 1600000, '2026-06-01', 'available'),
(20, 20190171, 2, 300000, '2026-06-01', 'available'),
(21, 20230315, 2, 1000000, '2026-06-01', 'available'),
(22, 20260244, 2, 400000, '2026-06-01', 'available'),
(23, 20180025, 3, 1000000, '2026-06-01', 'available'),
(24, 20140143, 3, 400000, '2026-06-01', 'available'),
(25, 20220174, 3, 400000, '2026-06-01', 'available'),
(26, 20230029, 3, 325000, '2026-06-01', 'available'),
(27, 20100052, 3, 400000, '2026-06-01', 'available'),
(28, 20150052, 3, 1200000, '2026-06-01', 'available'),
(29, 20230043, 3, 1200000, '2026-06-01', 'available'),
(30, 20220276, 3, 550000, '2026-06-01', 'available'),
(31, 20180212, 3, 550000, '2026-06-01', 'available'),
(32, 20230224, 3, 600000, '2026-06-01', 'available'),
(33, 20170121, 3, 550000, '2026-06-01', 'available'),
(34, 20130134, 4, 150000, '2026-06-01', 'available'),
(35, 20230270, 4, 350000, '2026-06-01', 'available'),
(36, 20210104, 4, 600000, '2026-06-01', 'available'),
(37, 20240097, 4, 600000, '2026-06-01', 'available'),
(38, 20170182, 4, 375000, '2026-06-01', 'available'),
(39, 20200077, 4, 650000, '2026-06-01', 'available'),
(40, 20200066, 4, 450000, '2026-06-01', 'available'),
(41, 20230067, 4, 450000, '2026-06-01', 'available'),
(42, 20160098, 4, 700000, '2026-06-01', 'available'),
(43, 20170164, 4, 750000, '2026-06-01', 'available'),
(44, 20260043, 4, 125000, '2026-06-01', 'available'),
(45, 20160079, 5, 500000, '2026-06-01', 'available'),
(46, 20210182, 5, 375000, '2026-06-01', 'available'),
(47, 20200146, 5, 750000, '2026-06-01', 'available'),
(48, 20150067, 5, 350000, '2026-06-01', 'available'),
(49, 20060066, 5, 100000, '2026-06-01', 'available'),
(50, 20240062, 5, 125000, '2026-06-01', 'available'),
(51, 20240063, 5, 350000, '2026-06-01', 'available'),
(52, 20260024, 5, 600000, '2026-06-01', 'available'),
(53, 20210161, 5, 800000, '2026-06-01', 'available'),
(54, 20230148, 5, 350000, '2026-06-01', 'available'),
(55, 20260021, 5, 175000, '2026-06-01', 'available'),
(56, 20190064, 6, 550000, '2026-06-01', 'available'),
(57, 20140059, 6, 225000, '2026-06-01', 'available'),
(58, 20260160, 6, 350000, '2026-06-01', 'available'),
(59, 20210305, 6, 350000, '2026-06-01', 'available'),
(60, 20250189, 6, 300000, '2026-06-01', 'available'),
(61, 20220279, 6, 300000, '2026-06-01', 'available'),
(62, 20120127, 6, 300000, '2026-06-01', 'available'),
(63, 20180127, 6, 225000, '2026-06-01', 'available'),
(64, 20040081, 6, 250000, '2026-06-01', 'available'),
(65, 20210223, 6, 550000, '2026-06-01', 'available'),
(66, 20190131, 6, 225000, '2026-06-01', 'available'),
(67, 20190375, 7, 400000, '2026-06-01', 'available'),
(68, 20150080, 7, 200000, '2026-06-01', 'available'),
(69, 20140135, 7, 250000, '2026-06-01', 'available'),
(70, 20130101, 7, 200000, '2026-06-01', 'available'),
(71, 20130102, 7, 400000, '2026-06-01', 'available'),
(72, 20160073, 7, 275000, '2026-06-01', 'available'),
(73, 20240078, 7, 800000, '2026-06-01', 'available'),
(74, 20240080, 7, 150000, '2026-06-01', 'available'),
(75, 20200170, 7, 350000, '2026-06-01', 'available'),
(76, 20260091, 7, 300000, '2026-06-01', 'available'),
(77, 20240084, 7, 150000, '2026-06-01', 'available'),
(78, 20160156, 8, 550000, '2026-06-01', 'available'),
(79, 20210165, 8, 325000, '2026-06-01', 'available'),
(80, 20260221, 8, 300000, '2026-06-01', 'available'),
(81, 20250093, 8, 500000, '2026-06-01', 'available'),
(82, 20200103, 8, 325000, '2026-06-01', 'available'),
(83, 20240323, 8, 450000, '2026-06-01', 'available'),
(84, 20210108, 8, 275000, '2026-06-01', 'available'),
(85, 20160047, 8, 450000, '2026-06-01', 'available'),
(86, 20250095, 8, 350000, '2026-06-01', 'available'),
(87, 20260228, 8, 1000000, '2026-06-01', 'available'),
(88, 20130108, 8, 325000, '2026-06-01', 'available'),
(89, 20160010, 9, 250000, '2026-06-01', 'available'),
(90, 20160130, 9, 225000, '2026-06-01', 'available'),
(91, 20210174, 9, 225000, '2026-06-01', 'available'),
(92, 20190161, 9, 275000, '2026-06-01', 'available'),
(93, 20140203, 9, 200000, '2026-06-01', 'available'),
(94, 20190194, 9, 150000, '2026-06-01', 'available'),
(95, 20230141, 9, 350000, '2026-06-01', 'available'),
(96, 20100079, 9, 400000, '2026-06-01', 'available'),
(97, 20220353, 9, 325000, '2026-06-01', 'available'),
(98, 20230333, 9, 500000, '2026-06-01', 'available'),
(99, 20200048, 9, 300000, '2026-06-01', 'available'),
(100, 20120148, 10, 600000, '2026-06-01', 'available'),
(101, 20170122, 10, 800000, '2026-06-01', 'available'),
(102, 20160037, 10, 400000, '2026-06-01', 'available'),
(103, 20230239, 10, 300000, '2026-06-01', 'available'),
(104, 20230048, 10, 700000, '2026-06-01', 'available'),
(105, 20210176, 10, 1000000, '2026-06-01', 'available'),
(106, 20230326, 10, 600000, '2026-06-01', 'available'),
(107, 20180110, 10, 450000, '2026-06-01', 'available'),
(108, 20230105, 10, 850000, '2026-06-01', 'available'),
(109, 20130248, 10, 700000, '2026-06-01', 'available'),
(110, 20250360, 10, 350000, '2026-06-01', 'available'),
(111, 20190154, 11, 350000, '2026-06-01', 'available'),
(112, 20220139, 11, 325000, '2026-06-01', 'available'),
(113, 20180324, 11, 350000, '2026-06-01', 'available'),
(114, 20230198, 11, 350000, '2026-06-01', 'available'),
(115, 20200317, 11, 500000, '2026-06-01', 'available'),
(116, 20180096, 11, 375000, '2026-06-01', 'available'),
(117, 20170022, 11, 700000, '2026-06-01', 'available'),
(118, 20190124, 11, 300000, '2026-06-01', 'available'),
(119, 20200164, 11, 175000, '2026-06-01', 'available'),
(120, 20180123, 11, 600000, '2026-06-01', 'available'),
(121, 20200174, 11, 375000, '2026-06-01', 'available'),
(122, 20140102, 12, 375000, '2026-06-01', 'available'),
(123, 20190114, 12, 125000, '2026-06-01', 'available'),
(124, 20260209, 12, 150000, '2026-06-01', 'available'),
(125, 20220053, 12, 400000, '2026-06-01', 'available'),
(126, 20120116, 12, 200000, '2026-06-01', 'available'),
(127, 20240210, 12, 225000, '2026-06-01', 'available'),
(128, 20230080, 12, 225000, '2026-06-01', 'available'),
(129, 20120151, 12, 225000, '2026-06-01', 'available'),
(130, 20200029, 12, 125000, '2026-06-01', 'available'),
(131, 20240209, 12, 100000, '2026-06-01', 'available'),
(132, 20250366, 12, 250000, '2026-06-01', 'available'),
(133, 238097, 1, 4600000, '2026-06-01', 'available'),
(134, 180283, 1, 1400000, '2026-06-01', 'available'),
(135, 193847, 1, 800000, '2026-06-01', 'available'),
(136, 210544, 1, 1800000, '2026-06-01', 'available'),
(137, 244582, 1, 1800000, '2026-06-01', 'available'),
(138, 205401, 2, 5500000, '2026-06-01', 'available'),
(139, 213189, 2, 2700000, '2026-06-01', 'available'),
(140, 246937, 2, 4600000, '2026-06-01', 'available'),
(141, 201528, 2, 1500000, '2026-06-01', 'available'),
(142, 268097, 2, 2400000, '2026-06-01', 'available'),
(143, 237424, 3, 3700000, '2026-06-01', 'available'),
(144, 227788, 3, 2100000, '2026-06-01', 'available'),
(145, 243061, 3, 2600000, '2026-06-01', 'available'),
(146, 238576, 3, 2200000, '2026-06-01', 'available'),
(147, 243673, 3, 2200000, '2026-06-01', 'available'),
(148, 233018, 4, 2200000, '2026-06-01', 'available'),
(149, 211004, 4, 1200000, '2026-06-01', 'available'),
(150, 222582, 4, 950000, '2026-06-01', 'available'),
(151, 213878, 4, 1200000, '2026-06-01', 'available'),
(152, 270203, 4, 1600000, '2026-06-01', 'available'),
(153, 209210, 5, 2500000, '2026-06-01', 'available'),
(154, 268313, 5, 2500000, '2026-06-01', 'available'),
(155, 272733, 5, 1900000, '2026-06-01', 'available'),
(156, 207730, 5, 1600000, '2026-06-01', 'available'),
(157, 255917, 5, 3600000, '2026-06-01', 'available'),
(158, 223994, 6, 2000000, '2026-06-01', 'available'),
(159, 202986, 6, 875000, '2026-06-01', 'available'),
(160, 209449, 6, 1500000, '2026-06-01', 'available'),
(161, 241970, 6, 1300000, '2026-06-01', 'available'),
(162, 221643, 6, 1300000, '2026-06-01', 'available'),
(163, 212439, 8, 1500000, '2026-06-01', 'available'),
(164, 205156, 8, 1100000, '2026-06-01', 'available'),
(165, 211786, 8, 1500000, '2026-06-01', 'available'),
(166, 202749, 8, 450000, '2026-06-01', 'available'),
(167, 238763, 8, 1700000, '2026-06-01', 'available'),
(168, 263034, 10, 2300000, '2026-06-01', 'available'),
(169, 238578, 10, 1900000, '2026-06-01', 'available'),
(170, 208063, 10, 1300000, '2026-06-01', 'available'),
(171, 267825, 10, 1600000, '2026-06-01', 'available'),
(172, 223336, 10, 1400000, '2026-06-01', 'available'),
(173, 209839, 12, 1500000, '2026-06-01', 'available'),
(174, 260492, 12, 3400000, '2026-06-01', 'available'),
(175, 208073, 12, 675000, '2026-06-01', 'available'),
(176, 263166, 12, 1700000, '2026-06-01', 'available'),
(177, 243422, 12, 1300000, '2026-06-01', 'available');

-- AUTO_INCREMENT 상한 조정 (소스 ID 충돌 방지)
ALTER TABLE PLAYER AUTO_INCREMENT = 30000000;


-- =====================================================
-- [4/5] EXTENSIONS -- SEASON / AUDIT_LOG / 트리거 / 뷰 / 인덱스
-- =====================================================

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


-- =====================================================
-- [5/5] PROCEDURES -- 프로시저 6개
-- =====================================================

-- =====================================================
-- K리그 이적시장 기반 스토브리그 체험 DB 시스템
-- STORED PROCEDURES
-- ※ 재실행 시 기존 프로시저 삭제 후 재생성
-- =====================================================

USE kleague_db;

DROP PROCEDURE IF EXISTS sp_buy_player;
DROP PROCEDURE IF EXISTS sp_release_player;
DROP PROCEDURE IF EXISTS sp_create_squad_battle;
DROP PROCEDURE IF EXISTS sp_list_player_for_transfer;
DROP PROCEDURE IF EXISTS sp_cancel_listing;
DROP PROCEDURE IF EXISTS sp_start_new_season;

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
    --    + season_id: 현재 활성 시즌
    INSERT INTO TRANSFER_HISTORY
        (player_id, from_club_id, to_club_id, transfer_type, fee, transfer_date, season_id)
    VALUES
        (v_player_id, v_seller_club_id, v_buyer_club_id, 'transfer', v_asking_fee, CURDATE(),
         (SELECT season_id FROM SEASON WHERE status='active' LIMIT 1));

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
-- =====================================================
DELIMITER $$
CREATE PROCEDURE sp_release_player(
    IN p_user_id   INT,
    IN p_player_id INT
)
BEGIN
    DECLARE v_club_id      INT;
    DECLARE v_player_club  INT;
    DECLARE v_squad_count  INT;

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

    -- 2-1. 최소 스쿼드 인원 확인 (방출 후 10명 이하 방지)
    SELECT COUNT(*) INTO v_squad_count
    FROM PLAYER WHERE club_id = v_club_id;

    IF v_squad_count <= 11 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '스쿼드가 11명 이하라 방출할 수 없습니다. (최소 11명 유지)';
    END IF;

    -- 3. 기존 CONTRACT expired 처리
    UPDATE CONTRACT
    SET status = 'expired'
    WHERE player_id = p_player_id AND status = 'active';

    -- 4. PLAYER.club_id = NULL (소속 없음)
    UPDATE PLAYER SET club_id = NULL WHERE player_id = p_player_id;

    -- 5. TRANSFER_HISTORY에 release 기록 (현재 시즌 id 함께 기록)
    INSERT INTO TRANSFER_HISTORY
        (player_id, from_club_id, to_club_id, transfer_type, fee, transfer_date, season_id)
    VALUES
        (p_player_id, v_club_id, NULL, 'release', 0, CURDATE(),
         (SELECT season_id FROM SEASON WHERE status='active' LIMIT 1));

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
-- PROCEDURE 3. sp_list_player_for_transfer (이적시장 등록)
-- 호출 예시: CALL sp_list_player_for_transfer(1, 7, 5000000);
--   p_user_id    : 등록하는 유저 ID
--   p_player_id  : 등록할 선수 ID
--   p_asking_fee : 요구 이적료
--
-- 처리 순서:
--   1. 유저 구단 확인
--   2. 선수가 해당 구단 소속인지 확인
--   3. 이적료 유효성 확인
--   4. TRANSFER_MARKET에 available 등록
-- =====================================================
DELIMITER $$
CREATE PROCEDURE sp_list_player_for_transfer(
    IN p_user_id    INT,
    IN p_player_id  INT,
    IN p_asking_fee DECIMAL(15,2)
)
BEGIN
    DECLARE v_club_id     INT;
    DECLARE v_player_club INT;

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

    -- 3. 이적료 유효성 확인
    IF p_asking_fee < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '이적료는 0 이상이어야 합니다.';
    END IF;

    -- 4. TRANSFER_MARKET 등록
    INSERT INTO TRANSFER_MARKET (player_id, seller_club_id, asking_fee, listed_date, status)
    VALUES (p_player_id, v_club_id, p_asking_fee, CURDATE(), 'available');

    SELECT 'LISTING_CREATED' AS result_code,
           p_player_id       AS player_id,
           p_asking_fee      AS asking_fee;

END$$
DELIMITER ;


-- =====================================================
-- PROCEDURE 4. sp_cancel_listing (이적시장 등록 취소)
-- 호출 예시: CALL sp_cancel_listing(1, 3);
--   p_user_id    : 취소를 요청하는 유저 ID
--   p_listing_id : 취소할 매물 ID
--
-- 처리 순서:
--   1. 유저 구단 확인
--   2. 매물 존재 여부 확인
--   3. 본인 구단 매물인지 확인
--   4. available 상태인지 확인
--   5. status = 'cancelled' 로 변경
-- =====================================================
DELIMITER $$
CREATE PROCEDURE sp_cancel_listing(
    IN p_user_id    INT,
    IN p_listing_id INT
)
BEGIN
    DECLARE v_club_id       INT;
    DECLARE v_seller_club   INT;
    DECLARE v_market_status VARCHAR(10);

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

    -- 2. 매물 정보 조회
    SELECT seller_club_id, status
    INTO v_seller_club, v_market_status
    FROM TRANSFER_MARKET WHERE listing_id = p_listing_id;

    IF v_seller_club IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '존재하지 않는 매물입니다.';
    END IF;

    -- 3. 본인 구단 매물인지 확인
    IF v_seller_club <> v_club_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '자신의 구단이 등록한 매물만 취소할 수 있습니다.';
    END IF;

    -- 4. available 상태인지 확인
    IF v_market_status <> 'available' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '이미 거래 완료되었거나 취소된 매물입니다.';
    END IF;

    -- 5. 매물 상태 cancelled 변경
    UPDATE TRANSFER_MARKET
    SET status = 'cancelled'
    WHERE listing_id = p_listing_id;

    COMMIT;

    SELECT 'LISTING_CANCELLED' AS result_code,
           p_listing_id        AS listing_id;

END$$
DELIMITER ;


-- =====================================================
-- PROCEDURE 5. sp_create_squad_battle (스쿼드 대결)
-- 호출 예시: CALL sp_create_squad_battle(1, 2);
--   p_home_club_id : 홈 구단 ID
--   p_away_club_id : 원정 구단 ID
--
-- 점수 산정: 포지션 가중치(GK 15%·DF 30%·MF 30%·FW 25%)
--           + 랜덤 ±5% 적용
--
-- 처리 순서:
--   1. 같은 구단끼리 대결 방지
--   2. 포지션 가중치로 양팀 점수 계산
--   3. 랜덤 변동(±5%) 적용
--   4. 점수 비교 → result 결정
--   5. SQUAD_BATTLE에 저장
-- =====================================================
DELIMITER $$
CREATE PROCEDURE sp_create_squad_battle(
    IN p_home_club_id INT,
    IN p_away_club_id INT
)
BEGIN
    DECLARE v_home_gk    DECIMAL(6,2) DEFAULT 0;
    DECLARE v_home_df    DECIMAL(6,2) DEFAULT 0;
    DECLARE v_home_mf    DECIMAL(6,2) DEFAULT 0;
    DECLARE v_home_fw    DECIMAL(6,2) DEFAULT 0;
    DECLARE v_away_gk    DECIMAL(6,2) DEFAULT 0;
    DECLARE v_away_df    DECIMAL(6,2) DEFAULT 0;
    DECLARE v_away_mf    DECIMAL(6,2) DEFAULT 0;
    DECLARE v_away_fw    DECIMAL(6,2) DEFAULT 0;
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

    -- 2. 홈팀 포지션별 평균 오버롤
    SELECT
        IFNULL(AVG(CASE WHEN p.position = 'GK' THEN ps.overall END), 0),
        IFNULL(AVG(CASE WHEN p.position = 'DF' THEN ps.overall END), 0),
        IFNULL(AVG(CASE WHEN p.position = 'MF' THEN ps.overall END), 0),
        IFNULL(AVG(CASE WHEN p.position = 'FW' THEN ps.overall END), 0)
    INTO v_home_gk, v_home_df, v_home_mf, v_home_fw
    FROM PLAYER p
    JOIN PLAYER_STATS ps ON p.player_id = ps.player_id
    WHERE p.club_id = p_home_club_id;

    -- 3. 원정팀 포지션별 평균 오버롤
    SELECT
        IFNULL(AVG(CASE WHEN p.position = 'GK' THEN ps.overall END), 0),
        IFNULL(AVG(CASE WHEN p.position = 'DF' THEN ps.overall END), 0),
        IFNULL(AVG(CASE WHEN p.position = 'MF' THEN ps.overall END), 0),
        IFNULL(AVG(CASE WHEN p.position = 'FW' THEN ps.overall END), 0)
    INTO v_away_gk, v_away_df, v_away_mf, v_away_fw
    FROM PLAYER p
    JOIN PLAYER_STATS ps ON p.player_id = ps.player_id
    WHERE p.club_id = p_away_club_id;

    -- 4. 가중치 합산 + 랜덤 ±5% 적용 + 홈 어드밴티지 +2
    --    GK 15% · DF 30% · MF 30% · FW 25%
    --    홈팀에 +2 보정 (홈 어드밴티지)
    SET v_home_score = ROUND(
        (v_home_gk * 0.15 + v_home_df * 0.30 + v_home_mf * 0.30 + v_home_fw * 0.25)
        * (0.95 + RAND() * 0.10) + 2, 2
    );
    SET v_away_score = ROUND(
        (v_away_gk * 0.15 + v_away_df * 0.30 + v_away_mf * 0.30 + v_away_fw * 0.25)
        * (0.95 + RAND() * 0.10), 2
    );

    -- 5. 결과 결정
    IF v_home_score > v_away_score THEN
        SET v_result = 'home';
    ELSEIF v_home_score < v_away_score THEN
        SET v_result = 'away';
    ELSE
        SET v_result = 'draw';
    END IF;

    -- 6. SQUAD_BATTLE에 저장 (현재 시즌 id 함께 기록)
    INSERT INTO SQUAD_BATTLE
        (home_club_id, away_club_id, home_score, away_score, result, battle_date, season_id)
    VALUES
        (p_home_club_id, p_away_club_id, v_home_score, v_away_score, v_result, CURDATE(),
         (SELECT season_id FROM SEASON WHERE status='active' LIMIT 1));

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
-- PROCEDURE 5. sp_start_new_season (시즌 종료 + 새 시즌 시작)
-- 호출 예시: CALL sp_start_new_season('2025-26');
--   p_new_season_name : 새 시즌 이름
--
-- 처리 순서:
--   1. 활성 시즌 조회
--   2. 활성 시즌의 승점 1위 = 우승팀 산출 (V_SEASON_STANDING)
--   3. 활성 시즌 종료(status='ended', end_date, champion 저장)
--   4. 신규 시즌 INSERT
-- =====================================================
DELIMITER $$
CREATE PROCEDURE sp_start_new_season(
    IN p_new_season_name VARCHAR(20)
)
BEGIN
    DECLARE v_current_id   INT;
    DECLARE v_champion_id  INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. 현재 활성 시즌
    SELECT season_id INTO v_current_id
    FROM SEASON WHERE status = 'active' LIMIT 1;

    IF v_current_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '활성 시즌이 없습니다.';
    END IF;

    -- 2. 우승팀 = V_SEASON_STANDING의 1위 (승점 → 승수 정렬)
    SELECT club_id INTO v_champion_id
    FROM V_SEASON_STANDING
    ORDER BY points DESC, wins DESC, club_id ASC
    LIMIT 1;

    -- 3. 현재 시즌 종료
    UPDATE SEASON
    SET status = 'ended',
        end_date = CURDATE(),
        champion_club_id = v_champion_id
    WHERE season_id = v_current_id;

    -- 4. 새 시즌 시작
    INSERT INTO SEASON (season_name, start_date, status)
    VALUES (p_new_season_name, CURDATE(), 'active');

    COMMIT;

    -- 결과 확인
    SELECT
        'SEASON_TRANSITIONED' AS result_code,
        p_new_season_name     AS new_season,
        v_champion_id         AS prev_champion_club_id,
        (SELECT name FROM CLUB WHERE club_id = v_champion_id) AS champion_name;
END$$
DELIMITER ;

