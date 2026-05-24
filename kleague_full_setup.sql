DROP DATABASE IF EXISTS kleague_db;
CREATE DATABASE kleague_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE kleague_db;

CREATE TABLE data_sources (
    source_id VARCHAR(40) PRIMARY KEY,
    source_name VARCHAR(120) NOT NULL,
    source_url VARCHAR(500) NOT NULL,
    used_for VARCHAR(500) NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE clubs (
    club_id INT NOT NULL,
    source_team_id VARCHAR(10) NOT NULL UNIQUE,
    club_name VARCHAR(100) NOT NULL UNIQUE,
    city VARCHAR(80) NOT NULL,
    founded_year SMALLINT NOT NULL,
    stadium_name VARCHAR(120) NOT NULL,
    stadium_capacity INT NOT NULL,
    initial_budget_eur DECIMAL(15,2) NOT NULL,
    current_budget_eur DECIMAL(15,2) NOT NULL,
    club_homepage VARCHAR(255),
    data_source_url VARCHAR(500),
    PRIMARY KEY (club_id),
    CONSTRAINT chk_club_capacity CHECK (stadium_capacity > 0),
    CONSTRAINT chk_club_initial_budget CHECK (initial_budget_eur >= 0),
    CONSTRAINT chk_club_current_budget CHECK (current_budget_eur >= 0)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE managers (
    manager_id INT NOT NULL,
    club_id INT NOT NULL UNIQUE,
    manager_name VARCHAR(100) NOT NULL,
    nationality VARCHAR(80) NOT NULL,
    preferred_formation VARCHAR(20) NOT NULL,
    rating TINYINT NOT NULL,
    rating_source VARCHAR(40) NOT NULL DEFAULT 'SIMULATION_RULE',
    PRIMARY KEY (manager_id),
    CONSTRAINT fk_managers_club FOREIGN KEY (club_id) REFERENCES clubs(club_id),
    CONSTRAINT chk_manager_rating CHECK (rating BETWEEN 1 AND 99)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE players (
    player_id INT NOT NULL,
    source_player_id VARCHAR(20) NOT NULL UNIQUE,
    club_id INT NULL,
    player_name VARCHAR(120) NOT NULL,
    nationality VARCHAR(80) NOT NULL,
    birth_date DATE NULL,
    age SMALLINT NULL,
    position_group ENUM('GK','DF','MF','FW') NOT NULL,
    primary_position VARCHAR(60) NOT NULL,
    squad_number SMALLINT NULL,
    squad_role ENUM('starter','sub') NOT NULL DEFAULT 'starter',
    height_cm SMALLINT NULL,
    weight_kg SMALLINT NULL,
    preferred_foot VARCHAR(20) NOT NULL DEFAULT 'Unknown',
    market_value_eur DECIMAL(15,2) NOT NULL DEFAULT 0,
    contract_until DATE NULL,
    joined_date DATE NULL,
    profile_source_url VARCHAR(500),
    value_source_url VARCHAR(500),
    PRIMARY KEY (player_id),
    CONSTRAINT fk_players_club FOREIGN KEY (club_id) REFERENCES clubs(club_id),
    CONSTRAINT chk_player_age CHECK (age IS NULL OR age BETWEEN 14 AND 60),
    CONSTRAINT chk_player_height CHECK (height_cm IS NULL OR height_cm BETWEEN 140 AND 220),
    CONSTRAINT chk_player_weight CHECK (weight_kg IS NULL OR weight_kg BETWEEN 40 AND 150),
    CONSTRAINT chk_player_market_value CHECK (market_value_eur >= 0),
    INDEX idx_players_club_position (club_id, position_group),
    INDEX idx_players_club_role (club_id, squad_role),
    INDEX idx_players_market_value (market_value_eur),
    INDEX idx_players_name (player_name)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE player_stats (
    player_id INT NOT NULL,
    appearances SMALLINT NOT NULL DEFAULT 0,
    starts_estimated SMALLINT NOT NULL DEFAULT 0,
    goals SMALLINT NOT NULL DEFAULT 0,
    assists SMALLINT NOT NULL DEFAULT 0,
    shots SMALLINT NOT NULL DEFAULT 0,
    yellow_cards SMALLINT NOT NULL DEFAULT 0,
    red_cards SMALLINT NOT NULL DEFAULT 0,
    pace TINYINT NOT NULL,
    shooting TINYINT NOT NULL,
    passing TINYINT NOT NULL,
    defending TINYINT NOT NULL,
    physical TINYINT NOT NULL,
    overall DECIMAL(5,2) GENERATED ALWAYS AS
        (ROUND((pace + shooting + passing + defending + physical) / 5, 2)) STORED,
    rating_source VARCHAR(40) NOT NULL DEFAULT 'DERIVED_PUBLIC_DATA',
    PRIMARY KEY (player_id),
    CONSTRAINT fk_stats_player FOREIGN KEY (player_id) REFERENCES players(player_id),
    CONSTRAINT chk_stats_nonnegative CHECK (
        appearances >= 0 AND starts_estimated >= 0 AND goals >= 0 AND assists >= 0
        AND shots >= 0 AND yellow_cards >= 0 AND red_cards >= 0
    ),
    CONSTRAINT chk_stats_rating_range CHECK (
        pace BETWEEN 1 AND 99 AND shooting BETWEEN 1 AND 99 AND passing BETWEEN 1 AND 99
        AND defending BETWEEN 1 AND 99 AND physical BETWEEN 1 AND 99
    ),
    INDEX idx_stats_overall (overall)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE contracts (
    contract_id INT NOT NULL AUTO_INCREMENT,
    player_id INT NOT NULL,
    club_id INT NOT NULL,
    start_date DATE NULL,
    end_date DATE NULL,
    salary_eur DECIMAL(15,2) NOT NULL DEFAULT 0,
    status ENUM('active','expired','released') NOT NULL DEFAULT 'active',
    PRIMARY KEY (contract_id),
    CONSTRAINT fk_contracts_player FOREIGN KEY (player_id) REFERENCES players(player_id),
    CONSTRAINT fk_contracts_club FOREIGN KEY (club_id) REFERENCES clubs(club_id),
    CONSTRAINT chk_contract_salary CHECK (salary_eur >= 0),
    CONSTRAINT chk_contract_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date > start_date),
    INDEX idx_contracts_player_status (player_id, status),
    INDEX idx_contracts_club_status (club_id, status)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE app_users (
    user_id INT NOT NULL,
    username VARCHAR(60) NOT NULL UNIQUE,
    club_id INT NOT NULL,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_users_club FOREIGN KEY (club_id) REFERENCES clubs(club_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE transfer_market (
    listing_id INT NOT NULL,
    player_id INT NOT NULL,
    seller_club_id INT NOT NULL,
    asking_fee_eur DECIMAL(15,2) NOT NULL,
    listed_date DATE NOT NULL,
    status ENUM('available','sold','cancelled') NOT NULL DEFAULT 'available',
    PRIMARY KEY (listing_id),
    CONSTRAINT fk_market_player FOREIGN KEY (player_id) REFERENCES players(player_id),
    CONSTRAINT fk_market_seller FOREIGN KEY (seller_club_id) REFERENCES clubs(club_id),
    CONSTRAINT chk_market_fee CHECK (asking_fee_eur >= 0),
    INDEX idx_market_status_fee (status, asking_fee_eur),
    INDEX idx_market_player_status (player_id, status)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE transfer_history (
    transfer_id INT NOT NULL AUTO_INCREMENT,
    player_id INT NOT NULL,
    from_club_id INT NULL,
    to_club_id INT NULL,
    transfer_type ENUM('buy','sell','release','free_agent','loan') NOT NULL,
    fee_eur DECIMAL(15,2) NOT NULL DEFAULT 0,
    transfer_date DATE NOT NULL,
    created_by_user_id INT NULL,
    memo VARCHAR(500),
    PRIMARY KEY (transfer_id),
    CONSTRAINT fk_history_player FOREIGN KEY (player_id) REFERENCES players(player_id),
    CONSTRAINT fk_history_from_club FOREIGN KEY (from_club_id) REFERENCES clubs(club_id),
    CONSTRAINT fk_history_to_club FOREIGN KEY (to_club_id) REFERENCES clubs(club_id),
    CONSTRAINT fk_history_user FOREIGN KEY (created_by_user_id) REFERENCES app_users(user_id),
    CONSTRAINT chk_history_fee CHECK (fee_eur >= 0),
    CONSTRAINT chk_history_has_side CHECK (from_club_id IS NOT NULL OR to_club_id IS NOT NULL),
    CONSTRAINT chk_history_diff_club CHECK (from_club_id IS NULL OR to_club_id IS NULL OR from_club_id <> to_club_id),
    INDEX idx_history_date (transfer_date),
    INDEX idx_history_player (player_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE squad_battles (
    battle_id INT NOT NULL AUTO_INCREMENT,
    home_club_id INT NOT NULL,
    away_club_id INT NOT NULL,
    home_score DECIMAL(6,2) NOT NULL,
    away_score DECIMAL(6,2) NOT NULL,
    result ENUM('home','away','draw') NOT NULL,
    battle_date DATE NOT NULL,
    PRIMARY KEY (battle_id),
    CONSTRAINT fk_battle_home FOREIGN KEY (home_club_id) REFERENCES clubs(club_id),
    CONSTRAINT fk_battle_away FOREIGN KEY (away_club_id) REFERENCES clubs(club_id),
    CONSTRAINT chk_battle_diff_club CHECK (home_club_id <> away_club_id),
    INDEX idx_battle_date (battle_date)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE VIEW v_club_budget AS
SELECT
    club_id,
    club_name,
    initial_budget_eur,
    current_budget_eur,
    initial_budget_eur - current_budget_eur AS total_spent_eur
FROM clubs;

CREATE VIEW v_player_info AS
SELECT
    p.player_id,
    p.player_name,
    p.nationality,
    p.position_group,
    p.primary_position,
    p.squad_role,
    c.club_name,
    p.market_value_eur,
    ps.appearances,
    ps.goals,
    ps.assists,
    ps.pace,
    ps.shooting,
    ps.passing,
    ps.defending,
    ps.physical,
    ps.overall
FROM players p
LEFT JOIN clubs c ON p.club_id = c.club_id
LEFT JOIN player_stats ps ON p.player_id = ps.player_id;

CREATE VIEW v_squad_score AS
SELECT
    c.club_id,
    c.club_name,
    m.manager_name,
    m.preferred_formation,
    COUNT(p.player_id) AS player_count,
    ROUND(AVG(ps.overall), 2) AS avg_player_overall,
    m.rating AS manager_rating,
    ROUND(AVG(ps.overall) * 0.85 + m.rating * 0.15, 2) AS squad_score
FROM clubs c
JOIN managers m ON c.club_id = m.club_id
LEFT JOIN players p ON c.club_id = p.club_id AND p.squad_role = 'starter'
LEFT JOIN player_stats ps ON p.player_id = ps.player_id
GROUP BY c.club_id, c.club_name, m.manager_name, m.preferred_formation, m.rating;

CREATE VIEW v_transfer_market AS
SELECT
    tm.listing_id,
    tm.player_id,
    p.player_name,
    p.position_group,
    p.primary_position,
    p.nationality,
    ps.overall,
    c.club_name AS seller_club,
    tm.seller_club_id,
    tm.asking_fee_eur,
    tm.listed_date,
    tm.status
FROM transfer_market tm
JOIN players p ON tm.player_id = p.player_id
JOIN player_stats ps ON p.player_id = ps.player_id
JOIN clubs c ON tm.seller_club_id = c.club_id
WHERE tm.status = 'available';

CREATE VIEW v_expiring_contracts AS
SELECT
    p.player_id,
    p.player_name,
    p.position_group,
    c.club_name,
    ct.end_date,
    DATEDIFF(ct.end_date, CURDATE()) AS days_remaining
FROM contracts ct
JOIN players p ON ct.player_id = p.player_id
JOIN clubs c ON ct.club_id = c.club_id
WHERE ct.status = 'active'
  AND ct.end_date IS NOT NULL
  AND ct.end_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 6 MONTH);

CREATE VIEW v_position_depth AS
SELECT
    c.club_id,
    c.club_name,
    p.position_group,
    COUNT(*) AS player_count,
    ROUND(AVG(ps.overall), 2) AS avg_overall
FROM clubs c
JOIN players p ON c.club_id = p.club_id
JOIN player_stats ps ON p.player_id = ps.player_id
GROUP BY c.club_id, c.club_name, p.position_group;

CREATE VIEW v_club_market_value AS
SELECT
    c.club_id,
    c.club_name,
    COUNT(p.player_id) AS player_count,
    SUM(p.market_value_eur) AS squad_market_value_eur,
    ROUND(AVG(p.market_value_eur), 2) AS avg_market_value_eur
FROM clubs c
LEFT JOIN players p ON c.club_id = p.club_id
GROUP BY c.club_id, c.club_name;

DELIMITER $$
CREATE TRIGGER trg_club_budget_before_update
BEFORE UPDATE ON clubs
FOR EACH ROW
BEGIN
    IF NEW.current_budget_eur < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Current budget cannot be negative';
    END IF;
END$$

CREATE TRIGGER trg_market_before_insert
BEFORE INSERT ON transfer_market
FOR EACH ROW
BEGIN
    DECLARE v_current_club_id INT;
    SELECT club_id INTO v_current_club_id FROM players WHERE player_id = NEW.player_id;

    IF v_current_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Released players cannot be listed by a club';
    END IF;

    IF v_current_club_id <> NEW.seller_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller club must match current player club';
    END IF;

    IF NEW.status = 'available'
       AND EXISTS (
           SELECT 1 FROM transfer_market
           WHERE player_id = NEW.player_id AND status = 'available'
       ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Player already has an available listing';
    END IF;
END$$

CREATE TRIGGER trg_market_before_update
BEFORE UPDATE ON transfer_market
FOR EACH ROW
BEGIN
    IF NEW.status = 'available'
       AND EXISTS (
           SELECT 1 FROM transfer_market
           WHERE player_id = NEW.player_id
             AND status = 'available'
             AND listing_id <> NEW.listing_id
       ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Player already has an available listing';
    END IF;
END$$
DELIMITER ;

USE kleague_db;

SET NAMES utf8mb4;

INSERT INTO data_sources (source_id, source_name, source_url, used_for) VALUES
('SRC_KLEAGUE_PLAYER', 'K League official player detail', 'https://www.kleague.com/record/playerDetail.do?playerId={PLAYER_ID}', 'player identity, team, position, number, nationality, height, weight, birth date'),
('SRC_KLEAGUE_STATS', 'K League official player records', 'https://www.kleague.com/record/selectPersonalRecordByClub.do', 'appearances, goals, assists, shots, cards'),
('SRC_TRANSFERMARKT', 'Transfermarkt squad pages', 'stored per club/player in source CSV', 'market value, foot, detailed position, joined date, contract date'),
('SRC_SIM_RULE', 'Simulation rules', 'local project rule', 'budget, manager rating, salary, simulator ability scores');

INSERT INTO clubs (club_id, source_team_id, club_name, city, founded_year, stadium_name, stadium_capacity, initial_budget_eur, current_budget_eur, club_homepage, data_source_url) VALUES
(1, 'K09', 'FC Seoul', 'Seoul', 1983, 'Seoul World Cup Stadium', 66704, 16400000, 16400000, 'https://www.fcseoul.com/', 'https://www.kleague.com/club/club.do?teamId=K09'),
(2, 'K01', 'Ulsan HD FC', 'Ulsan', 1983, 'Ulsan Munsu Football Stadium', 44102, 18800000, 18800000, 'https://www.uhdfc.com/fc/greetings.php', 'https://www.kleague.com/club/club.do?teamId=K01'),
(3, 'K05', 'Jeonbuk Hyundai Motors', 'Jeonju', 1994, 'Jeonju World Cup Stadium', 42477, 18000000, 18000000, 'https://www.hyundai-motorsfc.com', 'https://www.kleague.com/club/club.do?teamId=K05'),
(4, 'K21', 'Gangwon FC', 'Gangneung', 2008, 'Gangneung High1 Arena', 22333, 13000000, 13000000, 'https://www.gangwon-fc.com', 'https://www.kleague.com/club/club.do?teamId=K21'),
(5, 'K03', 'Pohang Steelers', 'Pohang', 1973, 'Pohang Steel Yard', 17443, 11200000, 11200000, 'https://www.steelers.co.kr', 'https://www.kleague.com/club/club.do?teamId=K03'),
(6, 'K18', 'Incheon United', 'Incheon', 2003, 'Incheon Football Stadium', 20891, 9100000, 9100000, 'https://www.incheonutd.com', 'https://www.kleague.com/club/club.do?teamId=K18'),
(7, 'K27', 'FC Anyang', 'Anyang', 2013, 'Anyang Sports Complex', 17143, 8700000, 8700000, 'https://www.fc-anyang.com', 'https://www.kleague.com/club/club.do?teamId=K27'),
(8, 'K04', 'Jeju SK', 'Seogwipo', 1982, 'Jeju World Cup Stadium', 29791, 12200000, 12200000, 'https://www.jejuskfc.com/', 'https://www.kleague.com/club/club.do?teamId=K04'),
(9, 'K26', 'Bucheon FC 1995', 'Bucheon', 2007, 'Bucheon Stadium', 34456, 8000000, 8000000, 'https://www.bfc1995.com', 'https://www.kleague.com/club/club.do?teamId=K26'),
(10, 'K10', 'Daejeon Hana Citizen', 'Daejeon', 1997, 'Daejeon World Cup Stadium', 40903, 16900000, 16900000, 'https://www.dhcfc.kr/', 'https://www.kleague.com/club/club.do?teamId=K10'),
(11, 'K35', 'Gimcheon Sangmu', 'Gimcheon', 2021, 'Gimcheon Sports Complex', 25000, 11000000, 11000000, 'https://gimcheonfc.com/', 'https://www.kleague.com/club/club.do?teamId=K35'),
(12, 'K22', 'Gwangju FC', 'Gwangju', 2010, 'Gwangju World Cup Stadium', 40245, 6000000, 6000000, 'https://www.gwangjufc.com/', 'https://www.kleague.com/club/club.do?teamId=K22');

INSERT INTO managers (manager_id, club_id, manager_name, nationality, preferred_formation, rating, rating_source) VALUES
(1, 1, 'Kim Gi-dong', 'South Korea', '4-3-3', 85, 'SIMULATION_RULE'),
(2, 2, 'Kim Hyun-seok', 'South Korea', '4-2-3-1', 88, 'SIMULATION_RULE'),
(3, 3, 'Jung Jung-yong', 'South Korea', '4-3-3', 87, 'SIMULATION_RULE'),
(4, 4, 'Jung Kyung-ho', 'South Korea', '4-4-2', 84, 'SIMULATION_RULE'),
(5, 5, 'Park Tae-ha', 'South Korea', '3-4-3', 82, 'SIMULATION_RULE'),
(6, 6, 'Yoon Jung-hwan', 'South Korea', '4-1-4-1', 80, 'SIMULATION_RULE'),
(7, 7, 'Yoo Byung-hoon', 'South Korea', '4-3-3', 79, 'SIMULATION_RULE'),
(8, 8, 'Sergio Costa', 'Portugal', '4-4-2', 83, 'SIMULATION_RULE'),
(9, 9, 'Lee Young-min', 'South Korea', '4-2-3-1', 78, 'SIMULATION_RULE'),
(10, 10, 'Hwang Sun-hong', 'South Korea', '4-2-3-1', 86, 'SIMULATION_RULE'),
(11, 11, 'Ju Seung-jin', 'South Korea', '4-3-3', 81, 'SIMULATION_RULE'),
(12, 12, 'Lee Jung-gyu', 'South Korea', '4-2-3-1', 77, 'SIMULATION_RULE');

INSERT INTO app_users (user_id, username, club_id) VALUES
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

INSERT INTO players (player_id, source_player_id, club_id, player_name, nationality, birth_date, age, position_group, primary_position, squad_number, height_cm, weight_kg, preferred_foot, market_value_eur, contract_until, joined_date, profile_source_url, value_source_url) VALUES
(20200301, '20200301', 1, 'Sungyun GU', 'South Korea', '1994-06-27', 31, 'GK', 'Goalkeeper', 25, 197, 95, 'right', 500000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20200301', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20260048, '20260048', 1, 'Juan Antonio ROS MARTINEZ', 'Spain', '1996-03-15', 30, 'DF', 'Centre-Back', 37, 187, 78, 'both', 850000, NULL, '2026-01-23', 'https://www.kleague.com/record/playerDetail.do?playerId=20260048', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20200041, '20200041', 1, 'Jun CHOI', 'South Korea', '1999-04-17', 27, 'DF', 'Right-Back', 16, 177, 72, 'right', 650000, NULL, '2024-01-05', 'https://www.kleague.com/record/playerDetail.do?playerId=20200041', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20170185, '20170185', 1, 'Jinsu KIM', 'South Korea', '1992-06-13', 33, 'DF', 'Left-Back', 22, 177, 68, 'left', 350000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20170185', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20240324, '20240324', 1, 'YAZAN MOUSA MAHMOUD ALARAB', 'Jordan', '1996-01-31', 30, 'DF', 'Centre-Back', 5, 187, 86, 'left', 900000, NULL, '2024-07-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20240324', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20170052, '20170052', 1, 'Seungmo LEE', 'South Korea', '1998-03-30', 28, 'MF', 'Central Midfield', 8, 185, 70, 'right', 450000, '2026-12-31', '2023-06-23', 'https://www.kleague.com/record/playerDetail.do?playerId=20170052', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20260045, '20260045', 1, 'Hrvoje BABEC', 'Croatia', '1999-07-28', 26, 'MF', 'Defensive Midfield', 6, 187, 84, 'right', 800000, '2028-12-31', '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20260045', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20260049, '20260049', 1, 'JEONGBEOM SON', 'South Korea', '2007-09-28', 18, 'MF', 'Central Midfield', 42, 184, 73, 'Unknown', 100000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20260049', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20180034, '20180034', 1, 'Minkyu SONG', 'South Korea', '1999-09-12', 26, 'FW', 'Left Winger', 34, 179, 72, 'right', 900000, NULL, '2026-01-21', 'https://www.kleague.com/record/playerDetail.do?playerId=20180034', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20160099, '20160099', 1, 'Seungwon JEONG', 'South Korea', '1997-02-27', 29, 'MF', 'Right Winger', 7, 173, 68, 'right', 550000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20160099', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20250331, '20250331', 1, 'Patryk KLIMALA', 'Poland', '1998-08-05', 27, 'FW', 'Centre-Forward', 9, 180, 79, 'right', 500000, NULL, '2025-06-02', 'https://www.kleague.com/record/playerDetail.do?playerId=20250331', 'https://www.transfermarkt.com/fc-seoul/kader/verein/6500/saison_id/2025/plus/1'),
(20130156, '20130156', 2, 'Hyeonwoo JO', 'South Korea', '1991-09-25', 34, 'GK', 'Goalkeeper', 21, 189, 75, 'right', 700000, NULL, '2020-01-20', 'https://www.kleague.com/record/playerDetail.do?playerId=20130156', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20200055, '20200055', 2, 'Hyuntaek CHO', 'South Korea', '2001-08-02', 24, 'DF', 'Left-Back', 26, 182, 76, 'left', 500000, NULL, '2020-01-10', 'https://www.kleague.com/record/playerDetail.do?playerId=20200055', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20180105, '20180105', 2, 'Jaeik LEE', 'South Korea', '1999-05-21', 27, 'DF', 'Centre-Back', 28, 185, 76, 'left', 250000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20180105', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20150109, '20150109', 2, 'Seunghyun JUNG', 'South Korea', '1994-04-03', 32, 'DF', 'Centre-Back', 15, 188, 74, 'right', 1200000, NULL, '2025-07-09', 'https://www.kleague.com/record/playerDetail.do?playerId=20150109', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20240107, '20240107', 2, 'Seokhyun CHOI', 'South Korea', '2003-01-13', 23, 'DF', 'Centre-Back', 96, 178, 77, 'right', 250000, NULL, '2024-01-03', 'https://www.kleague.com/record/playerDetail.do?playerId=20240107', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20150050, '20150050', 2, 'Gyusung LEE', 'South Korea', '1994-05-10', 32, 'MF', 'Central Midfield', 24, 174, 68, 'right', 500000, '2027-12-31', '2021-01-18', 'https://www.kleague.com/record/playerDetail.do?playerId=20150050', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20230108, '20230108', 2, 'Darijan BOJANIC', 'Sweden', '1994-12-28', 31, 'MF', 'Central Midfield', 6, 183, 74, 'right', 800000, '2027-12-31', '2023-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20230108', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20180088, '20180088', 2, 'Donggyeong LEE', 'South Korea', '1997-09-20', 28, 'MF', 'Attacking Midfield', 10, 175, 68, 'left', 1600000, NULL, '2018-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20180088', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20190171, '20190171', 2, 'Huigyun LEE', 'South Korea', '1998-04-29', 28, 'MF', 'Second Striker', 8, 168, 63, 'right', 300000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20190171', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20230315, '20230315', 2, 'Yago CARIELLO RIBEIRO', 'Brazil', '1999-07-27', 26, 'FW', 'Centre-Forward', 99, 186, 82, 'left', 1000000, NULL, '2024-07-09', 'https://www.kleague.com/record/playerDetail.do?playerId=20230315', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20260244, '20260244', 2, 'Benjamin Stanley MICHEL', 'United States', '1997-10-23', 28, 'FW', 'Left Winger', 91, 178, 77, 'right', 400000, NULL, '2026-02-14', 'https://www.kleague.com/record/playerDetail.do?playerId=20260244', 'https://www.transfermarkt.com/ulsan-hyundai/kader/verein/3535/saison_id/2025/plus/1'),
(20180025, '20180025', 3, 'Bumkeun SONG', 'South Korea', '1997-10-15', 28, 'GK', 'Goalkeeper', 31, 194, 88, 'right', 1000000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20180025', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20140143, '20140143', 3, 'YOUNGBIN KIM', 'South Korea', '1991-09-20', 34, 'DF', 'Centre-Back', 2, 184, 79, 'right', 400000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20140143', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20220174, '20220174', 3, 'Wijae CHO', 'South Korea', '2001-08-25', 24, 'DF', 'Centre-Back', 4, 189, 82, 'right', 400000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20220174', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20230029, '20230029', 3, 'Woojin CHOI', 'South Korea', '2004-07-18', 21, 'DF', 'Left-Back', 66, 175, 66, 'Unknown', 325000, NULL, '2025-02-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20230029', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20100052, '20100052', 3, 'Taehwan KIM', 'South Korea', '1989-07-24', 36, 'DF', 'Right-Back', 23, 177, 72, 'right', 400000, '2026-12-31', '2024-01-14', 'https://www.kleague.com/record/playerDetail.do?playerId=20100052', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20150052, '20150052', 3, 'Jingyu KIM', 'South Korea', '1997-02-24', 29, 'MF', 'Central Midfield', 97, 177, 68, 'right', 1200000, '2026-12-31', '2022-03-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20150052', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20230043, '20230043', 3, 'Oberdan ALIONCO DE LIMA', 'Brazil', '1995-07-30', 30, 'MF', 'Defensive Midfield', 8, 175, 69, 'right', 1200000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20230043', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20220276, '20220276', 3, 'Sangyoon KANG', 'South Korea', '2004-05-31', 21, 'MF', 'Central Midfield', 13, 171, 64, 'right', 550000, NULL, '2022-03-15', 'https://www.kleague.com/record/playerDetail.do?playerId=20220276', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20180212, '20180212', 3, 'Seungsub KIM', 'South Korea', '1996-11-01', 29, 'FW', 'Left Winger', 11, 177, 65, 'Unknown', 550000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20180212', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20230224, '20230224', 3, 'Bruno RODRIGUES MOTA', 'Brazil', '1996-02-10', 30, 'FW', 'Centre-Forward', 99, 193, 87, 'left', 600000, '2026-12-31', '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20230224', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20170121, '20170121', 3, 'Dongjun LEE', 'South Korea', '1997-02-01', 29, 'FW', 'Right Winger', 7, 173, 65, 'right', 550000, NULL, '2023-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20170121', 'https://www.transfermarkt.com/jeonbuk-hyundai-motors/kader/verein/6502/saison_id/2025/plus/1'),
(20130134, '20130134', 4, 'Cheonghyo PARK', 'South Korea', '1990-02-13', 36, 'GK', 'Goalkeeper', 1, 190, 78, 'right', 150000, NULL, '2024-01-23', 'https://www.kleague.com/record/playerDetail.do?playerId=20130134', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20230270, '20230270', 4, 'Junhyuk KANG', 'South Korea', '1999-10-20', 26, 'DF', 'Right-Back', 99, 177, 70, 'right', 350000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20230270', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20210104, '20210104', 4, 'Gihyuk LEE', 'South Korea', '2000-07-07', 25, 'DF', 'Centre-Back', 13, 184, 72, 'left', 600000, '2027-12-31', '2024-01-20', 'https://www.kleague.com/record/playerDetail.do?playerId=20210104', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20240097, '20240097', 4, 'Minah SHIN', 'South Korea', '2005-09-15', 20, 'DF', 'Centre-Back', 47, 186, 77, 'right', 600000, NULL, '2024-01-09', 'https://www.kleague.com/record/playerDetail.do?playerId=20240097', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20170182, '20170182', 4, 'Youhyeon LEE', 'South Korea', '1997-02-08', 29, 'MF', 'Right-Back', 97, 179, 74, 'right', 375000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20170182', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20200077, '20200077', 4, 'MINWOO SEO', 'South Korea', '1998-03-12', 28, 'MF', 'Defensive Midfield', 4, 183, 75, 'right', 650000, NULL, '2020-01-06', 'https://www.kleague.com/record/playerDetail.do?playerId=20200077', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20200066, '20200066', 4, 'YOUNGJUN GOH', 'South Korea', '2001-07-09', 24, 'MF', 'Attacking Midfield', 11, 169, 68, 'right', 450000, '2026-12-31', '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20200066', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20230067, '20230067', 4, 'Seungwon LEE', 'South Korea', '2003-03-06', 23, 'MF', 'Attacking Midfield', 8, 174, 73, 'right', 450000, NULL, '2023-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20230067', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20160098, '20160098', 4, 'DAEWON KIM', 'South Korea', '1997-02-10', 29, 'FW', 'Left Winger', 7, 171, 65, 'right', 700000, NULL, '2021-02-08', 'https://www.kleague.com/record/playerDetail.do?playerId=20160098', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20170164, '20170164', 4, 'Jaehyeon MO', 'South Korea', '1996-09-24', 29, 'FW', 'Right Winger', 10, 184, 74, 'right', 750000, '2027-12-31', '2025-06-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20170164', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20260043, '20260043', 4, 'ABDALLAH HLEIHIL', 'Israel', '2001-01-11', 25, 'FW', 'Centre-Forward', 77, 185, 77, 'Unknown', 125000, NULL, '2026-01-24', 'https://www.kleague.com/record/playerDetail.do?playerId=20260043', 'https://www.transfermarkt.com/gangwon-fc/kader/verein/21459/saison_id/2025/plus/1'),
(20160079, '20160079', 5, 'INJAE HWANG', 'South Korea', '1994-04-22', 32, 'GK', 'Goalkeeper', 21, 187, 73, 'Unknown', 500000, NULL, '2020-01-03', 'https://www.kleague.com/record/playerDetail.do?playerId=20160079', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20210182, '20210182', 5, 'Jeongwon EO', 'South Korea', '1999-07-08', 26, 'DF', 'Left-Back', 2, 175, 68, 'Unknown', 375000, NULL, '2024-01-02', 'https://www.kleague.com/record/playerDetail.do?playerId=20210182', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20200146, '20200146', 5, 'ChanYong Park', 'South Korea', '1996-01-27', 30, 'DF', 'Centre-Back', 20, 188, 80, 'right', 750000, NULL, '2022-01-02', 'https://www.kleague.com/record/playerDetail.do?playerId=20200146', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20150067, '20150067', 5, 'MINGWANG JEON', 'South Korea', '1993-01-17', 33, 'DF', 'Centre-Back', 4, 187, 73, 'right', 350000, NULL, '2019-01-04', 'https://www.kleague.com/record/playerDetail.do?playerId=20150067', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20060066, '20060066', 5, 'Kwanghoon SHIN', 'South Korea', '1987-03-18', 39, 'DF', 'Right-Back', 17, 178, 73, 'right', 100000, NULL, '2021-01-04', 'https://www.kleague.com/record/playerDetail.do?playerId=20060066', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20240062, '20240062', 5, 'Seowong HWANG', 'South Korea', '2005-01-22', 21, 'MF', 'Central Midfield', 70, 175, 67, 'Unknown', 125000, NULL, '2024-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20240062', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20240063, '20240063', 5, 'Dongjin KIM', 'South Korea', '2003-07-30', 22, 'MF', 'Central Midfield', 16, 180, 71, 'right', 350000, NULL, '2024-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20240063', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20260024, '20260024', 5, 'Kento NISHIYA', 'Japan', '1999-11-07', 26, 'MF', 'Defensive Midfield', 31, 175, 68, 'left', 600000, '2026-12-31', '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20260024', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20210161, '20210161', 5, 'Hojae LEE', 'South Korea', '2000-10-14', 25, 'FW', 'Centre-Forward', 19, 191, 85, 'right', 800000, '2027-12-31', '2021-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20210161', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20230148, '20230148', 5, 'Paulo Afonso ROCHA JUNIOR', 'Brazil', '1997-11-05', 28, 'FW', 'Right Winger', 11, 172, 64, 'left', 350000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20230148', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20260021, '20260021', 5, 'Jakob TRANZISKA', 'Germany', '2001-06-25', 24, 'FW', 'Centre-Forward', 10, 189, 82, 'right', 175000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20260021', 'https://www.transfermarkt.com/pohang-steelers/kader/verein/311/saison_id/2025/plus/1'),
(20190064, '20190064', 6, 'DONGHEON KIM', 'South Korea', '1997-03-03', 29, 'GK', 'Goalkeeper', 1, 186, 85, 'Unknown', 550000, NULL, '2019-01-04', 'https://www.kleague.com/record/playerDetail.do?playerId=20190064', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20140059, '20140059', 6, 'JUYONG LEE', 'South Korea', '1992-09-26', 33, 'DF', 'Left-Back', 32, 180, 78, 'left', 225000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20140059', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20260160, '20260160', 6, 'Juan FERNANDEZ BLANCO', 'Spain', '1995-08-17', 30, 'DF', 'Centre-Back', 2, 187, 80, 'left', 350000, '2026-12-31', '2026-01-30', 'https://www.kleague.com/record/playerDetail.do?playerId=20260160', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20210305, '20210305', 6, 'Myungsoon KIM', 'South Korea', '2000-07-17', 25, 'DF', 'Right-Back', 39, 177, 76, 'right', 350000, '2027-12-31', '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20210305', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20250189, '20250189', 6, 'Gyeongseop PARK', 'South Korea', '2004-07-02', 21, 'DF', 'Centre-Back', 20, 188, 83, 'Unknown', 300000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20250189', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20220279, '20220279', 6, 'Jaemin SEO', 'South Korea', '2003-09-16', 22, 'MF', 'Central Midfield', 15, 178, 73, 'left', 300000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20220279', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20120127, '20120127', 6, 'MYUNGJOO LEE', 'South Korea', '1990-04-24', 36, 'MF', 'Central Midfield', 5, 176, 74, 'right', 300000, NULL, '2022-01-30', 'https://www.kleague.com/record/playerDetail.do?playerId=20120127', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20180127, '20180127', 6, 'Huseong OH', 'South Korea', '1999-08-25', 26, 'DF', 'Attacking Midfield', 7, 173, 64, 'Unknown', 225000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20180127', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20040081, '20040081', 6, 'Chungyong LEE', 'South Korea', '1988-07-02', 37, 'MF', 'Right Winger', 72, 180, 69, 'right', 250000, NULL, '2026-02-11', 'https://www.kleague.com/record/playerDetail.do?playerId=20040081', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20210223, '20210223', 6, 'FERNANDES Gerso', 'Portugal', '1991-02-23', 35, 'MF', 'Left Winger', 11, 172, 62, 'left', 550000, NULL, '2023-01-10', 'https://www.kleague.com/record/playerDetail.do?playerId=20210223', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20190131, '20190131', 6, 'Dongryul LEE', 'South Korea', '2000-06-09', 25, 'FW', 'Left Winger', 10, 174, 70, 'left', 225000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20190131', 'https://www.transfermarkt.com/incheon-united/kader/verein/2996/saison_id/2025/plus/1'),
(20190375, '20190375', 7, 'JEONGHOON KIM', 'South Korea', '2001-04-20', 25, 'GK', 'Goalkeeper', 23, 188, 80, 'Unknown', 400000, '2028-12-31', '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20190375', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20150080, '20150080', 7, 'Taehee LEE', 'South Korea', '1992-06-16', 33, 'DF', 'Right-Back', 32, 181, 66, 'right', 200000, NULL, '2023-02-07', 'https://www.kleague.com/record/playerDetail.do?playerId=20150080', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20140135, '20140135', 7, 'Dongjin KIM', 'South Korea', '1992-12-28', 33, 'DF', 'Left-Back', 22, 177, 74, 'left', 250000, NULL, '2022-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20140135', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20130101, '20130101', 7, 'Youngchan KIM', 'South Korea', '1993-09-04', 32, 'DF', 'Centre-Back', 5, 189, 84, 'right', 200000, NULL, '2024-01-09', 'https://www.kleague.com/record/playerDetail.do?playerId=20130101', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20130102, '20130102', 7, 'Kyungwon KWON', 'South Korea', '1992-01-31', 34, 'DF', 'Centre-Back', 21, 188, 83, 'left', 400000, NULL, '2025-07-04', 'https://www.kleague.com/record/playerDetail.do?playerId=20130102', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20160073, '20160073', 7, 'Kim Jeonghyun', 'South Korea', '1993-06-01', 32, 'MF', 'Defensive Midfield', 8, 185, 74, 'right', 275000, '2026-12-31', '2023-01-04', 'https://www.kleague.com/record/playerDetail.do?playerId=20160073', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20240078, '20240078', 7, 'Matheus OLIVEIRA SANTOS', 'Brazil', '1997-09-28', 28, 'MF', 'Attacking Midfield', 7, 177, 70, 'left', 800000, NULL, '2024-01-10', 'https://www.kleague.com/record/playerDetail.do?playerId=20240078', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20240080, '20240080', 7, 'KA RAM HAN', 'South Korea', '1998-02-09', 28, 'MF', 'Defensive Midfield', 13, 177, 70, 'right', 150000, '2026-12-31', '2024-01-11', 'https://www.kleague.com/record/playerDetail.do?playerId=20240080', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20200170, '20200170', 7, 'GEONJU CHOI', 'South Korea', '1999-06-26', 26, 'FW', 'Left Winger', 27, 175, 64, 'right', 350000, NULL, '2026-01-22', 'https://www.kleague.com/record/playerDetail.do?playerId=20200170', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20260091, '20260091', 7, 'AIRTON MOISES SANTOS SOUSA', 'Brazil', '1999-02-02', 27, 'FW', 'Left Winger', 11, 179, 75, 'right', 300000, NULL, '2026-02-20', 'https://www.kleague.com/record/playerDetail.do?playerId=20260091', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20240084, '20240084', 7, 'Woon KIM', 'South Korea', '1994-11-15', 31, 'FW', 'Centre-Forward', 19, 181, 76, 'right', 150000, NULL, '2024-01-11', 'https://www.kleague.com/record/playerDetail.do?playerId=20240084', 'https://www.transfermarkt.com/fc-anyang/kader/verein/38898/saison_id/2025/plus/1'),
(20160156, '20160156', 8, 'Dongjun KIM', 'South Korea', '1994-12-19', 31, 'GK', 'Goalkeeper', 1, 189, 85, 'Unknown', 550000, NULL, '2022-01-11', 'https://www.kleague.com/record/playerDetail.do?playerId=20160156', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20210165, '20210165', 8, 'Ryunseong KIM', 'South Korea', '2002-06-04', 23, 'DF', 'Left-Back', 40, 179, 70, 'left', 325000, '2027-12-31', '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20210165', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20260221, '20260221', 8, 'SEUNGRO LEE', 'France', '1997-07-24', 28, 'DF', 'Centre-Back', 3, 192, 80, 'left', 300000, NULL, '2026-01-23', 'https://www.kleague.com/record/playerDetail.do?playerId=20260221', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20250093, '20250093', 8, 'MINGYU CHAN', 'South Korea', '1999-03-06', 27, 'DF', 'Centre-Back', 20, 186, 78, 'right', 500000, '2026-12-31', '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20250093', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20200103, '20200103', 8, 'Insoo YU', 'South Korea', '1994-12-28', 31, 'DF', 'Left-Back', 17, 178, 70, 'right', 325000, NULL, '2025-01-20', 'https://www.kleague.com/record/playerDetail.do?playerId=20200103', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20240323, '20240323', 8, 'taehee Nam', 'South Korea', '1991-07-03', 34, 'MF', 'Attacking Midfield', 10, 175, 73, 'right', 450000, NULL, '2024-07-25', 'https://www.kleague.com/record/playerDetail.do?playerId=20240323', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20210108, '20210108', 8, 'Jaehyeok OH', 'South Korea', '2002-06-21', 23, 'MF', 'Central Midfield', 14, 174, 69, 'Unknown', 275000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20210108', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20160047, '20160047', 8, 'Geonung KIM', 'South Korea', '1997-08-29', 28, 'MF', 'Central Midfield', 28, 185, 83, 'Unknown', 450000, NULL, '2023-07-18', 'https://www.kleague.com/record/playerDetail.do?playerId=20160047', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20250095, '20250095', 8, 'Junha KIM', 'South Korea', '2005-12-02', 20, 'MF', 'Right Winger', 27, 177, 66, 'right', 350000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20250095', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20260228, '20260228', 8, 'EMERSON RAMON BEZERRA OLIVEIRA', 'Brazil', '2000-11-24', 25, 'FW', 'Right Winger', 94, 173, 85, 'right', 1000000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20260228', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20130108, '20130108', 8, 'CHANGHOON KWON', 'South Korea', '1994-06-30', 31, 'MF', 'Right Winger', 22, 174, 69, 'left', 325000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20130108', 'https://www.transfermarkt.com/jeju-united/kader/verein/19684/saison_id/2025/plus/1'),
(20160010, '20160010', 9, 'Hyunggeun KIM', 'South Korea', '1994-01-06', 32, 'GK', 'Goalkeeper', 1, 188, 78, 'Unknown', 250000, NULL, '2024-01-08', 'https://www.kleague.com/record/playerDetail.do?playerId=20160010', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20160130, '20160130', 9, 'Taehyun AN', 'South Korea', '1993-03-01', 33, 'DF', 'Right-Back', 26, 174, 70, 'right', 225000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20160130', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20210174, '20210174', 9, 'Sungwook HONG', 'South Korea', '2002-09-17', 23, 'DF', 'Centre-Back', 20, 187, 77, 'right', 225000, NULL, '2023-01-11', 'https://www.kleague.com/record/playerDetail.do?playerId=20210174', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20190161, '20190161', 9, 'Jaewon SHIN', 'South Korea', '1998-09-16', 27, 'DF', 'Right-Back', 77, 183, 75, 'right', 275000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20190161', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20140203, '20140203', 9, 'Donggyu BAEK', 'South Korea', '1991-05-30', 34, 'DF', 'Centre-Back', 29, 184, 71, 'Unknown', 200000, NULL, '2025-06-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20140203', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20190194, '20190194', 9, 'Sangjun KIM', 'South Korea', '2001-10-01', 24, 'MF', 'Defensive Midfield', 16, 185, 75, 'right', 150000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20190194', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20230141, '20230141', 9, 'Kazuki TAKAHASHI', 'Japan', '1996-10-06', 29, 'MF', 'Central Midfield', 23, 178, 73, 'both', 350000, '2026-12-31', '2023-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20230141', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20100079, '20100079', 9, 'Bitgaram YOON', 'South Korea', '1990-05-07', 36, 'MF', 'Central Midfield', 8, 178, 75, 'right', 400000, '2027-12-31', '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20100079', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20220353, '20220353', 9, 'ISIDIO JEFFERSON FERNANDO', 'Brazil', '1997-04-04', 29, 'FW', 'Left Winger', 11, 177, 71, 'left', 325000, NULL, '2025-01-25', 'https://www.kleague.com/record/playerDetail.do?playerId=20220353', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20230333, '20230333', 9, 'VITOR GABRIEL CLAUDINO REGO FERREIRA', 'Brazil', '2000-01-20', 26, 'FW', 'Centre-Forward', 63, 187, 76, 'right', 500000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20230333', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20200048, '20200048', 9, 'Minjun KIM', 'South Korea', '2000-02-12', 26, 'FW', 'Right Winger', 13, 183, 74, 'Unknown', 300000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20200048', 'https://www.transfermarkt.com/bucheon-fc-1995/kader/verein/35759/saison_id/2025/plus/1'),
(20120148, '20120148', 10, 'changgeun LEE', 'South Korea', '1993-08-30', 32, 'GK', 'Goalkeeper', 1, 186, 75, 'Unknown', 600000, NULL, '2022-01-11', 'https://www.kleague.com/record/playerDetail.do?playerId=20120148', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20170122, '20170122', 10, 'Moonhwan KIM', 'South Korea', '1995-08-01', 30, 'DF', 'Right-Back', 33, 173, 64, 'right', 800000, '2027-12-31', '2024-06-20', 'https://www.kleague.com/record/playerDetail.do?playerId=20170122', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20160037, '20160037', 10, 'Yoonsung KANG', 'South Korea', '1997-07-01', 28, 'DF', 'Right-Back', 6, 172, 65, 'right', 400000, NULL, '2023-06-28', 'https://www.kleague.com/record/playerDetail.do?playerId=20160037', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20230239, '20230239', 10, 'Seonggwon CHO', 'South Korea', '2001-02-24', 25, 'DF', 'Centre-Back', 4, 182, 75, 'right', 300000, '2027-12-31', '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20230239', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20230048, '20230048', 10, 'Anton KRIVOTSYUK', 'Ukraine', '1998-08-20', 27, 'DF', 'Centre-Back', 98, 186, 76, 'left', 700000, '2027-12-31', '2023-02-21', 'https://www.kleague.com/record/playerDetail.do?playerId=20230048', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20210176, '20210176', 10, 'Bongsoo KIM', 'South Korea', '1999-12-26', 26, 'MF', 'Central Midfield', 30, 181, 74, 'right', 1000000, NULL, '2025-06-11', 'https://www.kleague.com/record/playerDetail.do?playerId=20210176', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20230326, '20230326', 10, 'BOBSIN PEREIRA VICTOR', 'Brazil', '2000-01-12', 26, 'MF', 'Defensive Midfield', 8, 183, 78, 'left', 600000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20230326', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20180110, '20180110', 10, 'Hyunsik LEE', 'South Korea', '1996-03-21', 30, 'MF', 'Central Midfield', 20, 175, 64, 'right', 450000, NULL, '2021-01-12', 'https://www.kleague.com/record/playerDetail.do?playerId=20180110', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20230105, '20230105', 10, 'Gustav Erik LUDWIGSON', 'Sweden', '1993-10-20', 32, 'MF', 'Left Winger', 17, 182, 75, 'Unknown', 850000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20230105', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20130248, '20130248', 10, 'Minkyu JOO', 'South Korea', '1990-04-13', 36, 'FW', 'Centre-Forward', 10, 183, 79, 'right', 700000, '2026-12-31', '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20130248', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20250360, '20250360', 10, 'Joao Victor LIMA FERREIRA', 'Brazil', '1999-02-25', 27, 'FW', 'Right Winger', 77, 176, 75, 'right', 350000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20250360', 'https://www.transfermarkt.com/daejeon-hana-citizen/kader/verein/6499/saison_id/2025/plus/1'),
(20190154, '20190154', 11, 'Jongbum BAEK', 'South Korea', '2001-01-21', 25, 'GK', 'Goalkeeper', 1, 190, 82, 'right', 350000, '2026-10-06', '2025-04-07', 'https://www.kleague.com/record/playerDetail.do?playerId=20190154', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20220139, '20220139', 11, 'Cheolwoo PARK', 'South Korea', '1997-10-21', 28, 'DF', 'Left-Back', 3, 176, 68, 'left', 325000, '2026-10-06', '2025-04-07', 'https://www.kleague.com/record/playerDetail.do?playerId=20220139', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20180324, '20180324', 11, 'Taehwan KIM', 'South Korea', '2000-03-25', 26, 'DF', 'Right-Back', 11, 179, 73, 'right', 350000, '2026-10-06', '2025-04-07', 'https://www.kleague.com/record/playerDetail.do?playerId=20180324', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20230198, '20230198', 11, 'Jungtaek LEE', 'South Korea', '1998-05-23', 27, 'DF', 'Centre-Back', 26, 183, 75, 'right', 350000, '2026-10-06', '2025-04-07', 'https://www.kleague.com/record/playerDetail.do?playerId=20230198', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20200317, '20200317', 11, 'Junsoo BYEON', 'South Korea', '2001-11-30', 24, 'DF', 'Centre-Back', 45, 190, 88, 'right', 500000, '2027-07-18', '2026-01-19', 'https://www.kleague.com/record/playerDetail.do?playerId=20200317', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20180096, '20180096', 11, 'Taejun PARK', 'South Korea', '1999-01-19', 27, 'MF', 'Central Midfield', 55, 175, 74, 'right', 375000, '2026-12-01', '2025-06-02', 'https://www.kleague.com/record/playerDetail.do?playerId=20180096', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20170022, '20170022', 11, 'Sangheon LEE', 'South Korea', '1998-02-26', 28, 'FW', 'Attacking Midfield', 47, 178, 67, 'right', 700000, '2027-05-16', '2025-11-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20170022', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20190124, '20190124', 11, 'Soobin LEE', 'South Korea', '2000-05-07', 26, 'MF', 'Defensive Midfield', 6, 180, 70, 'right', 300000, '2026-10-06', '2025-04-07', 'https://www.kleague.com/record/playerDetail.do?playerId=20190124', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20200164, '20200164', 11, 'Kunhee LEE', 'South Korea', '1998-02-17', 28, 'FW', 'Centre-Forward', 9, 186, 78, 'Unknown', 175000, '2026-10-06', '2025-04-07', 'https://www.kleague.com/record/playerDetail.do?playerId=20200164', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20180123, '20180123', 11, 'Jaehyeon GO', 'South Korea', '1999-03-05', 27, 'FW', 'Right Winger', 7, 180, 67, 'right', 600000, '2026-10-06', '2025-04-07', 'https://www.kleague.com/record/playerDetail.do?playerId=20180123', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20200174, '20200174', 11, 'Ingyun KIM', 'South Korea', '1998-07-23', 27, 'FW', 'Left Winger', 21, 175, 67, 'left', 375000, '2026-12-01', '2025-06-02', 'https://www.kleague.com/record/playerDetail.do?playerId=20200174', 'https://www.transfermarkt.com/gimcheon-sangmu/kader/verein/6505/saison_id/2025/plus/1'),
(20140102, '20140102', 12, 'Kyeongmin KIM', 'South Korea', '1991-11-01', 34, 'GK', 'Goalkeeper', 1, 190, 78, 'Unknown', 375000, NULL, '2022-01-09', 'https://www.kleague.com/record/playerDetail.do?playerId=20140102', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20190114, '20190114', 12, 'Seungun HA', 'South Korea', '1998-05-04', 28, 'FW', 'Right-Back', 9, 177, 74, 'Unknown', 125000, NULL, '2022-01-10', 'https://www.kleague.com/record/playerDetail.do?playerId=20190114', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20260209, '20260209', 12, 'Yonghyuk KIM', 'South Korea', '2007-01-11', 19, 'DF', 'Centre-Back', 24, 187, 76, 'Unknown', 150000, NULL, '2026-01-16', 'https://www.kleague.com/record/playerDetail.do?playerId=20260209', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20220053, '20220053', 12, 'Jinho KIM', 'South Korea', '2000-01-21', 26, 'DF', 'Right-Back', 27, 178, 74, 'right', 400000, '2026-12-31', '2024-01-23', 'https://www.kleague.com/record/playerDetail.do?playerId=20220053', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20120116, '20120116', 12, 'Youngkyu AHN', 'South Korea', '1989-12-04', 36, 'DF', 'Centre-Back', 6, 185, 79, 'right', 200000, NULL, '2022-01-06', 'https://www.kleague.com/record/playerDetail.do?playerId=20120116', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20240210, '20240210', 12, 'Minseo MOON', 'South Korea', '2004-02-18', 22, 'MF', 'Central Midfield', 88, 182, 74, 'right', 225000, '2026-12-31', '2024-01-08', 'https://www.kleague.com/record/playerDetail.do?playerId=20240210', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20230080, '20230080', 12, 'Jihun JUNG', 'South Korea', '2004-04-09', 22, 'FW', 'Attacking Midfield', 16, 175, 60, 'right', 225000, '2027-12-31', '2023-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20230080', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20120151, '20120151', 12, 'Sejong JU', 'South Korea', '1990-10-30', 35, 'MF', 'Central Midfield', 8, 176, 72, 'right', 225000, NULL, '2025-02-28', 'https://www.kleague.com/record/playerDetail.do?playerId=20120151', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20200029, '20200029', 12, 'Seongyun GWON', 'South Korea', '2001-03-30', 25, 'FW', 'Left Winger', 22, 174, 65, 'Unknown', 125000, NULL, '2025-01-17', 'https://www.kleague.com/record/playerDetail.do?playerId=20200029', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20240209, '20240209', 12, 'Hyeokjoo AN', 'South Korea', '2004-09-03', 21, 'FW', 'Left Winger', 19, 176, 70, 'Unknown', 100000, NULL, '2024-01-01', 'https://www.kleague.com/record/playerDetail.do?playerId=20240209', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1'),
(20250366, '20250366', 12, 'Holmbert Aron Briem FRIDJONSSON', 'Iceland', '1993-04-19', 33, 'FW', 'Centre-Forward', 11, 196, 86, 'left', 250000, NULL, '2025-08-06', 'https://www.kleague.com/record/playerDetail.do?playerId=20250366', 'https://www.transfermarkt.com/gwangju-fc/kader/verein/30925/saison_id/2025/plus/1');

INSERT INTO player_stats (player_id, appearances, starts_estimated, goals, assists, shots, yellow_cards, red_cards, pace, shooting, passing, defending, physical, rating_source) VALUES
(20200301, 15, 15, 0, 0, 0, 1, 0, 60, 25, 65, 78, 76, 'DERIVED_PUBLIC_DATA'),
(20260048, 15, 15, 2, 0, 5, 3, 0, 78, 48, 76, 86, 83, 'DERIVED_PUBLIC_DATA'),
(20200041, 15, 15, 0, 0, 5, 4, 0, 72, 42, 71, 81, 78, 'DERIVED_PUBLIC_DATA'),
(20170185, 14, 12, 0, 2, 5, 1, 0, 72, 42, 74, 80, 77, 'DERIVED_PUBLIC_DATA'),
(20240324, 12, 10, 1, 1, 8, 2, 1, 74, 45, 74, 82, 79, 'DERIVED_PUBLIC_DATA'),
(20170052, 15, 7, 4, 1, 17, 0, 0, 77, 85, 86, 77, 78, 'DERIVED_PUBLIC_DATA'),
(20260045, 14, 13, 2, 2, 11, 3, 0, 79, 81, 90, 79, 80, 'DERIVED_PUBLIC_DATA'),
(20260049, 12, 8, 1, 1, 9, 0, 1, 65, 64, 74, 65, 66, 'DERIVED_PUBLIC_DATA'),
(20180034, 15, 12, 3, 3, 17, 0, 0, 90, 94, 89, 70, 86, 'DERIVED_PUBLIC_DATA'),
(20160099, 15, 11, 0, 2, 9, 0, 0, 75, 71, 86, 75, 76, 'DERIVED_PUBLIC_DATA'),
(20250331, 13, 10, 5, 0, 27, 5, 0, 82, 91, 75, 62, 78, 'DERIVED_PUBLIC_DATA'),
(20130156, 15, 15, 0, 0, 0, 0, 0, 60, 25, 67, 80, 78, 'DERIVED_PUBLIC_DATA'),
(20200055, 15, 14, 0, 0, 10, 2, 0, 72, 42, 70, 80, 77, 'DERIVED_PUBLIC_DATA'),
(20180105, 14, 13, 0, 0, 4, 1, 0, 67, 42, 66, 76, 73, 'DERIVED_PUBLIC_DATA'),
(20150109, 12, 10, 2, 0, 8, 1, 0, 80, 48, 78, 88, 85, 'DERIVED_PUBLIC_DATA'),
(20240107, 12, 9, 0, 1, 6, 2, 0, 68, 42, 68, 76, 73, 'DERIVED_PUBLIC_DATA'),
(20150050, 15, 13, 0, 3, 4, 3, 0, 75, 71, 88, 75, 76, 'DERIVED_PUBLIC_DATA'),
(20230108, 14, 12, 0, 1, 10, 0, 0, 75, 71, 84, 75, 76, 'DERIVED_PUBLIC_DATA'),
(20180088, 14, 11, 5, 3, 37, 3, 0, 87, 88, 94, 87, 88, 'DERIVED_PUBLIC_DATA'),
(20190171, 14, 11, 1, 0, 12, 1, 0, 70, 69, 77, 70, 71, 'DERIVED_PUBLIC_DATA'),
(20230315, 12, 8, 6, 0, 32, 1, 0, 88, 94, 81, 68, 84, 'DERIVED_PUBLIC_DATA'),
(20260244, 10, 1, 0, 0, 4, 1, 0, 73, 72, 66, 53, 69, 'DERIVED_PUBLIC_DATA'),
(20180025, 15, 15, 0, 0, 0, 0, 0, 60, 25, 70, 83, 81, 'DERIVED_PUBLIC_DATA'),
(20140143, 14, 14, 1, 1, 6, 3, 0, 72, 45, 72, 80, 77, 'DERIVED_PUBLIC_DATA'),
(20220174, 12, 12, 2, 0, 6, 5, 0, 71, 48, 69, 79, 76, 'DERIVED_PUBLIC_DATA'),
(20230029, 12, 8, 0, 0, 2, 0, 0, 66, 42, 65, 75, 72, 'DERIVED_PUBLIC_DATA'),
(20100052, 10, 10, 0, 0, 0, 3, 0, 66, 42, 65, 75, 72, 'DERIVED_PUBLIC_DATA'),
(20150052, 15, 14, 1, 1, 7, 2, 0, 82, 81, 91, 82, 83, 'DERIVED_PUBLIC_DATA'),
(20230043, 15, 15, 1, 1, 11, 1, 0, 82, 81, 91, 82, 83, 'DERIVED_PUBLIC_DATA'),
(20220276, 13, 12, 1, 2, 10, 2, 0, 74, 73, 85, 74, 75, 'DERIVED_PUBLIC_DATA'),
(20180212, 15, 11, 1, 0, 20, 0, 0, 79, 80, 72, 59, 75, 'DERIVED_PUBLIC_DATA'),
(20230224, 15, 10, 2, 1, 27, 1, 0, 83, 86, 78, 63, 79, 'DERIVED_PUBLIC_DATA'),
(20170121, 15, 15, 3, 1, 21, 1, 0, 83, 88, 78, 63, 79, 'DERIVED_PUBLIC_DATA'),
(20130134, 15, 15, 0, 0, 0, 0, 0, 60, 25, 61, 74, 72, 'DERIVED_PUBLIC_DATA'),
(20230270, 15, 14, 0, 2, 7, 4, 0, 72, 42, 74, 80, 77, 'DERIVED_PUBLIC_DATA'),
(20210104, 14, 14, 0, 0, 7, 3, 0, 72, 42, 70, 80, 77, 'DERIVED_PUBLIC_DATA'),
(20240097, 13, 7, 0, 0, 2, 2, 0, 70, 42, 69, 79, 76, 'DERIVED_PUBLIC_DATA'),
(20170182, 13, 12, 1, 0, 19, 5, 0, 70, 69, 77, 70, 71, 'DERIVED_PUBLIC_DATA'),
(20200077, 15, 12, 0, 1, 5, 2, 0, 75, 71, 84, 75, 76, 'DERIVED_PUBLIC_DATA'),
(20200066, 14, 13, 0, 1, 9, 2, 0, 72, 68, 81, 72, 73, 'DERIVED_PUBLIC_DATA'),
(20230067, 8, 2, 0, 0, 1, 0, 0, 65, 61, 72, 65, 66, 'DERIVED_PUBLIC_DATA'),
(20160098, 15, 15, 5, 3, 31, 3, 0, 90, 94, 89, 70, 86, 'DERIVED_PUBLIC_DATA'),
(20170164, 15, 15, 2, 3, 28, 3, 0, 87, 90, 86, 67, 83, 'DERIVED_PUBLIC_DATA'),
(20260043, 15, 1, 6, 0, 19, 2, 0, 81, 92, 74, 61, 77, 'DERIVED_PUBLIC_DATA'),
(20160079, 15, 15, 0, 0, 0, 1, 0, 60, 25, 65, 78, 76, 'DERIVED_PUBLIC_DATA'),
(20210182, 14, 14, 0, 1, 7, 3, 0, 71, 42, 71, 79, 76, 'DERIVED_PUBLIC_DATA'),
(20200146, 12, 11, 0, 0, 12, 2, 1, 70, 42, 68, 78, 75, 'DERIVED_PUBLIC_DATA'),
(20150067, 11, 10, 0, 0, 1, 2, 1, 64, 42, 63, 73, 70, 'DERIVED_PUBLIC_DATA'),
(20060066, 9, 7, 0, 0, 1, 1, 0, 61, 42, 60, 70, 67, 'DERIVED_PUBLIC_DATA'),
(20240062, 15, 12, 0, 0, 6, 0, 0, 67, 63, 74, 67, 68, 'DERIVED_PUBLIC_DATA'),
(20240063, 14, 8, 0, 0, 7, 1, 0, 69, 65, 76, 69, 70, 'DERIVED_PUBLIC_DATA'),
(20260024, 12, 9, 0, 0, 5, 1, 0, 70, 66, 77, 70, 71, 'DERIVED_PUBLIC_DATA'),
(20210161, 15, 14, 7, 0, 23, 3, 0, 90, 94, 83, 70, 86, 'DERIVED_PUBLIC_DATA'),
(20230148, 13, 6, 2, 1, 12, 3, 0, 78, 81, 73, 58, 74, 'DERIVED_PUBLIC_DATA'),
(20260021, 11, 4, 1, 1, 6, 2, 0, 73, 74, 68, 53, 69, 'DERIVED_PUBLIC_DATA'),
(20190064, 11, 10, 0, 0, 0, 1, 0, 55, 25, 62, 75, 73, 'DERIVED_PUBLIC_DATA'),
(20140059, 14, 11, 0, 2, 2, 1, 0, 69, 42, 72, 78, 75, 'DERIVED_PUBLIC_DATA'),
(20260160, 14, 14, 2, 0, 8, 5, 0, 72, 48, 70, 80, 77, 'DERIVED_PUBLIC_DATA'),
(20210305, 13, 13, 0, 2, 4, 2, 0, 70, 42, 73, 79, 76, 'DERIVED_PUBLIC_DATA'),
(20250189, 11, 9, 0, 0, 0, 1, 0, 65, 42, 64, 74, 71, 'DERIVED_PUBLIC_DATA'),
(20220279, 15, 15, 1, 1, 7, 0, 0, 72, 71, 81, 72, 73, 'DERIVED_PUBLIC_DATA'),
(20120127, 15, 12, 1, 2, 6, 2, 0, 73, 72, 84, 73, 74, 'DERIVED_PUBLIC_DATA'),
(20180127, 8, 7, 1, 0, 6, 0, 0, 64, 45, 62, 72, 69, 'DERIVED_PUBLIC_DATA'),
(20040081, 15, 6, 1, 1, 8, 2, 0, 71, 70, 80, 71, 72, 'DERIVED_PUBLIC_DATA'),
(20210223, 15, 9, 2, 0, 14, 1, 0, 75, 77, 82, 75, 76, 'DERIVED_PUBLIC_DATA'),
(20190131, 14, 8, 2, 2, 13, 1, 0, 79, 82, 76, 59, 75, 'DERIVED_PUBLIC_DATA'),
(20190375, 13, 13, 0, 0, 0, 2, 0, 58, 25, 62, 75, 73, 'DERIVED_PUBLIC_DATA'),
(20150080, 14, 12, 0, 0, 5, 3, 0, 66, 42, 65, 75, 72, 'DERIVED_PUBLIC_DATA'),
(20140135, 13, 13, 1, 0, 4, 3, 0, 67, 45, 66, 76, 73, 'DERIVED_PUBLIC_DATA'),
(20130101, 13, 7, 1, 0, 4, 1, 0, 67, 45, 66, 76, 73, 'DERIVED_PUBLIC_DATA'),
(20130102, 11, 11, 0, 0, 2, 5, 0, 66, 42, 65, 75, 72, 'DERIVED_PUBLIC_DATA'),
(20160073, 13, 12, 1, 0, 5, 3, 1, 67, 66, 74, 67, 68, 'DERIVED_PUBLIC_DATA'),
(20240078, 13, 12, 4, 3, 25, 0, 1, 80, 88, 93, 80, 81, 'DERIVED_PUBLIC_DATA'),
(20240080, 8, 6, 0, 0, 3, 1, 0, 62, 58, 69, 62, 63, 'DERIVED_PUBLIC_DATA'),
(20200170, 14, 11, 3, 0, 14, 2, 0, 79, 84, 72, 59, 75, 'DERIVED_PUBLIC_DATA'),
(20260091, 13, 7, 5, 0, 22, 1, 0, 80, 89, 73, 60, 76, 'DERIVED_PUBLIC_DATA'),
(20240084, 12, 8, 2, 2, 7, 1, 0, 76, 79, 73, 56, 72, 'DERIVED_PUBLIC_DATA'),
(20160156, 15, 15, 0, 0, 0, 1, 0, 60, 25, 65, 78, 76, 'DERIVED_PUBLIC_DATA'),
(20210165, 14, 14, 1, 1, 4, 1, 0, 70, 45, 71, 79, 76, 'DERIVED_PUBLIC_DATA'),
(20260221, 14, 13, 1, 1, 6, 4, 0, 71, 45, 71, 79, 76, 'DERIVED_PUBLIC_DATA'),
(20250093, 14, 13, 1, 0, 8, 2, 0, 72, 45, 70, 80, 77, 'DERIVED_PUBLIC_DATA'),
(20200103, 13, 12, 0, 0, 3, 3, 0, 67, 42, 66, 76, 73, 'DERIVED_PUBLIC_DATA'),
(20240323, 13, 10, 1, 0, 11, 1, 0, 71, 70, 78, 71, 72, 'DERIVED_PUBLIC_DATA'),
(20210108, 10, 9, 1, 0, 11, 1, 0, 66, 65, 73, 66, 67, 'DERIVED_PUBLIC_DATA'),
(20160047, 8, 5, 0, 0, 4, 1, 0, 65, 61, 72, 65, 66, 'DERIVED_PUBLIC_DATA'),
(20250095, 15, 6, 1, 1, 7, 0, 0, 72, 71, 81, 72, 73, 'DERIVED_PUBLIC_DATA'),
(20260228, 15, 15, 2, 2, 44, 1, 0, 88, 91, 85, 68, 84, 'DERIVED_PUBLIC_DATA'),
(20130108, 13, 10, 0, 0, 17, 1, 0, 68, 64, 75, 68, 69, 'DERIVED_PUBLIC_DATA'),
(20160010, 13, 13, 0, 0, 0, 1, 0, 58, 25, 60, 73, 71, 'DERIVED_PUBLIC_DATA'),
(20160130, 14, 11, 0, 0, 4, 2, 0, 67, 42, 66, 76, 73, 'DERIVED_PUBLIC_DATA'),
(20210174, 14, 14, 0, 1, 5, 0, 0, 68, 42, 69, 77, 74, 'DERIVED_PUBLIC_DATA'),
(20190161, 13, 8, 1, 0, 2, 2, 0, 68, 45, 67, 77, 74, 'DERIVED_PUBLIC_DATA'),
(20140203, 11, 10, 0, 0, 5, 1, 0, 64, 42, 63, 73, 70, 'DERIVED_PUBLIC_DATA'),
(20190194, 14, 8, 0, 0, 9, 0, 0, 67, 63, 74, 67, 68, 'DERIVED_PUBLIC_DATA'),
(20230141, 14, 10, 0, 0, 0, 0, 0, 69, 65, 76, 69, 70, 'DERIVED_PUBLIC_DATA'),
(20100079, 12, 9, 0, 0, 5, 0, 0, 68, 64, 75, 68, 69, 'DERIVED_PUBLIC_DATA'),
(20220353, 14, 11, 4, 2, 31, 3, 0, 82, 89, 79, 62, 78, 'DERIVED_PUBLIC_DATA'),
(20230333, 11, 4, 2, 0, 7, 3, 0, 77, 80, 70, 57, 73, 'DERIVED_PUBLIC_DATA'),
(20200048, 10, 6, 1, 0, 4, 0, 0, 73, 74, 66, 53, 69, 'DERIVED_PUBLIC_DATA'),
(20120148, 15, 15, 0, 0, 0, 0, 0, 60, 25, 66, 79, 77, 'DERIVED_PUBLIC_DATA'),
(20170122, 15, 12, 0, 1, 2, 2, 0, 75, 42, 76, 84, 81, 'DERIVED_PUBLIC_DATA'),
(20160037, 11, 4, 0, 0, 4, 0, 0, 66, 42, 65, 75, 72, 'DERIVED_PUBLIC_DATA'),
(20230239, 10, 10, 0, 0, 2, 5, 0, 64, 42, 63, 73, 70, 'DERIVED_PUBLIC_DATA'),
(20230048, 9, 8, 0, 0, 2, 2, 0, 68, 42, 67, 77, 74, 'DERIVED_PUBLIC_DATA'),
(20210176, 14, 13, 0, 1, 6, 2, 0, 78, 74, 87, 78, 79, 'DERIVED_PUBLIC_DATA'),
(20230326, 11, 5, 0, 0, 3, 2, 0, 70, 66, 77, 70, 71, 'DERIVED_PUBLIC_DATA'),
(20180110, 10, 6, 0, 1, 1, 1, 0, 68, 64, 77, 68, 69, 'DERIVED_PUBLIC_DATA'),
(20230105, 15, 11, 1, 1, 12, 1, 0, 78, 77, 87, 78, 79, 'DERIVED_PUBLIC_DATA'),
(20130248, 14, 6, 1, 1, 16, 0, 0, 82, 83, 77, 62, 78, 'DERIVED_PUBLIC_DATA'),
(20250360, 12, 10, 0, 0, 13, 1, 0, 74, 73, 67, 54, 70, 'DERIVED_PUBLIC_DATA'),
(20190154, 14, 14, 0, 0, 0, 2, 0, 59, 25, 62, 75, 73, 'DERIVED_PUBLIC_DATA'),
(20220139, 15, 14, 1, 2, 14, 3, 0, 73, 45, 75, 81, 78, 'DERIVED_PUBLIC_DATA'),
(20180324, 14, 13, 0, 0, 6, 2, 0, 69, 42, 67, 77, 74, 'DERIVED_PUBLIC_DATA'),
(20230198, 14, 14, 0, 3, 0, 4, 0, 72, 42, 77, 81, 78, 'DERIVED_PUBLIC_DATA'),
(20200317, 8, 6, 1, 0, 3, 3, 0, 66, 45, 65, 75, 72, 'DERIVED_PUBLIC_DATA'),
(20180096, 14, 13, 2, 0, 7, 2, 0, 72, 74, 79, 72, 73, 'DERIVED_PUBLIC_DATA'),
(20170022, 11, 6, 0, 1, 6, 2, 1, 76, 75, 71, 56, 72, 'DERIVED_PUBLIC_DATA'),
(20190124, 11, 9, 0, 0, 7, 0, 0, 66, 62, 73, 66, 67, 'DERIVED_PUBLIC_DATA'),
(20200164, 15, 13, 3, 2, 22, 4, 0, 80, 85, 77, 60, 76, 'DERIVED_PUBLIC_DATA'),
(20180123, 14, 12, 4, 1, 21, 1, 0, 84, 91, 79, 64, 80, 'DERIVED_PUBLIC_DATA'),
(20200174, 10, 1, 1, 0, 13, 2, 0, 73, 74, 66, 53, 69, 'DERIVED_PUBLIC_DATA'),
(20140102, 8, 8, 0, 0, 0, 0, 0, 52, 25, 58, 71, 69, 'DERIVED_PUBLIC_DATA'),
(20190114, 15, 14, 0, 1, 5, 2, 0, 75, 74, 70, 55, 71, 'DERIVED_PUBLIC_DATA'),
(20260209, 12, 11, 0, 0, 0, 1, 0, 64, 42, 63, 73, 70, 'DERIVED_PUBLIC_DATA'),
(20220053, 12, 8, 0, 0, 3, 5, 0, 67, 42, 66, 76, 73, 'DERIVED_PUBLIC_DATA'),
(20120116, 12, 9, 0, 0, 1, 2, 0, 65, 42, 64, 74, 71, 'DERIVED_PUBLIC_DATA'),
(20240210, 15, 14, 2, 0, 11, 4, 0, 71, 73, 78, 71, 72, 'DERIVED_PUBLIC_DATA'),
(20230080, 13, 11, 0, 0, 7, 1, 0, 73, 72, 66, 53, 69, 'DERIVED_PUBLIC_DATA'),
(20120151, 13, 8, 0, 1, 3, 4, 0, 68, 64, 77, 68, 69, 'DERIVED_PUBLIC_DATA'),
(20200029, 14, 7, 0, 0, 5, 4, 0, 73, 72, 66, 53, 69, 'DERIVED_PUBLIC_DATA'),
(20240209, 14, 11, 0, 1, 12, 2, 0, 74, 73, 69, 54, 70, 'DERIVED_PUBLIC_DATA'),
(20250366, 13, 4, 1, 2, 13, 4, 0, 77, 78, 74, 57, 73, 'DERIVED_PUBLIC_DATA');

INSERT INTO contracts (player_id, club_id, start_date, end_date, salary_eur, status) VALUES
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
(20250366, 12, '2025-08-06', NULL, 30000, 'active');

CREATE TEMPORARY TABLE tmp_generated_subs AS
SELECT
    base.club_id,
    base.player_name,
    base.nationality,
    base.birth_date,
    base.age,
    base.position_group,
    base.primary_position,
    base.height_cm,
    base.weight_kg,
    base.preferred_foot,
    base.market_value_eur,
    base.contract_until,
    base.joined_date,
    base.profile_source_url,
    base.value_source_url,
    base.appearances,
    base.starts_estimated,
    base.goals,
    base.assists,
    base.shots,
    base.yellow_cards,
    base.red_cards,
    base.pace,
    base.shooting,
    base.passing,
    base.defending,
    base.physical,
    base.rating_source,
    CASE
        WHEN base.position_group = 'GK' AND base.pos_rank = 1 THEN 1
        WHEN base.position_group = 'DF' AND base.pos_rank = 1 THEN 2
        WHEN base.position_group = 'DF' AND base.pos_rank = 2 THEN 3
        WHEN base.position_group = 'MF' AND base.pos_rank = 1 THEN 4
        WHEN base.position_group = 'FW' AND base.pos_rank = 1 THEN 5
        ELSE NULL
    END AS slot_no
FROM (
    SELECT
        p.player_id,
        p.club_id,
        p.player_name,
        p.nationality,
        p.birth_date,
        p.age,
        p.position_group,
        p.primary_position,
        p.height_cm,
        p.weight_kg,
        p.preferred_foot,
        p.market_value_eur,
        p.contract_until,
        p.joined_date,
        p.profile_source_url,
        p.value_source_url,
        ps.appearances,
        ps.starts_estimated,
        ps.goals,
        ps.assists,
        ps.shots,
        ps.yellow_cards,
        ps.red_cards,
        ps.pace,
        ps.shooting,
        ps.passing,
        ps.defending,
        ps.physical,
        ps.rating_source,
        ROW_NUMBER() OVER (
            PARTITION BY p.club_id, p.position_group
            ORDER BY ps.overall DESC, p.player_id
        ) AS pos_rank
    FROM players p
    JOIN player_stats ps
      ON ps.player_id = p.player_id
    WHERE p.club_id IS NOT NULL
      AND p.squad_role = 'starter'
) base
WHERE
    (base.position_group = 'GK' AND base.pos_rank = 1)
    OR (base.position_group = 'DF' AND base.pos_rank IN (1, 2))
    OR (base.position_group = 'MF' AND base.pos_rank = 1)
    OR (base.position_group = 'FW' AND base.pos_rank = 1);

INSERT INTO players (
    player_id, source_player_id, club_id, player_name, nationality,
    birth_date, age, position_group, primary_position, squad_number, squad_role,
    height_cm, weight_kg, preferred_foot, market_value_eur, contract_until, joined_date,
    profile_source_url, value_source_url
)
SELECT
    90000000 + (club_id * 100) + slot_no AS player_id,
    CONCAT('SUB_', club_id, '_', LPAD(slot_no, 2, '0')) AS source_player_id,
    club_id,
    CONCAT(player_name, ' Reserve ', slot_no) AS player_name,
    nationality,
    birth_date,
    age,
    position_group,
    primary_position,
    NULL AS squad_number,
    'sub' AS squad_role,
    height_cm,
    weight_kg,
    preferred_foot,
    ROUND(market_value_eur * 0.55, 2) AS market_value_eur,
    contract_until,
    joined_date,
    profile_source_url,
    value_source_url
FROM tmp_generated_subs;

INSERT INTO player_stats (
    player_id, appearances, starts_estimated, goals, assists, shots, yellow_cards, red_cards,
    pace, shooting, passing, defending, physical, rating_source
)
SELECT
    90000000 + (club_id * 100) + slot_no AS player_id,
    GREATEST(0, FLOOR(appearances * 0.40)) AS appearances,
    GREATEST(0, FLOOR(starts_estimated * 0.20)) AS starts_estimated,
    GREATEST(0, FLOOR(goals * 0.40)) AS goals,
    GREATEST(0, FLOOR(assists * 0.40)) AS assists,
    GREATEST(0, FLOOR(shots * 0.45)) AS shots,
    GREATEST(0, FLOOR(yellow_cards * 0.50)) AS yellow_cards,
    GREATEST(0, FLOOR(red_cards * 0.50)) AS red_cards,
    GREATEST(1, LEAST(99, pace - 3)) AS pace,
    GREATEST(1, LEAST(99, shooting - 3)) AS shooting,
    GREATEST(1, LEAST(99, passing - 3)) AS passing,
    GREATEST(1, LEAST(99, defending - 3)) AS defending,
    GREATEST(1, LEAST(99, physical - 3)) AS physical,
    rating_source
FROM tmp_generated_subs;

INSERT INTO contracts (player_id, club_id, start_date, end_date, salary_eur, status)
SELECT
    90000000 + (club_id * 100) + slot_no AS player_id,
    club_id,
    COALESCE(joined_date, CURDATE()) AS start_date,
    contract_until AS end_date,
    30000 AS salary_eur,
    'active' AS status
FROM tmp_generated_subs;

DROP TEMPORARY TABLE tmp_generated_subs;

INSERT INTO transfer_market (listing_id, player_id, seller_club_id, asking_fee_eur, listed_date, status) VALUES
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
(132, 20250366, 12, 250000, '2026-06-01', 'available');

USE kleague_db;

DROP PROCEDURE IF EXISTS sp_buy_player;
DROP PROCEDURE IF EXISTS sp_release_player;
DROP PROCEDURE IF EXISTS sp_create_squad_battle;
DROP PROCEDURE IF EXISTS sp_list_player_for_transfer;
DROP FUNCTION IF EXISTS fn_squad_score;

DELIMITER $$

CREATE FUNCTION fn_squad_score(p_club_id INT)
RETURNS DECIMAL(6,2)
READS SQL DATA
BEGIN
    DECLARE v_avg_overall DECIMAL(6,2);
    DECLARE v_manager_rating TINYINT;
    DECLARE v_score DECIMAL(6,2);

    SELECT ROUND(AVG(ps.overall), 2)
      INTO v_avg_overall
    FROM players p
    JOIN player_stats ps
      ON ps.player_id = p.player_id
    WHERE p.club_id = p_club_id
      AND p.squad_role = 'starter';

    SELECT rating
      INTO v_manager_rating
    FROM managers
    WHERE club_id = p_club_id;

    IF v_avg_overall IS NULL OR v_manager_rating IS NULL THEN
        RETURN NULL;
    END IF;

    SET v_score = ROUND(v_avg_overall * 0.8 + v_manager_rating * 0.2, 2);

    RETURN v_score;
END$$

CREATE PROCEDURE sp_buy_player(IN p_user_id INT, IN p_listing_id INT)
BEGIN
    DECLARE v_buyer_club_id INT;
    DECLARE v_seller_club_id INT;
    DECLARE v_player_id INT;
    DECLARE v_fee DECIMAL(15,2);
    DECLARE v_status VARCHAR(20);
    DECLARE v_buyer_budget DECIMAL(15,2);
    DECLARE v_player_name VARCHAR(120);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT club_id INTO v_buyer_club_id
    FROM app_users
    WHERE user_id = p_user_id;

    IF v_buyer_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User does not exist';
    END IF;

    SELECT tm.player_id, tm.seller_club_id, tm.asking_fee_eur, tm.status, p.player_name
      INTO v_player_id, v_seller_club_id, v_fee, v_status, v_player_name
    FROM transfer_market tm
    JOIN players p ON tm.player_id = p.player_id
    WHERE tm.listing_id = p_listing_id
    FOR UPDATE;

    IF v_status <> 'available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listing is not available';
    END IF;

    IF v_buyer_club_id = v_seller_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot buy a player from your own club';
    END IF;

    SELECT current_budget_eur INTO v_buyer_budget
    FROM clubs
    WHERE club_id = v_buyer_club_id
    FOR UPDATE;

    IF v_buyer_budget < v_fee THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough budget';
    END IF;

    UPDATE contracts
    SET status = 'expired'
    WHERE player_id = v_player_id AND status = 'active';

    INSERT INTO contracts (player_id, club_id, start_date, end_date, salary_eur, status)
    VALUES (v_player_id, v_buyer_club_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 2 YEAR), GREATEST(v_fee * 0.08, 30000), 'active');

    UPDATE players
    SET club_id = v_buyer_club_id,
        joined_date = CURDATE(),
        contract_until = DATE_ADD(CURDATE(), INTERVAL 2 YEAR),
        squad_role = 'sub'
    WHERE player_id = v_player_id;

    UPDATE clubs
    SET current_budget_eur = current_budget_eur - v_fee
    WHERE club_id = v_buyer_club_id;

    UPDATE clubs
    SET current_budget_eur = current_budget_eur + v_fee
    WHERE club_id = v_seller_club_id;

    UPDATE transfer_market
    SET status = 'sold'
    WHERE listing_id = p_listing_id;

    INSERT INTO transfer_history
        (player_id, from_club_id, to_club_id, transfer_type, fee_eur, transfer_date, created_by_user_id, memo)
    VALUES
        (v_player_id, v_seller_club_id, v_buyer_club_id, 'buy', v_fee, CURDATE(), p_user_id, 'Completed through sp_buy_player');

    COMMIT;

    SELECT
        'BUY_COMPLETED' AS result_code,
        v_player_name AS player_name,
        v_fee AS fee_eur,
        v_seller_club_id AS from_club_id,
        v_buyer_club_id AS to_club_id;
END$$

CREATE PROCEDURE sp_release_player(IN p_user_id INT, IN p_player_id INT)
BEGIN
    DECLARE v_user_club_id INT;
    DECLARE v_player_club_id INT;
    DECLARE v_player_name VARCHAR(120);
    DECLARE v_player_role VARCHAR(10);
    DECLARE v_player_position_group VARCHAR(5);
    DECLARE v_promoted_player_id INT;
    DECLARE v_promoted_player_name VARCHAR(120);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT club_id INTO v_user_club_id
    FROM app_users
    WHERE user_id = p_user_id;

    SELECT club_id, player_name, squad_role, position_group
      INTO v_player_club_id, v_player_name, v_player_role, v_player_position_group
    FROM players
    WHERE player_id = p_player_id
    FOR UPDATE;

    IF v_player_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Player is already released';
    END IF;

    IF v_user_club_id <> v_player_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User can release only own club players';
    END IF;

    IF v_player_role = 'starter' THEN
        SET v_promoted_player_id = NULL;
        SET v_promoted_player_name = NULL;

        SELECT p.player_id, p.player_name
          INTO v_promoted_player_id, v_promoted_player_name
        FROM players p
        JOIN player_stats ps
          ON ps.player_id = p.player_id
        WHERE p.club_id = v_player_club_id
          AND p.squad_role = 'sub'
          AND p.position_group = v_player_position_group
        ORDER BY ps.overall DESC, p.player_id
        LIMIT 1
        FOR UPDATE;

        IF v_promoted_player_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '해당 포지션 후보가 없어 선발 11명을 유지할 수 없습니다.';
        END IF;

        UPDATE players
        SET squad_role = 'starter'
        WHERE player_id = v_promoted_player_id;
    END IF;

    UPDATE contracts
    SET status = 'released', end_date = CURDATE()
    WHERE player_id = p_player_id AND status = 'active';

    UPDATE transfer_market
    SET status = 'cancelled'
    WHERE player_id = p_player_id AND status = 'available';

    UPDATE players
    SET club_id = NULL,
        squad_role = 'sub'
    WHERE player_id = p_player_id;

    INSERT INTO transfer_history
        (player_id, from_club_id, to_club_id, transfer_type, fee_eur, transfer_date, created_by_user_id, memo)
    VALUES
        (p_player_id, v_player_club_id, NULL, 'release', 0, CURDATE(), p_user_id, 'Released through sp_release_player');

    COMMIT;

    SELECT 'RELEASE_COMPLETED' AS result_code, v_player_name AS player_name, v_player_club_id AS from_club_id;
END$$

CREATE PROCEDURE sp_create_squad_battle(IN p_home_club_id INT, IN p_away_club_id INT)
BEGIN
    DECLARE v_home_score DECIMAL(6,2);
    DECLARE v_away_score DECIMAL(6,2);
    DECLARE v_result VARCHAR(10);
    DECLARE v_home_starter_count INT;
    DECLARE v_away_starter_count INT;

    IF p_home_club_id = p_away_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Home and away clubs must be different';
    END IF;

    SELECT COUNT(*)
      INTO v_home_starter_count
    FROM players
    WHERE club_id = p_home_club_id
      AND squad_role = 'starter';

    SELECT COUNT(*)
      INTO v_away_starter_count
    FROM players
    WHERE club_id = p_away_club_id
      AND squad_role = 'starter';

    IF v_home_starter_count <> 11 OR v_away_starter_count <> 11 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '선발 선수가 11명이 아니므로 스쿼드 배틀을 진행할 수 없습니다.';
    END IF;

    SET v_home_score = fn_squad_score(p_home_club_id) + 2;
    SET v_away_score = fn_squad_score(p_away_club_id);

    IF v_home_score IS NULL OR v_away_score IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Club score not found';
    END IF;

    IF v_home_score > v_away_score THEN
        SET v_result = 'home';
    ELSEIF v_home_score < v_away_score THEN
        SET v_result = 'away';
    ELSE
        SET v_result = 'draw';
    END IF;

    INSERT INTO squad_battles
        (home_club_id, away_club_id, home_score, away_score, result, battle_date)
    VALUES
        (p_home_club_id, p_away_club_id, v_home_score, v_away_score, v_result, CURDATE());

    SELECT
        LAST_INSERT_ID() AS battle_id,
        p_home_club_id AS home_club_id,
        p_away_club_id AS away_club_id,
        v_home_score AS home_score,
        v_away_score AS away_score,
        v_result AS result;
END$$

CREATE PROCEDURE sp_list_player_for_transfer(IN p_user_id INT, IN p_player_id INT, IN p_asking_fee_eur DECIMAL(15,2))
BEGIN
    DECLARE v_user_club_id INT;
    DECLARE v_player_club_id INT;
    DECLARE v_new_listing_id INT;

    SELECT club_id INTO v_user_club_id
    FROM app_users
    WHERE user_id = p_user_id;

    SELECT club_id INTO v_player_club_id
    FROM players
    WHERE player_id = p_player_id;

    IF v_user_club_id <> v_player_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User can list only own club players';
    END IF;

    IF p_asking_fee_eur < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Asking fee cannot be negative';
    END IF;

    SELECT IFNULL(MAX(listing_id), 0) + 1 INTO v_new_listing_id
    FROM transfer_market;

    INSERT INTO transfer_market (listing_id, player_id, seller_club_id, asking_fee_eur, listed_date, status)
    VALUES (v_new_listing_id, p_player_id, v_user_club_id, p_asking_fee_eur, CURDATE(), 'available');

    SELECT 'LISTING_CREATED' AS result_code, p_player_id AS player_id, p_asking_fee_eur AS asking_fee_eur;
END$$

DELIMITER ;
