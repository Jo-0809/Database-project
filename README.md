# K League Transfer Simulator DB

K League 구단 감독/운영자가 예산, 포메이션, 선수단 밸런스, 이적시장, 시즌 결과를 확인할 수 있는 MySQL 중심 스쿼드 운영 시뮬레이터입니다. Streamlit UI는 의사결정 화면을 담당하고, 영입/매물/시즌/감사 로그 같은 핵심 변경은 DB 테이블, 뷰, 트리거, 저장 프로시저가 처리합니다.

## 핵심 기능

- K League 공식 공개 페이지 기준 K League 1/2 29개 구단, active 선수 1,092명 반영
- 선수단/기록/영문명은 K League 공식 데이터 사용
- 선수 몸값은 Transfermarkt K League 1/2 market value 공개 데이터만 사용
- Transfermarkt 200개 value 행 중 공식 영문명+구단 또는 유일한 구단/나이/국적/포지션 매칭으로 확인된 171명만 기본 이적시장 매물로 생성
- 매칭되지 않은 선수는 임의 몸값을 만들지 않고 `market_value_eur = 0`, `NO_CONFIDENT_TRANSFERMARKT_MATCH`로 남김
- 요구 이적료는 Transfermarkt market value와 동일하게 저장하고, UI에서는 `1 EUR = 1,761.3 KRW`로 원화 환산 표시
- 구단별 예산, 스쿼드 점수, 포지션 뎁스, 약점 분석, 데이터 기반 영입 추천
- 포메이션별 11명 배치와 후보 상위 7명만 낮은 비중으로 반영하는 전력 계산
- 영입 시 판매 구단이 최소 11명을 유지해야 하며, 배틀도 양 팀 모두 최소 11명 이상일 때만 가능
- 영입, 계약 변경, 예산 변경, 매물 상태 변경은 트랜잭션과 감사 로그로 추적

## 프로젝트 구성

```text
Database-project/
├─ kleague_app.py                 # Streamlit UI
├─ kleague_full_setup.sql         # DB 전체 생성 및 초기 데이터 입력
├─ kleague_ddl.sql                # 테이블, 뷰, 트리거
├─ kleague_dml.sql                # 초기 데이터
├─ kleague_dml_kor.sql            # 동일 초기 데이터 별칭
├─ kleague_procedures.sql         # 영입/배틀/시즌 저장 프로시저
├─ requirements.txt
├─ scripts/
│  └─ rebuild_kleague_dataset.py  # K League + Transfermarkt 데이터 재수집 및 SQL 재생성
├─ data/
│  ├─ cleaned_players.csv
│  ├─ transfermarkt_values.csv
│  └─ ...
└─ docs/
   ├─ ERD.mmd
   ├─ presentation_script.md
   └─ verification_queries.sql
```

## 실행 방법

MySQL에서 데이터베이스를 먼저 생성합니다.

```bash
mysql -u root -p < kleague_full_setup.sql
```

Python 패키지를 설치하고 Streamlit을 실행합니다.

```bash
pip install -r requirements.txt
set MYSQL_PASSWORD=본인비밀번호
streamlit run kleague_app.py
```

`kleague_app.py`는 기본값으로 `root / 빈 비밀번호 / kleague_db`를 사용합니다. 환경변수 `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE`로 변경할 수 있습니다.

## 데이터 기준

| 구분 | 내용 |
|---|---|
| K League 공식 | active 선수 명단, 선수 상세, 영문명, 구단, 포지션, 배번, 키/몸무게, 2026 공개 기록 |
| Transfermarkt | K League 1/2 market value, 선수 영문명, 구단, 나이, 국적, 포지션 |
| 매칭 방식 | 1순위 공식 영문명+구단, 2순위 유일한 구단/나이/국적/포지션 |
| 기본 매물 | Transfermarkt value가 확실히 매칭된 171명만 생성 |
| 미매칭 선수 | 임의 산정 금지. 몸값 0으로 유지하고 기본 이적시장에는 노출하지 않음 |

## 전력 계산 원칙

후보 선수가 많은 팀이 무조건 유리해지는 문제를 줄이기 위해 전체 평균을 그대로 쓰지 않습니다.

```text
스쿼드 점수 =
주전 상위 11명 평균 82%
+ 감독 능력치 14%
+ 후보 상위 7명 평균 2%
```

포메이션 배틀은 선택된 11명과 실제 슬롯을 기준으로 계산하고, 양 팀 모두 등록 선수가 11명 이상일 때만 저장됩니다.

## 추천 점수 계산

`v_transfer_recommendations`는 다음 요소를 조합해 구단별 영입 후보를 정렬합니다.

```text
추천 점수 =
선수 오버롤
+ 포지션 약점 보정
+ 예산 적합도
+ Transfermarkt 몸값 대비 이적료 효율
+ 어린 선수 성장 보너스
- 고령 선수 감점
```

요구 이적료는 기본 매물 기준으로 Transfermarkt market value와 동일하므로, 추천의 핵심은 포지션 약점과 예산 적합도입니다.

## 검증 쿼리

```sql
USE kleague_db;

SELECT COUNT(*) AS clubs FROM clubs;
SELECT COUNT(*) AS players FROM players;
SELECT COUNT(*) AS market_listings FROM transfer_market WHERE status = 'available';

SELECT p.player_name, c.club_name, p.market_value_eur, p.value_source_url
FROM players p
JOIN clubs c ON c.club_id = p.club_id
WHERE p.market_value_eur > 0
ORDER BY p.market_value_eur DESC
LIMIT 20;

SELECT tm.asking_fee_eur, p.market_value_eur
FROM transfer_market tm
JOIN players p ON p.player_id = tm.player_id
WHERE tm.asking_fee_eur <> p.market_value_eur;
```

마지막 쿼리가 빈 결과이면 기본 매물 요구 이적료가 Transfermarkt value와 동일하게 들어간 상태입니다.
