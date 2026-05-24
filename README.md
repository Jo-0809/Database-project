# K League Transfer Simulator DB

K League 구단을 선택해 선수 영입, 방출, 포메이션 배치, 구단 예산, 스쿼드 배틀 결과를 관리하는 MySQL 기반 이적시장 시뮬레이터이다.

프론트엔드는 Streamlit으로 구성되어 있으며, 데이터 저장과 이적 기록 관리는 MySQL에서 처리한다.

## 프로젝트 구성

```text
Database-project/
├─ kleague_app.py             # Streamlit UI
├─ kleague_full_setup.sql     # DB 전체 생성 및 초기 데이터 입력
├─ kleague_ddl.sql            # 테이블, 뷰, 트리거 생성
├─ kleague_dml.sql            # 기본 데이터 입력
├─ kleague_dml_kor.sql        # 한글 데이터 입력용 SQL
├─ kleague_procedures.sql     # 영입, 방출, 배틀 프로시저
├─ requirements.txt           # Python 패키지 목록
├─ data/                      # CSV 원본/정제 데이터
├─ docs/                      # ERD, 발표 스크립트, 검증 쿼리
└─ .streamlit/config.toml     # Streamlit 다크 테마 설정
```

## 실행 방법

MySQL에서 데이터베이스를 먼저 생성한다.

```bash
mysql -u root -p < kleague_full_setup.sql
```

Python 패키지를 설치한 뒤 Streamlit을 실행한다.

```bash
pip install -r requirements.txt
streamlit run kleague_app.py
```

`kleague_app.py`의 기본 DB 접속 정보는 `root / 1234` 기준이다. 로컬 MySQL 비밀번호가 다르면 `DB_CONFIG`의 `password` 값을 수정해야 한다.

## 핵심 데이터

- 구단 수는 12개이다.
- 선수 수는 132명이다.
- 각 구단은 11명 기준으로 시작한다.
- 선수 능력치는 `pace`, `shooting`, `passing`, `defending`, `physical`을 사용한다.
- `overall`은 위 5개 능력치의 평균값이다.
- 이적시장 매물은 `transfer_market` 테이블에서 관리한다.
- 영입, 방출, 배틀 결과는 각각 `transfer_history`, `squad_battles`에 저장된다.

## 기존 UI에서 바뀐 점

기존 UI는 기본 Streamlit 화면에 가까웠고, 선수 목록, 이적시장, 스쿼드 배틀, 기록을 표 중심으로 보여주는 구조였다.

현재 UI는 다음과 같이 수정되었다.

- 전체 화면을 다크 그린/골드 톤으로 정리하였다.
- Streamlit 기본 `Deploy` 메뉴와 개발용 메뉴를 숨겼다.
- Light mode로 전환되어도 화면이 깨지지 않도록 다크 테마를 고정하였다.
- 상단에 현재 메뉴, 선택 구단, 예산, 운영 규칙을 보여주는 헤더 카드를 추가하였다.
- 대시보드에 등록 구단 수, 등록 선수 수, 이적시장 매물 수, 배틀 수 요약 카드를 추가하였다.
- 내 스쿼드 화면에 포메이션 선택 기능을 추가하였다.
- 포메이션별로 `GK`, `CB`, `CM`, `ST` 같은 11개 배치 슬롯을 표시하였다.
- 각 슬롯마다 원하는 선수를 직접 선택할 수 있게 수정하였다.
- 같은 선수가 여러 포지션에 중복 배치되지 않게 막았다.
- 추천 배치, 배치 비우기, 포메이션 저장 버튼을 추가하였다.
- 경기장 배치도에서 선수 카드가 겹치지 않도록 위치와 카드 크기를 조정하였다.
- 이적시장에서 선수 검색, 포지션 필터, 최소 오버롤, 최대 이적료 필터를 추가하였다.
- 영입할 선수와 방출할 선수를 나란히 비교하는 카드를 추가하였다.
- 영입 전후 능력치 변화와 예상 팀점수 변화를 보여주도록 수정하였다.
- 선수를 영입할 때 내 선수 1명을 반드시 방출하도록 변경하였다.
- 영입과 방출은 하나의 트랜잭션으로 처리되도록 수정하였다.
- 방출 선수가 현재 배치도에 들어가 있으면 경고가 뜨도록 하였다.
- 스쿼드 배틀 화면에 상대 분석과 추천 코멘트를 추가하였다.
- 배틀 결과 화면을 승패가 더 잘 보이도록 수정하였다.
- 기록 페이지에 이적 기록, 배틀 전적, 구단 지출, 방출 수 요약 카드를 추가하였다.
- 시뮬레이션 초기화 오류를 수정하였다.

