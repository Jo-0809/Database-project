# K리그 이적시장 기반 스토브리그 체험 DB 시스템

> MySQL이 핵심 엔진, Streamlit은 그 엔진을 조작하는 화면

---

## 📁 파일 구성

```
Database-project/
├─ kleague_ddl.sql            ← DB 구조 생성 (테이블·뷰·트리거·함수)
├─ kleague_dml_base.sql       ← 구단/감독/유저/이적시장 기본 데이터
├─ kleague_dml_sample.sql     ← 선수 132명 데이터 (포지션·능력치·계약)
├─ kleague_extensions.sql     ← 시즌·감사로그 확장 (트리거·뷰·인덱스 포함)
├─ kleague_procedures.sql     ← 프로시저 6개 (영입/방출/대결/등록/취소/시즌)
├─ kleague_full_setup.sql     ← 위 5개를 한 번에 실행하는 통합 파일 ✅
├─ kleague_app.py             ← Streamlit 프론트엔드
├─ csv_to_sql.py              ← CSV → SQL INSERT 변환 스크립트
├─ requirements.txt
├─ data/                      ← 원본 CSV 데이터 (참고/출처용)
│  ├─ cleaned_clubs.csv
│  ├─ cleaned_players.csv
│  ├─ player_stats.csv
│  ├─ contracts.csv
│  ├─ transfer_market.csv
│  ├─ app_users.csv
│  └─ data_sources.csv
└─ docs/
   ├─ ERD.mmd                 ← Mermaid ERD
   ├─ presentation_script.md  ← 발표 스크립트
   └─ verification_queries.sql← 구축 확인 쿼리
```

---

## 🚀 실행 순서

### Step 0. CSV → SQL 변환 (최초 1회, 필수)

`data/` 폴더의 CSV 파일로부터 DML SQL 파일과 통합 파일을 생성합니다.

```bash
python csv_to_sql.py
```

> 아래 파일이 자동 생성됩니다:
> - `kleague_dml_base.sql` — CLUB / MANAGER / APP_USER
> - `kleague_dml_sample.sql` — PLAYER / PLAYER_STATS / CONTRACT / TRANSFER_MARKET
> - `kleague_full_setup.sql` — 위 5개 SQL을 하나로 합친 통합 파일

---

### Step 1. MySQL DB 구축

**방법 A — 통합 파일 한 번에 실행 (권장)**

`csv_to_sql.py` 실행 후 생성된 `kleague_full_setup.sql`을 MySQL Workbench에서 열고 전체 실행(`Ctrl+Shift+Enter`)

**방법 B — 터미널 SOURCE 명령어**

```sql
-- MySQL 접속 후 아래 순서로 실행
SOURCE /경로/kleague_ddl.sql;
SOURCE /경로/kleague_dml_base.sql;
SOURCE /경로/kleague_dml_sample.sql;
SOURCE /경로/kleague_extensions.sql;
SOURCE /경로/kleague_procedures.sql;
```

**방법 C — 터미널 파이프**

```bash
mysql -u root -p < kleague_ddl.sql
mysql -u root -p kleague_db < kleague_dml_base.sql
mysql -u root -p kleague_db < kleague_dml_sample.sql
mysql -u root -p kleague_db < kleague_extensions.sql
mysql -u root -p kleague_db < kleague_procedures.sql
```

> ⚠️ 반드시 위 순서를 지켜야 합니다. (DDL → DML Base → DML Sample → Extensions → Procedures)

---

### Step 2. DB 구축 확인

