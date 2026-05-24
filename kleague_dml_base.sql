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
