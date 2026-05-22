USE kleague_db;

DROP PROCEDURE IF EXISTS sp_buy_player;
DROP PROCEDURE IF EXISTS sp_release_player;
DROP PROCEDURE IF EXISTS sp_create_squad_battle;
DROP PROCEDURE IF EXISTS sp_list_player_for_transfer;

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

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT club_id INTO v_user_club_id
    FROM app_users
    WHERE user_id = p_user_id;

    SELECT club_id, player_name INTO v_player_club_id, v_player_name
    FROM players
    WHERE player_id = p_player_id
    FOR UPDATE;

    IF v_player_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Player is already released';
    END IF;

    IF v_user_club_id <> v_player_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User can release only own club players';
    END IF;

    UPDATE contracts
    SET status = 'released', end_date = CURDATE()
    WHERE player_id = p_player_id AND status = 'active';

    UPDATE transfer_market
    SET status = 'cancelled'
    WHERE player_id = p_player_id AND status = 'available';

    UPDATE players
    SET club_id = NULL
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

    IF p_home_club_id = p_away_club_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Home and away clubs must be different';
    END IF;

    SELECT squad_score INTO v_home_score
    FROM v_squad_score
    WHERE club_id = p_home_club_id;

    SELECT squad_score INTO v_away_score
    FROM v_squad_score
    WHERE club_id = p_away_club_id;

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