```sql
USE kleague_db;

-- 테이블/뷰/트리거/프로시저 목록 확인
SHOW TABLES;
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW TRIGGERS;
SHOW PROCEDURE STATUS WHERE Db = 'kleague_db';

-- 데이터 확인
SELECT * FROM V_SQUAD_SCORE ORDER BY squad_score DESC;
SELECT * FROM V_TRANSFER_MARKET;
SELECT * FROM V_CLUB_BUDGET ORDER BY current_budget DESC;

-- 프로시저 테스트
CALL sp_create_squad_battle(1, 2);   -- FC Seoul vs Ulsan 대결
CALL sp_buy_player(1, 12);           -- FC Seoul(user=1)이 Ulsan 매물 12번 영입
-- ※ listing 1~11은 FC Seoul 매물 → user_id=1로 영입 불가
```

---

### Step 3. Streamlit 앱 실행

`kleague_app.py` 상단 비밀번호 수정:

```python
DB_CONFIG = {
    "host":     "localhost",
    "port":     3306,
    "user":     "root",
    "password": "본인_MySQL_비밀번호",  # ← 여기만 수정
    "database": "kleague_db",
    "charset":  "utf8mb4",
}
```

패키지 설치 및 실행:

```bash
pip install -r requirements.txt
streamlit run kleague_app.py
```

---

## 🗄️ DB 구성 요약

### 테이블 (11개)

| 테이블 | 역할 |
|---|---|
| CLUB | 12개 K리그1 구단 + 예산 |
| MANAGER | 구단 감독 (구단당 1명) |
| PLAYER | 선수 기본 정보 + 현재 소속 |
| PLAYER_STATS | 선수 능력치 (overall 자동 계산) |
| CONTRACT | 선수-구단 계약 이력 |
| TRANSFER_HISTORY | 이적·방출 기록 |
| TRANSFER_MARKET | 이적시장 매물 |
| SQUAD_BATTLE | 스쿼드 점수 대결 결과 |
| APP_USER | 시스템 유저 |
| SEASON | 시즌 관리 (시작일·종료일·우승팀) |
| AUDIT_LOG | 변경 이력 자동 기록 |

### 뷰 (9개)

| 뷰 | 역할 |
|---|---|
| V_CLUB_BUDGET | 구단별 예산 현황 |
| V_PLAYER_INFO | 선수 소속 + 능력치 통합 조회 |
| V_SQUAD_SCORE | 구단별 스쿼드 점수 |
| V_EXPIRING_CONTRACTS | 계약 만료 임박 선수 (6개월 이내) |
| V_TRANSFER_MARKET | 이적시장 매물 목록 |
| V_SEASON_STANDING | 현재 시즌 순위표 (승점 집계) |
| V_SEASON_TOP_TRANSFERS | 시즌별 최다 이적료 (RANK 윈도우 함수) |
| V_CHAMPION_HISTORY | 역대 우승 기록 |
| V_AUDIT_RECENT | 감사 로그 조회 (행위자 JOIN) |

### 트리거 (10개)

| 트리거 | 역할 |
|---|---|
| trg_check_budget | 예산 초과 영입 차단 |
| trg_check_same_club | 자기 팀 이적 차단 |
| trg_check_duplicate_listing | 매물 중복 등록 차단 |
| trg_check_seller_club | 판매 구단-선수 소속 불일치 차단 |
| trg_audit_player_update | PLAYER 소속 변동 자동 기록 |
| trg_audit_club_update | CLUB 예산 변동 자동 기록 |
| trg_audit_contract_insert | CONTRACT 신규 생성 자동 기록 |
| trg_audit_contract_update | CONTRACT 상태 변경 자동 기록 |
| trg_audit_market_insert | TRANSFER_MARKET 등록 자동 기록 |
| trg_audit_market_update | TRANSFER_MARKET 상태 변경 자동 기록 |

### 프로시저 (6개)

| 프로시저 | 역할 |
|---|---|
| sp_buy_player(user_id, listing_id) | 선수 영입 (트랜잭션 12단계) |
| sp_release_player(user_id, player_id) | 선수 방출 (최소 11명 DB 검증) |
| sp_list_player_for_transfer(user_id, player_id, fee) | 이적시장 등록 |
| sp_cancel_listing(user_id, listing_id) | 이적시장 등록 취소 |
| sp_create_squad_battle(home_id, away_id) | 스쿼드 대결 |
| sp_start_new_season(season_name) | 시즌 종료 + 새 시즌 시작 |

