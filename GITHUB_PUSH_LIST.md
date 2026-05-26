# 로컬 제출/공유 대상

> 원격 GitHub push는 사용자가 따로 지시하기 전까지 하지 않습니다.

## 반드시 포함

- `README.md`
- `kleague_ddl.sql`
- `kleague_dml.sql`
- `kleague_procedures.sql`
- `kleague_full_setup.sql`
- `kleague_app.py`
- `requirements.txt`
- `.gitignore`
- `scripts/rebuild_kleague_dataset.py`
- `data/cleaned_clubs.csv`
- `data/cleaned_players.csv`
- `data/managers.csv`
- `data/player_stats.csv`
- `data/contracts.csv`
- `data/transfer_market.csv`
- `data/transfermarkt_values.csv`
- `data/app_users.csv`
- `data/data_sources.csv`
- `docs/ERD.mmd`
- `docs/presentation_script.md`
- `docs/verification_queries.sql`

## 포함하지 말 것

- `.env`
- MySQL 비밀번호가 들어간 파일
- `__pycache__/`
- `*.zip`
- 개인 PC 경로가 박힌 임시 파일
- Workbench local connection export

## 로컬 커밋이 필요할 때

```bash
git add README.md kleague_ddl.sql kleague_dml.sql kleague_dml_kor.sql kleague_procedures.sql kleague_full_setup.sql kleague_app.py requirements.txt scripts data docs
git commit -m "Improve K League transfer simulator"
```

원격 반영은 팀원들이 최종 확인하고 사용자가 명시적으로 요청한 뒤 진행합니다.