## 포메이션과 선수 배치 점수 계산

선수는 원래 포지션과 다른 위치에 배치될 수 있다. 이때 단순 오버롤만 쓰지 않고, 배치된 포지션에 맞는 능력치 가중치를 다시 적용한다.

슬롯 점수 계산식은 다음과 같다.

```text
슬롯 점수 = 능력치 가중합 + 세부 포지션 보너스 - 포지션 그룹 패널티
```

최종 슬롯 점수는 1점에서 99점 사이로 제한한다.

### 포지션별 능력치 가중치

| 배치 그룹 | pace | shooting | passing | defending | physical |
|---|---:|---:|---:|---:|---:|
| GK | 0.08 | 0.02 | 0.20 | 0.45 | 0.25 |
| DF | 0.15 | 0.03 | 0.12 | 0.45 | 0.25 |
| MF | 0.15 | 0.05 | 0.40 | 0.20 | 0.20 |
| FW | 0.25 | 0.38 | 0.12 | 0.05 | 0.20 |

예를 들어 공격수를 수비수 위치에 배치하면 `DF` 가중치를 사용한다. 이 경우 슈팅 비중은 낮아지고 수비와 피지컬 비중이 커진다. 여기에 포지션 그룹이 맞지 않는 패널티가 추가로 적용된다.

### 세부 포지션 보너스

세부 포지션이 슬롯과 잘 맞으면 `+4`점을 더한다.

예시는 다음과 같다.

- `Goalkeeper`가 `GK`에 배치되면 보너스를 받는다.
- `Centre-Back`이 `CB`, `LCB`, `RCB`에 배치되면 보너스를 받는다.
- `Left-Back`이 `LB`, `LWB`에 배치되면 보너스를 받는다.
- `Right-Back`이 `RB`, `RWB`에 배치되면 보너스를 받는다.
- `Central Midfield`가 `CM`, `LCM`, `RCM`에 배치되면 보너스를 받는다.
- `Defensive Midfield`가 `LDM`, `RDM`에 배치되면 보너스를 받는다.
- `Attacking Midfield`가 `CAM`, `LAM`, `RAM`에 배치되면 보너스를 받는다.
- `Left Winger`가 `LW`, `LM`에 배치되면 보너스를 받는다.
- `Right Winger`가 `RW`, `RM`에 배치되면 보너스를 받는다.
- `Centre-Forward`, `Second Striker`가 `ST`, `LS`, `RS`에 배치되면 보너스를 받는다.

### 포지션 그룹 패널티

포지션 그룹이 맞지 않으면 패널티가 적용된다.

| 상황 | 패널티 |
|---|---:|
| 같은 그룹 배치 | 0 |
| GK가 아닌 선수가 GK에 배치되거나 GK가 필드에 배치됨 | -32 |
| DF와 MF 사이의 변경 | -8 |
| MF와 FW 사이의 변경 | -9 |
| 그 외 그룹 변경 | -18 |

예를 들어 스트라이커를 센터백에 배치하면 `FW → DF` 이동이므로 `-18` 패널티가 적용된다. 반대로 수비수를 미드필더에 배치하면 `DF ↔ MF` 이동이므로 `-8` 패널티가 적용된다.

## 팀점수 계산

