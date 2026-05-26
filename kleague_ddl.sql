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
    league_id TINYINT NOT NULL,
    league_name VARCHAR(20) NOT NULL,
    club_name VARCHAR(100) NOT NULL UNIQUE,
    city VARCHAR(80) NOT NULL,
    founded_year SMALLINT NOT NULL,
    stadium_name VARCHAR(120) NOT NULL,
    stadium_capacity INT NOT NULL,
    initial_budget_krw DECIMAL(15,2) NOT NULL,
    current_budget_krw DECIMAL(15,2) NOT NULL,
    total_spent_krw DECIMAL(15,2) DEFAULT 0,
    club_homepage VARCHAR(255),
    data_source_url VARCHAR(500),
    PRIMARY KEY (club_id),
    CONSTRAINT chk_club_capacity CHECK (stadium_capacity > 0),
    CONSTRAINT chk_club_initial_budget CHECK (initial_budget_krw >= 0),
    CONSTRAINT chk_club_current_budget CHECK (current_budget_krw >= 0),
    CONSTRAINT chk_club_total_spent CHECK (total_spent_krw >= 0)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE managers (
    manager_id INT NOT NULL,
    club_id INT NOT NULL UNIQUE,
    manager_name VARCHAR(100) NOT NULL,
    nationality VARCHAR(80) NOT NULL,
    preferred_formation VARCHAR(20) NOT NULL,
    rating TINYINT NOT NULL,
    rating_source VARCHAR(80) NOT NULL DEFAULT 'SIMULATION_RULE',
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
    market_value_krw DECIMAL(15,2) NOT NULL DEFAULT 0,
    contract_until DATE NULL,
    joined_date DATE NULL,
    profile_source_url VARCHAR(500),
    value_source_url VARCHAR(500),
    PRIMARY KEY (player_id),
    CONSTRAINT fk_players_club FOREIGN KEY (club_id) REFERENCES clubs(club_id),
    CONSTRAINT chk_player_age CHECK (age IS NULL OR age BETWEEN 14 AND 60),
    CONSTRAINT chk_player_height CHECK (height_cm IS NULL OR height_cm BETWEEN 140 AND 220),
    CONSTRAINT chk_player_weight CHECK (weight_kg IS NULL OR weight_kg BETWEEN 40 AND 150),
    CONSTRAINT chk_player_market_value CHECK (market_value_krw >= 0),
    INDEX idx_players_club_position (club_id, position_group),
    INDEX idx_players_market_value (market_value_krw),
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
    rating_source VARCHAR(80) NOT NULL DEFAULT 'DERIVED_PUBLIC_DATA',
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
    salary_krw DECIMAL(15,2) NOT NULL DEFAULT 0,
    status ENUM('active','expired','released') NOT NULL DEFAULT 'active',
    PRIMARY KEY (contract_id),
    CONSTRAINT fk_contracts_player FOREIGN KEY (player_id) REFERENCES players(player_id),
    CONSTRAINT fk_contracts_club FOREIGN KEY (club_id) REFERENCES clubs(club_id),
    CONSTRAINT chk_contract_salary CHECK (salary_krw >= 0),
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

CREATE TABLE seasons (
    season_id INT NOT NULL AUTO_INCREMENT,
    season_name VARCHAR(20) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    status ENUM('active','ended') NOT NULL DEFAULT 'active',
    active_season_key TINYINT GENERATED ALWAYS AS (CASE WHEN status = 'active' THEN 1 ELSE NULL END) STORED,
    champion_club_id INT NULL,
    PRIMARY KEY (season_id),
    CONSTRAINT fk_seasons_champion FOREIGN KEY (champion_club_id) REFERENCES clubs(club_id),
    UNIQUE KEY uq_one_active_season (active_season_key),
    INDEX idx_seasons_status (status)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE transfer_market (
    listing_id INT NOT NULL AUTO_INCREMENT,
    player_id INT NOT NULL,
    seller_club_id INT NOT NULL,
    asking_fee_krw DECIMAL(15,2) NOT NULL,
    listed_date DATE NOT NULL,
    status ENUM('listed','sold','cancelled') NOT NULL DEFAULT 'listed',
    PRIMARY KEY (listing_id),
    CONSTRAINT fk_market_player FOREIGN KEY (player_id) REFERENCES players(player_id),
    CONSTRAINT fk_market_seller FOREIGN KEY (seller_club_id) REFERENCES clubs(club_id),
    CONSTRAINT chk_market_fee CHECK (asking_fee_krw > 0),
    INDEX idx_market_status_fee (status, asking_fee_krw),
    INDEX idx_market_player_status (player_id, status)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE transfer_history (
    transfer_id INT NOT NULL AUTO_INCREMENT,
    player_id INT NOT NULL,
    from_club_id INT NULL,
    to_club_id INT NULL,
    transfer_type ENUM('buy','sell','release','free_agent','loan') NOT NULL,
    fee_krw DECIMAL(15,2) NOT NULL,
    transfer_date DATE NOT NULL,
    season_id INT NULL,
    created_by_user_id INT NULL,
    memo VARCHAR(500),
    PRIMARY KEY (transfer_id),
    CONSTRAINT fk_history_player FOREIGN KEY (player_id) REFERENCES players(player_id),
    CONSTRAINT fk_history_from_club FOREIGN KEY (from_club_id) REFERENCES clubs(club_id),
    CONSTRAINT fk_history_to_club FOREIGN KEY (to_club_id) REFERENCES clubs(club_id),
    CONSTRAINT fk_history_season FOREIGN KEY (season_id) REFERENCES seasons(season_id),
    CONSTRAINT fk_history_user FOREIGN KEY (created_by_user_id) REFERENCES app_users(user_id),
    CONSTRAINT chk_history_fee CHECK (fee_krw > 0),
    CONSTRAINT chk_history_has_side CHECK (from_club_id IS NOT NULL OR to_club_id IS NOT NULL),
    CONSTRAINT chk_history_diff_club CHECK (from_club_id IS NULL OR to_club_id IS NULL OR from_club_id <> to_club_id),
    INDEX idx_history_date (transfer_date),
    INDEX idx_history_season (season_id),
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
    season_id INT NULL,
    PRIMARY KEY (battle_id),
    CONSTRAINT fk_battle_home FOREIGN KEY (home_club_id) REFERENCES clubs(club_id),
    CONSTRAINT fk_battle_away FOREIGN KEY (away_club_id) REFERENCES clubs(club_id),
    CONSTRAINT fk_battle_season FOREIGN KEY (season_id) REFERENCES seasons(season_id),
    CONSTRAINT chk_battle_diff_club CHECK (home_club_id <> away_club_id),
    INDEX idx_battle_season (season_id),
    INDEX idx_battle_date (battle_date)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE audit_logs (
    audit_id INT NOT NULL AUTO_INCREMENT,
    table_name VARCHAR(30) NOT NULL,
    action_type ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id INT NULL,
    old_value TEXT NULL,
    new_value TEXT NULL,
    changed_by_user_id INT NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    note VARCHAR(255) NULL,
    PRIMARY KEY (audit_id),
    CONSTRAINT fk_audit_user FOREIGN KEY (changed_by_user_id) REFERENCES app_users(user_id),
    INDEX idx_audit_table_time (table_name, changed_at),
    INDEX idx_audit_user_time (changed_by_user_id, changed_at)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE VIEW v_club_budget AS
SELECT
    club_id,
    league_name,
    club_name,
    initial_budget_krw,
    current_budget_krw,
    total_spent_krw
FROM clubs;

CREATE VIEW v_player_info AS
SELECT
    p.player_id,
    p.player_name,
    p.nationality,
    p.position_group,
    p.primary_position,
    c.league_name,
    c.club_name,
    p.market_value_krw,
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
    c.league_name,
    m.manager_name,
    m.preferred_formation,
    COUNT(r.player_id) AS player_count,
    ROUND(AVG(r.overall), 2) AS avg_player_overall,
    ROUND(AVG(CASE WHEN r.squad_rank <= 11 THEN r.overall END), 2) AS starting11_avg,
    ROUND(COALESCE(AVG(CASE WHEN r.squad_rank BETWEEN 12 AND 16 THEN r.overall END), 0), 2) AS bench_avg,
    SUM(CASE WHEN r.squad_rank BETWEEN 12 AND 16 THEN 1 ELSE 0 END) AS bench_count,
    m.rating AS manager_rating,
    ROUND(
        CASE
            WHEN COUNT(r.player_id) < 11 THEN 0
            ELSE
                COALESCE(AVG(CASE WHEN r.squad_rank <= 11 THEN r.overall END), 0) * 0.90
                + m.rating * 0.09
                + CASE
                    WHEN SUM(CASE WHEN r.squad_rank BETWEEN 12 AND 16 THEN 1 ELSE 0 END) > 0
                    THEN COALESCE(AVG(CASE WHEN r.squad_rank BETWEEN 12 AND 16 THEN r.overall END), 0) * 0.01
                    ELSE 0
                  END
        END,
        2
    ) AS squad_score
FROM clubs c
JOIN managers m ON c.club_id = m.club_id
LEFT JOIN (
    SELECT
        p.player_id,
        p.club_id,
        ps.overall,
        ROW_NUMBER() OVER (
            PARTITION BY p.club_id
            ORDER BY ps.overall DESC, p.player_id ASC
        ) AS squad_rank
    FROM players p
    JOIN player_stats ps ON p.player_id = ps.player_id
    WHERE p.club_id IS NOT NULL
) r ON c.club_id = r.club_id
GROUP BY c.club_id, c.club_name, c.league_name, m.manager_name, m.preferred_formation, m.rating;

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
    c.league_name AS seller_league,
    tm.seller_club_id,
    tm.asking_fee_krw,
    tm.listed_date,
    tm.status
FROM transfer_market tm
JOIN players p ON tm.player_id = p.player_id
JOIN player_stats ps ON p.player_id = ps.player_id
JOIN clubs c ON tm.seller_club_id = c.club_id
WHERE tm.status = 'listed';

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
    c.league_name,
    p.position_group,
    COUNT(*) AS player_count,
    ROUND(AVG(ps.overall), 2) AS avg_overall
FROM clubs c
JOIN players p ON c.club_id = p.club_id
JOIN player_stats ps ON p.player_id = ps.player_id
GROUP BY c.club_id, c.club_name, c.league_name, p.position_group;

CREATE VIEW v_club_market_value AS
SELECT
    c.club_id,
    c.club_name,
    c.league_name,
    COUNT(p.player_id) AS player_count,
    SUM(p.market_value_krw) AS squad_market_value_krw,
    ROUND(AVG(p.market_value_krw), 2) AS avg_market_value_krw
FROM clubs c
LEFT JOIN players p ON c.club_id = p.club_id
GROUP BY c.club_id, c.club_name, c.league_name;

CREATE VIEW v_club_position_gap AS
SELECT
    c.club_id,
    c.club_name,
    c.league_id,
    c.league_name,
    pg.position_group,
    COUNT(p.player_id) AS player_count,
    ROUND(AVG(ps.overall), 2) AS avg_overall,
    la.league_avg_overall,
    ROUND(
        CASE
            WHEN COUNT(p.player_id) = 0 THEN la.league_avg_overall
            ELSE la.league_avg_overall - AVG(ps.overall)
        END,
        2
    ) AS weakness_gap,
    CASE
        WHEN COUNT(p.player_id) = 0 THEN 'urgent'
        WHEN AVG(ps.overall) < la.league_avg_overall - 4 THEN 'weak'
        WHEN AVG(ps.overall) > la.league_avg_overall + 4 THEN 'strong'
        ELSE 'stable'
    END AS need_level
FROM clubs c
CROSS JOIN (
    SELECT 'GK' AS position_group
    UNION ALL SELECT 'DF'
    UNION ALL SELECT 'MF'
    UNION ALL SELECT 'FW'
) pg
JOIN (
    SELECT c.league_id, p.position_group, ROUND(AVG(ps.overall), 2) AS league_avg_overall
    FROM players p
    JOIN clubs c ON p.club_id = c.club_id
    JOIN player_stats ps ON p.player_id = ps.player_id
    WHERE p.club_id IS NOT NULL
    GROUP BY c.league_id, p.position_group
) la ON la.league_id = c.league_id
    AND la.position_group = pg.position_group
LEFT JOIN players p
    ON p.club_id = c.club_id
   AND p.position_group = pg.position_group
LEFT JOIN player_stats ps
    ON p.player_id = ps.player_id
GROUP BY c.club_id, c.club_name, c.league_id, c.league_name, pg.position_group, la.league_avg_overall;

CREATE VIEW v_transfer_recommendations AS
SELECT
    buyer.club_id AS buyer_club_id,
    buyer.club_name AS buyer_club,
    buyer.league_name AS buyer_league,
    tm.listing_id,
    tm.player_id,
    p.player_name,
    p.position_group,
    p.primary_position,
    p.age,
    p.nationality,
    ps.overall,
    seller.club_name AS seller_club,
    seller.league_name AS seller_league,
    tm.asking_fee_krw,
    buyer.current_budget_krw,
    gap.player_count AS current_position_players,
    gap.avg_overall AS current_position_avg,
    gap.league_avg_overall,
    gap.weakness_gap,
    gap.need_level,
    ROUND(
        ps.overall * 0.45
        + LEAST(GREATEST(gap.weakness_gap, 0), 12) * 2.8
        + CASE
            WHEN tm.asking_fee_krw <= buyer.current_budget_krw THEN 12
            ELSE -80
          END
        + CASE
            WHEN tm.asking_fee_krw <= 0 THEN 0
            ELSE LEAST(p.market_value_krw / tm.asking_fee_krw, 1.8) * 8
          END
        + CASE
            WHEN p.age IS NULL THEN 0
            WHEN p.age <= 23 THEN 6
            WHEN p.age >= 34 THEN -5
            ELSE 0
          END,
        2
    ) AS recommendation_score,
    CASE
        WHEN tm.asking_fee_krw > buyer.current_budget_krw THEN '예산 초과'
        WHEN gap.need_level IN ('urgent','weak') THEN '약점 보강'
        WHEN p.age <= 23 THEN '성장 가치'
        ELSE '전력 보강'
    END AS recommendation_reason
FROM clubs buyer
JOIN v_club_position_gap gap
    ON buyer.club_id = gap.club_id
JOIN transfer_market tm
    ON tm.status = 'listed'
JOIN players p
    ON tm.player_id = p.player_id
   AND p.position_group = gap.position_group
JOIN player_stats ps
    ON p.player_id = ps.player_id
JOIN clubs seller
    ON tm.seller_club_id = seller.club_id
WHERE buyer.club_id <> tm.seller_club_id;

CREATE VIEW v_season_standings AS
SELECT
    c.club_id,
    c.club_name,
    s.season_id,
    s.season_name,
    COUNT(sb.battle_id) AS played,
    SUM(CASE
        WHEN (sb.home_club_id = c.club_id AND sb.result = 'home')
          OR (sb.away_club_id = c.club_id AND sb.result = 'away') THEN 1 ELSE 0 END) AS wins,
    SUM(CASE
        WHEN sb.result = 'draw'
         AND (sb.home_club_id = c.club_id OR sb.away_club_id = c.club_id) THEN 1 ELSE 0 END) AS draws,
    SUM(CASE
        WHEN (sb.home_club_id = c.club_id AND sb.result = 'away')
          OR (sb.away_club_id = c.club_id AND sb.result = 'home') THEN 1 ELSE 0 END) AS losses,
    SUM(CASE
        WHEN (sb.home_club_id = c.club_id AND sb.result = 'home')
          OR (sb.away_club_id = c.club_id AND sb.result = 'away') THEN 3
        WHEN sb.result = 'draw'
         AND (sb.home_club_id = c.club_id OR sb.away_club_id = c.club_id) THEN 1
        ELSE 0 END) AS points
FROM clubs c
JOIN seasons s
    ON s.status = 'active'
LEFT JOIN squad_battles sb
    ON (sb.home_club_id = c.club_id OR sb.away_club_id = c.club_id)
   AND sb.season_id = s.season_id
GROUP BY c.club_id, c.club_name, s.season_id, s.season_name;

CREATE VIEW v_season_top_transfers AS
SELECT
    s.season_name,
    p.player_name,
    fc.club_name AS from_club,
    tc.club_name AS to_club,
    th.fee_krw,
    th.transfer_date,
    RANK() OVER (PARTITION BY th.season_id ORDER BY th.fee_krw DESC) AS fee_rank
FROM transfer_history th
JOIN seasons s ON th.season_id = s.season_id
JOIN players p ON th.player_id = p.player_id
LEFT JOIN clubs fc ON th.from_club_id = fc.club_id
LEFT JOIN clubs tc ON th.to_club_id = tc.club_id
WHERE th.transfer_type = 'buy'
  AND th.fee_krw > 0;

CREATE VIEW v_champion_history AS
SELECT
    s.season_id,
    s.season_name,
    s.start_date,
    s.end_date,
    c.club_name AS champion_club
FROM seasons s
LEFT JOIN clubs c ON s.champion_club_id = c.club_id
WHERE s.status = 'ended'
ORDER BY s.end_date DESC;

CREATE VIEW v_audit_recent AS
SELECT
    al.audit_id,
    al.changed_at,
    IFNULL(u.username, '(system)') AS changed_by,
    al.table_name,
    al.action_type,
    al.record_id,
    al.note,
    al.old_value,
    al.new_value
FROM audit_logs al
LEFT JOIN app_users u ON al.changed_by_user_id = u.user_id
ORDER BY al.changed_at DESC, al.audit_id DESC;

DELIMITER $$
CREATE TRIGGER trg_club_budget_before_update
BEFORE UPDATE ON clubs
FOR EACH ROW
BEGIN
    IF NEW.current_budget_krw < 0 THEN
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

    IF NEW.status = 'listed'
       AND EXISTS (
           SELECT 1 FROM transfer_market
           WHERE player_id = NEW.player_id AND status = 'listed'
       ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Player already has an active listing';
    END IF;
END$$

CREATE TRIGGER trg_market_before_update
BEFORE UPDATE ON transfer_market
FOR EACH ROW
BEGIN
    IF NEW.status = 'listed'
       AND EXISTS (
           SELECT 1 FROM transfer_market
           WHERE player_id = NEW.player_id
             AND status = 'listed'
             AND listing_id <> NEW.listing_id
       ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Player already has an active listing';
    END IF;
END$$

CREATE TRIGGER trg_audit_players_update
AFTER UPDATE ON players
FOR EACH ROW
BEGIN
    IF @app_user_id IS NOT NULL AND NOT (OLD.club_id <=> NEW.club_id) THEN
        INSERT INTO audit_logs
            (table_name, action_type, record_id, old_value, new_value, changed_by_user_id, note)
        VALUES
            ('players', 'UPDATE', NEW.player_id,
             CONCAT('club_id=', IFNULL(OLD.club_id, 'NULL')),
             CONCAT('club_id=', IFNULL(NEW.club_id, 'NULL')),
             @app_user_id,
             CONCAT(NEW.player_name, ' club changed'));
    END IF;
END$$

CREATE TRIGGER trg_audit_clubs_update
AFTER UPDATE ON clubs
FOR EACH ROW
BEGIN
    IF @app_user_id IS NOT NULL AND OLD.current_budget_krw <> NEW.current_budget_krw THEN
        INSERT INTO audit_logs
            (table_name, action_type, record_id, old_value, new_value, changed_by_user_id, note)
        VALUES
            ('clubs', 'UPDATE', NEW.club_id,
             CONCAT('current_budget_krw=', OLD.current_budget_krw),
             CONCAT('current_budget_krw=', NEW.current_budget_krw),
             @app_user_id,
             CONCAT(NEW.club_name, ' budget changed'));
    END IF;
END$$

CREATE TRIGGER trg_audit_contracts_insert
AFTER INSERT ON contracts
FOR EACH ROW
BEGIN
    IF @app_user_id IS NOT NULL THEN
        INSERT INTO audit_logs
            (table_name, action_type, record_id, new_value, changed_by_user_id, note)
        VALUES
            ('contracts', 'INSERT', NEW.contract_id,
             CONCAT('player_id=', NEW.player_id, ', club_id=', NEW.club_id, ', salary_krw=', NEW.salary_krw),
             @app_user_id,
             'New contract created');
    END IF;
END$$

CREATE TRIGGER trg_audit_contracts_update
AFTER UPDATE ON contracts
FOR EACH ROW
BEGIN
    IF @app_user_id IS NOT NULL AND OLD.status <> NEW.status THEN
        INSERT INTO audit_logs
            (table_name, action_type, record_id, old_value, new_value, changed_by_user_id, note)
        VALUES
            ('contracts', 'UPDATE', NEW.contract_id,
             CONCAT('status=', OLD.status),
             CONCAT('status=', NEW.status),
             @app_user_id,
             'Contract status changed');
    END IF;
END$$

CREATE TRIGGER trg_audit_market_insert
AFTER INSERT ON transfer_market
FOR EACH ROW
BEGIN
    IF @app_user_id IS NOT NULL THEN
        INSERT INTO audit_logs
            (table_name, action_type, record_id, new_value, changed_by_user_id, note)
        VALUES
            ('transfer_market', 'INSERT', NEW.listing_id,
             CONCAT('player_id=', NEW.player_id, ', asking_fee_krw=', NEW.asking_fee_krw),
             @app_user_id,
             'Transfer listing created');
    END IF;
END$$

CREATE TRIGGER trg_audit_market_update
AFTER UPDATE ON transfer_market
FOR EACH ROW
BEGIN
    IF @app_user_id IS NOT NULL AND OLD.status <> NEW.status THEN
        INSERT INTO audit_logs
            (table_name, action_type, record_id, old_value, new_value, changed_by_user_id, note)
        VALUES
            ('transfer_market', 'UPDATE', NEW.listing_id,
             CONCAT('status=', OLD.status),
             CONCAT('status=', NEW.status),
             @app_user_id,
             'Transfer listing status changed');
    END IF;
END$$
DELIMITER ;



