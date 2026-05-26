USE kleague_db;

DROP PROCEDURE IF EXISTS sp_buy_player;
DROP PROCEDURE IF EXISTS sp_buy_player_with_release;
DROP PROCEDURE IF EXISTS sp_release_player;
DROP PROCEDURE IF EXISTS sp_create_squad_battle;
DROP PROCEDURE IF EXISTS sp_save_squad_battle;
DROP PROCEDURE IF EXISTS sp_list_player_for_transfer;
DROP PROCEDURE IF EXISTS sp_cancel_listing;
DROP PROCEDURE IF EXISTS sp_start_new_season;

DELIMITER $$

CREATE PROCEDURE sp_buy_player(IN p_user_id INT, IN p_listing_id INT)
BEGIN
    DECLARE v_buyer_club_id INT;
    DECLARE v_seller_club_id INT;
    DECLARE v_player_id INT;
    DECLARE v_fee DECIMAL(15,2);
    DECLARE v_status VARCHAR(20);
    DECLARE v_buyer_budget DECIMAL(15,2);
    DECLARE v_player_name VARCHAR(120);
    DECLARE v_buyer_club_name VARCHAR(100);
    DECLARE v_seller_club_name VARCHAR(100);
    DECLARE v_seller_squad_count INT;
    DECLARE v_active_season_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @app_user_id = NULL;
        RESIGNAL;
    END;

    START TRANSACTION;
    SET @app_user_id = p_user_id;

    SELECT au.club_id, c.club_name
      INTO v_buyer_club_id, v_buyer_club_name
    FROM app_users au
    JOIN clubs c ON au.club_id = c.club_id
    WHERE au.user_id = p_user_id;

    IF v_buyer_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User does not exist';
    END IF;

    SELECT tm.player_id, tm.seller_club_id, tm.asking_fee_eur, tm.status, p.player_name, c.club_name
      INTO v_player_id, v_seller_club_id, v_fee, v_status, v_player_name, v_seller_club_name
    FROM transfer_market tm
    JOIN players p ON tm.player_id = p.player_id
    JOIN clubs c ON tm.seller_club_id = c.club_id
    WHERE tm.listing_id = p_listing_id
    FOR UPDATE;

    IF v_status <> 'available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listing is not available';
    END IF;

    IF v_buyer_club_id = v_seller_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot buy a player from your own club';
    END IF;

    SELECT COUNT(*) INTO v_seller_squad_count
    FROM players
    WHERE club_id = v_seller_club_id;

    IF v_seller_squad_count <= 11 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller club must keep at least 11 players';
    END IF;

    SELECT current_budget_eur INTO v_buyer_budget
    FROM clubs
    WHERE club_id = v_buyer_club_id
    FOR UPDATE;

    IF v_buyer_budget < v_fee THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough budget';
    END IF;

    SELECT season_id INTO v_active_season_id
    FROM seasons
    WHERE status = 'active'
    LIMIT 1;

    IF v_active_season_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active season is required for a transfer';
    END IF;

    UPDATE contracts
    SET status = 'expired'
    WHERE player_id = v_player_id AND status = 'active';

    INSERT INTO contracts (player_id, club_id, start_date, end_date, salary_eur, status)
    VALUES (v_player_id, v_buyer_club_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 2 YEAR), GREATEST(v_fee * 0.08, 20000), 'active');

    UPDATE players
    SET club_id = v_buyer_club_id,
        joined_date = CURDATE(),
        contract_until = DATE_ADD(CURDATE(), INTERVAL 2 YEAR)
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
        (player_id, from_club_id, to_club_id, transfer_type, fee_eur, transfer_date, season_id, created_by_user_id, memo)
    VALUES
        (v_player_id, v_seller_club_id, v_buyer_club_id, 'buy', v_fee, CURDATE(),
         v_active_season_id, p_user_id, 'Completed through sp_buy_player');

    COMMIT;
    SET @app_user_id = NULL;

    SELECT
        'BUY_COMPLETED' AS result_code,
        v_player_name AS bought_player,
        v_seller_club_name AS seller_club,
        v_buyer_club_name AS buyer_club,
        v_fee AS fee_eur,
        v_seller_club_id AS from_club_id,
        v_buyer_club_id AS to_club_id;
END$$

