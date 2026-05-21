# =====================================================
# K리그 이적시장 기반 스토브리그 체험 DB 시스템
# Streamlit 프론트엔드
# 실행: streamlit run kleague_app.py
# 필요 패키지: pip install streamlit pymysql pandas
# =====================================================

import streamlit as st
import pymysql
import pandas as pd

# =====================================================
# DB 연결 설정
# =====================================================
DB_CONFIG = {
    "host":     "localhost",
    "port":     3306,
    "user":     "root",
    "password": "your_password",   # ← 본인 MySQL 비밀번호 입력
    "database": "kleague_db",
    "charset":  "utf8mb4",
}

def get_conn():
    return pymysql.connect(**DB_CONFIG)

def run_query(sql, params=None):
    """SELECT 쿼리 실행 → DataFrame 반환"""
    conn = get_conn()
    try:
        df = pd.read_sql(sql, conn, params=params)
        return df
    finally:
        conn.close()

def run_procedure(sql, params=None):
    """프로시저 실행 → 결과 DataFrame 반환"""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or [])
            conn.commit()
            if cur.description:
                cols = [d[0] for d in cur.description]
                rows = cur.fetchall()
                return pd.DataFrame(rows, columns=cols), None
        return None, None
    except Exception as e:
        conn.rollback()
        return None, str(e)
    finally:
        conn.close()

# =====================================================
# 페이지 설정
# =====================================================
st.set_page_config(
    page_title="K리그 스토브리그",
    page_icon="⚽",
    layout="wide"
)

# =====================================================
# 사이드바: 유저 / 구단 선택
# =====================================================
st.sidebar.title("⚽ K리그 스토브리그")
st.sidebar.markdown("---")

users_df = run_query("""
    SELECT u.user_id, u.username, c.name AS club_name
    FROM APP_USER u JOIN CLUB c ON u.club_id = c.club_id
""")
user_options = {
    f"{row['username']} ({row['club_name']})": row['user_id']
    for _, row in users_df.iterrows()
}
selected_user_label = st.sidebar.selectbox("👤 유저 선택", list(user_options.keys()))
selected_user_id    = user_options[selected_user_label]

my_club_df = run_query("""
    SELECT c.club_id, c.name, c.current_budget
    FROM APP_USER u JOIN CLUB c ON u.club_id = c.club_id
    WHERE u.user_id = %s
""", (selected_user_id,))
my_club_id   = int(my_club_df.iloc[0]["club_id"])
my_club_name = my_club_df.iloc[0]["name"]
my_budget    = int(my_club_df.iloc[0]["current_budget"])

st.sidebar.markdown(f"**구단:** {my_club_name}")
st.sidebar.markdown(f"**잔여 예산:** {my_budget:,} 원")
st.sidebar.markdown("---")

page = st.sidebar.radio(
    "메뉴",
    ["📊 대시보드", "👥 내 스쿼드", "🛒 이적시장", "⚔️ 스쿼드 대결"]
)

# =====================================================
# 페이지 1. 대시보드
# =====================================================
if page == "📊 대시보드":
    st.title("📊 대시보드")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("🏆 구단별 스쿼드 점수 순위")
        score_df = run_query("""
            SELECT club_name, manager_name, tactics,
                   avg_overall, manager_rating, squad_score
            FROM V_SQUAD_SCORE ORDER BY squad_score DESC
        """)
        st.dataframe(score_df, use_container_width=True, hide_index=True)

    with col2:
        st.subheader("💰 구단별 예산 현황")
        budget_df = run_query("""
            SELECT name AS 구단,
                   FORMAT(initial_budget, 0) AS 초기예산,
                   FORMAT(current_budget, 0) AS 현재예산,
                   FORMAT(total_spent, 0)    AS 총지출
            FROM V_CLUB_BUDGET ORDER BY current_budget DESC
        """)
        st.dataframe(budget_df, use_container_width=True, hide_index=True)

    st.subheader("⚠️ 계약 만료 임박 선수 (6개월 이내)")
    expiring_df = run_query("""
        SELECT player_name, position, club_name, end_date, days_remaining
        FROM V_EXPIRING_CONTRACTS
    """)
    if expiring_df.empty:
        st.info("6개월 이내 만료 예정 계약이 없습니다.")
    else:
        st.dataframe(expiring_df, use_container_width=True, hide_index=True)

