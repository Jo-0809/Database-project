import html
import os
import pandas as pd
import pymysql
import streamlit as st
import streamlit.components.v1 as components


DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "1234",
    "database": "kleague_db",
    "charset": "utf8mb4",
    "cursorclass": pymysql.cursors.Cursor,
}

# 데이터프레임 컬럼 한글 매핑용 딕셔너리
COLUMN_MAPPING = {
    "club_name": "구단명",
    "manager_name": "감독명",
    "preferred_formation": "선호 포메이션",
    "player_count": "선수 수",
    "avg_player_overall": "평균 오버롤",
    "manager_rating": "감독 능력치",
    "squad_score": "스쿼드 점수",
    "initial_budget_eur": "초기 예산 (EUR)",
    "current_budget_eur": "현재 예산 (EUR)",
    "total_spent_eur": "총 지출 (EUR)",
    "position_group": "포지션 그룹",
    "avg_overall": "평균 오버롤",
    "player_name": "선수명",
    "primary_position": "주포지션",
    "nationality": "국적",
    "market_value_eur": "시장 가치 (EUR)",
    "appearances": "출전 횟수",
    "goals": "득점",
    "assists": "도움",
    "pace": "속도",
    "shooting": "슈팅",
    "passing": "패스",
    "defending": "수비",
    "physical": "피지컬",
    "overall": "오버롤",
    "seller_club": "판매 구단",
    "asking_fee_eur": "요구 이적료 (EUR)",
    "bought_player": "영입 선수",
    "released_player": "방출 선수",
    "buyer_club": "영입 구단",
    "transfer_id": "이적 ID",
    "from_club": "이전 구단",
    "to_club": "이적 구단",
    "transfer_type": "이적 형태",
    "fee_eur": "이적료 (EUR)",
    "transfer_date": "이적일",
    "memo": "비고",
    "battle_id": "배틀 ID",
    "home_club": "홈 팀",
    "away_club": "원정 팀",
    "home_score": "홈 점수",
    "away_score": "원정 점수",
    "result": "결과",
    "battle_date": "경기일"
}

FORMATION_POSITIONS = {
    "4-3-3": [
        {"slot": "GK", "group": "GK", "x": 50, "y": 88},
        {"slot": "LB", "group": "DF", "x": 15, "y": 72},
        {"slot": "LCB", "group": "DF", "x": 38, "y": 72},
        {"slot": "RCB", "group": "DF", "x": 62, "y": 72},
        {"slot": "RB", "group": "DF", "x": 85, "y": 72},
        {"slot": "LCM", "group": "MF", "x": 29, "y": 54},
        {"slot": "CM", "group": "MF", "x": 50, "y": 42},
        {"slot": "RCM", "group": "MF", "x": 71, "y": 54},
        {"slot": "LW", "group": "FW", "x": 18, "y": 22},
        {"slot": "ST", "group": "FW", "x": 50, "y": 15},
        {"slot": "RW", "group": "FW", "x": 82, "y": 22},
    ],
    "4-3-2-1": [
        {"slot": "GK", "group": "GK", "x": 50, "y": 88},
        {"slot": "LB", "group": "DF", "x": 15, "y": 72},
        {"slot": "LCB", "group": "DF", "x": 38, "y": 72},
        {"slot": "RCB", "group": "DF", "x": 62, "y": 72},
        {"slot": "RB", "group": "DF", "x": 85, "y": 72},
        {"slot": "LCM", "group": "MF", "x": 28, "y": 57},
        {"slot": "CM", "group": "MF", "x": 50, "y": 45},
        {"slot": "RCM", "group": "MF", "x": 72, "y": 57},
        {"slot": "LAM", "group": "MF", "x": 38, "y": 30},
        {"slot": "RAM", "group": "MF", "x": 62, "y": 30},
        {"slot": "ST", "group": "FW", "x": 50, "y": 15},
    ],
    "4-2-3-1": [
        {"slot": "GK", "group": "GK", "x": 50, "y": 88},
        {"slot": "LB", "group": "DF", "x": 15, "y": 72},
        {"slot": "LCB", "group": "DF", "x": 38, "y": 72},
        {"slot": "RCB", "group": "DF", "x": 62, "y": 72},
        {"slot": "RB", "group": "DF", "x": 85, "y": 72},
        {"slot": "LDM", "group": "MF", "x": 35, "y": 58},
        {"slot": "RDM", "group": "MF", "x": 65, "y": 58},
        {"slot": "LAM", "group": "MF", "x": 20, "y": 38},
        {"slot": "CAM", "group": "MF", "x": 50, "y": 32},
        {"slot": "RAM", "group": "MF", "x": 80, "y": 38},
        {"slot": "ST", "group": "FW", "x": 50, "y": 15},
    ],
    "4-4-2": [
        {"slot": "GK", "group": "GK", "x": 50, "y": 88},
        {"slot": "LB", "group": "DF", "x": 15, "y": 72},
        {"slot": "LCB", "group": "DF", "x": 38, "y": 72},
        {"slot": "RCB", "group": "DF", "x": 62, "y": 72},
        {"slot": "RB", "group": "DF", "x": 85, "y": 72},
        {"slot": "LM", "group": "MF", "x": 15, "y": 45},
        {"slot": "LCM", "group": "MF", "x": 38, "y": 50},
        {"slot": "RCM", "group": "MF", "x": 62, "y": 50},
        {"slot": "RM", "group": "MF", "x": 85, "y": 45},
        {"slot": "LS", "group": "FW", "x": 38, "y": 20},
        {"slot": "RS", "group": "FW", "x": 62, "y": 20},
    ],
    "3-5-2": [
        {"slot": "GK", "group": "GK", "x": 50, "y": 88},
        {"slot": "LCB", "group": "DF", "x": 28, "y": 72},
        {"slot": "CB", "group": "DF", "x": 50, "y": 75},
        {"slot": "RCB", "group": "DF", "x": 72, "y": 72},
        {"slot": "LWB", "group": "MF", "x": 12, "y": 50},
        {"slot": "LCM", "group": "MF", "x": 32, "y": 58},
        {"slot": "CM", "group": "MF", "x": 50, "y": 43},
        {"slot": "RCM", "group": "MF", "x": 68, "y": 58},
        {"slot": "RWB", "group": "MF", "x": 88, "y": 50},
        {"slot": "LS", "group": "FW", "x": 38, "y": 20},
        {"slot": "RS", "group": "FW", "x": 62, "y": 20},
    ],
}

ROLE_ATTRIBUTE_WEIGHTS = {
    "GK": {"pace": 0.08, "shooting": 0.02, "passing": 0.20, "defending": 0.45, "physical": 0.25},
    "DF": {"pace": 0.15, "shooting": 0.03, "passing": 0.12, "defending": 0.45, "physical": 0.25},
    "MF": {"pace": 0.15, "shooting": 0.05, "passing": 0.40, "defending": 0.20, "physical": 0.20},
    "FW": {"pace": 0.25, "shooting": 0.38, "passing": 0.12, "defending": 0.05, "physical": 0.20},
}


def get_conn():
    return pymysql.connect(**DB_CONFIG)


def run_query(sql, params=None):
    conn = get_conn()
    try:
        return pd.read_sql(sql, conn, params=params)
    finally:
        conn.close()


def run_procedure(sql, params=None):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or [])
            conn.commit()
            if cur.description:
                columns = [item[0] for item in cur.description]
                return pd.DataFrame(cur.fetchall(), columns=columns), None
            return pd.DataFrame(), None
    except Exception as exc:
        conn.rollback()
        return pd.DataFrame(), str(exc)
    finally:
        conn.close()


def run_execute(sql, params=None):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or [])
            conn.commit()
        return None
    except Exception as exc:
        conn.rollback()
        return str(exc)
    finally:
        conn.close()


def reset_simulation_data():
    conn = get_conn()
    try:
        conn.begin()

        with conn.cursor() as cur:
            cur.execute("DELETE FROM squad_battles")
            cur.execute("DELETE FROM transfer_history")

            cur.execute("""
                UPDATE players p
                JOIN transfer_market tm
                    ON p.player_id = tm.player_id
                SET p.club_id = tm.seller_club_id,
                    p.joined_date = '2026-01-01',
                    p.contract_until = '2028-01-01'
            """)

            cur.execute("""
                UPDATE transfer_market
                SET status = 'available'
            """)

            cur.execute("""
                UPDATE clubs
                SET current_budget_eur = initial_budget_eur
            """)

            cur.execute("DELETE FROM contracts")

            cur.execute("""
                INSERT INTO contracts
                    (player_id, club_id, start_date, end_date, salary_eur, status)
                SELECT p.player_id,
                       tm.seller_club_id,
                       '2026-01-01',
                       '2028-01-01',
                       GREATEST(p.market_value_eur * 0.08, 30000),
                       'active'
                FROM players p
                JOIN transfer_market tm
                    ON p.player_id = tm.player_id
            """)

        conn.commit()
        return None

    except Exception as exc:
        conn.rollback()
        return str(exc)
    finally:
        conn.close()


