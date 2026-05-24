# =====================================================
# K리그 이적시장 기반 스토브리그 체험 DB 시스템
# Streamlit 프론트엔드
# 실행: streamlit run kleague_app.py
# 필요 패키지: pip install streamlit pymysql pandas
# =====================================================

import streamlit as st
import streamlit.components.v1 as components
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

# 포메이션별 11개 슬롯 정의 (slot=슬롯명, group=포지션그룹, x/y=피치 위치 %)
FORMATION_SLOTS = {
    "4-3-3": [
        {"slot": "GK",  "group": "GK", "x": 50, "y": 88},
        {"slot": "LB",  "group": "DF", "x": 15, "y": 72},
        {"slot": "CB1", "group": "DF", "x": 38, "y": 72},
        {"slot": "CB2", "group": "DF", "x": 62, "y": 72},
        {"slot": "RB",  "group": "DF", "x": 85, "y": 72},
        {"slot": "LCM", "group": "MF", "x": 30, "y": 50},
        {"slot": "CM",  "group": "MF", "x": 50, "y": 42},
        {"slot": "RCM", "group": "MF", "x": 70, "y": 50},
        {"slot": "LW",  "group": "FW", "x": 18, "y": 22},
        {"slot": "ST",  "group": "FW", "x": 50, "y": 15},
        {"slot": "RW",  "group": "FW", "x": 82, "y": 22},
    ],
    "4-2-3-1": [
        {"slot": "GK",   "group": "GK", "x": 50, "y": 88},
        {"slot": "LB",   "group": "DF", "x": 15, "y": 72},
        {"slot": "CB1",  "group": "DF", "x": 38, "y": 72},
        {"slot": "CB2",  "group": "DF", "x": 62, "y": 72},
        {"slot": "RB",   "group": "DF", "x": 85, "y": 72},
        {"slot": "CDM1", "group": "MF", "x": 35, "y": 58},
        {"slot": "CDM2", "group": "MF", "x": 65, "y": 58},
        {"slot": "LM",   "group": "MF", "x": 20, "y": 38},
        {"slot": "CAM",  "group": "MF", "x": 50, "y": 32},
        {"slot": "RM",   "group": "MF", "x": 80, "y": 38},
        {"slot": "ST",   "group": "FW", "x": 50, "y": 15},
    ],
    "4-4-2": [
        {"slot": "GK",  "group": "GK", "x": 50, "y": 88},
        {"slot": "LB",  "group": "DF", "x": 15, "y": 72},
        {"slot": "CB1", "group": "DF", "x": 38, "y": 72},
        {"slot": "CB2", "group": "DF", "x": 62, "y": 72},
        {"slot": "RB",  "group": "DF", "x": 85, "y": 72},
        {"slot": "LM",  "group": "MF", "x": 15, "y": 45},
        {"slot": "CM1", "group": "MF", "x": 38, "y": 50},
        {"slot": "CM2", "group": "MF", "x": 62, "y": 50},
        {"slot": "RM",  "group": "MF", "x": 85, "y": 45},
        {"slot": "ST1", "group": "FW", "x": 38, "y": 20},
        {"slot": "ST2", "group": "FW", "x": 62, "y": 20},
    ],
    "3-4-3": [
        {"slot": "GK",  "group": "GK", "x": 50, "y": 88},
        {"slot": "CB1", "group": "DF", "x": 25, "y": 72},
        {"slot": "CB2", "group": "DF", "x": 50, "y": 72},
        {"slot": "CB3", "group": "DF", "x": 75, "y": 72},
        {"slot": "LM",  "group": "MF", "x": 15, "y": 52},
        {"slot": "CM1", "group": "MF", "x": 38, "y": 50},
        {"slot": "CM2", "group": "MF", "x": 62, "y": 50},
        {"slot": "RM",  "group": "MF", "x": 85, "y": 52},
        {"slot": "LW",  "group": "FW", "x": 18, "y": 22},
        {"slot": "ST",  "group": "FW", "x": 50, "y": 15},
        {"slot": "RW",  "group": "FW", "x": 82, "y": 22},
    ],
}

GROUP_COLORS = {"GK": "#f59e0b", "DF": "#3b82f6", "MF": "#10b981", "FW": "#ef4444"}


# =====================================================
# DB 헬퍼 함수
# =====================================================
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