# =====================================================
# 페이지 2. 내 스쿼드
# =====================================================
elif page == "👥 내 스쿼드":
    st.title(f"👥 {my_club_name} 스쿼드")

    squad_df = run_query("""
        SELECT player_id, player_name, position, nationality,
               attack, defense, stamina, speed, overall
        FROM V_PLAYER_INFO
        WHERE club_name = %s
        ORDER BY FIELD(position,'GK','DF','MF','FW'), overall DESC
    """, (my_club_name,))

    st.dataframe(
        squad_df.drop(columns=["player_id"]),
        use_container_width=True, hide_index=True
    )

    st.markdown("---")
    st.subheader("🚪 선수 방출")

    if squad_df.empty:
        st.warning("스쿼드에 선수가 없습니다.")
    else:
        player_options = {
            f"{row['player_name']} ({row['position']}) overall {row['overall']}": row['player_id']
            for _, row in squad_df.iterrows()
        }
        selected_player_label = st.selectbox("방출할 선수 선택", list(player_options.keys()))
        selected_player_id    = player_options[selected_player_label]
        player_name_only      = selected_player_label.split("(")[0].strip()

        if st.button("🚪 방출 실행", type="primary"):
            result_df, err = run_procedure(
                "CALL sp_release_player(%s, %s)",
                (selected_user_id, selected_player_id)
            )
            if err:
                st.error(f"❌ 방출 실패: {err}")
            else:
                # 방출 결과 요약 박스
                st.success("✅ 방출 완료!")
                st.markdown(f"""
                <div style="background:#fff3cd;border-left:5px solid #ffc107;
                            padding:16px;border-radius:8px;margin:12px 0;">
                    <h4>🚪 방출 결과 요약</h4>
                    <b>선수:</b> {player_name_only}<br>
                    <b>소속 변경:</b> {my_club_name} → <i>소속 없음</i><br>
                    <b>계약 상태:</b> active → expired<br>
                    <b>이적 유형:</b> release
                </div>
                """, unsafe_allow_html=True)
                st.rerun()

# =====================================================
# 페이지 3. 이적시장
# =====================================================
elif page == "🛒 이적시장":
    st.title("🛒 이적시장")

    market_df = run_query("""
        SELECT listing_id, player_name, position, nationality,
               overall, seller_club,
               FORMAT(asking_fee, 0) AS 이적료
        FROM V_TRANSFER_MARKET
    """)

    if market_df.empty:
        st.info("현재 이적시장에 매물이 없습니다.")
    else:
        st.dataframe(
            market_df.drop(columns=["listing_id"]),
            use_container_width=True, hide_index=True
        )

    st.markdown("---")
    st.subheader("📥 선수 영입")
    st.info(f"💰 현재 잔여 예산: **{my_budget:,} 원**")

    available_df = run_query("""
        SELECT tm.listing_id,
               p.name        AS player_name,
               p.position,
               ps.overall,
               c.name        AS seller_club,
               c.club_id     AS seller_club_id,
               tm.asking_fee
        FROM TRANSFER_MARKET tm
        JOIN PLAYER       p  ON tm.player_id      = p.player_id
        JOIN PLAYER_STATS ps ON p.player_id       = ps.player_id
        JOIN CLUB         c  ON tm.seller_club_id = c.club_id
        WHERE tm.status = 'available'
          AND tm.seller_club_id <> %s
        ORDER BY ps.overall DESC
    """, (my_club_id,))

    if available_df.empty:
        st.warning("영입 가능한 매물이 없습니다.")
    else:
        listing_options = {
            f"{row['player_name']} ({row['position']}) overall {row['overall']} "
            f"| {row['seller_club']} | {int(row['asking_fee']):,}원": row['listing_id']
            for _, row in available_df.iterrows()
        }
        selected_listing_label = st.selectbox("영입할 선수 선택", list(listing_options.keys()))
        selected_listing_id    = listing_options[selected_listing_label]

        selected_row  = available_df[available_df['listing_id'] == selected_listing_id].iloc[0]
        selected_fee  = int(selected_row['asking_fee'])
        selected_name = selected_row['player_name']
        seller_name   = selected_row['seller_club']
        seller_id     = int(selected_row['seller_club_id'])

        if selected_fee > my_budget:
            st.error(f"❌ 예산 부족! 필요: {selected_fee:,}원 / 잔여: {my_budget:,}원")
        else:
            if st.button("📥 영입 실행", type="primary"):

                # 영입 전 예산 스냅샷
                before_buyer  = run_query("SELECT current_budget FROM CLUB WHERE club_id = %s", (my_club_id,)).iloc[0][0]
                before_seller = run_query("SELECT current_budget FROM CLUB WHERE club_id = %s", (seller_id,)).iloc[0][0]

                result_df, err = run_procedure(
                    "CALL sp_buy_player(%s, %s)",
                    (selected_user_id, selected_listing_id)
                )

                if err:
                    st.error(f"❌ 영입 실패: {err}")
                else:
                    # 영입 후 예산 스냅샷
                    after_buyer  = run_query("SELECT current_budget FROM CLUB WHERE club_id = %s", (my_club_id,)).iloc[0][0]
                    after_seller = run_query("SELECT current_budget FROM CLUB WHERE club_id = %s", (seller_id,)).iloc[0][0]

                    # 영입 결과 요약 박스
                    st.success("✅ 영입 완료!")
                    st.markdown(f"""
                    <div style="background:#d4edda;border-left:5px solid #28a745;
                                padding:16px;border-radius:8px;margin:12px 0;">
                        <h4>📥 영입 결과 요약</h4>
                        <b>선수:</b> {selected_name}<br>
                        <b>소속 변경:</b> {seller_name} → {my_club_name}<br>
                        <b>이적료:</b> {selected_fee:,} 원<br><br>
                        <b>{my_club_name} 예산:</b>
                        {int(before_buyer):,}원 → {int(after_buyer):,}원
                        <span style="color:red;">
                            (▼ {int(before_buyer - after_buyer):,}원)
                        </span><br>
                        <b>{seller_name} 예산:</b>
                        {int(before_seller):,}원 → {int(after_seller):,}원
                        <span style="color:blue;">
                            (▲ {int(after_seller - before_seller):,}원)
                        </span><br>
                        <b>매물 상태:</b> available → sold
                    </div>
                    """, unsafe_allow_html=True)
                    st.rerun()

    st.markdown("---")
    st.subheader("📋 이적 기록")
    history_df = run_query("""
        SELECT p.name      AS 선수,
               fc.name     AS 출발구단,
               tc.name     AS 도착구단,
               th.transfer_type AS 유형,
               FORMAT(th.fee, 0) AS 이적료,
               th.transfer_date  AS 날짜
        FROM TRANSFER_HISTORY th
        JOIN  PLAYER p  ON th.player_id    = p.player_id
        LEFT JOIN CLUB fc ON th.from_club_id = fc.club_id
        LEFT JOIN CLUB tc ON th.to_club_id   = tc.club_id
        ORDER BY th.transfer_date DESC
    """)
    if history_df.empty:
        st.info("이적 기록이 없습니다.")
    else:
        st.dataframe(history_df, use_container_width=True, hide_index=True)

