# K League Transfer Simulator DB

K리그 구단 운영을 위한 DB 중심 프로젝트입니다. 선수 영입/방출, 이적시장, 예산, 이적 이력을 MySQL에서 관리하고 Streamlit UI로 확인합니다.

## 발표/제출용 기능 요약

주제: **K리그 구단 운영 카드형 선수 이적 관리 DB**

- 사용자/구단 선택 후 이적시장 선수 조회
- 예산 기반 선수 구매 처리
- 구매 시 이적 기록 자동 저장
- 트랜잭션 기반 DB 처리로 일관성 보장
- 예산 부족/중복 구매/없는 listing 차단
- KRW 단위 통일 및 검증 쿼리 제공

## 금액 단위 정책

본 시스템의 예산은 실제 구단 회계자료가 아니라, 게임 밸런스와 구단 규모를 반영해 설정한 시뮬레이션용 이적 예산입니다.  
모든 예산, 선수 가치, 이적료, 계약 금액은 **KRW(원화) 기준**으로 저장합니다.  
화면에서는 가독성을 위해 `원` 표기와 `억 원` 표기를 함께 사용합니다.

참고:
- `data/*.csv` 산출물은 이미 KRW 값입니다.
- 다만 SQL 시드(`kleague_dml.sql`, `kleague_dml_kor.sql`, `kleague_full_setup.sql`)의 원본 숫자 리터럴은 과거 EUR 스케일 스냅샷을 유지하고 있어, 로딩 시점에 `@krw_fx_rate`로 1회 KRW 변환을 수행합니다.
- 따라서 DB에 실제 저장되는 값은 KRW이며, 환산은 import 과정에서만 적용됩니다.

## 핵심 규칙

- `clubs.initial_budget_krw`, `clubs.current_budget_krw`, `clubs.total_spent_krw` 사용
- `players.market_value_krw` 사용
- `transfer_market.asking_fee_krw` 사용
- `transfer_history.fee_krw` 사용
- 이적시장 상태는 `listed`, `sold`, `cancelled`로 관리
- 구매 가능한 매물은 `status = 'listed'`만 조회

## 실행 순서 (제출/시연)

1. MySQL에서 `kleague_full_setup.sql` 실행
2. 터미널에서 `streamlit run kleague_app.py` 실행
3. 사용자 선택
4. 구단 선택
5. 선수 구매
6. 예산/이적 기록 확인

예시:

```bash
mysql -u root -p < kleague_full_setup.sql
streamlit run kleague_app.py
```

## 주요 검증

검증 쿼리는 `docs/verification_queries.sql`에 정리되어 있습니다.

```sql
SOURCE docs/verification_queries.sql;
```

포함된 검증 항목:

- 정상 구매
- 예산 부족 구매 실패
- 이미 판매된 선수 재구매 실패
- 없는 listing 구매 실패
- 구매 후 선수 소속 변경
- 구매 후 예산 차감
- 구매 후 `transfer_history` 기록
- 구매 후 `transfer_market.status = 'sold'`

## 프로젝트 파일

- `kleague_full_setup.sql`: DB 전체 생성 + 초기 데이터 + 뷰 + 프로시저
- `kleague_ddl.sql`: DDL/뷰/트리거
- `kleague_dml.sql`, `kleague_dml_kor.sql`: 초기 데이터
- `kleague_procedures.sql`: 주요 저장 프로시저
- `kleague_app.py`: Streamlit 앱
- `docs/verification_queries.sql`: 검증 쿼리