CREATE PROCEDURE sp_save_squad_battle(
    IN p_home_club_id INT,
    IN p_away_club_id INT,
    IN p_home_score DECIMAL(6,2),
    IN p_away_score DECIMAL(6,2),
    IN p_home_selected_count INT,
    IN p_away_selected_count INT
)
BEGIN
    DECLARE v_result VARCHAR(10);
    DECLARE v_home_count INT;
    DECLARE v_away_count INT;
    DECLARE v_active_season_id INT;

    IF p_home_club_id = p_away_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Home and away clubs must be different';
    END IF;

    IF p_home_selected_count < 11 OR p_away_selected_count < 11 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Both clubs need a selected 11-player lineup for a squad battle';
    END IF;

    IF p_home_score < 0 OR p_away_score < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Battle scores cannot be negative';
    END IF;

    SELECT COUNT(*) INTO v_home_count
    FROM players
    WHERE club_id = p_home_club_id;

    SELECT COUNT(*) INTO v_away_count
    FROM players
    WHERE club_id = p_away_club_id;

    IF v_home_count < 11 OR v_away_count < 11 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Both clubs need at least 11 players for a squad battle';
    END IF;

    SELECT season_id INTO v_active_season_id
    FROM seasons
    WHERE status = 'active'
    LIMIT 1;

    IF v_active_season_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active season is required for a squad battle';
    END IF;

    IF p_home_score > p_away_score THEN
        SET v_result = 'home';
    ELSEIF p_home_score < p_away_score THEN
        SET v_result = 'away';
    ELSE
        SET v_result = 'draw';
    END IF;

    INSERT INTO squad_battles
        (home_club_id, away_club_id, home_score, away_score, result, battle_date, season_id)
    VALUES
        (p_home_club_id, p_away_club_id, p_home_score, p_away_score, v_result, CURDATE(), v_active_season_id);

    SELECT
        LAST_INSERT_ID() AS battle_id,
        p_home_club_id AS home_club_id,
        p_away_club_id AS away_club_id,
        p_home_score AS home_score,
        p_away_score AS away_score,
        v_result AS result;
END$$

CREATE PROCEDURE sp_list_player_for_transfer(IN p_user_id INT, IN p_player_id INT, IN p_asking_fee_eur DECIMAL(15,2))
BEGIN
    DECLARE v_user_club_id INT;
    DECLARE v_player_club_id INT;
    DECLARE v_market_value_eur DECIMAL(15,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = NULL;
        RESIGNAL;
    END;

    SET @app_user_id = p_user_id;

    SELECT club_id INTO v_user_club_id
    FROM app_users
    WHERE user_id = p_user_id;

    SELECT club_id, market_value_eur
      INTO v_player_club_id, v_market_value_eur
    FROM players
    WHERE player_id = p_player_id;

    IF v_user_club_id <> v_player_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User can list only own club players';
    END IF;

    IF p_asking_fee_eur < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Asking fee cannot be negative';
    END IF;

    IF v_market_value_eur <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Player has no confirmed Transfermarkt market value';
    END IF;

    IF ABS(p_asking_fee_eur - v_market_value_eur) > 0.01 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Asking fee must equal confirmed Transfermarkt market value';
    END IF;

    INSERT INTO transfer_market (player_id, seller_club_id, asking_fee_eur, listed_date, status)
    VALUES (p_player_id, v_user_club_id, v_market_value_eur, CURDATE(), 'available');

    SET @app_user_id = NULL;

    SELECT 'LISTING_CREATED' AS result_code,
           LAST_INSERT_ID() AS listing_id,
           p_player_id AS player_id,
           v_market_value_eur AS asking_fee_eur;
END$$

CREATE PROCEDURE sp_cancel_listing(IN p_user_id INT, IN p_listing_id INT)
BEGIN
    DECLARE v_user_club_id INT;
    DECLARE v_seller_club_id INT;
    DECLARE v_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @app_user_id = NULL;
        RESIGNAL;
    END;

    START TRANSACTION;
    SET @app_user_id = p_user_id;

    SELECT club_id INTO v_user_club_id
    FROM app_users
    WHERE user_id = p_user_id;

    SELECT seller_club_id, status
      INTO v_seller_club_id, v_status
    FROM transfer_market
    WHERE listing_id = p_listing_id
    FOR UPDATE;

    IF v_seller_club_id <> v_user_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User can cancel only own club listings';
    END IF;

    IF v_status <> 'available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only available listings can be cancelled';
    END IF;

    UPDATE transfer_market
    SET status = 'cancelled'
    WHERE listing_id = p_listing_id;

    COMMIT;
    SET @app_user_id = NULL;

    SELECT 'LISTING_CANCELLED' AS result_code, p_listing_id AS listing_id;
END$$

CREATE PROCEDURE sp_start_new_season(IN p_new_season_name VARCHAR(20))
BEGIN
    DECLARE v_current_season_id INT;
    DECLARE v_champion_club_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT season_id INTO v_current_season_id
    FROM seasons
    WHERE status = 'active'
    LIMIT 1
    FOR UPDATE;

    IF v_current_season_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No active season exists';
    END IF;

    SELECT club_id INTO v_champion_club_id
    FROM v_season_standings
    ORDER BY points DESC, wins DESC, club_id ASC
    LIMIT 1;

    UPDATE seasons
    SET status = 'ended',
        end_date = CURDATE(),
        champion_club_id = v_champion_club_id
    WHERE season_id = v_current_season_id;

    INSERT INTO seasons (season_name, start_date, status)
    VALUES (p_new_season_name, CURDATE(), 'active');

    COMMIT;

    SELECT
        'SEASON_STARTED' AS result_code,
        p_new_season_name AS new_season,
        v_champion_club_id AS previous_champion_club_id,
        (SELECT club_name FROM clubs WHERE club_id = v_champion_club_id) AS previous_champion;
END$$

DELIMITER ;