# =====================================================
# 페이지 4. 스쿼드 대결
# =====================================================
elif page == "⚔️ 스쿼드 대결":
    st.title("⚔️ 스쿼드 대결")

    my_score_df = run_query(
        "SELECT squad_score FROM V_SQUAD_SCORE WHERE club_id = %s", (my_club_id,)
    )
    my_score = float(my_score_df.iloc[0]["squad_score"]) if not my_score_df.empty else 0

    st.info(f"🏠 **{my_club_name}** 현재 스쿼드 점수: **{my_score}**")

    opponent_df = run_query(
        "SELECT club_id, name FROM CLUB WHERE club_id <> %s ORDER BY name", (my_club_id,)
    )
    opp_options = {row["name"]: row["club_id"] for _, row in opponent_df.iterrows()}
    selected_opp_name = st.selectbox("상대 구단 선택", list(opp_options.keys()))
    selected_opp_id   = opp_options[selected_opp_name]

    opp_score_df = run_query(
        "SELECT squad_score FROM V_SQUAD_SCORE WHERE club_id = %s", (selected_opp_id,)
    )
    opp_score = float(opp_score_df.iloc[0]["squad_score"]) if not opp_score_df.empty else 0

    col1, col2, col3 = st.columns(3)
    col1.metric(my_club_name,      f"{my_score}점")
    col2.markdown("<h2 style='text-align:center;margin-top:20px;'>VS</h2>",
                  unsafe_allow_html=True)
    col3.metric(selected_opp_name, f"{opp_score}점")

    if st.button("⚔️ 대결 실행", type="primary"):
        result_df, err = run_procedure(
            "CALL sp_create_squad_battle(%s, %s)",
            (my_club_id, selected_opp_id)
        )
        if err:
            st.error(f"❌ 대결 실패: {err}")
        else:
            if result_df is not None and not result_df.empty:
                result     = result_df.iloc[0]["result"]
                home_score = result_df.iloc[0]["home_score"]
                away_score = result_df.iloc[0]["away_score"]

                # 대결 결과 요약 박스
                if result == "home":
                    color  = "#d4edda"
                    border = "#28a745"
                    msg    = f"🏆 {my_club_name} 승리!"
                elif result == "away":
                    color  = "#f8d7da"
                    border = "#dc3545"
                    msg    = f"😢 {selected_opp_name} 승리!"
                else:
                    color  = "#fff3cd"
                    border = "#ffc107"
                    msg    = "🤝 무승부!"

                st.markdown(f"""
                <div style="background:{color};border-left:5px solid {border};
                            padding:16px;border-radius:8px;margin:12px 0;">
                    <h4>{msg}</h4>
                    <b>{my_club_name}:</b> {home_score}점<br>
                    <b>{selected_opp_name}:</b> {away_score}점
                </div>
                """, unsafe_allow_html=True)

    st.markdown("---")
    st.subheader("📋 대결 기록")
    battle_df = run_query("""
        SELECT hc.name AS 홈구단,
               ac.name AS 원정구단,
               sb.home_score AS 홈점수,
               sb.away_score AS 원정점수,
               sb.result     AS 결과,
               sb.battle_date AS 날짜
        FROM SQUAD_BATTLE sb
        JOIN CLUB hc ON sb.home_club_id = hc.club_id
        JOIN CLUB ac ON sb.away_club_id = ac.club_id
        ORDER BY sb.battle_date DESC
    """)
    if battle_df.empty:
        st.info("대결 기록이 없습니다.")
    else:
        st.dataframe(battle_df, use_container_width=True, hide_index=True)

