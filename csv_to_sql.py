"""
csv_to_sql.py
─────────────────────────────────────────────────────────────────
CSV → SQL INSERT 변환 + 사전 검증 스크립트

사용법:
    python csv_to_sql.py kleague_players_verified.csv

출력:
    kleague_players_verified_converted.sql
        └─ PLAYER / PLAYER_STATS / CONTRACT INSERT문 + 검증 쿼리

주의:
    CLUB / MANAGER / APP_USER / TRANSFER_MARKET 은
    별도 DML 파일(kleague_dml_base.sql)에서 관리합니다.
─────────────────────────────────────────────────────────────────
"""

import csv
import sys
from collections import defaultdict
from datetime import datetime

# ─────────────────────────────────────────────
# 상수 정의
# ─────────────────────────────────────────────
CLUB_MAP = {
    '울산 HD FC':       1,
    '전북 현대 모터스': 2,
    'FC 서울':          3,
    '포항 스틸러스':    4,
    '강원 FC':          5,
    '제주 SK':          6,
    '인천 유나이티드':  7,
    '대전 하나 시티즌': 8,
    '김천 상무':        9,
    '광주 FC':         10,
    'FC 안양':         11,
    '부천 FC 1995':    12,
}

# EA 포지션 → DB 포지션
POS_MAP = {
    'GK':  'GK',
    'CB':  'DF', 'LB': 'DF', 'RB': 'DF', 'LWB': 'DF', 'RWB': 'DF',
    'CDM': 'MF', 'CM': 'MF', 'CAM': 'MF', 'LM': 'MF', 'RM': 'MF',
    'ST':  'FW', 'CF': 'FW', 'LW': 'FW', 'RW': 'FW',
}

# 팀별 필수 포지션 구성
REQUIRED = {'GK': 1, 'DF': 4, 'MF': 4, 'FW': 2}
TOTAL_PLAYERS = 132
TOTAL_CLUBS   = 12


# ─────────────────────────────────────────────
# 헬퍼
# ─────────────────────────────────────────────
def esc(s: str) -> str:
    """SQL 인젝션 방지: 작은따옴표 escape"""
    return s.replace("'", "''")

def to_db_pos(pos_raw: str) -> str:
    return POS_MAP.get(pos_raw.strip().upper(), '')