def buy_player_with_release(user_id, listing_id, release_player_id):
    conn = get_conn()
    try:
        conn.begin()

        with conn.cursor(pymysql.cursors.DictCursor) as cur:
            cur.execute("""
                SELECT au.club_id AS buyer_club_id,
                       c.club_name AS buyer_club
                FROM app_users au
                JOIN clubs c
                    ON au.club_id = c.club_id
                WHERE au.user_id = %s
                FOR UPDATE
            """, (user_id,))
            buyer = cur.fetchone()

            if not buyer:
                raise ValueError("사용자를 찾을 수 없습니다.")

            buyer_club_id = int(buyer["buyer_club_id"])

            cur.execute("""
                SELECT tm.player_id,
                       tm.seller_club_id,
                       tm.asking_fee_eur,
                       tm.status,
                       p.player_name,
                       c.club_name AS seller_club
                FROM transfer_market tm
                JOIN players p
                    ON tm.player_id = p.player_id
                JOIN clubs c
                    ON tm.seller_club_id = c.club_id
                WHERE tm.listing_id = %s
                FOR UPDATE
            """, (listing_id,))
            listing = cur.fetchone()

            if not listing:
                raise ValueError("선택한 매물을 찾을 수 없습니다.")

            if listing["status"] != "available":
                raise ValueError("이미 판매되었거나 취소된 매물입니다.")

            if buyer_club_id == int(listing["seller_club_id"]):
                raise ValueError("내 구단 선수는 영입할 수 없습니다.")

            cur.execute("""
                SELECT p.player_id,
                       p.club_id,
                       p.player_name
                FROM players p
                WHERE p.player_id = %s
                FOR UPDATE
            """, (release_player_id,))
            release_player = cur.fetchone()

            if not release_player:
                raise ValueError("방출할 선수를 찾을 수 없습니다.")

            if release_player["club_id"] is None:
                raise ValueError("이미 방출된 선수입니다.")

            if buyer_club_id != int(release_player["club_id"]):
                raise ValueError("방출 선수는 내 구단 선수만 선택할 수 있습니다.")

            if int(release_player["player_id"]) == int(listing["player_id"]):
                raise ValueError("영입 선수와 방출 선수가 같을 수 없습니다.")

            cur.execute("""
                SELECT current_budget_eur
                FROM clubs
                WHERE club_id = %s
                FOR UPDATE
            """, (buyer_club_id,))
            budget_row = cur.fetchone()

            if not budget_row:
                raise ValueError("구단 예산 정보를 찾을 수 없습니다.")

            if budget_row["current_budget_eur"] < listing["asking_fee_eur"]:
                raise ValueError("예산이 부족합니다.")

            cur.execute("""
                SELECT current_budget_eur
                FROM clubs
                WHERE club_id = %s
                FOR UPDATE
            """, (listing["seller_club_id"],))

            cur.execute("""
                UPDATE contracts
                SET status = 'expired'
                WHERE player_id = %s
                  AND status = 'active'
            """, (listing["player_id"],))

            cur.execute("""
                INSERT INTO contracts
                    (player_id, club_id, start_date, end_date, salary_eur, status)
                VALUES
                    (%s, %s, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 2 YEAR), GREATEST(%s * 0.08, 30000), 'active')
            """, (listing["player_id"], buyer_club_id, listing["asking_fee_eur"]))

            cur.execute("""
                UPDATE players
                SET club_id = %s,
                    joined_date = CURDATE(),
                    contract_until = DATE_ADD(CURDATE(), INTERVAL 2 YEAR)
                WHERE player_id = %s
            """, (buyer_club_id, listing["player_id"]))

            cur.execute("""
                UPDATE clubs
                SET current_budget_eur = current_budget_eur - %s
                WHERE club_id = %s
            """, (listing["asking_fee_eur"], buyer_club_id))

            cur.execute("""
                UPDATE clubs
                SET current_budget_eur = current_budget_eur + %s
                WHERE club_id = %s
            """, (listing["asking_fee_eur"], listing["seller_club_id"]))

            cur.execute("""
                UPDATE transfer_market
                SET status = 'sold'
                WHERE listing_id = %s
            """, (listing_id,))

            cur.execute("""
                INSERT INTO transfer_history
                    (player_id, from_club_id, to_club_id, transfer_type, fee_eur, transfer_date, created_by_user_id, memo)
                VALUES
                    (%s, %s, %s, 'buy', %s, CURDATE(), %s, 'Bought with mandatory squad release')
            """, (
                listing["player_id"],
                listing["seller_club_id"],
                buyer_club_id,
                listing["asking_fee_eur"],
                user_id
            ))

            cur.execute("""
                UPDATE contracts
                SET status = 'released',
                    end_date = CURDATE()
                WHERE player_id = %s
                  AND status = 'active'
            """, (release_player_id,))

            cur.execute("""
                UPDATE transfer_market
                SET status = 'cancelled'
                WHERE player_id = %s
                  AND status = 'available'
            """, (release_player_id,))

            cur.execute("""
                UPDATE players
                SET club_id = NULL
                WHERE player_id = %s
            """, (release_player_id,))

            cur.execute("""
                INSERT INTO transfer_history
                    (player_id, from_club_id, to_club_id, transfer_type, fee_eur, transfer_date, created_by_user_id, memo)
                VALUES
                    (%s, %s, NULL, 'release', 0, CURDATE(), %s, 'Released after incoming transfer to keep squad size fixed')
            """, (release_player_id, buyer_club_id, user_id))

        conn.commit()

        result = pd.DataFrame([{
            "result_code": "BUY_AND_RELEASE_COMPLETED",
            "bought_player": listing["player_name"],
            "released_player": release_player["player_name"],
            "seller_club": listing["seller_club"],
            "buyer_club": buyer["buyer_club"],
            "fee_eur": listing["asking_fee_eur"]
        }])

        return result, None

    except Exception as exc:
        conn.rollback()
        return pd.DataFrame(), str(exc)
    finally:
        conn.close()


def safe_formation(formation):
    if formation in FORMATION_POSITIONS:
        return formation
    return "4-3-3"


def load_manager_info(club_id):
    manager_df = run_query("""
        SELECT manager_name,
               preferred_formation,
               rating
        FROM managers
        WHERE club_id = %s
    """, (club_id,))

    if manager_df.empty:
        return {
            "manager_name": "-",
            "preferred_formation": "4-3-3",
            "rating": 75
        }

    row = manager_df.iloc[0]
    return {
        "manager_name": row["manager_name"],
        "preferred_formation": safe_formation(row["preferred_formation"]),
        "rating": float(row["rating"])
    }


def load_squad_for_score(club_id):
    return run_query("""
        SELECT p.player_id,
               p.player_name,
               p.position_group,
               p.primary_position,
               ps.pace,
               ps.shooting,
               ps.passing,
               ps.defending,
               ps.physical,
               ps.overall
        FROM players p
        JOIN player_stats ps
            ON p.player_id = ps.player_id
        WHERE p.club_id = %s
        ORDER BY FIELD(p.position_group, 'GK', 'DF', 'MF', 'FW'),
                 ps.overall DESC
    """, (club_id,))


def slot_detail_bonus(primary_position, slot):
    position = str(primary_position).lower()
    slot = slot.upper()

    if slot == "GK" and "goalkeeper" in position:
        return 4
    if slot in ["CB", "LCB", "RCB"] and "centre-back" in position:
        return 4
    if slot in ["LB", "LWB"] and "left-back" in position:
        return 4
    if slot in ["RB", "RWB"] and "right-back" in position:
        return 4
    if slot in ["CM", "LCM", "RCM"] and "central midfield" in position:
        return 4
    if slot in ["LDM", "RDM"] and "defensive midfield" in position:
        return 4
    if slot in ["CAM", "LAM", "RAM"] and "attacking midfield" in position:
        return 4
    if slot in ["LW", "LM"] and "left winger" in position:
        return 4
    if slot in ["RW", "RM"] and "right winger" in position:
        return 4
    if slot in ["ST", "LS", "RS"] and ("centre-forward" in position or "second striker" in position):
        return 4
    return 0


def group_penalty(player_group, slot_group):
    if player_group == slot_group:
        return 0
    if player_group == "GK" or slot_group == "GK":
        return 32
    if {player_group, slot_group} == {"DF", "MF"}:
        return 8
    if {player_group, slot_group} == {"MF", "FW"}:
        return 9
    return 18


def calculate_slot_score(player_row, slot_info):
    weights = ROLE_ATTRIBUTE_WEIGHTS[slot_info["group"]]
    weighted_score = sum(
        float(player_row[attr]) * weight
        for attr, weight in weights.items()
    )
    score = (
        weighted_score
        + slot_detail_bonus(player_row["primary_position"], slot_info["slot"])
        - group_penalty(player_row["position_group"], slot_info["group"])
    )
    return round(max(1, min(99, score)), 2)


def recommend_lineup_for_formation(squad_df, formation):
    positions = FORMATION_POSITIONS[safe_formation(formation)]
    rows = {
        int(row["player_id"]): row
        for _, row in squad_df.iterrows()
    }
    remaining_ids = set(rows.keys())
    lineup = {}

    for pos in positions:
        same_group_ids = [
            player_id
            for player_id in remaining_ids
            if rows[player_id]["position_group"] == pos["group"]
        ]
        candidate_ids = same_group_ids or list(remaining_ids)
        if not candidate_ids:
            lineup[pos["slot"]] = None
            continue

        selected_id = max(
            candidate_ids,
            key=lambda player_id: calculate_slot_score(rows[player_id], pos)
        )
        lineup[pos["slot"]] = selected_id
        remaining_ids.remove(selected_id)

    return lineup


