# K리그 이적시장 기반 스토브리그 체험 DB 시스템
## 발표 자료

---

## 1. 프로젝트 개요

### 주제
> K리그1 12개 구단 중 하나를 선택하여 구단의 재정 상황을 고려해 선수를 영입·방출하고, 스쿼드를 꾸려 다른 구단과 점수 기반 대결을 펼치는 DB 기반 스토브리그 체험 시스템

### DB 프로젝트 적합성
포켓몬, 당근마켓 등 타 조와 비교했을 때 이 주제가 DB 프로젝트로 적합한 이유는 다음과 같습니다.

- **복잡한 관계 모델링**: 선수-구단-계약의 M:N 관계를 CONTRACT 테이블로 해소하고, 이적 이력을 TRANSFER_HISTORY로 분리하여 정규화 적용
- **트랜잭션 중심 설계**: 선수 영입 시 계약 변경·소속 변경·예산 갱신·이적 기록·매물 상태 변경이 하나의 트랜잭션으로 처리되어 데이터 일관성 보장
- **다양한 DB 기능 활용**: CHECK, UNIQUE, TRIGGER, VIEW, FUNCTION, PROCEDURE를 모두 실제 비즈니스 로직에 적용
- **실제 데이터 기반**: K리그1 실제 구단과 선수 데이터를 활용하여 현실성 확보

---

## 2. 시스템 구조

### 테이블 구성 (9개)

| 테이블 | 역할 | 핵심 제약 |
|---|---|---|
| CLUB | 12개 K리그1 구단 정보 + 예산 | CHECK (budget >= 0) |
| MANAGER | 구단 감독 정보 | club_id UNIQUE (구단당 1명) |
| PLAYER | 선수 기본 정보 + 현재 소속 | position IN ('GK','DF','MF','FW') |
| PLAYER_STATS | 선수 능력치 | player_id UNIQUE, overall 자동계산 |
| CONTRACT | 선수-구단 계약 이력 | status IN ('active','expired') |
| TRANSFER_HISTORY | 이적·방출 기록 | transfer_type 5종 |
| SQUAD_BATTLE | 스쿼드 점수 대결 기록 | result IN ('home','away','draw') |
| APP_USER | 시스템 사용 유저 | - |
| TRANSFER_MARKET | 이적시장 매물 | status IN ('available','sold','cancelled') |

### 뷰 구성 (5개)

| 뷰 | 역할 |
|---|---|
| V_CLUB_BUDGET | 구단별 초기/현재 예산 및 총 지출 |
| V_PLAYER_INFO | 선수 소속 + 능력치 통합 조회 |
| V_SQUAD_SCORE | 구단별 스쿼드 점수 (overall 80% + 감독 rating 20%) |
| V_EXPIRING_CONTRACTS | 계약 만료 임박 선수 (6개월 이내) |
| V_TRANSFER_MARKET | 이적시장 매물 목록 (overall 높은 순) |

### 트리거 구성 (4개)

| 트리거 | 역할 |
|---|---|
| trg_check_budget | 예산 초과 영입 차단 |
| trg_check_same_club | 자기 팀 이적 차단 |
| trg_check_duplicate_listing | 동일 선수 매물 중복 등록 차단 |
| trg_check_seller_club | 선수 소속 구단과 판매 구단 불일치 차단 |

---

## 3. ERD 관계 설명

```
CLUB (1) ─────── (N) MANAGER        구단당 현재 감독 1명 (UNIQUE)
CLUB (1) ─────── (N) PLAYER         구단에 여러 선수 소속
CLUB (1) ─────── (N) CONTRACT       구단이 여러 계약 보유
CLUB (1) ─────── (N) TRANSFER_HISTORY  구단이 여러 이적에 관여 (영입/방출)
CLUB (1) ─────── (N) SQUAD_BATTLE   구단이 여러 대결 (홈/원정)
CLUB (1) ─────── (N) TRANSFER_MARKET  구단이 여러 매물 등록
PLAYER (1) ───── (1) PLAYER_STATS   선수당 능력치 1개 (UNIQUE)
PLAYER (1) ───── (N) CONTRACT       선수의 구단별 계약 이력 누적
PLAYER (1) ───── (N) TRANSFER_HISTORY  선수의 이적 이력 누적
APP_USER (N) ─── (1) CLUB           유저가 구단 1개 선택
```