# ─────────────────────────────────────────────
# 메인 변환 함수
# ─────────────────────────────────────────────
def convert(csv_file: str) -> None:
    rows        = []
    skip_errors = []   # checked != Y  또는 파싱 오류
    parse_errors = []  # 필드 오류

    # ── 1. CSV 읽기 + 기본 파싱 ──────────────────
    with open(csv_file, encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for line_no, row in enumerate(reader, start=2):
            name    = row.get('player_name', '').strip()
            club    = row.get('club_name', '').strip()
            nat     = row.get('nationality', '').strip()
            bd      = row.get('birth_date', '').strip()
            pos_raw = row.get('position_raw', '').strip()
            pos     = row.get('position', '').strip() or to_db_pos(pos_raw)
            checked = row.get('checked', '').strip().upper()

            # 1-① checked == Y 아닌 행 스킵
            if checked != 'Y':
                skip_errors.append(
                    f"  행 {line_no:>3} │ {club:<20} │ {name} "
                    f"→ checked='{row.get('checked','').strip()}' (미검수, 스킵)"
                )
                continue

            # 1-② 구단명 검증
            if club not in CLUB_MAP:
                parse_errors.append(f"  행 {line_no:>3} │ 알 수 없는 구단: '{club}'")
                continue

            # 1-③ 포지션 검증
            db_pos = pos if pos in ('GK', 'DF', 'MF', 'FW') else to_db_pos(pos_raw)
            if db_pos not in ('GK', 'DF', 'MF', 'FW'):
                parse_errors.append(
                    f"  행 {line_no:>3} │ {club} │ {name} "
                    f"→ 포지션 매핑 불가: '{pos_raw}'"
                )
                continue

            # 1-④ 생년월일 형식 검증
            try:
                datetime.strptime(bd, '%Y-%m-%d')
            except ValueError:
                parse_errors.append(
                    f"  행 {line_no:>3} │ {club} │ {name} "
                    f"→ 날짜 형식 오류: '{bd}' (YYYY-MM-DD 필요)"
                )
                continue

            # 1-⑤ 능력치 정수 파싱
            try:
                pac = int(row['pac'])
                sho = int(row['sho'])
                def_ = int(row['def'])
                phy = int(row['phy'])
            except (KeyError, ValueError) as e:
                parse_errors.append(
                    f"  행 {line_no:>3} │ {club} │ {name} "
                    f"→ 능력치 파싱 오류: {e}"
                )
                continue

            rows.append({
                'club': club, 'club_id': CLUB_MAP[club],
                'name': name, 'nat': nat, 'bd': bd,
                'pos_raw': pos_raw, 'pos': db_pos,
                'pac': pac, 'sho': sho, 'def': def_, 'phy': phy,
            })

    # ── 2. 사전 검증 ─────────────────────────────
    validation_errors = []

    # 2-① 전체 선수 수 132명
    if len(rows) != TOTAL_PLAYERS:
        validation_errors.append(
            f"  전체 선수 수: {len(rows)}명 (필요: {TOTAL_PLAYERS}명)"
        )

    # 2-② 팀 수 12개
    clubs_present = set(r['club'] for r in rows)
    if len(clubs_present) != TOTAL_CLUBS:
        missing = set(CLUB_MAP.keys()) - clubs_present
        extra   = clubs_present - set(CLUB_MAP.keys())
        if missing:
            validation_errors.append(f"  누락된 구단: {', '.join(sorted(missing))}")
        if extra:
            validation_errors.append(f"  알 수 없는 구단: {', '.join(sorted(extra))}")

    # 2-③ 팀별 선수 수 11명 + 포지션 구성 GK1/DF4/MF4/FW2
    club_players  = defaultdict(list)
    club_pos_cnt  = defaultdict(lambda: defaultdict(int))
    for r in rows:
        club_players[r['club']].append(r)
        club_pos_cnt[r['club']][r['pos']] += 1

    for club in sorted(CLUB_MAP.keys()):
        cnt = len(club_players[club])
        if cnt != 11:
            validation_errors.append(
                f"  {club}: 선수 수 {cnt}명 (필요: 11명)"
            )
        for pos, need in REQUIRED.items():
            have = club_pos_cnt[club].get(pos, 0)
            if have != need:
                validation_errors.append(
                    f"  {club}: {pos} {have}명 (필요: {need}명)"
                )

    # 2-④ 이름 + 생년월일 기준 중복 선수
    seen = defaultdict(list)
    for r in rows:
        key = (r['name'], r['bd'])
        seen[key].append(r['club'])
    for (name, bd), clubs in seen.items():
        if len(clubs) > 1:
            validation_errors.append(
                f"  중복 선수: {name} ({bd}) → {', '.join(clubs)}"
            )

    # ── 3. 결과 출력 ─────────────────────────────
    print("=" * 60)
    print("  K리그 베스트11 CSV → SQL 변환기")
    print("=" * 60)

    if skip_errors:
        print(f"\n[미검수 스킵] {len(skip_errors)}행")
        for m in skip_errors:
            print(m)

    if parse_errors:
        print(f"\n[파싱 오류] {len(parse_errors)}건 → 변환 중단")
        for m in parse_errors:
            print(m)
        sys.exit(1)

    if validation_errors:
        print(f"\n[검증 실패] {len(validation_errors)}건 → 변환 중단")
        for m in validation_errors:
            print(m)
        print("\nCSV를 수정한 뒤 다시 실행하세요.")
        sys.exit(1)

    print(f"\n[검증 통과] {len(rows)}명, {len(clubs_present)}개 구단 ✅")

    # ── 4. SQL 생성 ───────────────────────────────
    player_vals   = []
    stats_vals    = []
    contract_vals = []

    for pid, r in enumerate(rows, start=1):
        cid  = r['club_id']
        name = esc(r['name'])
        nat  = esc(r['nat'])
        bd   = r['bd']
        pos  = r['pos']

        player_vals.append(
            f"({cid}, '{name}', '{nat}', '{bd}', '{pos}', NULL, NULL)"
        )
        stats_vals.append(
            f"({pid}, {r['sho']}, {r['def']}, {r['phy']}, {r['pac']})"
            f"  -- {r['name']} ({r['club']}, {r['pos_raw']}→{pos})"
        )
        contract_vals.append(
            f"({pid}, {cid}, '2024-01-01', '2027-12-31', 200000000, 'active')"
        )

    lines = [
        "-- =====================================================",
        "-- K리그 이적시장 DB 시스템",
        "-- DML - PLAYER / PLAYER_STATS / CONTRACT",
        "-- ※ CLUB / MANAGER / APP_USER / TRANSFER_MARKET 은",
        "--   kleague_dml_base.sql 에서 별도 관리",
        "-- =====================================================",
        "",
        "USE kleague_db;",
        "",
        "-- PLAYER",
        "INSERT INTO PLAYER (club_id, name, nationality, birth_date, position, height, weight) VALUES",
        ",\n".join(player_vals) + ";",
        "",
        "-- PLAYER_STATS  (speed=PAC, attack=SHO, defense=DEF, stamina=PHY)",
        "INSERT INTO PLAYER_STATS (player_id, attack, defense, stamina, speed) VALUES",
        ",\n".join(stats_vals) + ";",
        "",
        "-- CONTRACT",
        "INSERT INTO CONTRACT (player_id, club_id, start_date, end_date, salary, status) VALUES",
        ",\n".join(contract_vals) + ";",
        "",
        "-- =====================================================",
        "-- DB 검증 쿼리 (실행해서 모두 0건이면 정상)",
        "-- =====================================================",
        "",
        "-- ① 전체 선수 수 (132명이어야 함)",
        "SELECT COUNT(*) AS total_players FROM PLAYER;",
        "",
        "-- ② 팀별 11명이 아닌 구단 (0건이어야 함)",
        "SELECT c.name, COUNT(*) AS player_count",
        "FROM PLAYER p JOIN CLUB c ON p.club_id = c.club_id",
        "GROUP BY c.name HAVING COUNT(*) <> 11;",
        "",
        "-- ③ 팀별 포지션 구성 확인",
        "SELECT c.name, p.position, COUNT(*) AS cnt",
        "FROM PLAYER p JOIN CLUB c ON p.club_id = c.club_id",
        "GROUP BY c.name, p.position",
        "ORDER BY c.name, FIELD(p.position,'GK','DF','MF','FW');",
        "",
        "-- ④ 중복 선수 확인 (0건이어야 함)",
        "SELECT name, birth_date, COUNT(*) AS cnt",
        "FROM PLAYER GROUP BY name, birth_date HAVING COUNT(*) > 1;",
    ]

    out_file = csv_file.replace('.csv', '_converted.sql')
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    print(f"\n[완료] SQL 파일 생성: {out_file}")
    print("\n실행 순서:")
    print("  1. SOURCE kleague_ddl.sql")
    print("  2. SOURCE kleague_dml_base.sql        ← CLUB/MANAGER/APP_USER/TRANSFER_MARKET")
    print(f"  3. SOURCE {out_file}   ← PLAYER/PLAYER_STATS/CONTRACT")
    print("  4. SOURCE kleague_procedures.sql")


# ─────────────────────────────────────────────
if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("사용법: python csv_to_sql.py 파일명.csv")
        sys.exit(1)
    convert(sys.argv[1])
