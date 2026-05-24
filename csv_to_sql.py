"""
csv_to_sql.py
─────────────────────────────────────────────────────────────────
CSV 파일들을 읽어 두 개의 DML SQL 파일을 생성합니다.

출력:
  kleague_dml_base.sql   <- CLUB / MANAGER / APP_USER
  kleague_dml_sample.sql <- PLAYER / PLAYER_STATS / CONTRACT / TRANSFER_MARKET

선수 구성:
  - data/cleaned_players.csv  : 기존 11명/구단 (전체 12구단)
  - DBPBL cleaned_players.csv : 9개 매핑 구단에 5명 추가 -> 16명/구단
  - FC Anyang(7), Bucheon(9), Gimcheon(11) : 11명 유지 (DBPBL 미매핑)

DBPBL 구단 -> 현재 club_id 매핑:
  Seoul->1  Ulsan->2  Jeonbuk Motors->3  Gangwon->4
  Pohang Steelers->5  Incheon United->6
  Jeju United->8  Daejeon Citizen->10  Gwangju->12

컬럼 매핑 (DBPBL -> PLAYER_STATS):
  shooting  -> attack
  defending -> defense
  physic    -> stamina
  pace      -> speed
─────────────────────────────────────────────────────────────────
"""

import csv
import os

DATA_DIR     = "data"
DBPBL_DIR    = r"C:\Users\l22s2\proj\DBPBL\soccer\cleaned"
BASE_FILE    = "kleague_dml_base.sql"
SAMPLE_FILE  = "kleague_dml_sample.sql"

# DBPBL club_name -> 현재 DB club_id
DBPBL_CLUB_MAP = {
    "Seoul":           1,
    "Ulsan":           2,
    "Jeonbuk Motors":  3,
    "Gangwon":         4,
    "Pohang Steelers": 5,
    "Incheon United":  6,
    "Jeju United":     8,
    "Daejeon Citizen": 10,
    "Gwangju":         12,
}

MANAGERS = [
    # (club_id, name, nationality, birth_date, tactics, rating)
    (1,  '안익수',  '대한민국', '1968-05-18', '4-4-2',   80),  # FC Seoul
    (2,  '홍명보',  '대한민국', '1969-02-01', '4-3-3',   88),  # Ulsan HD FC
    (3,  '김상식',  '대한민국', '1974-07-04', '4-2-3-1', 84),  # Jeonbuk
    (4,  '윤종환',  '대한민국', '1970-03-15', '4-3-3',   78),  # Gangwon
    (5,  '김기동',  '대한민국', '1972-01-05', '3-4-3',   79),  # Pohang
    (6,  '조성환',  '대한민국', '1970-09-11', '4-1-4-1', 77),  # Incheon
    (7,  '류병훈',  '대한민국', '1975-05-20', '4-3-3',   71),  # FC Anyang
    (8,  '남기일',  '대한민국', '1971-06-07', '4-4-2',   76),  # Jeju SK
    (9,  '조덕제',  '대한민국', '1968-09-30', '4-4-2',   70),  # Bucheon FC 1995
    (10, '황선홍',  '대한민국', '1968-07-14', '4-2-3-1', 83),  # Daejeon
    (11, '이병근',  '대한민국', '1973-11-20', '4-3-3',   74),  # Gimcheon
    (12, '이정효',  '대한민국', '1979-12-03', '4-2-3-1', 72),  # Gwangju
]


def esc(v):
    if v is None:
        return "NULL"
    return "'" + str(v).replace("'", "''") + "'"

def null_or_date(v):
    v = v.strip() if v else ""
    return "NULL" if not v else esc(v)