### 정규화 설명
- **PLAYER와 PLAYER_STATS 분리**: 선수 기본 정보와 능력치를 분리하여 단일 책임 원칙 적용. overall은 Generated Column으로 자동 계산되어 데이터 중복 방지
- **CONTRACT 테이블**: PLAYER와 CLUB 사이의 M:N 관계를 해소하는 동시에 계약 이력을 관리하는 테이블. 이적 시 기존 계약 expired → 새 계약 active로 상태 관리
- **TRANSFER_HISTORY 분리**: 이적 기록을 별도 테이블로 분리하여 이력 추적 가능

---

## 4. 핵심 기능 설명

### 선수 영입 트랜잭션 (sp_buy_player)
선수 영입은 단순 INSERT가 아니라 아래 12단계가 하나의 트랜잭션으로 처리됩니다.
하나라도 실패하면 전체가 ROLLBACK되어 데이터 일관성이 보장됩니다.

```
1.  유저 구단 확인
2.  매물 정보 조회
3.  매물 available 상태 확인
4.  자기 구단 선수 영입 방지
5.  예산 충분 여부 확인
6.  기존 CONTRACT → expired
7.  새 CONTRACT → active 생성
8.  PLAYER.club_id 변경
9.  TRANSFER_HISTORY 기록 (예산 차감 전 먼저 → 트리거 충돌 방지)
10. 구매 구단 current_budget 감소
11. 판매 구단 current_budget 증가
12. TRANSFER_MARKET status → sold
```

### 스쿼드 점수 계산 공식
```
squad_score = 선수 overall 평균 × 0.8 + 감독 rating × 0.2
overall     = (attack + defense + stamina + speed) / 4  (자동 계산)
```

---

## 5. 예상 질문 & 답변

### Q1. 이적이 발생하면 어떤 DB 작업이 일어나나요?
> 이적이 발생하면 기존 CONTRACT를 expired로 변경하고 새 CONTRACT를 active로 생성합니다. PLAYER의 현재 club_id를 새 구단으로 변경하고, 이적료에 따라 구매 구단의 current_budget을 차감하고 판매 구단의 current_budget을 증가시킵니다. 또한 TRANSFER_HISTORY에 이적 기록을 저장하고 TRANSFER_MARKET의 매물 상태를 sold로 변경합니다. 이 모든 과정은 하나의 트랜잭션으로 묶여 있어 중간에 실패하면 전체가 ROLLBACK됩니다.

### Q2. PLAYER.club_id와 CONTRACT.club_id가 중복 아닌가요?
> PLAYER.club_id는 현재 소속팀을 빠르게 조회하기 위한 컬럼이고, CONTRACT는 과거부터 현재까지의 계약 이력 전체를 저장하는 테이블입니다. 이적 시 트랜잭션으로 두 값을 동시에 업데이트하여 데이터 일관성을 유지합니다.

### Q3. 스쿼드 대결 점수는 어떻게 계산하나요?
> 각 구단 소속 선수들의 overall 평균과 감독 rating을 활용합니다. squad_score = 선수 overall 평균 × 0.8 + 감독 rating × 0.2로 계산하며, 두 구단의 점수를 비교해 home/away/draw 결과를 SQUAD_BATTLE에 저장합니다. overall은 attack·defense·stamina·speed 4개 능력치의 평균으로 자동 계산되는 Generated Column입니다.