포메이션에 배치된 11명 기준으로 팀점수를 계산한다.

```text
팀점수 =
선수 배치 평균 × 0.70
+ 포메이션 적합도 × 0.15
+ 감독 능력치 × 0.10
+ 11명 완성도 × 0.05
```

각 항목의 의미는 다음과 같다.

- 선수 배치 평균: 11개 슬롯에 들어간 선수들의 슬롯 점수 평균이다.
- 포메이션 적합도: 슬롯 그룹과 선수 포지션 그룹이 일치한 비율이다.
- 감독 능력치: `managers.rating` 값이다.
- 11명 완성도: 11개 슬롯 중 실제 선수가 배치된 비율이다.

포메이션 적합도와 완성도 계산식은 다음과 같다.

```text
포메이션 적합도 = 포지션 그룹이 맞는 선수 수 / 11 × 100
11명 완성도 = 배치된 선수 수 / 11 × 100
```

따라서 같은 선수단이라도 포메이션과 배치 위치가 바뀌면 팀점수가 달라진다.

## 이적시장 동작 방식

선수 영입은 단순히 선수를 추가하는 방식이 아니다. 각 구단이 11명 기준으로 시작하기 때문에, 선수를 영입하면 내 선수 1명을 반드시 방출해야 한다.

영입 과정은 다음 순서로 진행된다.

1. 영입할 매물을 선택한다.
2. 방출할 내 선수를 선택한다.
3. 영입 선수와 방출 선수를 비교한다.
4. 영입 후 예상 팀점수와 예산 변화를 확인한다.
5. `영입하고 1명 방출하기` 버튼을 누른다.
6. 영입, 계약 변경, 예산 변경, 방출, 이적 기록 저장이 한 번에 처리된다.

중간에 예산 부족, 이미 판매된 매물, 내 선수가 아닌 방출 대상 같은 문제가 생기면 전체 작업을 취소한다.

## 스쿼드 배틀 동작 방식

스쿼드 배틀은 두 구단의 팀점수를 비교해 결과를 저장한다.

내 팀은 현재 저장된 포메이션과 배치를 기준으로 계산한다. 상대 팀은 해당 구단의 선호 포메이션에 맞춰 추천 배치를 만든 뒤 계산한다.

배틀 화면에서는 다음 정보를 보여준다.

- 내 팀점수
- 상대 팀점수
- 배치 평균 차이
- 포메이션 적합도 차이
- 감독 능력치 차이
- 추천 코멘트
- 승패 결과
- 결과 해석

## 시뮬레이션 초기화

초기화 버튼은 다음 데이터를 원래 상태로 돌린다.

- 선수 소속
- 구단 예산
- 이적시장 매물 상태
- 계약 상태
- 이적 기록
- 배틀 기록
- 화면에 저장된 포메이션 배치 상태

초기 선수 소속은 `transfer_market.seller_club_id`를 기준으로 복구한다.

## 검증 쿼리

```sql
USE kleague_db;

SELECT COUNT(*) AS clubs FROM clubs;
SELECT COUNT(*) AS players FROM players;
SELECT COUNT(*) AS player_stats FROM player_stats;
SELECT COUNT(*) AS contracts FROM contracts;
SELECT COUNT(*) AS transfer_market FROM transfer_market;

SELECT club_id, COUNT(*) AS player_count
FROM players
WHERE club_id IS NOT NULL
GROUP BY club_id
ORDER BY club_id;

SELECT * FROM v_squad_score ORDER BY squad_score DESC;
SELECT * FROM v_transfer_market ORDER BY overall DESC LIMIT 20;
SELECT * FROM transfer_history ORDER BY transfer_id DESC;
SELECT * FROM squad_battles ORDER BY battle_id DESC;
```

기본 초기 상태의 예상 값은 다음과 같다.

- `clubs`: 12
- `players`: 132
- `player_stats`: 132
- `contracts`: 132
- `transfer_market`: 132
- 각 구단 선수 수: 11명
