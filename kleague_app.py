import html
import os
import warnings
import pandas as pd
import pymysql
import streamlit as st
import streamlit.components.v1 as components


EUR_TO_KRW = 1761.3

warnings.filterwarnings(
    "ignore",
    message="pandas only supports SQLAlchemy connectable",
    category=UserWarning,
)

DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "kleague_db"),
    "charset": "utf8mb4",
    "cursorclass": pymysql.cursors.Cursor,
}

# 데이터프레임 컬럼 한글 매핑용 딕셔너리
COLUMN_MAPPING = {
    "club_name": "구단명",
    "manager_name": "감독명",
    "preferred_formation": "선호 포메이션",
    "player_count": "선수 수",
    "avg_player_overall": "전체 평균 오버롤",
    "starting11_avg": "주전 11명 평균",
    "bench_avg": "후보 평균",
    "bench_count": "후보 수",
    "manager_rating": "감독 능력치",
    "squad_score": "스쿼드 점수",
    "initial_budget_eur": "초기 예산 (원)",
    "current_budget_eur": "현재 예산 (원)",
    "total_spent_eur": "총 지출 (원)",
    "position_group": "포지션 그룹",
    "avg_overall": "평균 오버롤",
    "player_name": "선수명",
    "primary_position": "주포지션",
    "nationality": "국적",
    "market_value_eur": "Transfermarkt 몸값 (원)",
    "appearances": "출전 횟수",
    "starts_estimated": "선발 추정",
    "goals": "득점",
    "assists": "도움",
    "shots": "슈팅",
    "yellow_cards": "경고",
    "red_cards": "퇴장",
    "pace": "속도",
    "shooting": "슈팅",
    "passing": "패스",
    "defending": "수비",
    "physical": "피지컬",
    "overall": "오버롤",
    "seller_club": "판매 구단",
    "asking_fee_eur": "요구 이적료 (원)",
    "bought_player": "영입 선수",
    "buyer_club": "영입 구단",
    "transfer_id": "이적 ID",
    "from_club": "이전 구단",
    "to_club": "이적 구단",
    "transfer_type": "이적 형태",
    "fee_eur": "이적료 (원)",
    "transfer_date": "이적일",
    "memo": "비고",
    "battle_id": "배틀 ID",
    "home_club": "홈 팀",
    "away_club": "원정 팀",
    "home_score": "홈 전력",
    "away_score": "원정 전력",
    "result": "결과",
    "battle_date": "경기일",
    "current_position_players": "현재 포지션 인원",
    "current_position_avg": "현재 포지션 평균",
    "league_avg_overall": "리그 평균",
    "weakness_gap": "약점 차이",
    "need_level": "보강 단계",
    "recommendation_score": "추천 점수",
    "recommendation_reason": "추천 이유",
    "season_name": "시즌",
    "played": "경기",
    "wins": "승",
    "draws": "무",
    "losses": "패",
    "points": "승점",
    "fee_rank": "이적료 순위",
    "changed_at": "변경 시각",
    "changed_by": "수행자",
    "table_name": "테이블",
    "action_type": "작업",
    "record_id": "레코드 ID",
    "old_value": "이전 값",
    "new_value": "변경 값"
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

def is_demo_mode():
    return bool(st.session_state.get("demo_mode"))


def load_demo_tables():
    if "demo_tables" in st.session_state:
        return st.session_state["demo_tables"]

    base_dir = os.path.dirname(__file__)
    data_dir = os.path.join(base_dir, "data")
    clubs = pd.read_csv(os.path.join(data_dir, "cleaned_clubs.csv"))
    players = pd.read_csv(os.path.join(data_dir, "cleaned_players.csv"))
    stats = pd.read_csv(os.path.join(data_dir, "player_stats.csv"))
    contracts = pd.read_csv(os.path.join(data_dir, "contracts.csv"))
    market = pd.read_csv(os.path.join(data_dir, "transfer_market.csv"))
    users = pd.read_csv(os.path.join(data_dir, "app_users.csv"))
    managers_path = os.path.join(data_dir, "managers.csv")
    if os.path.exists(managers_path):
        managers = pd.read_csv(managers_path)
    else:
        managers = clubs[["club_id", "club_name"]].copy()
        managers["manager_id"] = range(1, len(managers) + 1)
        managers["manager_name"] = managers["club_name"] + " Manager"
        managers["nationality"] = "Unknown"
        managers["preferred_formation"] = [
            FORMATION_CYCLE[index % len(FORMATION_CYCLE)]
            for index in range(len(managers))
        ]
        managers["rating"] = 75
        managers["rating_source"] = "DEMO_FALLBACK"
        managers = managers[["manager_id", "club_id", "manager_name", "nationality", "preferred_formation", "rating", "rating_source"]]

    numeric_columns = {
        "club_id", "player_id", "original_club_id", "manager_id", "contract_id", "listing_id", "seller_club_id",
        "user_id", "season_id", "transfer_id", "battle_id", "home_club_id", "away_club_id",
        "age", "appearances", "starts_estimated", "goals", "assists", "shots", "yellow_cards", "red_cards",
        "pace", "shooting", "passing", "defending", "physical", "overall", "market_value_eur",
        "asking_fee_eur", "salary_eur", "initial_budget_eur", "current_budget_eur", "rating"
    }
    for df in [clubs, players, stats, contracts, market, users, managers]:
        for col in df.columns:
            if col in numeric_columns:
                df[col] = pd.to_numeric(df[col], errors="coerce")

    if "overall" not in stats.columns:
        stats["overall"] = (
            stats[["pace", "shooting", "passing", "defending", "physical"]].sum(axis=1) / 5
        ).round(2)

    tables = {
        "clubs": clubs,
        "players": players,
        "player_stats": stats,
        "contracts": contracts,
        "transfer_market": market,
        "app_users": users,
        "managers": managers,
        "transfer_history": pd.DataFrame(columns=["transfer_id", "season_name", "player_name", "from_club", "to_club", "transfer_type", "fee_eur", "transfer_date", "memo"]),
        "squad_battles": pd.DataFrame(columns=["battle_id", "season_name", "home_club_id", "away_club_id", "home_club", "away_club", "home_score", "away_score", "result", "battle_date"]),
        "seasons": pd.DataFrame([{"season_id": 1, "season_name": "2026", "start_date": "2026-01-01", "end_date": None, "status": "active"}]),
        "audit_logs": pd.DataFrame(columns=["audit_id", "changed_at", "changed_by", "table_name", "action_type", "record_id", "note", "old_value", "new_value"]),
    }
    st.session_state["demo_tables"] = tables
    return tables


def demo_player_info(tables):
    players = tables["players"]
    clubs = tables["clubs"][["club_id", "club_name"]]
    stats = tables["player_stats"]
    return (
        players.merge(clubs, on="club_id", how="left")
        .merge(stats, on="player_id", how="left", suffixes=("", "_stat"))
    )


def demo_squad_score(tables):
    info = demo_player_info(tables)
    ranked = info.sort_values(["club_id", "overall"], ascending=[True, False]).copy()
    ranked["squad_rank"] = ranked.groupby("club_id").cumcount() + 1
    grouped = ranked.groupby(["club_id", "club_name"], as_index=False).agg(
        player_count=("player_id", "count"),
        avg_player_overall=("overall", "mean"),
        starting11_avg=("overall", lambda values: values.head(11).mean()),
        bench_avg=("overall", lambda values: values.iloc[11:18].mean() if len(values) > 11 else 0),
        bench_count=("overall", lambda values: max(0, min(len(values) - 11, 7))),
    )
    managers = tables["managers"][["club_id", "manager_name", "preferred_formation", "rating"]]
    df = grouped.merge(managers, on="club_id", how="left")
    df["avg_player_overall"] = df["avg_player_overall"].round(2)
    df["starting11_avg"] = df["starting11_avg"].fillna(0).round(2)
    df["bench_avg"] = df["bench_avg"].fillna(0).round(2)
    df["manager_rating"] = df["rating"]
    df["squad_score"] = (
        df["starting11_avg"] * 0.82
        + df["manager_rating"] * 0.14
        + df["bench_avg"].where(df["bench_count"] > 0, 0) * 0.02
    ).round(2)
    df.loc[df["player_count"] < 11, "squad_score"] = 0
    return df[[
        "club_id", "club_name", "manager_name", "preferred_formation",
        "player_count", "avg_player_overall", "starting11_avg", "bench_avg",
        "bench_count", "manager_rating", "squad_score"
    ]]


def demo_transfer_market(tables):
    market = tables["transfer_market"]
    available = market[market["status"] == "available"].copy()
    players = tables["players"][["player_id", "player_name", "position_group", "primary_position", "nationality", "age", "market_value_eur"]]
    stats = tables["player_stats"][["player_id", "overall"]]
    clubs = tables["clubs"][["club_id", "club_name"]].rename(columns={"club_id": "seller_club_id", "club_name": "seller_club"})
    return (
        available.merge(players, on="player_id", how="left")
        .merge(stats, on="player_id", how="left")
        .merge(clubs, on="seller_club_id", how="left")
    )


def demo_position_gap(tables):
    info = demo_player_info(tables)
    league = info.groupby("position_group")["overall"].mean().round(2).to_dict()
    rows = []
    for club in tables["clubs"].itertuples():
        club_players = info[info["club_id"] == club.club_id]
        for group in ["GK", "DF", "MF", "FW"]:
            group_players = club_players[club_players["position_group"] == group]
            avg = round(float(group_players["overall"].mean()), 2) if not group_players.empty else None
            league_avg = float(league.get(group, 0))
            gap = round(league_avg - (avg if avg is not None else 0), 2)
            if group_players.empty:
                need = "urgent"
            elif gap > 4:
                need = "weak"
            elif gap < -4:
                need = "strong"
            else:
                need = "stable"
            rows.append({
                "club_id": club.club_id,
                "club_name": club.club_name,
                "position_group": group,
                "player_count": len(group_players),
                "avg_overall": avg,
                "league_avg_overall": league_avg,
                "weakness_gap": gap,
                "need_level": need,
            })
    return pd.DataFrame(rows)


def demo_recommendations(tables):
    clubs = tables["clubs"][["club_id", "club_name", "current_budget_eur"]]
    market = demo_transfer_market(tables)
    gap = demo_position_gap(tables)
    rows = []
    for buyer in clubs.itertuples():
        buyer_gap = gap[gap["club_id"] == buyer.club_id]
        for player in market.itertuples():
            if int(player.seller_club_id) == int(buyer.club_id):
                continue
            gap_row = buyer_gap[buyer_gap["position_group"] == player.position_group].iloc[0]
            weakness = max(float(gap_row["weakness_gap"]), 0)
            fee = float(player.asking_fee_eur)
            market_value = float(player.market_value_eur)
            score = (
                float(player.overall) * 0.45
                + min(weakness, 12) * 2.8
                + (12 if fee <= float(buyer.current_budget_eur) else -80)
                + ((10 if fee == 0 else min(market_value / fee, 1.8) * 8))
                + (6 if pd.notna(player.age) and int(player.age) <= 23 else -5 if pd.notna(player.age) and int(player.age) >= 34 else 0)
            )
            reason = "예산 초과" if fee > float(buyer.current_budget_eur) else "약점 보강" if gap_row["need_level"] in ["urgent", "weak"] else "성장 가치" if pd.notna(player.age) and int(player.age) <= 23 else "전력 보강"
            rows.append({
                "buyer_club_id": buyer.club_id,
                "buyer_club": buyer.club_name,
                "listing_id": player.listing_id,
                "player_id": player.player_id,
                "player_name": player.player_name,
                "position_group": player.position_group,
                "primary_position": player.primary_position,
                "age": player.age,
                "nationality": player.nationality,
                "overall": player.overall,
                "seller_club": player.seller_club,
                "seller_club_id": player.seller_club_id,
                "asking_fee_eur": player.asking_fee_eur,
                "current_budget_eur": buyer.current_budget_eur,
                "current_position_players": gap_row["player_count"],
                "current_position_avg": gap_row["avg_overall"],
                "league_avg_overall": gap_row["league_avg_overall"],
                "weakness_gap": gap_row["weakness_gap"],
                "need_level": gap_row["need_level"],
                "recommendation_score": round(score, 2),
                "recommendation_reason": reason,
            })
    return pd.DataFrame(rows)


def demo_query(sql, params=None):
    tables = load_demo_tables()
    normalized = " ".join(sql.lower().split())
    params = params or ()

    if "from app_users" in normalized and "join clubs" in normalized:
        users = tables["app_users"]
        clubs = tables["clubs"][["club_id", "club_name", "current_budget_eur"]]
        return users.merge(clubs, on="club_id", how="left").sort_values("club_name").reset_index(drop=True)

    if "(select count(*) from clubs)" in normalized:
        return pd.DataFrame([{
            "club_count": len(tables["clubs"]),
            "registered_players": int(tables["players"]["club_id"].notna().sum()),
            "available_listings": int((tables["transfer_market"]["status"] == "available").sum()),
            "battle_count": len(tables["squad_battles"]),
        }])

    if "from v_squad_score" in normalized:
        df = demo_squad_score(tables)
        return df.sort_values("squad_score", ascending=False).reset_index(drop=True)

    if "from v_club_budget" in normalized:
        df = tables["clubs"][["club_id", "club_name", "initial_budget_eur", "current_budget_eur"]].copy()
        df["total_spent_eur"] = df["initial_budget_eur"] - df["current_budget_eur"]
        return df.sort_values("current_budget_eur", ascending=False).reset_index(drop=True)

    if "from v_position_depth" in normalized:
        info = demo_player_info(tables)
        df = info.groupby(["club_name", "position_group"], as_index=False).agg(
            player_count=("player_id", "count"),
            avg_overall=("overall", "mean")
        )
        df["avg_overall"] = df["avg_overall"].round(2)
        return df.sort_values(["club_name", "position_group"]).reset_index(drop=True)

    if "from v_club_position_gap" in normalized:
        df = demo_position_gap(tables)
        if params:
            df = df[df["club_id"] == int(params[0])]
        return df.reset_index(drop=True)

    if "from v_transfer_recommendations" in normalized:
        df = demo_recommendations(tables)
        if params:
            df = df[df["buyer_club_id"] == int(params[0])]
        if "asking_fee_eur <= current_budget_eur" in normalized:
            df = df[df["asking_fee_eur"] <= df["current_budget_eur"]]
        return df.sort_values(["recommendation_score", "overall", "asking_fee_eur"], ascending=[False, False, True]).head(12 if "limit 12" in normalized else len(df)).reset_index(drop=True)

    if "select preferred_formation" in normalized and "from managers" in normalized:
        df = tables["managers"]
        if params:
            df = df[df["club_id"] == int(params[0])]
        return df[["preferred_formation"]].reset_index(drop=True)

    if "select manager_name" in normalized and "from managers" in normalized:
        df = tables["managers"]
        if params:
            df = df[df["club_id"] == int(params[0])]
        return df[["manager_name", "preferred_formation", "rating"]].reset_index(drop=True)

    if "from v_player_info" in normalized:
        df = demo_player_info(tables)
        if params:
            df = df[df["club_name"] == params[0]]
        return df.sort_values(["position_group", "overall"], ascending=[True, False]).reset_index(drop=True)

    if "from players p join player_stats ps" in normalized and "where p.club_id = %s" in normalized:
        df = tables["players"].merge(tables["player_stats"], on="player_id", how="left")
        if params:
            df = df[df["club_id"] == int(params[0])]
            if "not exists" in normalized:
                listed = tables["transfer_market"][tables["transfer_market"]["status"] == "available"]["player_id"]
                df = df[~df["player_id"].isin(listed)]
        if "p.market_value_eur > 0" in normalized:
            df = df[df["market_value_eur"] > 0]
        return df.sort_values(["position_group", "overall", "player_name"], ascending=[True, False, True]).reset_index(drop=True)

    if "from v_transfer_market" in normalized:
        df = demo_transfer_market(tables)
        if "join player_stats" in normalized:
            stats = tables["player_stats"][["player_id", "pace", "shooting", "passing", "defending", "physical"]]
            df = df.merge(stats, on="player_id", how="left")
            rec = demo_recommendations(tables)
            if params:
                rec = rec[rec["buyer_club_id"] == int(params[0])]
            rec_cols = ["listing_id", "recommendation_reason", "recommendation_score"]
            df = df.merge(rec[rec_cols], on="listing_id", how="left")
            if len(params) > 1:
                df = df[df["seller_club_id"] != int(params[1])]
        elif params:
            df = df[df["seller_club_id"] == int(params[0])]
        return df.sort_values(["overall", "asking_fee_eur"], ascending=[False, True]).reset_index(drop=True)

    if "from clubs" in normalized and "where club_id <> %s" in normalized:
        df = tables["clubs"][["club_id", "club_name"]]
        if params:
            df = df[df["club_id"] != int(params[0])]
        return df.sort_values("club_name").reset_index(drop=True)

    if "from transfer_history" in normalized:
        return tables["transfer_history"].copy()

    if "from squad_battles" in normalized:
        return tables["squad_battles"].copy()

    if "from seasons" in normalized:
        return tables["seasons"].copy().sort_values("season_id", ascending=False).reset_index(drop=True)

    if "from v_season_standings" in normalized:
        standings = tables["clubs"][["club_id", "club_name"]].copy()
        standings["season_name"] = "2026"
        for column in ["played", "wins", "draws", "losses", "points"]:
            standings[column] = 0

        for battle in tables["squad_battles"].itertuples():
            home_mask = standings["club_id"] == int(battle.home_club_id)
            away_mask = standings["club_id"] == int(battle.away_club_id)
            standings.loc[home_mask | away_mask, "played"] += 1
            if battle.result == "home":
                standings.loc[home_mask, ["wins", "points"]] += [1, 3]
                standings.loc[away_mask, "losses"] += 1
            elif battle.result == "away":
                standings.loc[away_mask, ["wins", "points"]] += [1, 3]
                standings.loc[home_mask, "losses"] += 1
            else:
                standings.loc[home_mask | away_mask, ["draws", "points"]] += [1, 1]

        return standings[["season_name", "club_name", "played", "wins", "draws", "losses", "points"]]

    if "from v_season_top_transfers" in normalized or "from v_champion_history" in normalized or "from v_audit_recent" in normalized:
        if "audit" in normalized:
            return tables["audit_logs"].copy()
        return pd.DataFrame()

    return pd.DataFrame()


def get_conn():
    config = DB_CONFIG.copy()
    config["host"] = st.session_state.get("db_host", config["host"])
    config["port"] = int(st.session_state.get("db_port", config["port"]))
    config["user"] = st.session_state.get("db_user", config["user"])
    config["password"] = st.session_state.get("db_password", config["password"])
    config["database"] = st.session_state.get("db_database", config["database"])
    return pymysql.connect(**config)


def run_query(sql, params=None):
    if is_demo_mode():
        return demo_query(sql, params)

    conn = get_conn()
    try:
        return pd.read_sql(sql, conn, params=params)
    finally:
        conn.close()


def run_procedure(sql, params=None, app_user_id=None):
    if is_demo_mode():
        return pd.DataFrame(), "데모 모드에서는 DB 변경 프로시저를 실행하지 않습니다."

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            if app_user_id is not None:
                cur.execute("SET @app_user_id = %s", (app_user_id,))
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


def run_execute(sql, params=None, app_user_id=None):
    if is_demo_mode():
        return None

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            if app_user_id is not None:
                cur.execute("SET @app_user_id = %s", (app_user_id,))
            cur.execute(sql, params or [])
            conn.commit()
        return None
    except Exception as exc:
        conn.rollback()
        return str(exc)
    finally:
        conn.close()


def reset_simulation_data():
    if is_demo_mode():
        st.session_state.pop("demo_tables", None)
        st.session_state["demo_tables"] = load_demo_tables()
        return None

    conn = get_conn()
    try:
        conn.begin()

        with conn.cursor() as cur:
            cur.execute("DELETE FROM squad_battles")
            cur.execute("DELETE FROM transfer_history")
            cur.execute("DELETE FROM seasons")
            cur.execute("""
                INSERT INTO seasons (season_id, season_name, start_date, status)
                VALUES (1, '2026', '2026-01-01', 'active')
            """)

            cur.execute("""
                UPDATE players
                SET club_id = original_club_id,
                    joined_date = '2026-01-01',
                    contract_until = '2028-01-01'
                WHERE original_club_id IS NOT NULL
            """)

            cur.execute("DELETE FROM transfer_market")

            cur.execute("""
                INSERT INTO transfer_market
                    (player_id, seller_club_id, asking_fee_eur, listed_date, status)
                SELECT p.player_id,
                       p.original_club_id,
                       p.market_value_eur,
                       '2026-01-01',
                       'available'
                FROM players p
                WHERE p.original_club_id IS NOT NULL
                  AND p.market_value_eur > 0
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
                       p.original_club_id,
                       '2026-01-01',
                       '2028-01-01',
                       GREATEST(p.market_value_eur * 0.08, 20000),
                       'active'
                FROM players p
                WHERE p.original_club_id IS NOT NULL
            """)
            cur.execute("DELETE FROM audit_logs")

        conn.commit()
        return None

    except Exception as exc:
        conn.rollback()
        return str(exc)
    finally:
        conn.close()


def buy_player(user_id, listing_id):
    return run_procedure(
        "CALL sp_buy_player(%s, %s)",
        (user_id, listing_id),
        app_user_id=user_id
    )


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


def selected_player_ids(lineup):
    return [
        int(player_id)
        for player_id in (lineup or {}).values()
        if player_id is not None
    ]


def remap_lineup_to_formation(squad_df, previous_lineup, formation):
    positions = FORMATION_POSITIONS[safe_formation(formation)]
    rows = {
        int(row["player_id"]): row
        for _, row in squad_df.iterrows()
    }
    selected_ids = [
        player_id
        for player_id in selected_player_ids(previous_lineup)
        if player_id in rows
    ]
    remaining_ids = set(selected_ids)
    lineup = {}

    for pos in positions:
        candidate_ids = [
            player_id
            for player_id in remaining_ids
            if rows[player_id]["position_group"] == pos["group"]
        ] or list(remaining_ids)
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
    bench_df = squad_df[
        ~squad_df["player_id"].astype(int).isin(selected_ids)
    ].sort_values("overall", ascending=False)
    bench_count = min(len(bench_df), 7)
    bench_avg = float(bench_df.head(7)["overall"].mean()) if bench_count else 0
    total_score = (
        avg_slot_score * 0.76
        + formation_fit * 0.12
        + float(manager_rating) * 0.10
        + (bench_avg * 0.02 if bench_count else 0)
    )
    if selected_count < 11:
        total_score *= selected_count / 11

    return {
        "total_score": round(total_score, 2),
        "avg_slot_score": round(avg_slot_score, 2),
        "formation_fit": round(formation_fit, 2),
        "completion": round(completion, 2),
        "bench_avg": round(bench_avg, 2),
        "bench_count": bench_count,
        "selected_count": selected_count,
        "natural_count": natural_count,
    }


def save_squad_battle(home_club_id, away_club_id, home_score, away_score, home_selected_count, away_selected_count):
    if home_selected_count < 11 or away_selected_count < 11:
        return None, "배틀은 양 팀 모두 11명 라인업이 완성되어야 저장할 수 있습니다."

    if is_demo_mode():
        tables = load_demo_tables()
        if home_score > away_score:
            result = "home"
        elif away_score > home_score:
            result = "away"
        else:
            result = "draw"

        battle_id = len(tables["squad_battles"]) + 1
        clubs = tables["clubs"][["club_id", "club_name"]]
        home_name = clubs.loc[clubs["club_id"] == home_club_id, "club_name"].iloc[0]
        away_name = clubs.loc[clubs["club_id"] == away_club_id, "club_name"].iloc[0]
        tables["squad_battles"] = pd.concat([
            tables["squad_battles"],
            pd.DataFrame([{
                "battle_id": battle_id,
                "season_name": "2026",
                "home_club_id": home_club_id,
                "away_club_id": away_club_id,
                "home_club": home_name,
                "away_club": away_name,
                "home_score": home_score,
                "away_score": away_score,
                "result": result,
                "battle_date": pd.Timestamp.today().date().isoformat(),
            }])
        ], ignore_index=True)
        st.session_state["demo_tables"] = tables
        return result, None

    squad_count_df = run_query("""
        SELECT club_id,
               COUNT(*) AS player_count
        FROM players
        WHERE club_id IN (%s, %s)
        GROUP BY club_id
    """, (home_club_id, away_club_id))
    counts = {
        int(row.club_id): int(row.player_count)
        for row in squad_count_df.itertuples()
    }
    if counts.get(home_club_id, 0) < 11 or counts.get(away_club_id, 0) < 11:
        return None, "배틀은 양 팀 모두 등록 선수 11명 이상일 때만 저장할 수 있습니다."

    result_df, err = run_procedure("""
        CALL sp_save_squad_battle(%s, %s, %s, %s, %s, %s)
    """, (home_club_id, away_club_id, home_score, away_score, home_selected_count, away_selected_count))

    if err:
        return None, err

    return result_df.iloc[0]["result"], None


def eur_to_krw(value):
    return float(value or 0) * EUR_TO_KRW


def format_krw_from_eur(value):
    krw = eur_to_krw(value)
    if krw >= 100_000_000:
        return f"₩{krw:,.0f} ({krw / 100_000_000:.1f}억)"
    return f"₩{krw:,.0f}"


def format_eur(value):
    return format_krw_from_eur(value)


def prepare_display_df(df, drop_columns=None):
    if df is None or df.empty:
        return df

    display_df = df.copy()
    if drop_columns:
        display_df = display_df.drop(columns=drop_columns, errors="ignore")

    for column in ["initial_budget_eur", "current_budget_eur", "total_spent_eur", "market_value_eur", "asking_fee_eur", "fee_eur", "salary_eur"]:
        if column in display_df.columns:
            display_df[column] = display_df[column].apply(format_krw_from_eur)

    return display_df


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
        background: #07110d;
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
        background: #0d1713;
        border-right: 1px solid rgba(245, 196, 0, 0.18);
    }

    [data-testid="stSidebar"] [data-testid="stMetric"] {
        background: rgba(255, 255, 255, 0.045);
        border: 1px solid rgba(245, 196, 0, 0.16);
        border-radius: 8px;
        padding: 0.7rem 0.8rem;
    }

    [data-testid="stSidebar"] label,
    [data-testid="stSidebar"] p {
        color: #e5e7eb;
    }

    .dbpbl-sidebar-card {
        background: #111c17;
        border: 1px solid rgba(245, 196, 0, 0.18);
        border-radius: 8px;
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
        border-radius: 8px;
        padding: 22px 26px;
        margin: 0.3rem 0 1.35rem 0;
        background: #0c2017;
        box-shadow: 0 22px 50px rgba(0, 0, 0, 0.35);
    }

    .dbpbl-hero::after {
        display: none;
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
        border-radius: 8px;
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
        background: #111c17;
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
        background: #111c17;
        border: 1px solid rgba(245, 196, 0, 0.20);
        border-radius: 8px;
        padding: 0.8rem 0.95rem;
        box-shadow: 0 10px 24px rgba(0, 0, 0, 0.18);
    }

    div[data-testid="stMetric"] label,
    div[data-testid="stMetric"] [data-testid="stMetricValue"],
    div[data-testid="stMetric"] [data-testid="stMetricDelta"] {
        color: #f8fafc;
    }

    .stButton > button {
        border-radius: 8px;
        border: 1px solid rgba(245, 196, 0, 0.45);
        background: #f5c400;
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
        border-radius: 8px;
        overflow: hidden;
        box-shadow: 0 16px 32px rgba(0, 0, 0, 0.22);
    }

    div[data-baseweb="select"] > div,
    [data-testid="stTextInput"] input {
        background-color: #111c17;
        border-color: rgba(245, 196, 0, 0.24);
        border-radius: 8px;
    }

    [data-testid="stAlert"] {
        border-radius: 8px;
        border: 1px solid rgba(245, 196, 0, 0.18);
    }

    .dbpbl-section-card {
        background: #111c17;
        border: 1px solid rgba(245, 196, 0, 0.16);
        border-radius: 8px;
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
        border-radius: 8px;
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
        <p>공식 K리그 선수단 기반으로 영입, 포메이션 배치, 후보 전력, 스쿼드 배틀을 한 화면 흐름으로 관리합니다.</p>
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
                <strong>최소 11명 유지</strong>
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

    recommendation_html = ""
    if "recommendation_score" in row and pd.notna(row.get("recommendation_score")):
        recommendation_html = (
            f'<span class="dbpbl-badge">추천 {float(row["recommendation_score"]):.1f}</span>'
            f'<span class="dbpbl-badge">{html.escape(str(row.get("recommendation_reason", "추천 후보")))}</span>'
        )

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
            {recommendation_html}
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

try:
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
except pymysql.err.OperationalError as exc:
    st.error("MySQL 연결에 실패했습니다.")
    st.caption(str(exc))

    with st.form("db_connection_form"):
        st.markdown("#### DB 접속 정보")
        form_cols = st.columns([1.4, 0.7, 1, 1.2])
        with form_cols[0]:
            db_host = st.text_input("Host", value=st.session_state.get("db_host", DB_CONFIG["host"]))
        with form_cols[1]:
            db_port = st.number_input("Port", value=int(st.session_state.get("db_port", DB_CONFIG["port"])), min_value=1, max_value=65535)
        with form_cols[2]:
            db_user = st.text_input("User", value=st.session_state.get("db_user", DB_CONFIG["user"]))
        with form_cols[3]:
            db_database = st.text_input("Database", value=st.session_state.get("db_database", DB_CONFIG["database"]))
        db_password = st.text_input("Password", type="password", value=st.session_state.get("db_password", ""))
        submitted = st.form_submit_button("이 정보로 다시 연결")

    if submitted:
        st.session_state["db_host"] = db_host
        st.session_state["db_port"] = int(db_port)
        st.session_state["db_user"] = db_user
        st.session_state["db_database"] = db_database
        st.session_state["db_password"] = db_password
        st.rerun()

    st.markdown("---")
    if st.button("DB 없이 샘플 데이터로 UI 보기"):
        st.session_state["demo_mode"] = True
        st.rerun()

    st.info("비밀번호가 맞는데도 데이터베이스가 없다고 나오면 MySQL Workbench에서 `kleague_full_setup.sql`을 전체 실행한 뒤 새로고침하세요.")
    st.stop()
except Exception as exc:
    st.error("DB 스키마를 읽는 중 오류가 발생했습니다.")
    st.caption(str(exc))
    st.info("MySQL Workbench에서 `kleague_full_setup.sql`을 전체 실행한 뒤 이 화면을 새로고침하세요.")
    st.stop()

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
users_df["display_name"] = users_df.apply(
    lambda row: row["display_name"] if pd.notna(row["display_name"]) else f"{row['club_name']} 감독",
    axis=1
)

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
    <span>현재 예산 (원)</span>
    <strong class="dbpbl-budget">{format_krw_from_eur(my_budget)}</strong>
</div>
""", unsafe_allow_html=True)

page = st.sidebar.radio(
    "메뉴",
    ["대시보드", "팀 분석", "내 스쿼드", "이적 시장", "스쿼드 배틀", "시즌", "기록", "감사 로그"]
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
                       starting11_avg,
                       bench_avg,
                       bench_count,
                       manager_rating,
                       squad_score
                FROM v_squad_score
                ORDER BY squad_score DESC
            """),
            width="stretch",
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

    with col2:
        st.subheader("구단별 예산 현황")

        st.dataframe(
            prepare_display_df(run_query("""
                SELECT club_name,
                       initial_budget_eur,
                       current_budget_eur,
                       total_spent_eur
                FROM v_club_budget
                ORDER BY current_budget_eur DESC
            """)),
            width="stretch",
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
        width="stretch",
        hide_index=True,
        column_config=COLUMN_MAPPING
    )