### 스쿼드 대결 점수 계산

```
배틀 점수 = (GK 평균 × 15% + DF 평균 × 30% + MF 평균 × 30% + FW 평균 × 25%)
            × 랜덤 계수(0.95 ~ 1.05)
            + 홈 어드밴티지 +2 (홈팀만)
```

---

## 📱 Streamlit 화면 구성 (6페이지)

| 페이지 | 주요 기능 |
|---|---|
| 📊 대시보드 | 스쿼드 점수 순위 / 예산 현황 / 만료 임박 계약 |
| 👥 내 스쿼드 | 선수 목록 / 전술 배치도 / 이적등록·방출·등록취소 |
| 🛒 이적시장 | 매물 조회 / 영입 실행 / 예산 전후 비교 / 이적 기록 |
| ⚔️ 스쿼드 대결 | 상대 선택 / 대결 실행 / 결과 카드 / W·D·L 전적 시각화 |
| 🗓️ 시즌 | 순위표 / 최다 이적료 TOP5 / 우승 기록 / 시즌 종료 |
| 📜 감사 로그 | 테이블·작업 필터 / INSERT·UPDATE·DELETE 배지 테이블 |

---

## ⚠️ 구단별 스쿼드 현황

| 구단 | 선수 수 | 비고 |
|---|---|---|
| FC Seoul, Ulsan HD FC, Jeonbuk Hyundai Motors | 16명 | 기존 11명 + DBPBL 5명 보충 |
| Gangwon FC, Pohang Steelers, Incheon United | 16명 | 기존 11명 + DBPBL 5명 보충 |
| Jeju SK, Daejeon Hana Citizen, Gwangju FC | 16명 | 기존 11명 + DBPBL 5명 보충 |
| **FC Anyang** | **11명** | DBPBL 미매핑 구단 — 방출 불가 |
| **Bucheon FC 1995** | **11명** | DBPBL 미매핑 구단 — 방출 불가 |
| **Gimcheon Sangmu** | **11명** | DBPBL 미매핑 구단 — 방출 불가 |

> FC Anyang, Bucheon FC 1995, Gimcheon Sangmu는 2026 K리그 승격팀으로
> DBPBL(FIFA 구형 데이터)에 대응 구단이 없어 11명을 유지합니다.
> 해당 구단은 영입 없이는 방출이 불가합니다.

---

## ⚠️ 주의사항

- `kleague_ddl.sql` 재실행 시 기존 DB가 초기화됩니다 (`DROP DATABASE IF EXISTS`)
- `kleague_procedures.sql` 재실행은 언제든 안전합니다 (DROP 후 재생성)
- `kleague_extensions.sql` 재실행도 안전합니다 (멱등 처리 적용)
- 프로시저 테스트는 DML 실행 직후 한 번만 실행하세요
  - `sp_buy_player(1, 9)` 재실행 시 "이미 sold된 매물" 에러가 나는 것은 정상
- `data/` 폴더의 CSV는 원본 데이터 출처·참고용입니다 (현재 브랜치 스키마와 컬럼명 다름)

---

## 💬 발표 핵심 문장

> "MySQL에서 DDL·DML·Extensions·프로시저 파일을 순서대로 실행해 DB를 구축했습니다.
> Streamlit 프론트엔드는 구축된 DB에 연결하여 VIEW를 조회하고,
> 영입·방출·대결은 MySQL 저장 프로시저를 호출하는 방식으로 동작합니다.
> 복잡한 데이터 처리 로직(트랜잭션·무결성 검증·감사 기록)은 전부 MySQL 내부에 있고,
> 프론트엔드는 그 결과를 보여주는 화면 역할만 합니다."