def calculate_team_score(squad_df, formation, lineup, manager_rating):
    positions = FORMATION_POSITIONS[safe_formation(formation)]
    rows = {
        int(row["player_id"]): row
        for _, row in squad_df.iterrows()
    }

    slot_scores = []
    natural_count = 0
    selected_count = 0
    selected_ids = set()

    for pos in positions:
        player_id = lineup.get(pos["slot"])
        if player_id is None or int(player_id) not in rows or int(player_id) in selected_ids:
            continue

        player_id = int(player_id)
        row = rows[player_id]
        selected_ids.add(player_id)
        selected_count += 1
        slot_scores.append(calculate_slot_score(row, pos))

        if row["position_group"] == pos["group"]:
            natural_count += 1

    avg_slot_score = sum(slot_scores) / len(slot_scores) if slot_scores else 0
    formation_fit = natural_count / 11 * 100
    completion = selected_count / 11 * 100
    total_score = (
        avg_slot_score * 0.70
        + formation_fit * 0.15
        + float(manager_rating) * 0.10
        + completion * 0.05
    )

    return {
        "total_score": round(total_score, 2),
        "avg_slot_score": round(avg_slot_score, 2),
        "formation_fit": round(formation_fit, 2),
        "completion": round(completion, 2),
        "selected_count": selected_count,
        "natural_count": natural_count,
    }


def save_squad_battle(home_club_id, away_club_id, home_score, away_score):
    if home_score > away_score:
        result = "home"
    elif away_score > home_score:
        result = "away"
    else:
        result = "draw"

    err = run_execute("""
        INSERT INTO squad_battles
            (home_club_id, away_club_id, home_score, away_score, result, battle_date)
        VALUES
            (%s, %s, %s, %s, %s, CURDATE())
    """, (home_club_id, away_club_id, home_score, away_score, result))

    return result, err


def format_eur(value):
    return f"EUR {float(value):,.0f}"


def inject_global_styles():
    st.markdown("""
    <style>
    :root {
        --dbpbl-bg: #07110d;
        --dbpbl-panel: #0d1713;
        --dbpbl-panel-soft: #111c17;
        --dbpbl-green: #087333;
        --dbpbl-green-soft: #0f8f45;
        --dbpbl-gold: #f5c400;
        --dbpbl-line: rgba(245, 196, 0, 0.28);
        --dbpbl-text: #f8fafc;
        --dbpbl-muted: #cbd5e1;
    }

    html,
    body,
    .stApp {
        color-scheme: dark;
    }

    .stApp {
        background:
            radial-gradient(circle at top left, rgba(8, 115, 51, 0.22), transparent 34rem),
            linear-gradient(180deg, #08110d 0%, #090d12 48%, #080b10 100%);
        color: var(--dbpbl-text);
    }

    header[data-testid="stHeader"] {
        background: transparent !important;
        height: 2.75rem !important;
    }

    [data-testid="stDecoration"],
    [data-testid="stStatusWidget"],
    #MainMenu {
        display: none !important;
        visibility: hidden !important;
        height: 0 !important;
    }

    [data-testid="stToolbar"] {
        background: transparent !important;
    }

    [data-testid="stToolbar"] button[aria-label="Deploy"],
    [data-testid="stToolbar"] button[aria-label="Main menu"],
    [data-testid="stToolbar"] [data-testid="stDeployButton"],
    [data-testid="stToolbar"] [data-testid="baseButton-header"],
    [data-testid="stToolbar"] [data-testid="stBaseButton-header"] {
        display: none !important;
        visibility: hidden !important;
    }

    [data-testid="collapsedControl"],
    [data-testid="stSidebarCollapsedControl"] {
        display: flex !important;
        visibility: visible !important;
        color: #f8fafc !important;
    }

    .block-container {
        padding-top: 1.4rem;
        padding-bottom: 3rem;
        max-width: 1320px;
    }

    [data-testid="stSidebar"] {
        background: linear-gradient(180deg, #06110c 0%, #0d1713 100%);
        border-right: 1px solid rgba(245, 196, 0, 0.18);
    }

    [data-testid="stSidebar"] [data-testid="stMetric"] {
        background: rgba(255, 255, 255, 0.045);
        border: 1px solid rgba(245, 196, 0, 0.16);
        border-radius: 12px;
        padding: 0.7rem 0.8rem;
    }

    [data-testid="stSidebar"] label,
    [data-testid="stSidebar"] p {
        color: #e5e7eb;
    }

    .dbpbl-sidebar-card {
        background: linear-gradient(180deg, rgba(17, 28, 23, 0.98), rgba(10, 18, 15, 0.98));
        border: 1px solid rgba(245, 196, 0, 0.18);
        border-radius: 12px;
        padding: 0.85rem 0.95rem;
        margin: 0.75rem 0;
    }

    .dbpbl-sidebar-card span {
        display: block;
        color: #cbd5e1;
        font-size: 0.8rem;
        font-weight: 800;
        margin-bottom: 0.35rem;
    }

    .dbpbl-sidebar-card strong {
        display: block;
        color: #f8fafc;
        font-size: 1.05rem;
        font-weight: 900;
        line-height: 1.25;
        white-space: normal;
        word-break: keep-all;
    }

    .dbpbl-sidebar-card strong.dbpbl-budget {
        font-size: 1.45rem;
    }

    h1, h2, h3 {
        letter-spacing: 0;
    }

    h2, h3 {
        color: #f8fafc;
    }

    hr {
        border-color: rgba(245, 196, 0, 0.18);
        margin: 1.4rem 0;
    }

    .dbpbl-hero {
        position: relative;
        overflow: hidden;
        border: 1px solid rgba(245, 196, 0, 0.42);
        border-radius: 18px;
        padding: 28px 30px;
        margin: 0.3rem 0 1.35rem 0;
        background:
            linear-gradient(135deg, rgba(8, 115, 51, 0.95), rgba(9, 20, 16, 0.98) 58%, rgba(6, 13, 18, 0.98)),
            repeating-linear-gradient(90deg, rgba(255,255,255,0.06), rgba(255,255,255,0.06) 1px, transparent 1px, transparent 96px);
        box-shadow: 0 22px 50px rgba(0, 0, 0, 0.35);
    }

    .dbpbl-hero::after {
        content: "";
        position: absolute;
        width: 340px;
        height: 340px;
        border: 1px solid rgba(245, 196, 0, 0.22);
        border-radius: 50%;
        right: -118px;
        top: -138px;
    }

    .dbpbl-eyebrow {
        color: var(--dbpbl-gold);
        font-size: 0.78rem;
        font-weight: 900;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        margin-bottom: 0.35rem;
    }

    .dbpbl-hero h1 {
        color: white;
        font-size: clamp(2.15rem, 4.2vw, 4.1rem);
        line-height: 1.05;
        margin: 0;
        font-weight: 950;
    }

    .dbpbl-hero p {
        color: #e5e7eb;
        font-size: 1.02rem;
        margin: 0.8rem 0 1.2rem;
        max-width: 820px;
    }

    .dbpbl-hero-stats,
    .dbpbl-stat-grid {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 12px;
    }

    .dbpbl-hero-chip,
    .dbpbl-stat-card {
        background: rgba(8, 14, 12, 0.72);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 14px;
        padding: 13px 15px;
        backdrop-filter: blur(8px);
    }

    .dbpbl-hero-chip span,
    .dbpbl-stat-card span {
        display: block;
        color: var(--dbpbl-muted);
        font-size: 0.78rem;
        font-weight: 700;
        margin-bottom: 0.25rem;
    }

    .dbpbl-hero-chip strong,
    .dbpbl-stat-card strong {
        display: block;
        color: white;
        font-size: 1.08rem;
        font-weight: 900;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .dbpbl-stat-grid {
        margin: 0.4rem 0 1.4rem;
    }

    .dbpbl-stat-card {
        background: linear-gradient(180deg, rgba(17, 28, 23, 0.98), rgba(10, 18, 15, 0.98));
        border: 1px solid rgba(245, 196, 0, 0.18);
        box-shadow: 0 14px 28px rgba(0, 0, 0, 0.24);
    }

    .dbpbl-stat-card small {
        color: #9ca3af;
        display: block;
        margin-top: 0.35rem;
        font-size: 0.74rem;
    }

    div[data-testid="stMetric"] {
        background: linear-gradient(180deg, rgba(17, 28, 23, 0.98), rgba(10, 18, 15, 0.98));
        border: 1px solid rgba(245, 196, 0, 0.20);
        border-radius: 14px;
        padding: 0.8rem 0.95rem;
        box-shadow: 0 10px 24px rgba(0, 0, 0, 0.18);
    }

    div[data-testid="stMetric"] label,
    div[data-testid="stMetric"] [data-testid="stMetricValue"],
    div[data-testid="stMetric"] [data-testid="stMetricDelta"] {
        color: #f8fafc;
    }

    .stButton > button {
        border-radius: 10px;
        border: 1px solid rgba(245, 196, 0, 0.45);
        background: linear-gradient(180deg, #f7d34b 0%, #f5c400 100%);
        color: #07110d;
        font-weight: 900;
        box-shadow: 0 10px 22px rgba(245, 196, 0, 0.18);
        transition: transform 120ms ease, box-shadow 120ms ease, border-color 120ms ease;
    }

    .stButton > button:hover {
        transform: translateY(-1px);
        border-color: rgba(255, 255, 255, 0.7);
        box-shadow: 0 14px 28px rgba(245, 196, 0, 0.24);
    }

    .stButton > button:disabled {
        background: #26332d;
        color: #94a3b8;
        border-color: rgba(148, 163, 184, 0.28);
        box-shadow: none;
    }

    [data-testid="stDataFrame"] {
        border: 1px solid rgba(255, 255, 255, 0.10);
        border-radius: 14px;
        overflow: hidden;
        box-shadow: 0 16px 32px rgba(0, 0, 0, 0.22);
    }

    div[data-baseweb="select"] > div,
    [data-testid="stTextInput"] input {
        background-color: #111c17;
        border-color: rgba(245, 196, 0, 0.24);
        border-radius: 10px;
    }

    [data-testid="stAlert"] {
        border-radius: 12px;
        border: 1px solid rgba(245, 196, 0, 0.18);
    }

    .dbpbl-section-card {
        background: linear-gradient(180deg, rgba(17, 28, 23, 0.92), rgba(8, 14, 12, 0.94));
        border: 1px solid rgba(245, 196, 0, 0.16);
        border-radius: 14px;
        padding: 16px 18px;
        margin: 0.65rem 0 1rem;
        box-shadow: 0 14px 28px rgba(0, 0, 0, 0.18);
    }

    .dbpbl-section-card h4 {
        color: #f8fafc;
        font-size: 1rem;
        font-weight: 900;
        margin: 0 0 0.7rem;
    }

    .dbpbl-player-title {
        color: white;
        font-size: 1.22rem;
        font-weight: 950;
        line-height: 1.18;
        margin-bottom: 0.35rem;
        word-break: keep-all;
    }

    .dbpbl-player-meta {
        color: #cbd5e1;
        font-size: 0.86rem;
        margin-bottom: 0.7rem;
    }

    .dbpbl-badge-row {
        display: flex;
        flex-wrap: wrap;
        gap: 7px;
        margin-top: 0.65rem;
    }

    .dbpbl-badge {
        display: inline-flex;
        align-items: center;
        min-height: 28px;
        padding: 5px 9px;
        border-radius: 999px;
        background: rgba(245, 196, 0, 0.11);
        border: 1px solid rgba(245, 196, 0, 0.22);
        color: #f8fafc;
        font-size: 0.78rem;
        font-weight: 800;
    }

    .dbpbl-delta-positive {
        color: #86efac;
    }

    .dbpbl-delta-negative {
        color: #fca5a5;
    }

    .dbpbl-delta-neutral {
        color: #e5e7eb;
    }

    .dbpbl-empty {
        border: 1px dashed rgba(245, 196, 0, 0.30);
        border-radius: 14px;
        padding: 20px;
        color: #cbd5e1;
        background: rgba(8, 14, 12, 0.58);
        text-align: center;
        margin: 0.7rem 0 1.2rem;
    }

    .dbpbl-empty strong {
        display: block;
        color: #f8fafc;
        font-size: 1.05rem;
        margin-bottom: 0.3rem;
    }

    .dbpbl-analysis-list {
        margin: 0.2rem 0 0;
        padding-left: 1rem;
        color: #d1d5db;
    }

    .dbpbl-analysis-list li {
        margin: 0.35rem 0;
    }

    @media (max-width: 900px) {
        .dbpbl-hero-stats,
        .dbpbl-stat-grid {
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }

        .dbpbl-hero {
            padding: 22px;
        }
    }

    @media (max-width: 560px) {
        .dbpbl-hero-stats,
        .dbpbl-stat-grid {
            grid-template-columns: 1fr;
        }
    }
    </style>
    """, unsafe_allow_html=True)


