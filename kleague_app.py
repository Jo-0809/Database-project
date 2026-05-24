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
    "overall": "오버롤",
    "seller_club": "판매 구단",
    "asking_fee_eur": "요구 이적료 (EUR)",
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


st.set_page_config(
    page_title="K리그 이적시장 시뮬레이터",
    page_icon="⚽",
    layout="wide"
)

st.title("K리그 이적시장 시뮬레이터")

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

st.sidebar.metric("선택된 구단", my_club_name)
st.sidebar.metric("현재 예산 (EUR)", f"{my_budget:,.0f}")

page = st.sidebar.radio(
    "메뉴",
    ["대시보드", "내 스쿼드", "이적 시장", "스쿼드 배틀", "기록"]
)

st.sidebar.markdown("---")

if st.sidebar.button("시뮬레이션 초기화"):

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("DELETE FROM transfer_history")

    cur.execute("""
        UPDATE transfer_market
        SET status = 'available'
    """)

    cur.execute("""
        UPDATE players
        SET club_id = original_club_id
        WHERE player_id > 0
    """)

    cur.execute("""
        UPDATE clubs
        SET current_budget_eur = initial_budget_eur,
            total_spent_eur = 0
        WHERE club_id > 0
    """)

    conn.commit()

    cur.close()
    conn.close()

    st.sidebar.success("초기화 완료!")

    st.rerun()

