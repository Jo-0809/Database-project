USE kleague_db;

SELECT COUNT(*) AS clubs FROM clubs;
SELECT COUNT(*) AS players FROM players;
SELECT COUNT(*) AS player_stats FROM player_stats;
SELECT COUNT(*) AS contracts FROM contracts;
SELECT COUNT(*) AS transfer_market FROM transfer_market;

SELECT club_name, current_budget_eur FROM v_club_budget ORDER BY current_budget_eur DESC;
SELECT club_name, player_count, avg_player_overall, manager_rating, squad_score
FROM v_squad_score
ORDER BY squad_score DESC;

SELECT listing_id, player_name, seller_club, overall, asking_fee_eur
FROM v_transfer_market
ORDER BY overall DESC
LIMIT 20;

CALL sp_create_squad_battle(1, 2);
SELECT * FROM squad_battles ORDER BY battle_id DESC;
