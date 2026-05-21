# K리그 이적시장 기반 스토브리그 체험 DB 시스템

> MySQL이 핵심 엔진, Streamlit은 그 엔진을 조작하는 화면

---

## 📁 파일 구성

```
kleague_project/
├─ kleague_ddl.sql          ← DB 구조 생성 (테이블, 뷰, 트리거, 함수)
├─ kleague_dml.sql          ← 샘플 데이터 입력
├─ kleague_procedures.sql   ← 영입/방출/대결 프로시저
├─ kleague_app.py           ← Streamlit 프론트엔드
└─ kleague_presentation.md  ← 발표 자료
```

> ⚠️ 경로에 한글이나 공백이 있으면 오류가 날 수 있어요.
> `C:/db_project/kleague/` 같은 경로 추천

---

## 🚀 실행 순서

### Step 1. MySQL DB 구축

**방법 A — MySQL Workbench**

1. MySQL Workbench 실행 → 로컬 접속
2. `kleague_ddl.sql` 열고 전체 실행
3. `kleague_dml.sql` 열고 전체 실행
4. `kleague_procedures.sql` 열고 전체 실행

**방법 B — 터미널**

```bash
mysql -u root -p < kleague_ddl.sql
mysql -u root -p kleague_db < kleague_dml.sql
mysql -u root -p kleague_db < kleague_procedures.sql
```

**방법 C — MySQL 내부에서 SOURCE**

```sql
SOURCE C:/db_project/kleague/kleague_ddl.sql;
SOURCE C:/db_project/kleague/kleague_dml.sql;
SOURCE C:/db_project/kleague/kleague_procedures.sql;
```

---

### Step 2. DB 구축 확인

```sql
USE kleague_db;

-- 테이블/뷰/트리거/프로시저/함수 확인
SHOW TABLES;
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW TRIGGERS;
SHOW PROCEDURE STATUS WHERE Db = 'kleague_db';
SHOW FUNCTION STATUS WHERE Db = 'kleague_db';

-- 데이터 확인
SELECT * FROM CLUB;
SELECT * FROM V_PLAYER_INFO;
SELECT * FROM V_TRANSFER_MARKET;
SELECT * FROM V_SQUAD_SCORE;

-- 프로시저 테스트
CALL sp_buy_player(1, 9);        -- 울산이 양현준 영입
CALL sp_release_player(1, 4);    -- 울산이 레오나르도 방출
CALL sp_create_squad_battle(1, 2); -- 울산 vs 전북 대결
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
pip install streamlit pymysql pandas
streamlit run kleague_app.py
```

---

## 🗄️ DB 구성 요약

### 테이블 (9개)

| 테이블 | 역할 |
|---|---|
| CLUB | 12개 K리그1 구단 + 예산 |
| MANAGER | 구단 감독 (구단당 1명) |
| PLAYER | 선수 기본 정보 + 현재 소속 |
| PLAYER_STATS | 선수 능력치 (overall 자동 계산) |
| CONTRACT | 선수-구단 계약 이력 |
| TRANSFER_HISTORY | 이적·방출 기록 |
| SQUAD_BATTLE | 스쿼드 점수 대결 결과 |
| APP_USER | 시스템 유저 |
| TRANSFER_MARKET | 이적시장 매물 |

### 뷰 (5개)

| 뷰 | 역할 |
|---|---|
| V_CLUB_BUDGET | 구단별 예산 현황 |
| V_PLAYER_INFO | 선수 소속 + 능력치 통합 조회 |
| V_SQUAD_SCORE | 구단별 스쿼드 점수 |
| V_EXPIRING_CONTRACTS | 계약 만료 임박 선수 |
| V_TRANSFER_MARKET | 이적시장 매물 목록 |

### 트리거 (4개)

| 트리거 | 역할 |
|---|---|
| trg_check_budget | 예산 초과 영입 차단 |
| trg_check_same_club | 자기 팀 이적 차단 |
| trg_check_duplicate_listing | 매물 중복 등록 차단 |
| trg_check_seller_club | 판매 구단-선수 소속 불일치 차단 |

### 프로시저 (3개)

| 프로시저 | 역할 |
|---|---|
| sp_buy_player(user_id, listing_id) | 선수 영입 (12단계 트랜잭션) |
| sp_release_player(user_id, player_id) | 선수 방출 |
| sp_create_squad_battle(home_id, away_id) | 스쿼드 대결 |

---

## 📱 Streamlit 화면 구성

| 페이지 | 주요 기능 |
|---|---|
| 📊 대시보드 | 스쿼드 점수 순위 / 예산 현황 / 만료 임박 계약 |
| 👥 내 스쿼드 | 선수 목록 조회 / 방출 실행 |
| 🛒 이적시장 | 매물 조회 / 영입 실행 / 전후 비교 요약 / 이적 기록 |
| ⚔️ 스쿼드 대결 | 상대 선택 / 대결 실행 / 결과 표시 / 대결 기록 |

---

## 💬 발표 핵심 문장

> "MySQL에서 DDL, DML, 저장 프로시저 파일을 순서대로 실행해 DB를 구축했습니다.
> Streamlit 프론트엔드는 구축된 DB에 연결하여 VIEW를 조회하고,
> 선수 영입·방출·스쿼드 대결은 MySQL 저장 프로시저를 호출하는 방식으로 동작합니다.
> 복잡한 데이터 처리 로직은 전부 MySQL 내부에 있고,
> 프론트엔드는 그 결과를 보여주는 화면 역할만 합니다."

---

## ⚠️ 주의사항

- `kleague_ddl.sql` 재실행 시 기존 DB가 초기화됩니다 (`DROP DATABASE IF EXISTS`)
- `kleague_procedures.sql` 재실행 시 기존 프로시저가 삭제 후 재생성됩니다
- 프로시저 테스트는 DML 실행 직후 한 번만 실행하세요
  - `sp_buy_player(1, 9)` 재실행 시 "이미 sold된 매물" 에러가 나는 것은 정상입니다
- 재실행 시에는 DDL → DML → 프로시저 순서를 반드시 지키세요

