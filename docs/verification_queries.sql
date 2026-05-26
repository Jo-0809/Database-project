USE kleague_db;

SELECT COUNT(*) AS clubs FROM clubs;
SELECT COUNT(*) AS players FROM players;
SELECT COUNT(*) AS player_stats FROM player_stats;
SELECT COUNT(*) AS contracts FROM contracts;
SELECT COUNT(*) AS transfer_market FROM transfer_market;
SELECT COUNT(*) AS seasons FROM seasons;
SELECT COUNT(*) AS audit_logs FROM audit_logs;

SELECT club_name, current_budget_eur FROM v_club_budget ORDER BY current_budget_eur DESC;
SELECT club_name, player_count, avg_player_overall, starting11_avg, bench_avg, bench_count, manager_rating, squad_score
FROM v_squad_score
ORDER BY squad_score DESC;

SELECT MIN(player_count) AS min_squad, MAX(player_count) AS max_squad
FROM v_squad_score;

SELECT position_group, player_count, avg_overall, league_avg_overall, weakness_gap, need_level
FROM v_club_position_gap
WHERE club_id = 1
ORDER BY FIELD(position_group, 'GK', 'DF', 'MF', 'FW');

SELECT player_name, position_group, seller_club, asking_fee_eur, recommendation_reason, recommendation_score
FROM v_transfer_recommendations
WHERE buyer_club_id = 1
ORDER BY recommendation_score DESC
LIMIT 10;

SELECT listing_id, player_name, seller_club, overall, asking_fee_eur
FROM v_transfer_market
ORDER BY overall DESC
LIMIT 20;

SELECT listing_id INTO @sample_listing_id
FROM v_transfer_market
WHERE seller_club_id <> 1
ORDER BY asking_fee_eur ASC
LIMIT 1;
CALL sp_buy_player(1, @sample_listing_id);
SELECT * FROM transfer_history ORDER BY transfer_id DESC LIMIT 5;

SET @home_score = (SELECT squad_score FROM v_squad_score WHERE club_id = 1);
SET @away_score = (SELECT squad_score FROM v_squad_score WHERE club_id = 2);
CALL sp_save_squad_battle(1, 2, @home_score, @away_score, 11, 11);
SELECT * FROM squad_battles ORDER BY battle_id DESC;

SELECT * FROM v_season_standings ORDER BY points DESC, wins DESC;
SELECT * FROM v_audit_recent LIMIT 20;
