<<<<<<< HEAD
# K League Transfer Simulator DB

이 폴더는 팀원에게 바로 넘길 수 있는 최종 DB 구축 패키지입니다.

## 프로젝트 한 줄 설명

K League 1 구단을 선택해 선수 영입, 방출, 예산 관리, 계약 변경, 이적 기록 저장, 스쿼드 점수 대결을 수행하는 MySQL 중심 이적시장 시뮬레이터입니다.

## 중요한 원칙

- DB에 들어가는 핵심 데이터 값은 영어/숫자 중심입니다.
- 선수 이름은 `player_name_en`, 팀명은 영문 팀명을 사용했습니다.
- 국적, 도시, 경기장, 포지션도 영어로 정리했습니다.
- 능력치, 예산, 급여는 실제 공개 데이터에서 파생한 시뮬레이션 값입니다. 공식 FC24 능력치가 아닙니다.
- 현재 포함 선수 수는 검증된 K League Best 11 기준 132명입니다.

## 파일 구성

```text
kleague_db_final/
├─ kleague_ddl.sql            # DB, TABLE, VIEW, TRIGGER 생성
├─ kleague_dml.sql            # 영어/숫자 데이터 INSERT
├─ kleague_procedures.sql     # 영입/방출/스쿼드 대결 프로시저
├─ kleague_full_setup.sql     # 위 3개를 한 번에 실행하는 통합 SQL
├─ kleague_app.py             # Streamlit 프론트엔드
├─ requirements.txt
├─ data/
│  ├─ cleaned_clubs.csv
│  ├─ cleaned_players.csv
│  ├─ player_stats.csv
│  ├─ contracts.csv
│  ├─ transfer_market.csv
│  ├─ app_users.csv
│  └─ data_sources.csv
└─ docs/
   ├─ ERD.mmd
   ├─ presentation_script.md
   └─ verification_queries.sql
```

## MySQL Workbench 실행 순서

가장 쉬운 방법은 `kleague_full_setup.sql` 하나만 열어서 전체 실행하는 것입니다.

분리 실행하려면 아래 순서로 실행하세요.

```sql
SOURCE C:/path/to/kleague_db_final/kleague_ddl.sql;
SOURCE C:/path/to/kleague_db_final/kleague_dml.sql;
SOURCE C:/path/to/kleague_db_final/kleague_procedures.sql;
```

## 실행 후 검증 쿼리

```sql
USE kleague_db;

SELECT COUNT(*) AS clubs FROM clubs;
SELECT COUNT(*) AS players FROM players;
SELECT COUNT(*) AS player_stats FROM player_stats;
SELECT COUNT(*) AS contracts FROM contracts;
SELECT COUNT(*) AS transfer_market FROM transfer_market;

SELECT * FROM v_club_budget;
SELECT * FROM v_squad_score ORDER BY squad_score DESC;
SELECT * FROM v_transfer_market ORDER BY overall DESC LIMIT 20;
```

예상 값:

- clubs: 12
- players: 132
- player_stats: 132
- contracts: 132
- transfer_market: 132

## 프로시저 테스트

```sql
CALL sp_buy_player(1, 12);
CALL sp_release_player(1, 20200301);
CALL sp_create_squad_battle(1, 2);

SELECT * FROM transfer_history ORDER BY transfer_id DESC;
SELECT * FROM squad_battles ORDER BY battle_id DESC;
```

프로시저는 트랜잭션으로 동작합니다. 영입 중 예산 부족, 자기 팀 선수 영입, 이미 판매된 매물 같은 문제가 생기면 전체 작업이 ROLLBACK됩니다.

## Streamlit 실행

```bash
pip install -r requirements.txt
set MYSQL_PASSWORD=본인비밀번호
streamlit run kleague_app.py
```

macOS/Linux:

```bash
export MYSQL_PASSWORD=본인비밀번호
streamlit run kleague_app.py
```

## DB 핵심 테이블

- `clubs`: 구단과 예산
- `managers`: 감독과 전술/시뮬레이션 rating
- `players`: 선수 기본 정보와 현재 소속
- `player_stats`: 실제 기록 기반 경기 기록 + 시뮬레이션 능력치
- `contracts`: 선수 계약 이력
- `transfer_market`: 영입 가능한 매물
- `transfer_history`: 영입/방출 이력
- `squad_battles`: 스쿼드 점수 대결 결과
- `app_users`: 테스트 유저와 선택 구단

## 발표 핵심 문장

> 저희 프로젝트는 K League 1 선수 데이터를 기반으로 구단 예산, 계약, 선수 소속, 이적시장 매물, 이적 기록을 MySQL에서 관리하는 DB 중심 이적시장 시뮬레이터입니다. 선수 영입과 방출은 저장 프로시저와 트랜잭션으로 처리되어 예산 변경, 계약 변경, 소속 변경, 이력 저장이 하나의 작업으로 보장됩니다.
=======
# Database-project
>>>>>>> e5e7d876d352eafd3f73e5e13e57df00c50e79ac