### Q4. PLAYER_STATS를 PLAYER와 분리한 이유는?
> 선수의 기본 정보(이름, 국적, 포지션 등)와 능력치 정보(공격, 수비, 체력, 스피드)는 성격이 다른 데이터입니다. 분리함으로써 단일 책임 원칙을 적용하고, 능력치 업데이트 시 선수 기본 정보 테이블에 영향을 주지 않도록 정규화했습니다. 또한 overall은 4개 능력치의 평균을 자동 계산하는 Generated Column으로 관리하여 데이터 중복을 방지합니다.

### Q5. 트리거는 어떤 역할을 하나요?
> 4개의 트리거를 구현했습니다. 예산 초과 영입 차단(trg_check_budget), 자기 팀 이적 차단(trg_check_same_club), 동일 선수 매물 중복 등록 차단(trg_check_duplicate_listing), 판매 구단과 선수 소속 불일치 차단(trg_check_seller_club)입니다. 특히 판매 구단 검증 트리거는 소속이 NULL인 방출 선수가 이적시장에 등록되는 것도 차단합니다.

### Q6. CONTRACT의 active 계약이 중복으로 생길 수 있지 않나요?
> 이론적으로는 가능하지만, 영입 트랜잭션(sp_buy_player) 내에서 새 계약을 active로 생성하기 전에 반드시 기존 active 계약을 먼저 expired로 변경합니다. 이 두 작업이 하나의 트랜잭션으로 묶여 있어 중간 상태가 존재하지 않습니다.

### Q7. UI는 구현하나요?
> UI 개발은 핵심 범위에 포함하지 않고, DB 설계와 SQL 기능 구현에 집중했습니다. 발표에서는 MySQL Workbench에서 프로시저를 직접 호출하여 영입 전후 예산 변화, 선수 소속 변경, 계약 상태 변경, 이적 기록 생성, 매물 상태 변경을 시연합니다.

---

## 6. 발표 시연 순서 (권장)

```
[1] V_SQUAD_SCORE      → 초기 스쿼드 점수 순위 확인
[2] V_CLUB_BUDGET      → 초기 예산 현황 확인
[3] V_TRANSFER_MARKET  → 이적시장 매물 목록 확인
[4] V_EXPIRING_CONTRACTS → 계약 만료 임박 선수 확인

[5] CALL sp_buy_player(1, 9)
    → 울산이 양현준(강원) 영입

[6] 영입 후 변화 확인
    - 울산/강원 예산 변화
    - 양현준 club_id 변경 확인
    - CONTRACT 상태 expired → active
    - TRANSFER_HISTORY 기록 확인
    - TRANSFER_MARKET status → sold

[7] CALL sp_release_player(1, 4)
    → 울산이 레오나르도 방출
    - 레오나르도 club_id → NULL
    - TRANSFER_HISTORY release 기록

[8] CALL sp_create_squad_battle(1, 2)
    → 울산 vs 전북 스쿼드 점수 비교

[9] V_SQUAD_SCORE → 영입 후 최종 점수 순위 확인
```

---

## 7. 강조 포인트 (발표 시 꼭 언급)

1. **트랜잭션**: "선수 영입은 12단계가 하나의 트랜잭션으로 처리됩니다. 중간에 실패하면 전체 ROLLBACK됩니다."
2. **정규화**: "PLAYER와 PLAYER_STATS를 분리하고, CONTRACT로 M:N 관계를 해소했습니다."
3. **무결성**: "4개의 트리거로 예산 초과, 자기 팀 이적, 매물 중복 등록, 소속 불일치를 DB 레벨에서 차단합니다."
4. **뷰 활용**: "복잡한 JOIN을 VIEW로 추상화하여 발표 시연에서 직관적으로 데이터를 확인할 수 있습니다."
5. **Generated Column**: "overall은 직접 입력하지 않고 4개 능력치의 평균으로 자동 계산됩니다."

