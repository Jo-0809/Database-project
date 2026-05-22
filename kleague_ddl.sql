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
    total_spent_eur DECIMAL(15,2) DEFAULT 0,
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
    original_club_id INT NULL,
    player_name VARCHAR(120) NOT NULL,
    nationality VARCHAR(80) NOT NULL,
    birth_date DATE NULL,
    age SMALLINT NULL,
    position_group ENUM('GK','DF','MF','FW') NOT NULL,
    primary_position VARCHAR(60) NOT NULL,
    squad_number SMALLINT NULL,
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
LEFT JOIN players p ON c.club_id = p.club_id
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