if page == "대시보드":
    
    

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
               squad_role,
               nationality,
               market_value_eur,
               appearances,
               goals,
               assists,
               overall
        FROM v_player_info
        WHERE club_name = %s
        ORDER BY FIELD(squad_role, 'starter', 'sub'),
                 FIELD(position_group, 'GK', 'DF', 'MF', 'FW'),
                 overall DESC
    """, (my_club_name,))

    starter_df = squad_df[squad_df["squad_role"] == "starter"].copy()
    sub_df = squad_df[squad_df["squad_role"] == "sub"].copy()

    st.subheader(f"선발 명단 ({len(starter_df)}명)")
    st.dataframe(
        starter_df.drop(columns=["player_id", "squad_role"]),
        use_container_width=True,
        hide_index=True,
        column_config=COLUMN_MAPPING
    )

    st.subheader(f"후보 명단 ({len(sub_df)}명)")
    st.dataframe(
        sub_df.drop(columns=["player_id", "squad_role"]),
        use_container_width=True,
        hide_index=True,
        column_config=COLUMN_MAPPING
    )

    # =========================
    # 전술 배치도
    # =========================

    st.markdown("---")

    # DB에서 조회한 감독의 선호 포메이션 적용 (데이터가 없을 경우 기본값 '4-3-3')
    formation = "4-3-3"
    if not formation_df.empty:
        formation = formation_df.iloc[0]["preferred_formation"]

    st.subheader(f"전술 배치도 ({formation})")

    formation_positions = {
        "4-3-3": {
            "GK": [(50, 88)],
            "DF": [
                (15, 72),
                (38, 72),
                (62, 72),
                (85, 72)
            ],
            "MF": [
                (30, 50),
                (50, 42),
                (70, 50)
            ],
            "FW": [
                (18, 22),
                (50, 15),
                (82, 22)
            ]
        },
        "4-2-3-1": {
            "GK": [(50, 88)],
            "DF": [
                (15, 72),
                (38, 72),
                (62, 72),
                (85, 72)
            ],
            "MF": [
                (35, 58),
                (65, 58),
                (20, 38),
                (50, 32),
                (80, 38)
            ],
            "FW": [
                (50, 15)
            ]
        },
        "4-4-2": {
            "GK": [(50, 88)],
            "DF": [
                (15, 72),
                (38, 72),
                (62, 72),
                (85, 72)
            ],
            "MF": [
                (15, 45),
                (38, 50),
                (62, 50),
                (85, 45)
            ],
            "FW": [
                (38, 20),
                (62, 20)
            ]
        }
    }

    current_positions = formation_positions.get(
        formation,
        formation_positions["4-3-3"]
    )

    pitch_html = """
    <div style="
    position:relative;
    width:700px;
    height:900px;
    background:#0b6623;
    border:4px solid white;
    margin:auto;
    border-radius:10px;
    overflow:hidden;
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
    top:50%;
    left:50%;
    transform:translate(-50%,-50%);
    width:120px;
    height:120px;
    border:2px solid white;
    border-radius:50%;
    "></div>
    """

    # 포지션 그룹별로 오버롤이 높은 순으로 정렬하여 배치
    grouped = {
        "GK": starter_df[starter_df["position_group"] == "GK"].sort_values("overall", ascending=False),
        "DF": starter_df[starter_df["position_group"] == "DF"].sort_values("overall", ascending=False),
        "MF": starter_df[starter_df["position_group"] == "MF"].sort_values("overall", ascending=False),
        "FW": starter_df[starter_df["position_group"] == "FW"].sort_values("overall", ascending=False),
    }

    for group_name, players_df in grouped.items():
        coords = current_positions.get(group_name, [])
        
        for idx, (_, row) in enumerate(players_df.iterrows()):
            if idx >= len(coords):
                break

            x, y = coords[idx]
            player_name = row["player_name"]
            overall = row["overall"]

            pitch_html += f"""
            <div style="
            position:absolute;
            left:{x}%;
            top:{y}%;
            transform:translate(-50%,-50%);
            background:#111827;
            color:white;
            padding:8px;
            border-radius:10px;
            width:95px;
            text-align:center;
            font-size:12px;
            border:2px solid gold;
            box-shadow:0 0 10px rgba(0,0,0,0.5);
            ">
            <b>{player_name}</b><br>
            OVR {overall}
            </div>
            """

    pitch_html += "</div>"

    components.html(pitch_html, height=950)
    
    

elif page == "이적 시장":

    st.subheader("영입 가능한 선수 목록")

    market_df = run_query("""
        SELECT listing_id,
               player_name,
               position_group,
               primary_position,
               nationality,
               overall,
               seller_club,
               asking_fee_eur
        FROM v_transfer_market
        WHERE seller_club_id <> %s
        ORDER BY overall DESC,
                 asking_fee_eur DESC
    """, (my_club_id,))

    st.dataframe(
        market_df.drop(columns=["listing_id"]),
        use_container_width=True,
        hide_index=True,
        column_config=COLUMN_MAPPING
    )

    st.markdown("---")

    st.subheader("선수 영입")

    if not market_df.empty:

        options = {
            f"{row.player_name} | {row.position_group} | OVR {row.overall} | {row.seller_club} | EUR {row.asking_fee_eur:,.0f}": int(row.listing_id)
            for row in market_df.itertuples()
        }

        selected = st.selectbox(
            "영입할 매물 선택",
            list(options.keys())
        )

        if st.button("영입하기", type="primary"):

            result, err = run_procedure(
                "CALL sp_buy_player(%s, %s)",
                (selected_user_id, options[selected])
            )

            if err:
                st.error(err)

            else:
                st.success("이적 계약이 성사되었습니다.")
                st.dataframe(
                    result,
                    use_container_width=True,
                    hide_index=True
                )
                st.rerun()

elif page == "스쿼드 배틀":

    st.subheader("\uc2a4\ucffc\ub4dc \ubc30\ud2c0 \uc0dd\uc131")

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
        "\uc0c1\ub300 \uad6c\ub2e8 \uc120\ud0dd",
        list(opponents.keys())
    )

    if st.button("\ubc30\ud2c0 \uc2dc\uc791", type="primary"):

        result, err = run_procedure(
            "CALL sp_create_squad_battle(%s, %s)",
            (my_club_id, opponents[selected_opp])
        )

        if err:
            st.error(err)

        else:
            home_score = float(result.iloc[0]["home_score"])
            away_score = float(result.iloc[0]["away_score"])
            result_type = result.iloc[0]["result"]
            score_diff = abs(home_score - away_score)

            if result_type == "home":
                st.markdown(f"### \U0001f3c6 {my_club_name} \uc2b9\ub9ac")
            elif result_type == "away":
                st.markdown(f"### \U0001f3c6 {selected_opp} \uc2b9\ub9ac")
            else:
                st.markdown("### \U0001f91d \ubb34\uc2b9\ubd80")

            st.markdown(f"**{my_club_name} {home_score:.1f} : {away_score:.1f} {selected_opp}**")

            if result_type == "draw":
                st.markdown("\uc810\uc218 \ucc28\uc774 0.0")
            else:
                st.markdown(f"\uc810\uc218 \ucc28\uc774 +{score_diff:.1f}")

            with st.expander("\ubc30\ud2c0 \uc0c1\uc138 \ub370\uc774\ud130"):
                st.dataframe(
                    result,
                    use_container_width=True,
                    hide_index=True
                )

elif page == "기록":

    st.subheader("이적 히스토리")

    st.dataframe(
        run_query("""
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
        """),
        use_container_width=True,
        hide_index=True,
        column_config=COLUMN_MAPPING
    )

    st.subheader("스쿼드 배틀 매치 히스토리")

    st.dataframe(
        run_query("""
            SELECT sb.battle_id,
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
        """),
        use_container_width=True,
        hide_index=True,
        column_config=COLUMN_MAPPING
    )