def render_app_header(page, club_name, budget):
    st.markdown(f"""
    <section class="dbpbl-hero">
        <div class="dbpbl-eyebrow">K LEAGUE TRANSFER SIMULATOR DB</div>
        <h1>K리그 이적시장 시뮬레이터</h1>
        <p>선수 영입, 의무 방출, 포메이션 배치, 스쿼드 배틀을 한 화면 흐름으로 관리합니다.</p>
        <div class="dbpbl-hero-stats">
            <div class="dbpbl-hero-chip">
                <span>현재 메뉴</span>
                <strong>{html.escape(str(page))}</strong>
            </div>
            <div class="dbpbl-hero-chip">
                <span>선택 구단</span>
                <strong>{html.escape(str(club_name))}</strong>
            </div>
            <div class="dbpbl-hero-chip">
                <span>현재 예산</span>
                <strong>{format_eur(budget)}</strong>
            </div>
            <div class="dbpbl-hero-chip">
                <span>운영 규칙</span>
                <strong>영입 시 1명 방출</strong>
            </div>
        </div>
    </section>
    """, unsafe_allow_html=True)


def render_stat_card(label, value, caption):
    st.markdown(f"""
    <div class="dbpbl-stat-card">
        <span>{html.escape(str(label))}</span>
        <strong>{html.escape(str(value))}</strong>
        <small>{html.escape(str(caption))}</small>
    </div>
    """, unsafe_allow_html=True)


def render_empty_state(title, message):
    st.markdown(f"""
    <div class="dbpbl-empty">
        <strong>{html.escape(str(title))}</strong>
        {html.escape(str(message))}
    </div>
    """, unsafe_allow_html=True)


def render_player_card(title, row, fee=None):
    if row is None:
        render_empty_state(title, "선수를 선택하면 상세 정보가 표시됩니다.")
        return

    fee_html = ""
    if fee is not None:
        fee_html = f'<span class="dbpbl-badge">{format_eur(fee)}</span>'

    st.markdown(f"""
    <div class="dbpbl-section-card">
        <h4>{html.escape(str(title))}</h4>
        <div class="dbpbl-player-title">{html.escape(str(row["player_name"]))}</div>
        <div class="dbpbl-player-meta">
            {html.escape(str(row["position_group"]))} / {html.escape(str(row["primary_position"]))}
        </div>
        <div class="dbpbl-badge-row">
            <span class="dbpbl-badge">OVR {float(row["overall"]):.2f}</span>
            <span class="dbpbl-badge">속도 {float(row["pace"]):.0f}</span>
            <span class="dbpbl-badge">슈팅 {float(row["shooting"]):.0f}</span>
            <span class="dbpbl-badge">패스 {float(row["passing"]):.0f}</span>
            <span class="dbpbl-badge">수비 {float(row["defending"]):.0f}</span>
            <span class="dbpbl-badge">피지컬 {float(row["physical"]):.0f}</span>
            {fee_html}
        </div>
    </div>
    """, unsafe_allow_html=True)


def render_delta_card(label, before, after, suffix=""):
    delta = float(after) - float(before)
    if delta > 0:
        delta_class = "dbpbl-delta-positive"
        delta_text = f"+{delta:.2f}{suffix}"
    elif delta < 0:
        delta_class = "dbpbl-delta-negative"
        delta_text = f"{delta:.2f}{suffix}"
    else:
        delta_class = "dbpbl-delta-neutral"
        delta_text = f"0.00{suffix}"

    st.markdown(f"""
    <div class="dbpbl-stat-card">
        <span>{html.escape(str(label))}</span>
        <strong>{float(before):.2f}{suffix} → {float(after):.2f}{suffix}</strong>
        <small class="{delta_class}">변화 {delta_text}</small>
    </div>
    """, unsafe_allow_html=True)


st.set_page_config(
    page_title="K리그 이적시장 시뮬레이터",
    page_icon="⚽",
    layout="wide"
)

inject_global_styles()

users_df = run_query("""
    SELECT u.user_id,
           u.username,
           c.club_id,
           c.club_name,
           c.current_budget_eur
    FROM app_users u
    JOIN clubs c
        ON u.club_id = c.club_id
    ORDER BY c.club_name
""")

if users_df.empty:
    st.error("사용자를 찾을 수 없습니다. 먼저 SQL 파일을 실행하세요.")
    st.stop()

# =========================
# 감독 표시명 한글화
# =========================
display_name_map = {
    "manager_fc_seoul": "FC 서울 감독",
    "manager_ulsan_hd_fc": "울산 HD 감독",
    "manager_jeonbuk_hyundai_motors": "전북 현대 감독",
    "manager_gangwon_fc": "강원 FC 감독",
    "manager_pohang_steelers": "포항 스틸러스 감독",
    "manager_incheon_united": "인천 유나이티드 감독",
    "manager_fc_anyang": "FC 안양 감독",
    "manager_jeju_sk": "제주 SK 감독",
    "manager_bucheon_fc_1995": "부천 FC 1995 감독",
    "manager_daejeon_hana_citizen": "대전 하나 시티즌 감독",
    "manager_gimcheon_sangmu": "김천 상무 감독",
    "manager_gwangju_fc": "광주 FC 감독"
}

users_df["display_name"] = users_df["username"].map(display_name_map)

# =========================
# 사이드바 사용자 선택
# =========================
user_options = {
    f"{row.display_name} / {row.club_name}": int(row.user_id)
    for row in users_df.itertuples()
}

selected_user_label = st.sidebar.selectbox(
    "사용자 / 구단 선택",
    list(user_options.keys())
)

selected_user_id = user_options[selected_user_label]

my_row = users_df[
    users_df["user_id"] == selected_user_id
].iloc[0]

my_club_id = int(my_row["club_id"])
my_club_name = my_row["club_name"]
my_budget = float(my_row["current_budget_eur"])

st.sidebar.markdown(f"""
<div class="dbpbl-sidebar-card">
    <span>선택된 구단</span>
    <strong>{html.escape(str(my_club_name))}</strong>
</div>
<div class="dbpbl-sidebar-card">
    <span>현재 예산 (EUR)</span>
    <strong class="dbpbl-budget">{float(my_budget):,.0f}</strong>
</div>
""", unsafe_allow_html=True)

