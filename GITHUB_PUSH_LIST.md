# GitHub에 push할 것

## 반드시 push

- `README.md`
- `kleague_ddl.sql`
- `kleague_dml.sql`
- `kleague_procedures.sql`
- `kleague_full_setup.sql`
- `kleague_app.py`
- `requirements.txt`
- `.gitignore`
- `data/cleaned_clubs.csv`
- `data/cleaned_players.csv`
- `data/player_stats.csv`
- `data/contracts.csv`
- `data/transfer_market.csv`
- `data/app_users.csv`
- `data/data_sources.csv`
- `docs/ERD.mmd`
- `docs/presentation_script.md`
- `docs/verification_queries.sql`

## push하지 말 것

- `.env`
- MySQL 비밀번호가 들어간 파일
- `__pycache__/`
- 개인 PC 경로가 박힌 임시 파일
- Workbench local connection export

## 추천 커밋 메시지

```bash
git add .
git commit -m "Implement K League transfer simulator database"
git push
```