elif page == "팀 분석":

    st.subheader(f"{my_club_name} 약점 분석")

    gap_df = run_query("""
        SELECT position_group,
               player_count,
               avg_overall,
               league_avg_overall,
               weakness_gap,
               need_level
        FROM v_club_position_gap
        WHERE club_id = %s
        ORDER BY FIELD(position_group, 'GK', 'DF', 'MF', 'FW')
    """, (my_club_id,))

    recommendation_df = run_query("""
        SELECT player_name,
               position_group,
               primary_position,
               age,
               nationality,
               overall,
               seller_club,
               asking_fee_eur,
               current_position_avg,
               league_avg_overall,
               weakness_gap,
               recommendation_reason,
               recommendation_score
        FROM v_transfer_recommendations
        WHERE buyer_club_id = %s
          AND asking_fee_eur <= current_budget_eur
        ORDER BY recommendation_score DESC,
                 overall DESC,
                 asking_fee_eur ASC
        LIMIT 12
    """, (my_club_id,))

    if gap_df.empty:
        render_empty_state("분석 데이터가 없습니다", "DB를 다시 구축한 뒤 확인해 주세요.")
    else:
        weakest = gap_df.sort_values("weakness_gap", ascending=False).iloc[0]
        affordable_count = len(recommendation_df)
        top_target = recommendation_df.iloc[0] if not recommendation_df.empty else None

        analysis_cols = st.columns(4)
        with analysis_cols[0]:
            render_stat_card(
                "최우선 보강",
                weakest["position_group"],
                f"리그 평균 대비 {float(weakest['weakness_gap']):+.2f}"
            )
        with analysis_cols[1]:
            render_stat_card(
                "약점 단계",
                weakest["need_level"],
                f"{int(weakest['player_count'])}명 보유"
            )
        with analysis_cols[2]:
            render_stat_card(
                "예산 내 후보",
                f"{affordable_count}명",
                "현재 예산으로 영입 가능"
            )
        with analysis_cols[3]:
            render_stat_card(
                "추천 1순위",
                top_target["player_name"] if top_target is not None else "-",
                top_target["recommendation_reason"] if top_target is not None else "조건에 맞는 후보 없음"
            )

        st.markdown("##### 포지션별 리그 평균 비교")
        st.dataframe(
            gap_df,
            width="stretch",
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

        st.markdown("##### 데이터 기반 영입 추천")
        if recommendation_df.empty:
            render_empty_state("예산 내 추천 선수가 없습니다", "이적료 필터를 낮추거나 다른 구단을 선택해 보세요.")
        else:
            st.dataframe(
                prepare_display_df(recommendation_df),
                width="stretch",
                hide_index=True,
                column_config=COLUMN_MAPPING
            )
            st.caption(
                "추천 점수는 선수 오버롤, 포지션 약점, 예산 적합도, Transfermarkt 몸값 대비 이적료, 나이 보너스를 합산해 계산합니다."
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
        prepare_display_df(squad_df, drop_columns=["player_id"]),
        width="stretch",
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

    lineup_key = f"lineup_{my_club_id}_active"
    formation_state_key = f"{lineup_key}_formation"
    if lineup_key not in st.session_state:
        st.session_state[lineup_key] = recommended_lineup()
        st.session_state[formation_state_key] = formation
    elif st.session_state.get(formation_state_key) != formation:
        st.session_state[lineup_key] = remap_lineup_to_formation(
            squad_df,
            st.session_state[lineup_key],
            formation
        )
        st.session_state[formation_state_key] = formation

    col_a, col_b, col_c = st.columns([1, 1, 1])
    with col_a:
        if st.button("추천 배치"):
            st.session_state[lineup_key] = recommended_lineup()
            st.session_state[formation_state_key] = formation
            for pos in current_positions:
                st.session_state[f"{lineup_key}_{formation}_{pos['slot']}"] = st.session_state[lineup_key].get(pos["slot"])
            st.rerun()
    with col_b:
        if st.button("배치 비우기"):
            st.session_state[lineup_key] = {
                pos["slot"]: None
                for pos in current_positions
            }
            st.session_state[formation_state_key] = formation
            for pos in current_positions:
                st.session_state[f"{lineup_key}_{formation}_{pos['slot']}"] = None
            st.rerun()
    with col_c:
        if st.button("포메이션 저장"):
            if is_demo_mode():
                tables = load_demo_tables()
                manager_mask = tables["managers"]["club_id"] == my_club_id
                tables["managers"].loc[manager_mask, "preferred_formation"] = formation
                st.session_state["demo_tables"] = tables
                st.success("데모 모드에서 포메이션이 임시 저장되었습니다.")
                st.rerun()
            else:
                err = run_execute("""
                    UPDATE managers
                    SET preferred_formation = %s
                    WHERE club_id = %s
                """, (formation, my_club_id))
                if err:
                    st.error(err)
                else:
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
            widget_key = f"{lineup_key}_{formation}_{slot}"
            current_lineup[slot] = st.selectbox(
                f"{slot} ({pos['group']})",
                options,
                index=options.index(current_value),
                format_func=select_label,
                key=widget_key
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
    metric_cols[3].metric("후보 기여", f"{lineup_metrics['bench_avg']:.2f}", f"{lineup_metrics['bench_count']}명 반영")

    st.caption(
        f"점수 = 주전 배치 평균 76% + 포메이션 적합도 12% + 감독 능력치 10% + 후보 상위 7명 2%. 배치 완료 {lineup_metrics['selected_count']}/11"
    )

    pitch_html = """
    <div style="
    position:relative;
    width:min(92vw,760px);
    height:900px;
    background:#087333;
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
        background:#152033;
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
    st.caption(
        "선수단/기록은 K League 공식 공개 데이터, 몸값은 Transfermarkt 공개 market value를 사용합니다. "
        "공식 영문명과 구단 기준으로 확실히 매칭된 선수만 기본 이적시장에 표시되며, 요구 이적료는 market value와 동일하게 원화 환산됩니다."
    )

    if "transfer_result" in st.session_state:
        transfer_result = pd.DataFrame([st.session_state.pop("transfer_result")])
        st.success("이적 계약이 완료되었습니다.")
        st.dataframe(
            prepare_display_df(transfer_result),
            width="stretch",
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
               tr.recommendation_reason,
               tr.recommendation_score,
               ps.pace,
               ps.shooting,
               ps.passing,
               ps.defending,
               ps.physical
        FROM v_transfer_market vm
        JOIN player_stats ps
            ON vm.player_id = ps.player_id
        JOIN (
            SELECT club_id, COUNT(*) AS seller_player_count
            FROM players
            WHERE club_id IS NOT NULL
            GROUP BY club_id
        ) seller_squad
            ON seller_squad.club_id = vm.seller_club_id
        LEFT JOIN v_transfer_recommendations tr
            ON tr.listing_id = vm.listing_id
           AND tr.buyer_club_id = %s
        WHERE vm.seller_club_id <> %s
          AND seller_squad.seller_player_count > 11
        ORDER BY tr.recommendation_score DESC,
                 vm.overall DESC,
                 vm.asking_fee_eur ASC
    """, (my_club_id, my_club_id,))

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
            overall_min = int(market_df["overall"].min())
            overall_max = int(market_df["overall"].max())
            if overall_min == overall_max:
                st.metric("최소 오버롤", overall_min)
                min_overall = overall_min
            else:
                min_overall = st.slider(
                    "최소 오버롤",
                    min_value=overall_min,
                    max_value=overall_max,
                    value=overall_min
                )
        with filter_cols[3]:
            min_fee = int(market_df["asking_fee_eur"].min())
            highest_fee = int(market_df["asking_fee_eur"].max())
            default_max_fee = max(min_fee, min(int(my_budget), highest_fee))
            if min_fee == highest_fee:
                st.metric("최대 이적료", format_krw_from_eur(highest_fee))
                max_fee_krw = int(eur_to_krw(highest_fee))
            else:
                max_fee_krw = st.slider(
                    "최대 이적료 (원)",
                    min_value=int(eur_to_krw(min_fee)),
                    max_value=int(eur_to_krw(highest_fee)),
                    value=int(eur_to_krw(default_max_fee)),
                    step=50_000_000,
                    format="%d원"
                )
            max_fee = max_fee_krw / EUR_TO_KRW

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
                prepare_display_df(filtered_market_df[[
                    "player_name",
                    "position_group",
                    "primary_position",
                    "nationality",
                    "overall",
                    "seller_club",
                    "asking_fee_eur",
                    "recommendation_reason",
                    "recommendation_score"
                ]]),
                width="stretch",
                hide_index=True,
                column_config=COLUMN_MAPPING
            )

    st.markdown("---")

    st.subheader("선수 영입")

    if not filtered_market_df.empty:

        options = {
            f"{row.player_name} | {row.position_group} | OVR {row.overall} | {row.seller_club} | {format_krw_from_eur(row.asking_fee_eur)}": int(row.listing_id)
            for row in filtered_market_df.itertuples()
        }

        st.info("전체 선수단 데이터 기준에서는 영입 시 자동 방출이 필요하지 않습니다. 예산과 최소 11명 규칙만 검증합니다.")

        selected = st.selectbox(
            "영입할 매물 선택",
            list(options.keys())
        )
        selected_listing_id = options[selected]
        selected_player = filtered_market_df[
            filtered_market_df["listing_id"] == selected_listing_id
        ].iloc[0].to_dict()

        st.markdown("##### 영입 후보 상세")
        render_player_card("영입할 선수", selected_player, selected_player["asking_fee_eur"])

        manager_info = load_manager_info(my_club_id)
        preview_formation = manager_info["preferred_formation"]
        current_squad_for_score = load_squad_for_score(my_club_id)
        current_lineup_key = f"lineup_{my_club_id}_active"
        current_lineup_formation = st.session_state.get(f"{current_lineup_key}_formation")
        current_lineup = st.session_state.get(current_lineup_key)
        if current_lineup_formation != preview_formation or not current_lineup:
            current_lineup = recommend_lineup_for_formation(current_squad_for_score, preview_formation)
        current_score = calculate_team_score(
            current_squad_for_score,
            preview_formation,
            current_lineup,
            manager_info["rating"]
        )

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
        preview_squad = pd.concat([current_squad_for_score, incoming_row], ignore_index=True)
        preview_lineup = recommend_lineup_for_formation(preview_squad, preview_formation)
        preview_score = calculate_team_score(
            preview_squad,
            preview_formation,
            preview_lineup,
            manager_info["rating"]
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
        if is_demo_mode():
            st.info("데모 모드에서는 영입 실행은 비활성화됩니다. 실제 DB 연결 후 사용할 수 있습니다.")

        if st.button("영입하기", type="primary", disabled=insufficient_budget or is_demo_mode()):

            result, err = buy_player(
                selected_user_id,
                selected_listing_id
            )

            if err:
                st.error(err)

            else:
                st.session_state["transfer_result"] = result.to_dict("records")[0]
                for key in list(st.session_state.keys()):
                    if key.startswith(f"lineup_{my_club_id}_"):
                        del st.session_state[key]
                st.rerun()

    st.markdown("---")
    st.subheader("내 선수 이적시장 등록 / 취소")

    register_tab, cancel_tab = st.tabs(["매물 등록", "등록 취소"])

    with register_tab:
        listable_df = run_query("""
            SELECT p.player_id,
                   p.player_name,
                   p.position_group,
                   p.primary_position,
                   p.market_value_eur,
                   ps.overall
            FROM players p
            JOIN player_stats ps
                ON p.player_id = ps.player_id
            WHERE p.club_id = %s
              AND p.market_value_eur > 0
              AND NOT EXISTS (
                  SELECT 1
                  FROM transfer_market tm
                  WHERE tm.player_id = p.player_id
                    AND tm.status = 'available'
              )
            ORDER BY FIELD(p.position_group, 'GK', 'DF', 'MF', 'FW'),
                     ps.overall DESC,
                     p.player_name
        """, (my_club_id,))

        if listable_df.empty:
            render_empty_state("등록 가능한 선수가 없습니다", "Transfermarkt 몸값이 확인된 선수는 이미 매물로 등록되어 있거나 현재 스쿼드에 없습니다.")
        else:
            list_options = {
                f"{row.player_name} | {row.position_group} | OVR {row.overall} | Transfermarkt {format_eur(row.market_value_eur)}": int(row.player_id)
                for row in listable_df.itertuples()
            }
            selected_list_label = st.selectbox("등록할 선수", list(list_options.keys()))
            default_fee = int(listable_df[listable_df["player_id"] == list_options[selected_list_label]].iloc[0]["market_value_eur"])
            asking_fee_krw = st.number_input(
                "요구 이적료 (원)",
                min_value=0,
                value=int(eur_to_krw(max(default_fee, 0))),
                step=50_000_000,
                disabled=True,
                help="임의 산정을 막기 위해 Transfermarkt market value와 동일하게 고정됩니다."
            )
            asking_fee = default_fee

            if is_demo_mode():
                st.info("데모 모드에서는 매물 등록이 비활성화됩니다.")

            if st.button("이적시장에 등록", disabled=is_demo_mode()):
                result, err = run_procedure(
                    "CALL sp_list_player_for_transfer(%s, %s, %s)",
                    (selected_user_id, list_options[selected_list_label], asking_fee),
                    app_user_id=selected_user_id
                )
                if err:
                    st.error(err)
                else:
                    st.success("매물 등록이 완료되었습니다.")
                    st.dataframe(prepare_display_df(result), width="stretch", hide_index=True)
                    st.rerun()

    with cancel_tab:
        own_listing_df = run_query("""
            SELECT listing_id,
                   player_name,
                   position_group,
                   primary_position,
                   overall,
                   asking_fee_eur
            FROM v_transfer_market
            WHERE seller_club_id = %s
            ORDER BY listed_date DESC,
                     player_name
        """, (my_club_id,))

        if own_listing_df.empty:
            render_empty_state("취소할 매물이 없습니다", "내 구단이 등록한 available 매물이 없습니다.")
        else:
            cancel_options = {
                f"{row.player_name} | {row.position_group} | OVR {row.overall} | {format_eur(row.asking_fee_eur)}": int(row.listing_id)
                for row in own_listing_df.itertuples()
            }
            selected_cancel_label = st.selectbox("취소할 매물", list(cancel_options.keys()))

            if is_demo_mode():
                st.info("데모 모드에서는 등록 취소가 비활성화됩니다.")

            if st.button("등록 취소", disabled=is_demo_mode()):
                result, err = run_procedure(
                    "CALL sp_cancel_listing(%s, %s)",
                    (selected_user_id, cancel_options[selected_cancel_label]),
                    app_user_id=selected_user_id
                )
                if err:
                    st.error(err)
                else:
                    st.success("매물 등록이 취소되었습니다.")
                    st.dataframe(prepare_display_df(result), width="stretch", hide_index=True)
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

    my_lineup_key = f"lineup_{my_club_id}_active"
    if my_lineup_key in st.session_state and st.session_state.get(f"{my_lineup_key}_formation") == my_formation:
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
            f"후보 {my_score['bench_count']}명 평균 {my_score['bench_avg']:.2f} / "
            f"감독 {my_manager['rating']:.0f}"
        )

    with preview_cols[1]:
        st.metric(f"{selected_opp} 팀점수", f"{opp_score['total_score']:.2f}", opp_formation)
        st.caption(
            f"배치평균 {opp_score['avg_slot_score']:.2f} / "
            f"적합도 {opp_score['formation_fit']:.1f}% / "
            f"후보 {opp_score['bench_count']}명 평균 {opp_score['bench_avg']:.2f} / "
            f"감독 {opp_manager['rating']:.0f}"
        )

    st.caption(
        "배틀 점수 = 주전 배치 평균 76% + 포메이션 적합도 12% + 감독 10% + 후보 상위 7명 2%입니다. 11명 미만 팀은 배틀할 수 없습니다."
    )

    my_roster_count = len(my_squad_for_score)
    opp_roster_count = len(opp_squad_for_score)
    battle_disabled = (
        my_roster_count < 11
        or opp_roster_count < 11
        or my_score["selected_count"] < 11
        or opp_score["selected_count"] < 11
    )
    if battle_disabled:
        st.error(
            f"배틀 불가: {my_club_name} 등록 {my_roster_count}명/선발 {my_score['selected_count']}명, "
            f"{selected_opp} 등록 {opp_roster_count}명/선발 {opp_score['selected_count']}명입니다. "
            "양 팀 모두 등록 선수와 선발 배치가 11명 이상이어야 합니다."
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

    if st.button("배틀 시작", type="primary", disabled=battle_disabled):
        result, err = save_squad_battle(
            my_club_id,
            opponent_club_id,
            my_score["total_score"],
            opp_score["total_score"],
            my_score["selected_count"],
            opp_score["selected_count"]
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
                    background:#0b6623;
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
                width="stretch",
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

elif page == "시즌":

    st.subheader("시즌 운영")

    season_df = run_query("""
        SELECT season_id,
               season_name,
               start_date,
               end_date,
               status
        FROM seasons
        ORDER BY season_id DESC
    """)

    standing_df = run_query("""
        SELECT season_name,
               club_name,
               played,
               wins,
               draws,
               losses,
               points
        FROM v_season_standings
        ORDER BY points DESC,
                 wins DESC,
                 club_name
    """)

    top_transfer_df = run_query("""
        SELECT season_name,
               fee_rank,
               player_name,
               from_club,
               to_club,
               fee_eur,
               transfer_date
        FROM v_season_top_transfers
        WHERE fee_rank <= 5
        ORDER BY fee_rank ASC,
                 fee_eur DESC
    """)

    champion_df = run_query("""
        SELECT season_name,
               start_date,
               end_date,
               champion_club
        FROM v_champion_history
    """)

    season_cols = st.columns(3)
    active_season = season_df[season_df["status"] == "active"].iloc[0] if not season_df.empty and not season_df[season_df["status"] == "active"].empty else None
    with season_cols[0]:
        render_stat_card("현재 시즌", active_season["season_name"] if active_season is not None else "-", "활성 시즌")
    with season_cols[1]:
        render_stat_card("이번 시즌 경기", f"{int(standing_df['played'].sum() / 2) if not standing_df.empty else 0}경기", "저장된 배틀 기준")
    with season_cols[2]:
        leader = standing_df.iloc[0]["club_name"] if not standing_df.empty else "-"
        render_stat_card("현재 1위", leader, "승점 우선 정렬")

    st.markdown("##### 현재 시즌 순위표")
    if standing_df.empty:
        render_empty_state("시즌 기록이 없습니다", "스쿼드 배틀을 진행하면 순위표가 채워집니다.")
    else:
        st.dataframe(
            standing_df,
            width="stretch",
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

    col_a, col_b = st.columns(2)
    with col_a:
        st.markdown("##### 시즌별 이적료 TOP 5")
        if top_transfer_df.empty:
            render_empty_state("아직 유료 이적이 없습니다", "이적시장에서 영입을 진행하면 여기에 표시됩니다.")
        else:
            st.dataframe(
                prepare_display_df(top_transfer_df),
                width="stretch",
                hide_index=True,
                column_config=COLUMN_MAPPING
            )

    with col_b:
        st.markdown("##### 시즌 목록")
        st.dataframe(
            season_df,
            width="stretch",
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

    st.markdown("##### 새 시즌 시작")
    next_season_name = st.text_input("새 시즌 이름", value="2027")
    if is_demo_mode():
        st.info("데모 모드에서는 시즌 시작이 비활성화됩니다.")
    if st.button("현재 시즌 종료 후 새 시즌 시작", type="primary", disabled=is_demo_mode()):
        result, err = run_procedure(
            "CALL sp_start_new_season(%s)",
            (next_season_name.strip(),)
        )
        if err:
            st.error(err)
        else:
            st.success("새 시즌이 시작되었습니다.")
            st.dataframe(prepare_display_df(result), width="stretch", hide_index=True)
            st.rerun()

    if not champion_df.empty:
        st.markdown("##### 역대 우승 기록")
        st.dataframe(
            champion_df,
            width="stretch",
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

elif page == "기록":

    st.subheader("이적 히스토리")

    transfer_history_df = run_query("""
        SELECT th.transfer_id,
               s.season_name,
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
        LEFT JOIN seasons s
            ON th.season_id = s.season_id
        ORDER BY th.transfer_id DESC
    """)

    battle_history_df = run_query("""
        SELECT sb.battle_id,
               s.season_name,
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
        LEFT JOIN seasons s
            ON sb.season_id = s.season_id
        ORDER BY sb.battle_id DESC
    """)

    buy_spent = 0
    outgoing_count = 0
    if not transfer_history_df.empty:
        buy_spent = transfer_history_df[
            (transfer_history_df["to_club"] == my_club_name)
            & (transfer_history_df["transfer_type"] == "buy")
        ]["fee_eur"].sum()
        outgoing_count = len(transfer_history_df[
            (transfer_history_df["from_club"] == my_club_name)
            & (transfer_history_df["transfer_type"] == "buy")
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
        render_stat_card("전체 이적 기록", f"{len(transfer_history_df)}건", "영입/판매 포함")
    with record_cols[1]:
        render_stat_card("내 구단 지출", format_eur(buy_spent), "완료된 영입 이적료")
    with record_cols[2]:
        render_stat_card("내 구단 판매", f"{outgoing_count}명", "다른 구단으로 이동한 선수")
    with record_cols[3]:
        render_stat_card("내 배틀 전적", f"{wins}승 {draws}무 {losses}패", f"총 {len(current_battles)}경기")

    if transfer_history_df.empty:
        render_empty_state("아직 이적 기록이 없습니다", "이적시장에서 영입을 진행하면 여기에 기록됩니다.")
    else:
        st.dataframe(
            prepare_display_df(transfer_history_df),
            width="stretch",
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

    st.subheader("스쿼드 배틀 매치 히스토리")

    if battle_history_df.empty:
        render_empty_state("아직 배틀 기록이 없습니다", "스쿼드 배틀을 시작하면 경기 결과가 저장됩니다.")
    else:
        st.dataframe(
            battle_history_df.drop(columns=["home_club_id", "away_club_id"]),
            width="stretch",
            hide_index=True,
            column_config=COLUMN_MAPPING
        )

elif page == "감사 로그":

    st.subheader("DB 변경 감사 로그")

    log_df = run_query("""
        SELECT audit_id,
               changed_at,
               changed_by,
               table_name,
               action_type,
               record_id,
               note,
               old_value,
               new_value
        FROM v_audit_recent
        LIMIT 300
    """)

    if log_df.empty:
        render_empty_state("아직 감사 로그가 없습니다", "영입, 이적시장 등록/취소를 수행하면 DB 트리거가 변경 이력을 남깁니다.")
    else:
        filter_cols = st.columns([1, 1, 1])
        with filter_cols[0]:
            table_filter = st.selectbox("테이블", ["전체"] + sorted(log_df["table_name"].dropna().unique().tolist()))
        with filter_cols[1]:
            action_filter = st.selectbox("작업", ["전체"] + sorted(log_df["action_type"].dropna().unique().tolist()))
        with filter_cols[2]:
            row_limit = st.selectbox("표시 행 수", [50, 100, 200, 300], index=1)

        filtered_logs = log_df.copy()
        if table_filter != "전체":
            filtered_logs = filtered_logs[filtered_logs["table_name"] == table_filter]
        if action_filter != "전체":
            filtered_logs = filtered_logs[filtered_logs["action_type"] == action_filter]

        st.dataframe(
            filtered_logs.head(row_limit),
            width="stretch",
            hide_index=True,
            column_config=COLUMN_MAPPING
        )