page = st.sidebar.radio(
    "메뉴",
    ["대시보드", "내 스쿼드", "이적 시장", "스쿼드 배틀", "기록"]
)

st.sidebar.markdown("---")

if st.sidebar.button("시뮬레이션 초기화"):

    err = reset_simulation_data()

    if err:
        st.sidebar.error(err)
    else:
        for key in list(st.session_state.keys()):
            if key.startswith("lineup_") or key == "transfer_result":
                del st.session_state[key]

        st.sidebar.success("초기화 완료!")
        st.rerun()

render_app_header(page, my_club_name, my_budget)

if page == "대시보드":

    summary_df = run_query("""
        SELECT
            (SELECT COUNT(*) FROM clubs) AS club_count,
            (SELECT COUNT(*) FROM players WHERE club_id IS NOT NULL) AS registered_players,
            (SELECT COUNT(*) FROM transfer_market WHERE status = 'available') AS available_listings,
            (SELECT COUNT(*) FROM squad_battles) AS battle_count
    """)
    summary = summary_df.iloc[0]

    stat_cols = st.columns(4)
    with stat_cols[0]:
        render_stat_card("등록 구단", f"{int(summary['club_count'])}개", "현재 시뮬레이션 참가 팀")
    with stat_cols[1]:
        render_stat_card("등록 선수", f"{int(summary['registered_players'])}명", "소속 구단이 있는 선수")
    with stat_cols[2]:
        render_stat_card("이적시장 매물", f"{int(summary['available_listings'])}명", "영입 가능한 선수")
    with stat_cols[3]:
        render_stat_card("스쿼드 배틀", f"{int(summary['battle_count'])}경기", "저장된 배틀 기록")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("스쿼드 점수 랭킹")

        st.dataframe(
            run_query("""
                SELECT club_name,
                       manager_name,
                       preferred_formation,
                       player_count,
                       avg_player_overall,
                       manager_rating,
                       squad_score
                FROM v_squad_score
                ORDER BY squad_score DESC
            """),
            use_container_width=True,
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

    with col2:
        st.subheader("구단별 예산 현황")

        st.dataframe(
            run_query("""
                SELECT club_name,
                       initial_budget_eur,
                       current_budget_eur,
                       total_spent_eur
                FROM v_club_budget
                ORDER BY current_budget_eur DESC
            """),
            use_container_width=True,
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

    st.subheader("포지션별 뎁스")

    st.dataframe(
        run_query("""
            SELECT club_name,
                   position_group,
                   player_count,
                   avg_overall
            FROM v_position_depth
            ORDER BY club_name,
                     FIELD(position_group, 'GK', 'DF', 'MF', 'FW')
        """),
        use_container_width=True,
        hide_index=True,
        column_config=COLUMN_MAPPING
    )

elif page == "내 스쿼드":

    st.subheader(f"{my_club_name} 스쿼드 현황")
    
    formation_df = run_query("""
    SELECT preferred_formation
    FROM managers
    WHERE club_id = %s
""", (my_club_id,))


    squad_df = run_query("""
        SELECT player_id,
               player_name,
               position_group,
               primary_position,
               nationality,
               market_value_eur,
               appearances,
               goals,
               assists,
               pace,
               shooting,
               passing,
               defending,
               physical,
               overall
        FROM v_player_info
        WHERE club_name = %s
        ORDER BY FIELD(position_group, 'GK', 'DF', 'MF', 'FW'),
                 overall DESC
    """, (my_club_name,))

    st.dataframe(
        squad_df.drop(columns=["player_id"]),
        use_container_width=True,
        hide_index=True,
        column_config=COLUMN_MAPPING
    )

    # =========================
    # 전술 배치도
    # =========================

    st.markdown("---")

    # DB에서 조회한 감독의 선호 포메이션 적용 (데이터가 없을 경우 기본값 '4-3-3')
    db_formation = "4-3-3"
    if not formation_df.empty:
        db_formation = formation_df.iloc[0]["preferred_formation"]

    st.subheader("전술 배치도")

    formation_positions = {
        "4-3-3": [
            {"slot": "GK", "group": "GK", "x": 50, "y": 88},
            {"slot": "LB", "group": "DF", "x": 15, "y": 72},
            {"slot": "LCB", "group": "DF", "x": 38, "y": 72},
            {"slot": "RCB", "group": "DF", "x": 62, "y": 72},
            {"slot": "RB", "group": "DF", "x": 85, "y": 72},
            {"slot": "LCM", "group": "MF", "x": 29, "y": 54},
            {"slot": "CM", "group": "MF", "x": 50, "y": 42},
            {"slot": "RCM", "group": "MF", "x": 71, "y": 54},
            {"slot": "LW", "group": "FW", "x": 18, "y": 22},
            {"slot": "ST", "group": "FW", "x": 50, "y": 15},
            {"slot": "RW", "group": "FW", "x": 82, "y": 22},
        ],
        "4-3-2-1": [
            {"slot": "GK", "group": "GK", "x": 50, "y": 88},
            {"slot": "LB", "group": "DF", "x": 15, "y": 72},
            {"slot": "LCB", "group": "DF", "x": 38, "y": 72},
            {"slot": "RCB", "group": "DF", "x": 62, "y": 72},
            {"slot": "RB", "group": "DF", "x": 85, "y": 72},
            {"slot": "LCM", "group": "MF", "x": 28, "y": 57},
            {"slot": "CM", "group": "MF", "x": 50, "y": 45},
            {"slot": "RCM", "group": "MF", "x": 72, "y": 57},
            {"slot": "LAM", "group": "MF", "x": 38, "y": 30},
            {"slot": "RAM", "group": "MF", "x": 62, "y": 30},
            {"slot": "ST", "group": "FW", "x": 50, "y": 15},
        ],
        "4-2-3-1": [
            {"slot": "GK", "group": "GK", "x": 50, "y": 88},
            {"slot": "LB", "group": "DF", "x": 15, "y": 72},
            {"slot": "LCB", "group": "DF", "x": 38, "y": 72},
            {"slot": "RCB", "group": "DF", "x": 62, "y": 72},
            {"slot": "RB", "group": "DF", "x": 85, "y": 72},
            {"slot": "LDM", "group": "MF", "x": 35, "y": 58},
            {"slot": "RDM", "group": "MF", "x": 65, "y": 58},
            {"slot": "LAM", "group": "MF", "x": 20, "y": 38},
            {"slot": "CAM", "group": "MF", "x": 50, "y": 32},
            {"slot": "RAM", "group": "MF", "x": 80, "y": 38},
            {"slot": "ST", "group": "FW", "x": 50, "y": 15},
        ],
        "4-4-2": [
            {"slot": "GK", "group": "GK", "x": 50, "y": 88},
            {"slot": "LB", "group": "DF", "x": 15, "y": 72},
            {"slot": "LCB", "group": "DF", "x": 38, "y": 72},
            {"slot": "RCB", "group": "DF", "x": 62, "y": 72},
            {"slot": "RB", "group": "DF", "x": 85, "y": 72},
            {"slot": "LM", "group": "MF", "x": 15, "y": 45},
            {"slot": "LCM", "group": "MF", "x": 38, "y": 50},
            {"slot": "RCM", "group": "MF", "x": 62, "y": 50},
            {"slot": "RM", "group": "MF", "x": 85, "y": 45},
            {"slot": "LS", "group": "FW", "x": 38, "y": 20},
            {"slot": "RS", "group": "FW", "x": 62, "y": 20},
        ],
        "3-5-2": [
            {"slot": "GK", "group": "GK", "x": 50, "y": 88},
            {"slot": "LCB", "group": "DF", "x": 28, "y": 72},
            {"slot": "CB", "group": "DF", "x": 50, "y": 75},
            {"slot": "RCB", "group": "DF", "x": 72, "y": 72},
            {"slot": "LWB", "group": "MF", "x": 12, "y": 50},
            {"slot": "LCM", "group": "MF", "x": 32, "y": 58},
            {"slot": "CM", "group": "MF", "x": 50, "y": 43},
            {"slot": "RCM", "group": "MF", "x": 68, "y": 58},
            {"slot": "RWB", "group": "MF", "x": 88, "y": 50},
            {"slot": "LS", "group": "FW", "x": 38, "y": 20},
            {"slot": "RS", "group": "FW", "x": 62, "y": 20},
        ],
    }

    formation_names = list(formation_positions.keys())
    if db_formation not in formation_positions:
        db_formation = "4-3-3"

    formation = st.selectbox(
        "포메이션 선택",
        formation_names,
        index=formation_names.index(db_formation)
    )

    current_positions = formation_positions[formation]

    player_rows = {
        int(row["player_id"]): row
        for _, row in squad_df.iterrows()
    }

    def select_label(player_id):
        if player_id is None:
            return "선수 선택 안 함"
        row = player_rows[int(player_id)]
        return f"{row['player_name']} | {row['position_group']} | OVR {row['overall']}"

    def recommended_lineup():
        remaining_ids = set(player_rows.keys())
        lineup = {}

        for pos in current_positions:
            same_group_ids = [
                player_id
                for player_id in remaining_ids
                if player_rows[player_id]["position_group"] == pos["group"]
            ]
            candidate_ids = same_group_ids or list(remaining_ids)
            if not candidate_ids:
                lineup[pos["slot"]] = None
                continue

            selected_id = max(
                candidate_ids,
                key=lambda player_id: calculate_slot_score(player_rows[player_id], pos)
            )
            lineup[pos["slot"]] = selected_id
            remaining_ids.remove(selected_id)

        return lineup

    lineup_key = f"lineup_{my_club_id}_{formation}"
    if lineup_key not in st.session_state:
        st.session_state[lineup_key] = recommended_lineup()

    col_a, col_b, col_c = st.columns([1, 1, 1])
    with col_a:
        if st.button("추천 배치"):
            st.session_state[lineup_key] = recommended_lineup()
            for pos in current_positions:
                st.session_state[f"{lineup_key}_{pos['slot']}"] = st.session_state[lineup_key].get(pos["slot"])
            st.rerun()
    with col_b:
        if st.button("배치 비우기"):
            st.session_state[lineup_key] = {
                pos["slot"]: None
                for pos in current_positions
            }
            for pos in current_positions:
                st.session_state[f"{lineup_key}_{pos['slot']}"] = None
            st.rerun()
    with col_c:
        if st.button("포메이션 저장"):
            conn = get_conn()
            cur = conn.cursor()
            cur.execute("""
                UPDATE managers
                SET preferred_formation = %s
                WHERE club_id = %s
            """, (formation, my_club_id))
            conn.commit()
            cur.close()
            conn.close()
            st.success("포메이션이 저장되었습니다.")
            st.rerun()

    st.markdown("##### 포지션별 선수 선택")
    selector_columns = st.columns(4)
    all_player_ids = list(player_rows.keys())

    for idx, pos in enumerate(current_positions):
        slot = pos["slot"]
        current_lineup = st.session_state[lineup_key]
        selected_elsewhere = {
            int(player_id)
            for other_slot, player_id in current_lineup.items()
            if other_slot != slot and player_id is not None
        }

        options = [None]
        same_group_options = [
            player_id
            for player_id in all_player_ids
            if player_rows[player_id]["position_group"] == pos["group"]
               and player_id not in selected_elsewhere
        ]
        other_options = [
            player_id
            for player_id in all_player_ids
            if player_rows[player_id]["position_group"] != pos["group"]
               and player_id not in selected_elsewhere
        ]
        options.extend(same_group_options + other_options)

        current_value = current_lineup.get(slot)
        if current_value not in options:
            current_value = None
            current_lineup[slot] = None

        with selector_columns[idx % 4]:
            current_lineup[slot] = st.selectbox(
                f"{slot} ({pos['group']})",
                options,
                index=options.index(current_value),
                format_func=select_label,
                key=f"{lineup_key}_{slot}"
            )

    manager_info = load_manager_info(my_club_id)
    lineup_metrics = calculate_team_score(
        squad_df,
        formation,
        st.session_state[lineup_key],
        manager_info["rating"]
    )

    metric_cols = st.columns(4)
    metric_cols[0].metric("현재 배치 팀점수", f"{lineup_metrics['total_score']:.2f}")
    metric_cols[1].metric("선수 배치 평균", f"{lineup_metrics['avg_slot_score']:.2f}")
    metric_cols[2].metric("포메이션 적합도", f"{lineup_metrics['formation_fit']:.1f}%")
    metric_cols[3].metric("배치 완료", f"{lineup_metrics['selected_count']}/11")

    st.caption(
        "점수 = 선수 배치 평균 70% + 포메이션 적합도 15% + 감독 능력치 10% + 11명 완성도 5%"
    )

    pitch_html = """
    <div style="
    position:relative;
    width:min(92vw,760px);
    height:900px;
    background:
        linear-gradient(90deg, rgba(255,255,255,0.045) 0 8%, transparent 8% 16%),
        linear-gradient(180deg, #087333 0%, #06662d 45%, #075a28 100%);
    background-size:160px 100%, 100% 100%;
    border:4px solid rgba(255,255,255,0.92);
    outline:2px solid rgba(245,196,0,0.58);
    margin:18px auto 0;
    border-radius:18px;
    overflow:hidden;
    box-shadow:0 28px 70px rgba(0,0,0,0.34);
    ">

    <div style="
    position:absolute;
    left:0;
    top:50%;
    width:100%;
    height:2px;
    background:white;
    "></div>

    <div style="
    position:absolute;
    left:50%;
    top:7%;
    transform:translateX(-50%);
    width:36%;
    height:14%;
    border:2px solid rgba(255,255,255,0.9);
    border-top:0;
    border-radius:0 0 18px 18px;
    "></div>

    <div style="
    position:absolute;
    left:50%;
    bottom:7%;
    transform:translateX(-50%);
    width:36%;
    height:14%;
    border:2px solid rgba(255,255,255,0.9);
    border-bottom:0;
    border-radius:18px 18px 0 0;
    "></div>

    <div style="
    position:absolute;
    top:50%;
    left:50%;
    transform:translate(-50%,-50%);
    width:120px;
    height:120px;
    border:2px solid white;
    border-radius:50%;
    "></div>
    """

    for pos in current_positions:
        x = pos["x"]
        y = pos["y"]
        slot = pos["slot"]
        player_id = st.session_state[lineup_key].get(slot)

        if player_id is None:
            player_name = "선수 선택"
            position_score = pos["group"]
            border_style = "2px dashed gold"
        else:
            row = player_rows[int(player_id)]
            display_name = str(row["player_name"])
            if len(display_name) > 18:
                display_name = display_name[:17] + "..."
            player_name = html.escape(display_name)
            position_score = f"배치 {calculate_slot_score(row, pos):.1f}"
            border_style = "2px solid gold"

        pitch_html += f"""
        <div style="
        position:absolute;
        left:{x}%;
        top:{y}%;
        transform:translate(-50%,-50%);
        background:linear-gradient(180deg,#152033 0%,#0d1422 100%);
        color:white;
        padding:8px;
        border-radius:12px;
        width:112px;
        height:82px;
        box-sizing:border-box;
        overflow:hidden;
        text-align:center;
        font-size:11px;
        line-height:1.18;
        border:{border_style};
        box-shadow:0 12px 22px rgba(0,0,0,0.44);
        ">
        <b style="color:#f5c400;font-size:12px;">{slot}</b><br>
        {player_name}<br>
        <span style="color:#d1d5db;">{position_score}</span>
        </div>
        """

    pitch_html += "</div>"

    components.html(pitch_html, height=950)
    
    

elif page == "이적 시장":

    st.subheader("영입 가능한 선수 목록")

    if "transfer_result" in st.session_state:
        transfer_result = pd.DataFrame([st.session_state.pop("transfer_result")])
        st.success("이적 계약과 선수 방출이 함께 완료되었습니다.")
        st.dataframe(
            transfer_result,
            use_container_width=True,
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

    market_df = run_query("""
        SELECT vm.listing_id,
               vm.player_id,
               vm.player_name,
               vm.position_group,
               vm.primary_position,
               vm.nationality,
               vm.overall,
               vm.seller_club,
               vm.asking_fee_eur,
               ps.pace,
               ps.shooting,
               ps.passing,
               ps.defending,
               ps.physical
        FROM v_transfer_market vm
        JOIN player_stats ps
            ON vm.player_id = ps.player_id
        WHERE vm.seller_club_id <> %s
        ORDER BY vm.overall DESC,
                 vm.asking_fee_eur DESC
    """, (my_club_id,))

    if market_df.empty:
        render_empty_state("영입 가능한 매물이 없습니다", "초기화 후 다시 확인하거나 다른 구단을 선택해 주세요.")
        filtered_market_df = market_df
    else:
        filter_cols = st.columns([1.35, 0.75, 1, 1])
        with filter_cols[0]:
            keyword = st.text_input(
                "선수 검색",
                placeholder="선수명, 판매 구단, 세부 포지션"
            ).strip().lower()
        with filter_cols[1]:
            position_filter = st.selectbox(
                "포지션",
                ["전체", "GK", "DF", "MF", "FW"]
            )
        with filter_cols[2]:
            min_overall = st.slider(
                "최소 오버롤",
                min_value=int(market_df["overall"].min()),
                max_value=int(market_df["overall"].max()),
                value=int(market_df["overall"].min())
            )
        with filter_cols[3]:
            min_fee = int(market_df["asking_fee_eur"].min())
            highest_fee = int(market_df["asking_fee_eur"].max())
            default_max_fee = max(min_fee, min(int(my_budget), highest_fee))
            max_fee = st.slider(
                "최대 이적료",
                min_value=min_fee,
                max_value=highest_fee,
                value=default_max_fee,
                step=50000,
                format="EUR %d"
            )

        filtered_market_df = market_df[
            (market_df["overall"] >= min_overall)
            & (market_df["asking_fee_eur"] <= max_fee)
        ].copy()

        if position_filter != "전체":
            filtered_market_df = filtered_market_df[
                filtered_market_df["position_group"] == position_filter
            ]

        if keyword:
            keyword_mask = (
                filtered_market_df["player_name"].str.lower().str.contains(keyword, na=False)
                | filtered_market_df["seller_club"].str.lower().str.contains(keyword, na=False)
                | filtered_market_df["primary_position"].str.lower().str.contains(keyword, na=False)
            )
            filtered_market_df = filtered_market_df[keyword_mask]

        st.caption(f"검색 결과 {len(filtered_market_df)}명 / 전체 매물 {len(market_df)}명")

        if filtered_market_df.empty:
            render_empty_state("조건에 맞는 선수가 없습니다", "필터를 조금 낮추면 다시 매물이 보입니다.")
        else:
            st.dataframe(
                filtered_market_df[[
                    "player_name",
                    "position_group",
                    "primary_position",
                    "nationality",
                    "overall",
                    "seller_club",
                    "asking_fee_eur"
                ]],
                use_container_width=True,
                hide_index=True,
                column_config=COLUMN_MAPPING
            )

    st.markdown("---")

    st.subheader("선수 영입")

    if not filtered_market_df.empty:

        release_df = run_query("""
            SELECT p.player_id,
                   p.player_name,
                   p.position_group,
                   p.primary_position,
                   p.market_value_eur,
                   ps.pace,
                   ps.shooting,
                   ps.passing,
                   ps.defending,
                   ps.physical,
                   ps.overall
            FROM players p
            JOIN player_stats ps
                ON p.player_id = ps.player_id
            WHERE p.club_id = %s
            ORDER BY FIELD(p.position_group, 'GK', 'DF', 'MF', 'FW'),
                     ps.overall DESC,
                     p.player_name
        """, (my_club_id,))

        options = {
            f"{row.player_name} | {row.position_group} | OVR {row.overall} | {row.seller_club} | EUR {row.asking_fee_eur:,.0f}": int(row.listing_id)
            for row in filtered_market_df.itertuples()
        }

        release_options = {
            f"{row.player_name} | {row.position_group} | {row.primary_position} | OVR {row.overall}": int(row.player_id)
            for row in release_df.itertuples()
        }
        release_labels = list(release_options.keys()) or ["방출 가능한 선수가 없습니다"]

        st.info("이제 선수를 영입하려면 내 선수 1명을 반드시 같이 방출해야 합니다. 내 스쿼드는 항상 11명 기준으로 유지됩니다.")

        col_buy, col_release = st.columns(2)

        with col_buy:
            selected = st.selectbox(
                "영입할 매물 선택",
                list(options.keys())
            )

        with col_release:
            selected_release = st.selectbox(
                "방출할 내 선수 선택",
                release_labels,
                disabled=release_df.empty
            )

        if release_df.empty:
            st.warning("방출할 내 선수가 없어 영입을 진행할 수 없습니다.")

        selected_listing_id = options[selected]
        selected_release_id = release_options[selected_release] if not release_df.empty else None
        selected_player = filtered_market_df[
            filtered_market_df["listing_id"] == selected_listing_id
        ].iloc[0].to_dict()
        release_player = None
        if selected_release_id is not None:
            release_player = release_df[
                release_df["player_id"] == selected_release_id
            ].iloc[0].to_dict()

        st.markdown("##### 영입 전후 비교")
        compare_cols = st.columns(2)
        with compare_cols[0]:
            render_player_card("영입할 선수", selected_player, selected_player["asking_fee_eur"])
        with compare_cols[1]:
            render_player_card("방출할 선수", release_player)

        if release_player is not None:
            attr_rows = []
            for attr, label in [
                ("overall", "오버롤"),
                ("pace", "속도"),
                ("shooting", "슈팅"),
                ("passing", "패스"),
                ("defending", "수비"),
                ("physical", "피지컬"),
            ]:
                incoming = float(selected_player[attr])
                outgoing = float(release_player[attr])
                attr_rows.append({
                    "능력치": label,
                    "영입 선수": round(incoming, 2),
                    "방출 선수": round(outgoing, 2),
                    "변화": round(incoming - outgoing, 2),
                })

            st.dataframe(
                pd.DataFrame(attr_rows),
                use_container_width=True,
                hide_index=True
            )

        manager_info = load_manager_info(my_club_id)
        preview_formation = manager_info["preferred_formation"]
        current_squad_for_score = load_squad_for_score(my_club_id)
        current_lineup_key = f"lineup_{my_club_id}_{preview_formation}"
        current_lineup = st.session_state.get(
            current_lineup_key,
            recommend_lineup_for_formation(current_squad_for_score, preview_formation)
        )
        current_score = calculate_team_score(
            current_squad_for_score,
            preview_formation,
            current_lineup,
            manager_info["rating"]
        )

        preview_score = current_score
        if release_player is not None:
            incoming_row = pd.DataFrame([{
                "player_id": int(selected_player["player_id"]),
                "player_name": selected_player["player_name"],
                "position_group": selected_player["position_group"],
                "primary_position": selected_player["primary_position"],
                "pace": selected_player["pace"],
                "shooting": selected_player["shooting"],
                "passing": selected_player["passing"],
                "defending": selected_player["defending"],
                "physical": selected_player["physical"],
                "overall": selected_player["overall"],
            }])
            preview_squad = pd.concat(
                [
                    current_squad_for_score[
                        current_squad_for_score["player_id"] != selected_release_id
                    ],
                    incoming_row
                ],
                ignore_index=True
            )
            preview_lineup = recommend_lineup_for_formation(preview_squad, preview_formation)
            preview_score = calculate_team_score(
                preview_squad,
                preview_formation,
                preview_lineup,
                manager_info["rating"]
            )

            release_slots = []
            for state_key, lineup_value in st.session_state.items():
                if state_key.startswith(f"lineup_{my_club_id}_") and isinstance(lineup_value, dict):
                    for slot, player_id in lineup_value.items():
                        if player_id == selected_release_id:
                            release_slots.append(slot)

            if release_slots:
                st.warning(
                    f"방출 예정 선수는 현재 배치도 {', '.join(release_slots)} 슬롯에 있습니다. "
                    "영입이 완료되면 배치는 자동으로 다시 추천됩니다."
                )

        st.markdown("##### 영입 예상 효과")
        impact_cols = st.columns(4)
        with impact_cols[0]:
            render_delta_card("팀점수", current_score["total_score"], preview_score["total_score"])
        with impact_cols[1]:
            render_delta_card("배치 평균", current_score["avg_slot_score"], preview_score["avg_slot_score"])
        with impact_cols[2]:
            render_delta_card("포메이션 적합도", current_score["formation_fit"], preview_score["formation_fit"], "%")
        with impact_cols[3]:
            render_stat_card(
                "예산 변화",
                f"{format_eur(my_budget)} → {format_eur(my_budget - float(selected_player['asking_fee_eur']))}",
                f"지출 {format_eur(selected_player['asking_fee_eur'])}"
            )

        insufficient_budget = float(selected_player["asking_fee_eur"]) > my_budget
        if insufficient_budget:
            st.error("현재 예산보다 이적료가 높아 영입할 수 없습니다.")

        if st.button("영입하고 1명 방출하기", type="primary", disabled=release_df.empty or insufficient_budget):

            result, err = buy_player_with_release(
                selected_user_id,
                selected_listing_id,
                selected_release_id
            )

            if err:
                st.error(err)

            else:
                st.session_state["transfer_result"] = result.to_dict("records")[0]
                for key in list(st.session_state.keys()):
                    if key.startswith(f"lineup_{my_club_id}_"):
                        del st.session_state[key]
                st.rerun()

elif page == "스쿼드 배틀":

    st.subheader("스쿼드 배틀 생성")

    clubs_df = run_query("""
        SELECT club_id,
               club_name
        FROM clubs
        WHERE club_id <> %s
        ORDER BY club_name
    """, (my_club_id,))

    opponents = {
        row.club_name: int(row.club_id)
        for row in clubs_df.itertuples()
    }

    selected_opp = st.selectbox(
        "상대 구단 선택",
        list(opponents.keys())
    )
    opponent_club_id = opponents[selected_opp]

    my_manager = load_manager_info(my_club_id)
    opp_manager = load_manager_info(opponent_club_id)

    my_formation = safe_formation(my_manager["preferred_formation"])
    opp_formation = safe_formation(opp_manager["preferred_formation"])

    my_squad_for_score = load_squad_for_score(my_club_id)
    opp_squad_for_score = load_squad_for_score(opponent_club_id)

    my_lineup_key = f"lineup_{my_club_id}_{my_formation}"
    if my_lineup_key in st.session_state:
        my_lineup = st.session_state[my_lineup_key]
    else:
        my_lineup = recommend_lineup_for_formation(my_squad_for_score, my_formation)

    opp_lineup = recommend_lineup_for_formation(opp_squad_for_score, opp_formation)

    my_score = calculate_team_score(
        my_squad_for_score,
        my_formation,
        my_lineup,
        my_manager["rating"]
    )
    opp_score = calculate_team_score(
        opp_squad_for_score,
        opp_formation,
        opp_lineup,
        opp_manager["rating"]
    )

    preview_cols = st.columns(2)
    with preview_cols[0]:
        st.metric(f"{my_club_name} 팀점수", f"{my_score['total_score']:.2f}", my_formation)
        st.caption(
            f"배치평균 {my_score['avg_slot_score']:.2f} / "
            f"적합도 {my_score['formation_fit']:.1f}% / "
            f"감독 {my_manager['rating']:.0f}"
        )

    with preview_cols[1]:
        st.metric(f"{selected_opp} 팀점수", f"{opp_score['total_score']:.2f}", opp_formation)
        st.caption(
            f"배치평균 {opp_score['avg_slot_score']:.2f} / "
            f"적합도 {opp_score['formation_fit']:.1f}% / "
            f"감독 {opp_manager['rating']:.0f}"
        )

    st.caption(
        "배틀 점수 = 선수 배치 평균 70% + 포메이션 적합도 15% + 감독 능력치 10% + 11명 완성도 5%"
    )

    st.markdown("##### 상대 분석")
    diff_cols = st.columns(4)
    with diff_cols[0]:
        render_stat_card(
            "팀점수 차이",
            f"{my_score['total_score'] - opp_score['total_score']:+.2f}",
            "양수면 내 팀 우세"
        )
    with diff_cols[1]:
        render_stat_card(
            "배치 평균 차이",
            f"{my_score['avg_slot_score'] - opp_score['avg_slot_score']:+.2f}",
            "선발 배치 품질"
        )
    with diff_cols[2]:
        render_stat_card(
            "포메이션 적합도 차이",
            f"{my_score['formation_fit'] - opp_score['formation_fit']:+.1f}%",
            "제자리 배치 비율"
        )
    with diff_cols[3]:
        render_stat_card(
            "감독 능력치 차이",
            f"{my_manager['rating'] - opp_manager['rating']:+.0f}",
            "감독 보정 점수"
        )

    battle_notes = []
    if my_score["total_score"] >= opp_score["total_score"]:
        battle_notes.append("현재 전력 기준으로는 내 팀이 우세합니다.")
    else:
        battle_notes.append("현재 전력 기준으로는 상대가 우세합니다. 이적 또는 포메이션 조정이 효과적입니다.")

    if my_score["formation_fit"] < 90:
        battle_notes.append("포메이션 적합도가 90% 미만이라 일부 선수가 익숙하지 않은 위치에 있습니다.")
    if my_score["avg_slot_score"] < opp_score["avg_slot_score"]:
        battle_notes.append("선수 배치 평균이 상대보다 낮아 선발 조합 개선 여지가 있습니다.")
    if my_score["completion"] < 100:
        battle_notes.append("11명 배치가 완성되지 않아 완성도 점수에서 손해를 봅니다.")

    st.markdown(
        "<div class='dbpbl-section-card'><h4>추천 코멘트</h4><ul class='dbpbl-analysis-list'>"
        + "".join(f"<li>{html.escape(note)}</li>" for note in battle_notes)
        + "</ul></div>",
        unsafe_allow_html=True
    )

    if st.button("배틀 시작", type="primary"):
        result, err = save_squad_battle(
            my_club_id,
            opponent_club_id,
            my_score["total_score"],
            opp_score["total_score"]
        )

        if err:
            st.error(err)

        else:
            if result == "home":
                winner_name = my_club_name
                loser_name = selected_opp
                winner_score = my_score["total_score"]
                loser_score = opp_score["total_score"]
                result_text = f"{winner_name} 승리!"
            elif result == "away":
                winner_name = selected_opp
                loser_name = my_club_name
                winner_score = opp_score["total_score"]
                loser_score = my_score["total_score"]
                result_text = f"{winner_name} 승리!"
            else:
                winner_name = "무승부"
                loser_name = f"{my_club_name} vs {selected_opp}"
                winner_score = my_score["total_score"]
                loser_score = opp_score["total_score"]
                result_text = "무승부"

            if result == "draw":
                result_html = f"""
                <div style="
                    background:#374151;
                    color:white;
                    border:3px solid #facc15;
                    border-radius:14px;
                    padding:26px;
                    text-align:center;
                    margin:18px 0;
                    box-shadow:0 0 18px rgba(0,0,0,0.25);
                ">
                    <div style="font-size:34px;font-weight:900;">{html.escape(result_text)}</div>
                    <div style="font-size:22px;margin-top:8px;">
                        {my_score['total_score']:.2f} : {opp_score['total_score']:.2f}
                    </div>
                    <div style="font-size:15px;margin-top:8px;color:#e5e7eb;">
                        {html.escape(loser_name)}
                    </div>
                </div>
                """
            else:
                score_gap = abs(winner_score - loser_score)
                result_html = f"""
                <div style="
                    background:linear-gradient(135deg,#0b6623,#111827);
                    color:white;
                    border:3px solid #facc15;
                    border-radius:14px;
                    padding:28px;
                    text-align:center;
                    margin:18px 0;
                    box-shadow:0 0 22px rgba(11,102,35,0.35);
                ">
                    <div style="font-size:38px;font-weight:900;color:#facc15;">
                        {html.escape(result_text)}
                    </div>
                    <div style="font-size:24px;margin-top:8px;">
                        {winner_score:.2f} : {loser_score:.2f}
                    </div>
                    <div style="font-size:16px;margin-top:8px;color:#d1d5db;">
                        {html.escape(loser_name)} 상대로 +{score_gap:.2f}
                    </div>
                </div>
                """

            st.markdown(result_html, unsafe_allow_html=True)
            st.success("포메이션 기반 배틀 결과가 저장되었습니다.")

            battle_summary_df = pd.DataFrame([
                {
                    "팀": my_club_name,
                    "포메이션": my_formation,
                    "배치 평균": my_score["avg_slot_score"],
                    "포메이션 적합도": my_score["formation_fit"],
                    "감독 능력치": my_manager["rating"],
                    "팀점수": my_score["total_score"],
                },
                {
                    "팀": selected_opp,
                    "포메이션": opp_formation,
                    "배치 평균": opp_score["avg_slot_score"],
                    "포메이션 적합도": opp_score["formation_fit"],
                    "감독 능력치": opp_manager["rating"],
                    "팀점수": opp_score["total_score"],
                },
            ])
            st.dataframe(
                battle_summary_df,
                use_container_width=True,
                hide_index=True
            )

            result_notes = [
                f"팀점수 차이는 {my_score['total_score'] - opp_score['total_score']:+.2f}입니다.",
                f"포메이션 적합도는 {my_club_name} {my_score['formation_fit']:.1f}%, {selected_opp} {opp_score['formation_fit']:.1f}%입니다.",
                f"선수 배치 평균은 {my_club_name} {my_score['avg_slot_score']:.2f}, {selected_opp} {opp_score['avg_slot_score']:.2f}입니다.",
            ]
            st.markdown(
                "<div class='dbpbl-section-card'><h4>결과 해석</h4><ul class='dbpbl-analysis-list'>"
                + "".join(f"<li>{html.escape(note)}</li>" for note in result_notes)
                + "</ul></div>",
                unsafe_allow_html=True
            )

elif page == "기록":

    st.subheader("이적 히스토리")

    transfer_history_df = run_query("""
        SELECT th.transfer_id,
               p.player_name,
               fc.club_name AS from_club,
               tc.club_name AS to_club,
               th.transfer_type,
               th.fee_eur,
               th.transfer_date,
               th.memo
        FROM transfer_history th
        JOIN players p
            ON th.player_id = p.player_id
        LEFT JOIN clubs fc
            ON th.from_club_id = fc.club_id
        LEFT JOIN clubs tc
            ON th.to_club_id = tc.club_id
        ORDER BY th.transfer_id DESC
    """)

    battle_history_df = run_query("""
        SELECT sb.battle_id,
               sb.home_club_id,
               sb.away_club_id,
               hc.club_name AS home_club,
               ac.club_name AS away_club,
               sb.home_score,
               sb.away_score,
               sb.result,
               sb.battle_date
        FROM squad_battles sb
        JOIN clubs hc
            ON sb.home_club_id = hc.club_id
        JOIN clubs ac
            ON sb.away_club_id = ac.club_id
        ORDER BY sb.battle_id DESC
    """)

    buy_spent = 0
    release_count = 0
    if not transfer_history_df.empty:
        buy_spent = transfer_history_df[
            (transfer_history_df["to_club"] == my_club_name)
            & (transfer_history_df["transfer_type"] == "buy")
        ]["fee_eur"].sum()
        release_count = len(transfer_history_df[
            (transfer_history_df["from_club"] == my_club_name)
            & (transfer_history_df["transfer_type"] == "release")
        ])

    current_battles = pd.DataFrame()
    wins = losses = draws = 0
    if not battle_history_df.empty:
        current_battles = battle_history_df[
            (battle_history_df["home_club_id"] == my_club_id)
            | (battle_history_df["away_club_id"] == my_club_id)
        ]
        for battle in current_battles.itertuples():
            is_home = int(battle.home_club_id) == my_club_id
            if battle.result == "draw":
                draws += 1
            elif (is_home and battle.result == "home") or ((not is_home) and battle.result == "away"):
                wins += 1
            else:
                losses += 1

    record_cols = st.columns(4)
    with record_cols[0]:
        render_stat_card("전체 이적 기록", f"{len(transfer_history_df)}건", "영입/방출 포함")
    with record_cols[1]:
        render_stat_card("내 구단 지출", format_eur(buy_spent), "완료된 영입 이적료")
    with record_cols[2]:
        render_stat_card("내 구단 방출", f"{release_count}명", "영입과 함께 정리된 선수")
    with record_cols[3]:
        render_stat_card("내 배틀 전적", f"{wins}승 {draws}무 {losses}패", f"총 {len(current_battles)}경기")

    if transfer_history_df.empty:
        render_empty_state("아직 이적 기록이 없습니다", "이적시장에서 영입과 방출을 진행하면 여기에 기록됩니다.")
    else:
        st.dataframe(
            transfer_history_df,
            use_container_width=True,
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

    st.subheader("스쿼드 배틀 매치 히스토리")

    if battle_history_df.empty:
        render_empty_state("아직 배틀 기록이 없습니다", "스쿼드 배틀을 시작하면 경기 결과가 저장됩니다.")
    else:
        st.dataframe(
            battle_history_df.drop(columns=["home_club_id", "away_club_id"]),
            use_container_width=True,
            hide_index=True,
            column_config=COLUMN_MAPPING
        )