def run_procedure(sql, params=None, user_id=None):
    """프로시저 실행 → 결과 DataFrame 반환.
       user_id가 주어지면 세션 변수 @app_user_id 설정 후 실행 (감사 로그용)."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            if user_id is not None:
                cur.execute("SET @app_user_id = %s", (user_id,))
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

def get_squad_count(club_id):
    """구단 현재 선수 수 반환"""
    df = run_query("SELECT COUNT(*) AS cnt FROM PLAYER WHERE club_id = %s", (club_id,))
    return int(df.iloc[0]["cnt"])

def clear_slot_state():
    """배치도 세션 상태 초기화"""
    for key in list(st.session_state.keys()):
        if key.startswith("slots_"):
            del st.session_state[key]

def init_slot_assignments(squad_df, slots):
    """포메이션 슬롯에 오버롤 높은 순으로 선수 자동 배치"""
    assignments = {}
    assigned_ids = set()
    for slot_def in slots:
        group = slot_def["group"]
        available = squad_df[
            (squad_df["position"] == group) &
            (~squad_df["player_id"].isin(assigned_ids))
        ].sort_values("overall", ascending=False)
        if not available.empty:
            pid = int(available.iloc[0]["player_id"])
            assignments[slot_def["slot"]] = pid
            assigned_ids.add(pid)
        else:
            assignments[slot_def["slot"]] = None
    return assignments

def render_pitch(slots, assignments, squad_df):
    """선수 배치가 반영된 피치 HTML 반환"""
    player_lookup = {}
    if not squad_df.empty:
        player_lookup = (
            squad_df.set_index("player_id")[["player_name", "overall", "position"]]
            .to_dict("index")
        )

    pitch_html = """
    <div style="position:relative;width:680px;height:880px;
    background:linear-gradient(180deg,#0a5c1d 0%,#0d7a2a 50%,#0a5c1d 100%);
    border:4px solid white;margin:auto;border-radius:10px;overflow:hidden;
    box-shadow:0 8px 32px rgba(0,0,0,0.5);">
    <div style="position:absolute;left:0;top:50%;width:100%;height:2px;
    background:rgba(255,255,255,0.7);"></div>
    <div style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
    width:110px;height:110px;border:2px solid rgba(255,255,255,0.7);border-radius:50%;"></div>
    <div style="position:absolute;top:50%;left:50%;width:8px;height:8px;
    border-radius:50%;background:white;transform:translate(-50%,-50%);"></div>
    <div style="position:absolute;left:18%;top:0;width:64%;height:13%;
    border:2px solid rgba(255,255,255,0.5);border-top:none;"></div>
    <div style="position:absolute;left:18%;bottom:0;width:64%;height:13%;
    border:2px solid rgba(255,255,255,0.5);border-bottom:none;"></div>
    """

    for slot_def in slots:
        sn = slot_def["slot"]
        x, y = slot_def["x"], slot_def["y"]
        pid = assignments.get(sn)

        if pid and pid in player_lookup:
            p = player_lookup[pid]
            name = p["player_name"]
            ovr  = p["overall"]
            border_color = GROUP_COLORS.get(p["position"], "gold")
        else:
            name = "미배치"
            ovr  = "-"
            border_color = "#6b7280"

        pitch_html += f"""
        <div style="position:absolute;left:{x}%;top:{y}%;transform:translate(-50%,-50%);
        background:rgba(15,20,35,0.92);color:white;padding:5px 6px;border-radius:10px;width:88px;
        text-align:center;border:2px solid {border_color};box-shadow:0 0 14px rgba(0,0,0,0.7);">
        <div style="font-size:9px;color:{border_color};font-weight:700;letter-spacing:0.5px;">{sn}</div>
        <div style="font-size:11px;font-weight:600;margin:1px 0;
        white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{name}</div>
        <div style="font-size:14px;font-weight:800;color:{border_color};">OVR {ovr}</div>
        </div>
        """

    pitch_html += "</div>"
    return pitch_html


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

# 현재 활성 시즌 표시
season_info_df = run_query(
    "SELECT season_id, season_name, start_date FROM SEASON WHERE status='active' LIMIT 1"
)
if not season_info_df.empty:
    st.sidebar.markdown(
        f"**🗓️ 현재 시즌:** {season_info_df.iloc[0]['season_name']} "
        f"_(시작 {season_info_df.iloc[0]['start_date']})_"
    )

st.sidebar.markdown("---")

page = st.sidebar.radio(
    "메뉴",
    ["📊 대시보드", "👥 내 스쿼드", "🛒 이적시장", "⚔️ 스쿼드 대결",
     "🗓️ 시즌", "📜 감사 로그"]
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

    # ─── 전술 배치도 ──────────────────────────────────
    st.markdown("---")

    # 감독 포메이션 조회 (없으면 4-3-3 기본값)
    formation_df = run_query("""
        SELECT tactics FROM V_SQUAD_SCORE WHERE club_id = %s
    """, (my_club_id,))
    formation = "4-3-3"
    if not formation_df.empty and pd.notna(formation_df.iloc[0]["tactics"]):
        raw = str(formation_df.iloc[0]["tactics"])
        if raw in FORMATION_SLOTS:
            formation = raw

    st.subheader(f"🗺️ 전술 배치도 ({formation})")

    current_slots = FORMATION_SLOTS.get(formation, FORMATION_SLOTS["4-3-3"])
    slot_key = f"slots_{my_club_id}_{formation}"

    if slot_key not in st.session_state:
        st.session_state[slot_key] = init_slot_assignments(squad_df, current_slots)

    # 전체 선수 옵션 (어느 슬롯에나 아무 선수나 배치 가능)
    pid_to_label = {None: "(미배치)"}
    for _, row in squad_df.iterrows():
        pid_to_label[int(row["player_id"])] = (
            f"{row['player_name']} [{row['position']}] OVR {row['overall']}"
        )
    label_to_pid = {v: k for k, v in pid_to_label.items()}

    pitch_col, ctrl_col = st.columns([5, 3])

    with ctrl_col:
        st.markdown("#### 선수 배치 설정")
        st.caption("슬롯을 클릭해 원하는 선수로 교체하세요. 어느 슬롯에나 배치 가능합니다.")
        for grp in ["GK", "DF", "MF", "FW"]:
            grp_slots = [s for s in current_slots if s["group"] == grp]
            if not grp_slots:
                continue
            color = GROUP_COLORS[grp]
            st.markdown(
                f'<div style="color:{color};font-weight:700;margin-top:12px;">■ {grp}</div>',
                unsafe_allow_html=True,
            )
            for slot_def in grp_slots:
                sn      = slot_def["slot"]
                cur_pid = st.session_state[slot_key].get(sn)
                cur_lbl = pid_to_label.get(cur_pid, "(미배치)")
                labels  = list(pid_to_label.values())
                try:
                    idx = labels.index(cur_lbl)
                except ValueError:
                    idx = 0
                new_lbl = st.selectbox(
                    sn, labels, index=idx,
                    key=f"dd_{my_club_id}_{formation}_{sn}"
                )
                st.session_state[slot_key][sn] = label_to_pid.get(new_lbl)

    with pitch_col:
        components.html(
            render_pitch(current_slots, st.session_state[slot_key], squad_df),
            height=920,
        )

    # ─── 선수 관리 (이적 등록 / 방출) ─────────────────
    st.markdown("---")
    st.subheader("🔧 선수 관리")

    my_count = get_squad_count(my_club_id)

    # 이미 이적시장에 등록된 선수 제외 (방출·신규등록 대상)
    my_players_df = run_query("""
        SELECT p.player_id, p.name AS player_name, p.position, p.nationality, ps.overall
        FROM PLAYER p
        JOIN PLAYER_STATS ps ON p.player_id = ps.player_id
        LEFT JOIN TRANSFER_MARKET tm ON p.player_id = tm.player_id AND tm.status = 'available'
        WHERE p.club_id = %s AND tm.player_id IS NULL
        ORDER BY FIELD(p.position,'GK','DF','MF','FW'), ps.overall DESC
    """, (my_club_id,))

    # 현재 이적시장에 등록된 내 선수 (취소 대상)
    listed_players_df = run_query("""
        SELECT tm.listing_id, p.player_id, p.name AS player_name, p.position,
               ps.overall, tm.asking_fee, tm.listed_date
        FROM TRANSFER_MARKET tm
        JOIN PLAYER p       ON tm.player_id = p.player_id
        JOIN PLAYER_STATS ps ON p.player_id = ps.player_id
        WHERE tm.seller_club_id = %s AND tm.status = 'available'
        ORDER BY FIELD(p.position,'GK','DF','MF','FW'), ps.overall DESC
    """, (my_club_id,))

    if my_players_df.empty:
        st.info("관리할 선수가 없습니다.")
    else:
        if my_count <= 11:
            st.warning(
                f"⚠️ 현재 스쿼드가 {my_count}명입니다. "
                "이적시장 등록 후 매각되면 10명 이하가 될 수 있습니다. "
                "방출은 11명 이하일 때 불가합니다."
            )

        player_options = {
            f"{row['player_name']} ({row['position']}) OVR {row['overall']}": row['player_id']
            for _, row in my_players_df.iterrows()
        }

        sell_tab, release_tab, cancel_tab = st.tabs(["📋 이적시장 등록", "🚪 방출", "📤 등록 취소"])

        with sell_tab:
            selected_sell_lbl = st.selectbox(
                "판매 등록할 선수", list(player_options.keys()), key="sell_select"
            )
            selected_sell_id = player_options[selected_sell_lbl]

            asking_fee = st.number_input(
                "요구 이적료 (원)", min_value=0, value=1_000_000,
                step=500_000, format="%d", key="asking_fee"
            )

            if st.button("📋 이적시장 등록", type="primary", key="list_btn"):
                result_df, err = run_procedure(
                    "CALL sp_list_player_for_transfer(%s, %s, %s)",
                    (selected_user_id, selected_sell_id, asking_fee),
                    user_id=selected_user_id
                )
                if err:
                    st.error(f"❌ 등록 실패: {err}")
                else:
                    sell_name = selected_sell_lbl.split("(")[0].strip()
                    st.success("✅ 이적시장 등록 완료!")
                    st.markdown(f"""
                    <div style="background:#cce5ff;border-left:5px solid #004085;
                                padding:16px;border-radius:8px;margin:12px 0;">
                        <h4>📋 등록 결과 요약</h4>
                        <b>선수:</b> {sell_name}<br>
                        <b>구단:</b> {my_club_name}<br>
                        <b>요구 이적료:</b> {int(asking_fee):,} 원<br>
                        <b>상태:</b> available (영입 대기)
                    </div>
                    """, unsafe_allow_html=True)
                    st.rerun()

        with release_tab:
            selected_release_lbl = st.selectbox(
                "방출할 선수", list(player_options.keys()), key="release_select"
            )
            selected_release_id = player_options[selected_release_lbl]
            release_name = selected_release_lbl.split("(")[0].strip()

            if my_count <= 11:
                # 10명 이하로 내려가므로 완전 차단
                st.error(
                    f"🚫 방출 불가 — 현재 스쿼드 {my_count}명입니다. "
                    "방출 시 10명 이하가 되어 진행할 수 없습니다. (최소 11명 유지)"
                )
            else:
                if st.button("🚪 방출 실행", type="primary", key="release_btn"):
                    result_df, err = run_procedure(
                        "CALL sp_release_player(%s, %s)",
                        (selected_user_id, selected_release_id),
                        user_id=selected_user_id
                    )
                    if err:
                        st.error(f"❌ 방출 실패: {err}")
                    else:
                        st.success("✅ 방출 완료!")
                        st.markdown(f"""
                        <div style="background:#fff3cd;border-left:5px solid #ffc107;
                                    padding:16px;border-radius:8px;margin:12px 0;">
                            <h4>🚪 방출 결과 요약</h4>
                            <b>선수:</b> {release_name}<br>
                            <b>소속 변경:</b> {my_club_name} → <i>소속 없음</i><br>
                            <b>계약 상태:</b> active → expired<br>
                            <b>이적 유형:</b> release
                        </div>
                        """, unsafe_allow_html=True)
                        clear_slot_state()
                        st.rerun()

        with cancel_tab:
            st.caption("이적시장에 등록된 내 매물을 취소합니다. 취소된 선수는 스쿼드로 돌아옵니다.")
            if listed_players_df.empty:
                st.info("현재 이적시장에 등록된 매물이 없습니다.")
            else:
                cancel_options = {
                    f"{row['player_name']} ({row['position']}) OVR {row['overall']} "
                    f"| {int(row['asking_fee']):,}원 (등록일: {row['listed_date']})": row['listing_id']
                    for _, row in listed_players_df.iterrows()
                }
                selected_cancel_lbl = st.selectbox(
                    "취소할 매물 선택", list(cancel_options.keys()), key="cancel_select"
                )
                selected_cancel_id  = cancel_options[selected_cancel_lbl]
                cancel_name = selected_cancel_lbl.split("(")[0].strip()

                st.warning("⚠️ 취소하면 매물이 이적시장에서 즉시 제거됩니다. 되돌릴 수 없습니다.")
                if st.button("📤 등록 취소 실행", type="secondary", key="cancel_btn"):
                    result_df, err = run_procedure(
                        "CALL sp_cancel_listing(%s, %s)",
                        (selected_user_id, selected_cancel_id),
                        user_id=selected_user_id
                    )
                    if err:
                        st.error(f"❌ 취소 실패: {err}")
                    else:
                        st.success("✅ 이적시장 등록 취소 완료!")
                        st.markdown(f"""
                        <div style="background:#fff3cd;border-left:5px solid #ffc107;
                                    padding:16px;border-radius:8px;margin:12px 0;">
                            <h4>📤 취소 결과 요약</h4>
                            <b>선수:</b> {cancel_name}<br>
                            <b>구단:</b> {my_club_name}<br>
                            <b>매물 상태:</b> available → cancelled
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
            f"{row['player_name']} ({row['position']}) OVR {row['overall']} "
            f"| {row['seller_club']} | {int(row['asking_fee']):,}원": row['listing_id']
            for _, row in available_df.iterrows()
        }
        selected_listing_label = st.selectbox("영입할 선수 선택", list(listing_options.keys()))
        selected_listing_id    = listing_options[selected_listing_label]

        selected_row   = available_df[available_df['listing_id'] == selected_listing_id].iloc[0]
        selected_fee   = int(selected_row['asking_fee'])
        selected_name  = selected_row['player_name']
        seller_name    = selected_row['seller_club']
        seller_id      = int(selected_row['seller_club_id'])

        # 판매 구단 스쿼드 부족 경고
        seller_count = get_squad_count(seller_id)
        if seller_count <= 11:
            st.warning(
                f"⚠️ {seller_name}의 현재 스쿼드가 {seller_count}명입니다. "
                "영입 후 해당 구단 선수가 부족해질 수 있습니다."
            )

        if selected_fee > my_budget:
            st.error(f"❌ 예산 부족! 필요: {selected_fee:,}원 / 잔여: {my_budget:,}원")
        else:
            if st.button("📥 영입 실행", type="primary"):

                before_buyer  = run_query("SELECT current_budget FROM CLUB WHERE club_id = %s", (my_club_id,)).iloc[0][0]
                before_seller = run_query("SELECT current_budget FROM CLUB WHERE club_id = %s", (seller_id,)).iloc[0][0]

                result_df, err = run_procedure(
                    "CALL sp_buy_player(%s, %s)",
                    (selected_user_id, selected_listing_id),
                    user_id=selected_user_id
                )

                if err:
                    st.error(f"❌ 영입 실패: {err}")
                else:
                    after_buyer  = run_query("SELECT current_budget FROM CLUB WHERE club_id = %s", (my_club_id,)).iloc[0][0]
                    after_seller = run_query("SELECT current_budget FROM CLUB WHERE club_id = %s", (seller_id,)).iloc[0][0]

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
                        <span style="color:red;">(▼ {int(before_buyer - after_buyer):,}원)</span><br>
                        <b>{seller_name} 예산:</b>
                        {int(before_seller):,}원 → {int(after_seller):,}원
                        <span style="color:blue;">(▲ {int(after_seller - before_seller):,}원)</span><br>
                        <b>매물 상태:</b> available → sold
                    </div>
                    """, unsafe_allow_html=True)
                    clear_slot_state()
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
    st.caption("⚡ 배틀 점수 = 포지션 가중치 (GK 15% · DF 30% · MF 30% · FW 25%) + 랜덤 ±5%")

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
            (my_club_id, selected_opp_id),
            user_id=selected_user_id
        )
        if err:
            st.error(f"❌ 대결 실패: {err}")
        else:
            if result_df is not None and not result_df.empty:
                result     = str(result_df.iloc[0]["result"])
                home_score = float(result_df.iloc[0]["home_score"])
                away_score = float(result_df.iloc[0]["away_score"])

                if result == "home":
                    outcome, outcome_color, outcome_bg, outcome_emoji = (
                        "승리!", "#28a745", "#0d2818", "🏆"
                    )
                elif result == "away":
                    outcome, outcome_color, outcome_bg, outcome_emoji = (
                        "패배...", "#dc3545", "#2c0f12", "💔"
                    )
                else:
                    outcome, outcome_color, outcome_bg, outcome_emoji = (
                        "무승부", "#ffc107", "#2c2a12", "🤝"
                    )

                home_score_color = outcome_color if result == "home" else "#888"
                away_score_color = outcome_color if result == "away" else "#888"

                st.markdown(f"""
                <div style="background:{outcome_bg};border:2px solid {outcome_color};
                border-radius:16px;padding:28px 32px;text-align:center;
                max-width:560px;margin:20px auto;color:white;
                box-shadow:0 8px 32px rgba(0,0,0,0.5);">
                    <div style="font-size:26px;font-weight:700;color:{outcome_color};margin-bottom:20px;">
                        {outcome_emoji} {my_club_name} {outcome}
                    </div>
                    <div style="display:flex;justify-content:space-around;align-items:center;gap:16px;">
                        <div style="flex:1;">
                            <div style="font-size:12px;color:#888;margin-bottom:4px;">홈</div>
                            <div style="font-size:16px;font-weight:600;">{my_club_name}</div>
                            <div style="font-size:52px;font-weight:800;
                            color:{home_score_color};line-height:1.1;">{home_score:.1f}</div>
                        </div>
                        <div style="font-size:22px;color:#555;font-weight:700;">VS</div>
                        <div style="flex:1;">
                            <div style="font-size:12px;color:#888;margin-bottom:4px;">원정</div>
                            <div style="font-size:16px;font-weight:600;">{selected_opp_name}</div>
                            <div style="font-size:52px;font-weight:800;
                            color:{away_score_color};line-height:1.1;">{away_score:.1f}</div>
                        </div>
                    </div>
                    <div style="margin-top:16px;font-size:11px;color:#555;">
                        포지션 가중치 스쿼드 점수 · 랜덤 변동 ±5% 적용
                    </div>
                </div>
                """, unsafe_allow_html=True)

    # ─── 내 전적 요약 ─────────────────────────────────
    st.markdown("---")
    st.subheader(f"📊 {my_club_name} 전적")

    wdl_df = run_query("""
        SELECT
            SUM(CASE WHEN (home_club_id = %s AND result = 'home')
                       OR (away_club_id = %s AND result = 'away') THEN 1 ELSE 0 END) AS wins,
            SUM(CASE WHEN result = 'draw'
                      AND (home_club_id = %s OR away_club_id = %s) THEN 1 ELSE 0 END) AS draws,
            SUM(CASE WHEN (home_club_id = %s AND result = 'away')
                       OR (away_club_id = %s AND result = 'home') THEN 1 ELSE 0 END) AS losses,
            COUNT(*) AS total
        FROM SQUAD_BATTLE
        WHERE home_club_id = %s OR away_club_id = %s
    """, (my_club_id,) * 8)

    if not wdl_df.empty and int(wdl_df.iloc[0]["total"]) > 0:
        w     = int(wdl_df.iloc[0]["wins"])
        d     = int(wdl_df.iloc[0]["draws"])
        l     = int(wdl_df.iloc[0]["losses"])
        total = int(wdl_df.iloc[0]["total"])

        c1, c2, c3, c4 = st.columns(4)
        c1.metric("승", w)
        c2.metric("무", d)
        c3.metric("패", l)
        c4.metric("승률", f"{w / total * 100:.0f}%")

        # 승/무/패 비율 바
        w_pct = w / total * 100
        d_pct = d / total * 100
        l_pct = l / total * 100
        st.markdown(f"""
        <div style="display:flex;height:18px;border-radius:9px;overflow:hidden;
        margin:10px 0;max-width:480px;">
            <div style="background:#28a745;width:{w_pct:.1f}%;
            min-width:{'4px' if w > 0 else '0'};"></div>
            <div style="background:#ffc107;width:{d_pct:.1f}%;
            min-width:{'4px' if d > 0 else '0'};"></div>
            <div style="background:#dc3545;width:{l_pct:.1f}%;
            min-width:{'4px' if l > 0 else '0'};"></div>
        </div>
        <div style="font-size:12px;color:#888;margin-bottom:12px;">
            <span style="color:#28a745;">■ 승</span>&nbsp;&nbsp;
            <span style="color:#ffc107;">■ 무</span>&nbsp;&nbsp;
            <span style="color:#dc3545;">■ 패</span>
        </div>
        """, unsafe_allow_html=True)
    else:
        st.info("아직 대결 기록이 없습니다.")

    # ─── 대결 히스토리 (색상 배지 테이블) ───────────────
    st.markdown("---")
    st.subheader("📋 대결 기록")

    battle_df = run_query("""
        SELECT hc.name        AS home_club,
               ac.name        AS away_club,
               sb.home_score,
               sb.away_score,
               sb.result,
               sb.battle_date,
               sb.home_club_id,
               sb.away_club_id
        FROM SQUAD_BATTLE sb
        JOIN CLUB hc ON sb.home_club_id = hc.club_id
        JOIN CLUB ac ON sb.away_club_id = ac.club_id
        ORDER BY sb.battle_date DESC
    """)

    if battle_df.empty:
        st.info("대결 기록이 없습니다.")
    else:
        def get_my_result(row):
            if row["home_club_id"] == my_club_id:
                if row["result"] == "home": return "승"
                elif row["result"] == "away": return "패"
                return "무"
            elif row["away_club_id"] == my_club_id:
                if row["result"] == "away": return "승"
                elif row["result"] == "home": return "패"
                return "무"
            return "-"

        table_rows = ""
        for _, row in battle_df.iterrows():
            mr = get_my_result(row)
            if mr == "승":
                badge  = '<span style="background:#28a745;color:white;font-weight:700;padding:2px 10px;border-radius:12px;">🏆 승</span>'
                row_bg = "background:#0d2818;"
            elif mr == "패":
                badge  = '<span style="background:#dc3545;color:white;font-weight:700;padding:2px 10px;border-radius:12px;">❌ 패</span>'
                row_bg = "background:#2c0f12;"
            elif mr == "무":
                badge  = '<span style="background:#ffc107;color:#333;font-weight:700;padding:2px 10px;border-radius:12px;">🤝 무</span>'
                row_bg = "background:#2c2a00;"
            else:
                badge  = "-"
                row_bg = ""

            table_rows += f"""
            <tr style="{row_bg}">
                <td style="padding:8px 14px;text-align:center;">{row['home_club']}</td>
                <td style="padding:8px 14px;text-align:center;font-size:22px;font-weight:800;color:#f0f0f0;">{float(row['home_score']):.1f}</td>
                <td style="padding:8px 14px;text-align:center;color:#555;font-weight:700;">:</td>
                <td style="padding:8px 14px;text-align:center;font-size:22px;font-weight:800;color:#f0f0f0;">{float(row['away_score']):.1f}</td>
                <td style="padding:8px 14px;text-align:center;">{row['away_club']}</td>
                <td style="padding:8px 14px;text-align:center;">{badge}</td>
                <td style="padding:8px 14px;text-align:center;color:#888;font-size:12px;">{row['battle_date']}</td>
            </tr>
            """

        st.markdown(f"""
        <table style="width:100%;border-collapse:collapse;font-size:14px;color:white;">
            <thead>
                <tr style="background:#1e1e2e;border-bottom:2px solid #333;">
                    <th style="padding:10px 14px;">홈 팀</th>
                    <th style="padding:10px 14px;" colspan="3">스코어</th>
                    <th style="padding:10px 14px;">원정 팀</th>
                    <th style="padding:10px 14px;">내 결과</th>
                    <th style="padding:10px 14px;">경기일</th>
                </tr>
            </thead>
            <tbody>{table_rows}</tbody>
        </table>
        """, unsafe_allow_html=True)

# =====================================================
# 페이지 5. 시즌
# =====================================================
elif page == "🗓️ 시즌":
    st.title("🗓️ 시즌 관리")

    cur_season_df = run_query(
        "SELECT season_id, season_name, start_date FROM SEASON WHERE status='active' LIMIT 1"
    )
    if cur_season_df.empty:
        st.error("활성 시즌이 없습니다. kleague_extensions.sql 을 먼저 실행해주세요.")
    else:
        cur_season_name = cur_season_df.iloc[0]["season_name"]
        cur_season_start = cur_season_df.iloc[0]["start_date"]
        cur_season_id    = int(cur_season_df.iloc[0]["season_id"])

        c1, c2, c3 = st.columns(3)
        c1.metric("진행 중 시즌", cur_season_name)
        c2.metric("시작일", str(cur_season_start))
        # 시즌 경기 수
        bcount_df = run_query(
            "SELECT COUNT(*) AS cnt FROM SQUAD_BATTLE WHERE season_id = %s",
            (cur_season_id,)
        )
        c3.metric("누적 경기", int(bcount_df.iloc[0]["cnt"]))

        # ─── 시즌 순위표 ──────────────────────────────────
        st.subheader("📊 현재 시즌 순위표")
        st.caption("승점 = 승×3 + 무×1 + 패×0")

        standing_df = run_query("""
            SELECT club_name AS 구단, played AS 경기, wins AS 승,
                   draws AS 무, losses AS 패, points AS 승점
            FROM V_SEASON_STANDING
            ORDER BY 승점 DESC, 승 DESC, 구단 ASC
        """)
        if standing_df.empty:
            st.info("아직 시즌 데이터가 없습니다.")
        else:
            standing_df.index = range(1, len(standing_df) + 1)
            standing_df.index.name = "순위"
            st.dataframe(standing_df, use_container_width=True)

        # ─── 시즌 최다 이적료 TOP5 ─────────────────────────
        st.markdown("---")
        st.subheader("💸 이번 시즌 최다 이적료 TOP 5 (윈도우 함수 RANK)")

        top_transfers = run_query("""
            SELECT season_name AS 시즌, fee_rank AS 순위, player_name AS 선수,
                   from_club AS 원소속, to_club AS 신소속,
                   FORMAT(fee, 0) AS 이적료, transfer_date AS 거래일
            FROM V_SEASON_TOP_TRANSFERS
            WHERE season_name = %s AND fee_rank <= 5
            ORDER BY fee_rank
        """, (cur_season_name,))
        if top_transfers.empty:
            st.info("이번 시즌 이적 거래가 아직 없습니다.")
        else:
            st.dataframe(top_transfers, use_container_width=True, hide_index=True)

        # ─── 우승 기록 ────────────────────────────────────
        st.markdown("---")
        st.subheader("🏆 역대 우승 기록")

        champ_df = run_query("""
            SELECT season_name AS 시즌, start_date AS 시작, end_date AS 종료,
                   champion_club AS 우승팀
            FROM V_CHAMPION_HISTORY
        """)
        if champ_df.empty:
            st.info("종료된 시즌이 아직 없습니다.")
        else:
            st.dataframe(champ_df, use_container_width=True, hide_index=True)

        # ─── 시즌 종료 액션 ────────────────────────────────
        st.markdown("---")
        st.subheader("⏭️ 시즌 종료 & 새 시즌 시작")
        st.warning(
            "시즌을 종료하면 **현재 승점 1위 팀이 우승팀으로 기록**되고, "
            "새 시즌이 즉시 시작됩니다. 이후 등록되는 경기·이적은 새 시즌으로 분류됩니다."
        )

        # 다음 시즌 기본 이름 생성 (YYYY-YY+1)
        try:
            parts = cur_season_name.split("-")
            base_year = int(parts[0])
            next_default = f"{base_year+1}-{(base_year+2) % 100:02d}"
        except Exception:
            next_default = "다음 시즌"

        new_name = st.text_input("새 시즌 이름", value=next_default, key="new_season_name")

        if st.button("🏁 시즌 종료 & 새 시즌 시작", type="primary"):
            if not new_name.strip():
                st.error("새 시즌 이름을 입력하세요.")
            else:
                result_df, err = run_procedure(
                    "CALL sp_start_new_season(%s)",
                    (new_name.strip(),),
                    user_id=selected_user_id
                )
                if err:
                    st.error(f"❌ 시즌 전환 실패: {err}")
                else:
                    champ = result_df.iloc[0]["champion_name"] if (result_df is not None and not result_df.empty) else "없음"
                    st.success(f"✅ 시즌 전환 완료! 이전 시즌 우승팀: **{champ}**")
                    st.rerun()


# =====================================================
# 페이지 6. 감사 로그
# =====================================================
elif page == "📜 감사 로그":
    st.title("📜 감사 로그 (Audit Log)")
    st.caption(
        "트리거가 PLAYER · CLUB · CONTRACT · TRANSFER_MARKET 변경을 자동 기록합니다. "
        "행위자는 세션 변수 @app_user_id 로 식별됩니다."
    )

    # 필터
    fc1, fc2, fc3 = st.columns(3)
    table_filter = fc1.selectbox(
        "테이블",
        ["전체", "PLAYER", "CLUB", "CONTRACT", "TRANSFER_MARKET"]
    )
    action_filter = fc2.selectbox(
        "작업",
        ["전체", "INSERT", "UPDATE", "DELETE"]
    )
    limit_rows = fc3.selectbox("표시 행 수", [50, 100, 200, 500], index=1)

    where_clauses = []
    params = []
    if table_filter != "전체":
        where_clauses.append("table_name = %s")
        params.append(table_filter)
    if action_filter != "전체":
        where_clauses.append("action = %s")
        params.append(action_filter)
    where_sql = (" WHERE " + " AND ".join(where_clauses)) if where_clauses else ""

    audit_df = run_query(f"""
        SELECT changed_at, changed_by, table_name, action, record_id, note, old_value, new_value
        FROM V_AUDIT_RECENT
        {where_sql}
        LIMIT {int(limit_rows)}
    """, tuple(params) if params else None)

    if audit_df.empty:
        st.info("기록된 감사 로그가 없습니다.")
    else:
        # 요약 통계
        s1, s2, s3, s4 = st.columns(4)
        s1.metric("표시 건수", len(audit_df))
        s2.metric("INSERT", int((audit_df["action"] == "INSERT").sum()))
        s3.metric("UPDATE", int((audit_df["action"] == "UPDATE").sum()))
        s4.metric("DELETE", int((audit_df["action"] == "DELETE").sum()))

        # 색상 배지 HTML 테이블
        rows_html = ""
        for _, row in audit_df.iterrows():
            act = row["action"]
            if act == "INSERT":
                badge = '<span style="background:#28a745;color:white;padding:2px 8px;border-radius:8px;font-size:11px;font-weight:700;">INSERT</span>'
            elif act == "UPDATE":
                badge = '<span style="background:#0d6efd;color:white;padding:2px 8px;border-radius:8px;font-size:11px;font-weight:700;">UPDATE</span>'
            elif act == "DELETE":
                badge = '<span style="background:#dc3545;color:white;padding:2px 8px;border-radius:8px;font-size:11px;font-weight:700;">DELETE</span>'
            else:
                badge = act

            old_v = "" if pd.isna(row["old_value"]) or row["old_value"] is None else str(row["old_value"])
            new_v = "" if pd.isna(row["new_value"]) or row["new_value"] is None else str(row["new_value"])

            rows_html += f"""
            <tr style="border-bottom:1px solid #2a2a2a;">
                <td style="padding:8px 10px;color:#aaa;white-space:nowrap;font-size:11px;">{row['changed_at']}</td>
                <td style="padding:8px 10px;color:#ddd;">{row['changed_by']}</td>
                <td style="padding:8px 10px;color:#ccc;font-family:monospace;">{row['table_name']}</td>
                <td style="padding:8px 10px;">{badge}</td>
                <td style="padding:8px 10px;color:#aaa;">{row['record_id'] if pd.notna(row['record_id']) else '-'}</td>
                <td style="padding:8px 10px;color:#fff;">{row['note'] or ''}</td>
                <td style="padding:8px 10px;color:#888;font-size:11px;font-family:monospace;">{old_v}</td>
                <td style="padding:8px 10px;color:#bbb;font-size:11px;font-family:monospace;">{new_v}</td>
            </tr>
            """

        st.markdown(f"""
        <table style="width:100%;border-collapse:collapse;font-size:13px;color:white;">
            <thead>
                <tr style="background:#1e1e2e;border-bottom:2px solid #333;text-align:left;">
                    <th style="padding:10px;">시각</th>
                    <th style="padding:10px;">행위자</th>
                    <th style="padding:10px;">테이블</th>
                    <th style="padding:10px;">작업</th>
                    <th style="padding:10px;">레코드</th>
                    <th style="padding:10px;">설명</th>
                    <th style="padding:10px;">이전 값</th>
                    <th style="padding:10px;">새 값</th>
                </tr>
            </thead>
            <tbody>{rows_html}</tbody>
        </table>
        """, unsafe_allow_html=True)