def read_csv(path):
    # utf-8-sig: BOM 있는 파일도 처리
    with open(path, encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


# ─────────────────────────────────────────────────────────────────
# DML BASE: CLUB / MANAGER / APP_USER
# ─────────────────────────────────────────────────────────────────
def gen_base():
    clubs = read_csv(os.path.join(DATA_DIR, "cleaned_clubs.csv"))
    users = read_csv(os.path.join(DATA_DIR, "app_users.csv"))

    lines = []
    lines += [
        "-- =====================================================",
        "-- K리그 이적시장 기반 스토브리그 체험 DB 시스템",
        "-- DML BASE -- CLUB / MANAGER / APP_USER",
        "-- (csv_to_sql.py 자동 생성)",
        "-- =====================================================",
        "", "USE kleague_db;", "",
    ]

    # CLUB
    lines += [
        "-- =====================================================",
        "-- 1. CLUB  (출처: data/cleaned_clubs.csv)",
        "-- =====================================================",
        "INSERT INTO CLUB",
        "    (club_id, name, city, founded_year,",
        "     stadium_name, stadium_capacity,",
        "     initial_budget, current_budget)",
        "VALUES",
    ]
    rows = []
    for c in clubs:
        rows.append(
            f"({c['club_id']}, {esc(c['club_name'])}, {esc(c['city'])}, "
            f"{c['founded_year']}, {esc(c['stadium_name'])}, "
            f"{c['stadium_capacity']}, "
            f"{c['initial_budget_eur']}, {c['current_budget_eur']})"
        )
    lines.append(",\n".join(rows) + ";")
    lines.append("")

    # MANAGER
    lines += [
        "-- =====================================================",
        "-- 2. MANAGER",
        "-- =====================================================",
        "INSERT INTO MANAGER (club_id, name, nationality, birth_date, tactics, rating) VALUES",
    ]
    mgr_rows = [
        f"({m[0]}, {esc(m[1])}, {esc(m[2])}, {esc(m[3])}, {esc(m[4])}, {m[5]})"
        for m in MANAGERS
    ]
    lines.append(",\n".join(mgr_rows) + ";")
    lines.append("")

    # APP_USER
    lines += [
        "-- =====================================================",
        "-- 3. APP_USER  (출처: data/app_users.csv)",
        "-- =====================================================",
        "INSERT INTO APP_USER (user_id, username, club_id) VALUES",
    ]
    u_rows = [
        f"({u['user_id']}, {esc(u['username'])}, {u['club_id']})"
        for u in users
    ]
    lines.append(",\n".join(u_rows) + ";")
    lines.append("")

    with open(BASE_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"[OK] {BASE_FILE} ({len(clubs)} clubs, {len(users)} users)")


# ─────────────────────────────────────────────────────────────────
# DML SAMPLE: PLAYER / PLAYER_STATS / CONTRACT / TRANSFER_MARKET
# ─────────────────────────────────────────────────────────────────
def gen_sample():
    # ── 기존 data/ 파일 로드 ────────────────────────────────────
    cur_players  = read_csv(os.path.join(DATA_DIR, "cleaned_players.csv"))
    cur_stats    = {r["player_id"]: r
                    for r in read_csv(os.path.join(DATA_DIR, "player_stats.csv"))}
    cur_contracts= {r["player_id"]: r
                    for r in read_csv(os.path.join(DATA_DIR, "contracts.csv"))}
    cur_market   = read_csv(os.path.join(DATA_DIR, "transfer_market.csv"))

    # ── DBPBL 파일 로드 ─────────────────────────────────────────
    dbpbl_all = read_csv(os.path.join(DBPBL_DIR, "cleaned_players.csv"))

    # 구단별로 그룹화 (매핑 구단만)
    from collections import defaultdict
    dbpbl_by_club = defaultdict(list)
    for r in dbpbl_all:
        if r["club_name"] in DBPBL_CLUB_MAP:
            dbpbl_by_club[r["club_name"]].append(r)

    # 기존 player_id 집합 (중복 방지)
    existing_ids = {r["player_id"] for r in cur_players}

    # 각 구단에서 overall 기준 상위 5명 선택
    added_players = []
    for club_name, club_id in DBPBL_CLUB_MAP.items():
        candidates = [
            r for r in dbpbl_by_club[club_name]
            if r["player_id"] not in existing_ids
        ]
        top5 = sorted(candidates, key=lambda x: int(x["overall"]), reverse=True)[:5]
        for r in top5:
            r["_mapped_club_id"] = club_id
            added_players.append(r)
            existing_ids.add(r["player_id"])

    print(f"  DBPBL 추가 선수: {len(added_players)}명 "
          f"(9구단 x 5명 = {9*5}명 목표)")

    lines = []
    lines += [
        "-- =====================================================",
        "-- K리그 이적시장 기반 스토브리그 체험 DB 시스템",
        "-- DML SAMPLE -- PLAYER / PLAYER_STATS / CONTRACT / TRANSFER_MARKET",
        "-- (csv_to_sql.py 자동 생성)",
        "-- =====================================================",
        "", "USE kleague_db;", "",
    ]

    # ── PLAYER ────────────────────────────────────────────────────
    lines += [
        "-- =====================================================",
        "-- 1. PLAYER",
        "--   기존 data/ : 132명 (12구단 x 11명)",
        "--   DBPBL 추가 :  45명 (9구단 x  5명)",
        "--   합계       : 177명",
        "-- =====================================================",
        "INSERT INTO PLAYER",
        "    (player_id, club_id, name, nationality,",
        "     birth_date, position, height, weight)",
        "VALUES",
    ]
    p_rows = []

    # 기존 선수
    for p in cur_players:
        pos = p["position_group"].strip()
        if pos not in ("GK","DF","MF","FW"):
            continue
        h = p.get("height_cm","").strip()
        w = p.get("weight_kg","").strip()
        p_rows.append(
            f"({p['player_id']}, {p['club_id']}, {esc(p['player_name'])}, "
            f"{esc(p['nationality'])}, {esc(p['birth_date'])}, "
            f"{esc(pos)}, "
            f"{'NULL' if not h else h}, {'NULL' if not w else w})"
        )

    # DBPBL 추가 선수
    for p in added_players:
        pos = p["position_group"].strip()
        if pos not in ("GK","DF","MF","FW"):
            continue
        name = p["long_name"][:50]
        h = p.get("height_cm","").strip()
        w = p.get("weight_kg","").strip()
        p_rows.append(
            f"({p['player_id']}, {p['_mapped_club_id']}, {esc(name)}, "
            f"{esc(p['nationality'])}, {esc(p['dob'])}, "
            f"{esc(pos)}, "
            f"{'NULL' if not h else h}, {'NULL' if not w else w})"
        )

    lines.append(",\n".join(p_rows) + ";")
    lines.append("")

    # ── PLAYER_STATS ──────────────────────────────────────────────
    lines += [
        "-- =====================================================",
        "-- 2. PLAYER_STATS",
        "--   기존: shooting->attack, defending->defense, physical->stamina, pace->speed",
        "--   DBPBL: shooting->attack, defending->defense, physic->stamina, pace->speed",
        "-- =====================================================",
        "INSERT INTO PLAYER_STATS (player_id, attack, defense, stamina, speed)",
        "VALUES",
    ]
    s_rows = []

    for p in cur_players:
        pid = p["player_id"]
        s = cur_stats.get(pid)
        if not s:
            continue
        s_rows.append(
            f"({pid}, {s['shooting']}, {s['defending']}, "
            f"{s['physical']}, {s['pace']})"
        )

    for p in added_players:
        pid = p["player_id"]
        s_rows.append(
            f"({pid}, {p['shooting']}, {p['defending']}, "
            f"{p['physic']}, {p['pace']})"
        )

    lines.append(",\n".join(s_rows) + ";")
    lines.append("")

    # ── CONTRACT ──────────────────────────────────────────────────
    lines += [
        "-- =====================================================",
        "-- 3. CONTRACT",
        "-- =====================================================",
        "INSERT INTO CONTRACT (player_id, club_id, start_date, end_date, salary, status)",
        "VALUES",
    ]
    c_rows = []

    for p in cur_players:
        pid = p["player_id"]
        c = cur_contracts.get(pid)
        if not c:
            continue
        c_rows.append(
            f"({pid}, {c['club_id']}, {esc(c['start_date'])}, "
            f"{null_or_date(c['end_date'])}, {c['salary_eur']}, "
            f"{esc(c['status'])})"
        )

    for p in added_players:
        pid = p["player_id"]
        c_rows.append(
            f"({pid}, {p['_mapped_club_id']}, '2024-01-01', "
            f"NULL, {p['wage_eur']}, 'active')"
        )

    lines.append(",\n".join(c_rows) + ";")
    lines.append("")

    # ── TRANSFER_MARKET ───────────────────────────────────────────
    lines += [
        "-- =====================================================",
        "-- 4. TRANSFER_MARKET  (기존 132명 + DBPBL 추가 45명)",
        "-- =====================================================",
        "INSERT INTO TRANSFER_MARKET",
        "    (listing_id, player_id, seller_club_id, asking_fee, listed_date, status)",
        "VALUES",
    ]
    m_rows = []

    # 기존 132명
    for row in cur_market:
        m_rows.append(
            f"({row['listing_id']}, {row['player_id']}, {row['seller_club_id']}, "
            f"{row['asking_fee_eur']}, {esc(row['listed_date'])}, {esc(row['status'])})"
        )

    # DBPBL 추가 45명 (listing_id = 133 부터)
    for i, p in enumerate(added_players, start=len(cur_market) + 1):
        m_rows.append(
            f"({i}, {p['player_id']}, {p['_mapped_club_id']}, "
            f"{p['value_eur']}, '2026-06-01', 'available')"
        )

    lines.append(",\n".join(m_rows) + ";")
    lines.append("")

    # AUTO_INCREMENT 조정
    lines += [
        "-- AUTO_INCREMENT 상한 조정 (소스 ID 충돌 방지)",
        "ALTER TABLE PLAYER AUTO_INCREMENT = 30000000;",
        "",
    ]

    with open(SAMPLE_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"[OK] {SAMPLE_FILE}")
    print(f"     PLAYER: {len(p_rows)}명 (기존 {len(cur_players)} + DBPBL {len(added_players)})")
    print(f"     PLAYER_STATS: {len(s_rows)}개")
    print(f"     CONTRACT: {len(c_rows)}개")
    print(f"     TRANSFER_MARKET: {len(m_rows)}개")


def validate():
    cur  = read_csv(os.path.join(DATA_DIR, "cleaned_players.csv"))
    dbp  = read_csv(os.path.join(DBPBL_DIR, "cleaned_players.csv"))

    from collections import Counter, defaultdict
    cur_by_club  = Counter(r["club_id"] for r in cur)
    dbpbl_by_club= defaultdict(list)
    for r in dbp:
        if r["club_name"] in DBPBL_CLUB_MAP:
            dbpbl_by_club[DBPBL_CLUB_MAP[r["club_name"]]].append(r)

    print("\n[Club player count after merge]")
    club_names = {
        1:"FC Seoul", 2:"Ulsan HD FC", 3:"Jeonbuk", 4:"Gangwon",
        5:"Pohang", 6:"Incheon", 7:"FC Anyang", 8:"Jeju SK",
        9:"Bucheon", 10:"Daejeon", 11:"Gimcheon", 12:"Gwangju"
    }
    for cid in range(1, 13):
        cur_n  = cur_by_club.get(str(cid), 0)
        add_n  = min(5, len(dbpbl_by_club.get(cid, [])))
        total  = cur_n + add_n
        note   = "" if cid not in [7, 9, 11] else " (DBPBL 미매핑, 11명 유지)"
        print(f"  club {cid:2d} {club_names[cid]:25s}: {cur_n} + {add_n} = {total}명{note}")


if __name__ == "__main__":
    validate()
    print()
    gen_base()
    gen_sample()
    print("\nDone. SQL execution order:")
    print("  kleague_ddl.sql -> kleague_dml_base.sql -> kleague_dml_sample.sql")
    print("  -> kleague_extensions.sql -> kleague_procedures.sql")
