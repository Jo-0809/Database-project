import csv
import html
import math
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, datetime
from pathlib import Path
from urllib.parse import urljoin
import unicodedata

import pandas as pd
import requests


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
BASE_URL = "https://www.kleague.com"
TRANSFERMARKT_BASE_URL = "https://www.transfermarkt.com"
REFERENCE_DATE = date(2026, 5, 26)
EUR_TO_KRW = 1761.3

FIELD_NAME = "\uc774\ub984"
FIELD_ENGLISH_NAME = "\uc601\ubb38\uba85"
FIELD_CLUB = "\uc18c\uc18d\uad6c\ub2e8"
FIELD_POSITION = "\ud3ec\uc9c0\uc158"
FIELD_NUMBER = "\ubc30\ubc88"
FIELD_NATIONALITY = "\uad6d\uc801"
FIELD_HEIGHT = "\ud0a4"
FIELD_WEIGHT = "\ubab8\ubb34\uac8c"
FIELD_BIRTH_DATE = "\uc0dd\ub144\uc6d4\uc77c"

TRANSFERMARKT_COMPETITIONS = {
    1: {"league_name": "K League 1", "slug": "k-league-1", "competition_id": "RSK1"},
    2: {"league_name": "K League 2", "slug": "k-league-2", "competition_id": "RSK2"},
}

TRANSFERMARKT_CLUB_ALIASES = {
    "Cheonan City": "Cheonan City FC",
    "Chungnam Asan": "Chungnam Asan FC",
    "Gimhae FC 2008": "Gimhae FC",
    "Paju Frontier": "Paju Citizen FC",
    "Seoul E-Land": "Seoul E-Land FC",
    "Yongin FC": "Yongin City FC",
}


TEAMS = [
    {"club_id": 1, "source_team_id": "K09", "club_name": "FC Seoul", "club_name_ko": "서울", "league_id": 1, "city": "Seoul", "founded_year": 1983, "stadium_name": "Seoul World Cup Stadium", "stadium_capacity": 66704, "budget": 16000000, "homepage": "https://www.fcseoul.com/"},
    {"club_id": 2, "source_team_id": "K01", "club_name": "Ulsan HD FC", "club_name_ko": "울산", "league_id": 1, "city": "Ulsan", "founded_year": 1983, "stadium_name": "Ulsan Munsu Football Stadium", "stadium_capacity": 44102, "budget": 17500000, "homepage": "https://www.uhdfc.com/"},
    {"club_id": 3, "source_team_id": "K05", "club_name": "Jeonbuk Hyundai Motors", "club_name_ko": "전북", "league_id": 1, "city": "Jeonju", "founded_year": 1994, "stadium_name": "Jeonju World Cup Stadium", "stadium_capacity": 42477, "budget": 18000000, "homepage": "https://www.hyundai-motorsfc.com"},
    {"club_id": 4, "source_team_id": "K21", "club_name": "Gangwon FC", "club_name_ko": "강원", "league_id": 1, "city": "Gangneung", "founded_year": 2008, "stadium_name": "Gangneung Stadium", "stadium_capacity": 22333, "budget": 11500000, "homepage": "https://www.gangwon-fc.com"},
    {"club_id": 5, "source_team_id": "K03", "club_name": "Pohang Steelers", "club_name_ko": "포항", "league_id": 1, "city": "Pohang", "founded_year": 1973, "stadium_name": "Pohang Steel Yard", "stadium_capacity": 17443, "budget": 13000000, "homepage": "https://www.steelers.co.kr"},
    {"club_id": 6, "source_team_id": "K18", "club_name": "Incheon United", "club_name_ko": "인천", "league_id": 1, "city": "Incheon", "founded_year": 2003, "stadium_name": "Incheon Football Stadium", "stadium_capacity": 20891, "budget": 9500000, "homepage": "https://www.incheonutd.com"},
    {"club_id": 7, "source_team_id": "K27", "club_name": "FC Anyang", "club_name_ko": "안양", "league_id": 1, "city": "Anyang", "founded_year": 2013, "stadium_name": "Anyang Sports Complex", "stadium_capacity": 17143, "budget": 8500000, "homepage": "https://www.fc-anyang.com"},
    {"club_id": 8, "source_team_id": "K04", "club_name": "Jeju SK", "club_name_ko": "제주", "league_id": 1, "city": "Seogwipo", "founded_year": 1982, "stadium_name": "Jeju World Cup Stadium", "stadium_capacity": 29791, "budget": 12000000, "homepage": "https://www.jejuskfc.com/"},
    {"club_id": 9, "source_team_id": "K26", "club_name": "Bucheon FC 1995", "club_name_ko": "부천", "league_id": 1, "city": "Bucheon", "founded_year": 2007, "stadium_name": "Bucheon Stadium", "stadium_capacity": 34456, "budget": 8500000, "homepage": "https://www.bfc1995.com"},
    {"club_id": 10, "source_team_id": "K10", "club_name": "Daejeon Hana Citizen", "club_name_ko": "대전", "league_id": 1, "city": "Daejeon", "founded_year": 1997, "stadium_name": "Daejeon World Cup Stadium", "stadium_capacity": 40903, "budget": 14500000, "homepage": "https://www.dhcfc.kr/"},
    {"club_id": 11, "source_team_id": "K35", "club_name": "Gimcheon Sangmu", "club_name_ko": "김천", "league_id": 1, "city": "Gimcheon", "founded_year": 2021, "stadium_name": "Gimcheon Sports Complex", "stadium_capacity": 25000, "budget": 10000000, "homepage": "https://gimcheonfc.com/"},
    {"club_id": 12, "source_team_id": "K22", "club_name": "Gwangju FC", "club_name_ko": "광주", "league_id": 1, "city": "Gwangju", "founded_year": 2010, "stadium_name": "Gwangju Football Stadium", "stadium_capacity": 10007, "budget": 9000000, "homepage": "https://www.gwangjufc.com/"},
    {"club_id": 13, "source_team_id": "K06", "club_name": "Busan IPark", "club_name_ko": "부산", "league_id": 2, "city": "Busan", "founded_year": 1979, "stadium_name": "Busan Asiad Main Stadium", "stadium_capacity": 53769, "budget": 8200000, "homepage": "https://www.busanipark.com"},
    {"club_id": 14, "source_team_id": "K02", "club_name": "Suwon Samsung Bluewings", "club_name_ko": "수원", "league_id": 2, "city": "Suwon", "founded_year": 1995, "stadium_name": "Suwon World Cup Stadium", "stadium_capacity": 43288, "budget": 10000000, "homepage": "https://www.bluewings.kr/"},
    {"club_id": 15, "source_team_id": "K31", "club_name": "Seoul E-Land FC", "club_name_ko": "서울E", "league_id": 2, "city": "Seoul", "founded_year": 2014, "stadium_name": "Mokdong Stadium", "stadium_capacity": 15511, "budget": 7600000, "homepage": "https://www.seoulelandfc.com"},
    {"club_id": 16, "source_team_id": "K39", "club_name": "Hwaseong FC", "club_name_ko": "화성", "league_id": 2, "city": "Hwaseong", "founded_year": 2013, "stadium_name": "Hwaseong Sports Complex", "stadium_capacity": 35265, "budget": 6200000, "homepage": "https://www.hwaseongfc.com/"},
    {"club_id": 17, "source_team_id": "K17", "club_name": "Daegu FC", "club_name_ko": "대구", "league_id": 2, "city": "Daegu", "founded_year": 2002, "stadium_name": "DGB Daegu Bank Park", "stadium_capacity": 12419, "budget": 9000000, "homepage": "https://daegufc.co.kr"},
    {"club_id": 18, "source_team_id": "K29", "club_name": "Suwon FC", "club_name_ko": "수원FC", "league_id": 2, "city": "Suwon", "founded_year": 2003, "stadium_name": "Suwon Sports Complex", "stadium_capacity": 11808, "budget": 7800000, "homepage": "https://www.suwonfc.com"},
    {"club_id": 19, "source_team_id": "K36", "club_name": "Gimpo FC", "club_name_ko": "김포", "league_id": 2, "city": "Gimpo", "founded_year": 2013, "stadium_name": "Gimpo Salter Soccer Field", "stadium_capacity": 5076, "budget": 5800000, "homepage": "https://www.gimpofc.com"},
    {"club_id": 20, "source_team_id": "K34", "club_name": "Chungnam Asan FC", "club_name_ko": "충남아산", "league_id": 2, "city": "Asan", "founded_year": 2020, "stadium_name": "Yi Sun-sin Stadium", "stadium_capacity": 19283, "budget": 6000000, "homepage": "https://www.asanfc.com"},
    {"club_id": 21, "source_team_id": "K20", "club_name": "Gyeongnam FC", "club_name_ko": "경남", "league_id": 2, "city": "Changwon", "founded_year": 2006, "stadium_name": "Changwon Football Center", "stadium_capacity": 15071, "budget": 6500000, "homepage": "http://www.gyeongnamfc.com"},
    {"club_id": 22, "source_team_id": "K08", "club_name": "Seongnam FC", "club_name_ko": "성남", "league_id": 2, "city": "Seongnam", "founded_year": 1989, "stadium_name": "Tancheon Sports Complex", "stadium_capacity": 16146, "budget": 6800000, "homepage": "https://seongnamfc.com/"},
    {"club_id": 23, "source_team_id": "K38", "club_name": "Cheonan City FC", "club_name_ko": "천안", "league_id": 2, "city": "Cheonan", "founded_year": 2008, "stadium_name": "Cheonan Stadium", "stadium_capacity": 26000, "budget": 5600000, "homepage": "https://cheonancityfc.kr/"},
    {"club_id": 24, "source_team_id": "K40", "club_name": "Paju Citizen FC", "club_name_ko": "파주", "league_id": 2, "city": "Paju", "founded_year": 2012, "stadium_name": "Paju Stadium", "stadium_capacity": 23000, "budget": 5200000, "homepage": "https://fc.pajusports.co.kr/"},
    {"club_id": 25, "source_team_id": "K42", "club_name": "Yongin City FC", "club_name_ko": "용인", "league_id": 2, "city": "Yongin", "founded_year": 2010, "stadium_name": "Yongin Mireu Stadium", "stadium_capacity": 37155, "budget": 5200000, "homepage": "https://www.yonginfc.co.kr/"},
    {"club_id": 26, "source_team_id": "K32", "club_name": "Ansan Greeners", "club_name_ko": "안산", "league_id": 2, "city": "Ansan", "founded_year": 2017, "stadium_name": "Ansan Wa Stadium", "stadium_capacity": 35000, "budget": 5400000, "homepage": "https://www.greenersfc.com/"},
    {"club_id": 27, "source_team_id": "K37", "club_name": "Chungbuk Cheongju FC", "club_name_ko": "충북청주", "league_id": 2, "city": "Cheongju", "founded_year": 2002, "stadium_name": "Cheongju Stadium", "stadium_capacity": 16280, "budget": 5600000, "homepage": "https://chfc.kr/"},
    {"club_id": 28, "source_team_id": "K07", "club_name": "Jeonnam Dragons", "club_name_ko": "전남", "league_id": 2, "city": "Gwangyang", "founded_year": 1994, "stadium_name": "Gwangyang Football Stadium", "stadium_capacity": 13496, "budget": 7000000, "homepage": "https://www.dragons.co.kr"},
    {"club_id": 29, "source_team_id": "K41", "club_name": "Gimhae FC", "club_name_ko": "김해", "league_id": 2, "city": "Gimhae", "founded_year": 2008, "stadium_name": "Gimhae Stadium", "stadium_capacity": 30000, "budget": 5200000, "homepage": "https://gimhaefc2008.com/"},
]


TEAM_BY_ID = {team["source_team_id"]: team for team in TEAMS}
TEAM_BY_KO = {team["club_name_ko"]: team for team in TEAMS}
FORMATION_CYCLE = ["4-3-3", "4-2-3-1", "4-3-2-1", "4-4-2", "3-5-2"]


def clean_html(text):
    text = re.sub(r"<[^>]+>", "", str(text))
    return re.sub(r"\s+", " ", text).strip()


def clamp(value, low=35, high=92):
    return int(max(low, min(high, round(value))))


def money_round(value):
    return int(round(float(value) / 10000) * 10000)


def eur_to_krw(value):
    return int(round(float(value or 0) * EUR_TO_KRW))


def sql_str(value):
    if value is None or (isinstance(value, float) and math.isnan(value)) or value == "":
        return "NULL"
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def sql_num(value):
    if value is None or (isinstance(value, float) and math.isnan(value)) or value == "":
        return "NULL"
    return str(value)


def row_values(row, columns):
    numeric_columns = {
        "club_id", "original_club_id", "founded_year", "stadium_capacity",
        "league_id",
        "initial_budget_krw", "current_budget_krw", "age", "squad_number",
        "height_cm", "weight_kg", "market_value_krw", "appearances",
        "starts_estimated", "goals", "assists", "shots", "yellow_cards",
        "red_cards", "pace", "shooting", "passing", "defending", "physical",
        "salary_krw", "asking_fee_krw", "listing_id", "manager_id", "rating",
        "season_id", "player_id", "seller_club_id", "user_id",
    }
    values = []
    for column in columns:
        value = row.get(column)
        if column in numeric_columns:
            values.append(sql_num(value))
        else:
            values.append(sql_str(value))
    return "(" + ", ".join(values) + ")"


def insert_sql(table, columns, rows):
    if not rows:
        return ""
    chunks = []
    chunk_size = 250
    for start in range(0, len(rows), chunk_size):
        part = rows[start:start + chunk_size]
        chunks.append(
            f"INSERT INTO {table} ({', '.join(columns)}) VALUES\n"
            + ",\n".join(row_values(row, columns) for row in part)
            + ";"
        )
    return "\n\n".join(chunks)


def get_session():
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (compatible; DB-PBL-KLeague-Simulator/1.0)",
        "Referer": BASE_URL + "/player.do",
    })
    return session


def fetch_html(session, path, params=None):
    for attempt in range(3):
        response = session.get(urljoin(BASE_URL, path), params=params, timeout=25)
        if response.ok:
            response.encoding = response.apparent_encoding or "utf-8"
            return response.text
        time.sleep(0.5 + attempt)
    response.raise_for_status()


def get_transfermarkt_session():
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (compatible; DB-PBL-KLeague-Simulator/1.0)",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": TRANSFERMARKT_BASE_URL,
    })
    return session


def normalize_external_name(value):
    text = unicodedata.normalize("NFKD", str(value or "").lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9가-힣]", "", text)


def normalize_transfermarkt_club(value):
    value = html.unescape(value or "").strip()
    return TRANSFERMARKT_CLUB_ALIASES.get(value, value)


def normalize_transfermarkt_nationality(value):
    mapping = {
        "Korea, South": "South Korea",
        "Bosnia-Herzegovina": "Bosnia and Herzegovina",
        "Cote d'Ivoire": "Ivory Coast",
        "Côte d'Ivoire": "Ivory Coast",
    }
    value = html.unescape(value or "").strip()
    return mapping.get(value, value or "Unknown")


def transfermarkt_position_group(value):
    text = (value or "").lower()
    if "goalkeeper" in text:
        return "GK"
    if "back" in text or "defender" in text:
        return "DF"
    if "midfield" in text:
        return "MF"
    return "FW"


def parse_transfermarkt_value(value):
    text = clean_html(html.unescape(value or "")).lower()
    if not re.search(r"\d", text):
        return 0
    match = re.search(r"(\d+(?:[\.,]\d+)?)\s*([mk])?", text)
    if not match:
        return 0
    number = float(match.group(1).replace(",", "."))
    multiplier = {"m": 1_000_000, "k": 1_000}.get(match.group(2), 1)
    return int(round(number * multiplier))


def transfermarkt_page_url(league_id, page=1):
    competition = TRANSFERMARKT_COMPETITIONS[league_id]
    url = (
        f"{TRANSFERMARKT_BASE_URL}/{competition['slug']}/marktwerte/"
        f"wettbewerb/{competition['competition_id']}/plus/1"
    )
    if page > 1:
        url += f"/page/{page}"
    return url


def fetch_transfermarkt_html(session, url):
    for attempt in range(3):
        response = session.get(url, timeout=25)
        if response.ok:
            response.encoding = response.apparent_encoding or "utf-8"
            return response.text
        time.sleep(0.8 + attempt)
    response.raise_for_status()


def transfermarkt_table_rows(page_html):
    starts = [match.start() for match in re.finditer(r'<tr class="(?:odd|even)">', page_html)]
    rows = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else page_html.find("</tbody>", start)
        rows.append(page_html[start:end])
    return rows


def parse_transfermarkt_row(block, league_id, page_url):
    player_match = re.search(
        r'<td class="hauptlink"[^>]*>\s*<a title="([^"]+)" href="([^"]*/profil/spieler/(\d+))"',
        block,
    )
    value_matches = re.findall(
        r'<a href="([^"]*marktwertverlauf/spieler/\d+)">([^<]+)</a>',
        block,
    )
    if not player_match or not value_matches:
        return None

    club_matches = re.findall(r'<a title="([^"]+)" href="/[^"]+/startseite/verein/\d+', block)
    nationality_matches = re.findall(r'<img[^>]+title="([^"]+)"[^>]*class="flaggenrahmen"', block)
    centered_cells = [clean_html(cell) for cell in re.findall(r'<td class="zentriert">([\s\S]*?)</td>', block)]
    numeric_cells = [int(cell) for cell in centered_cells if cell.isdigit()]
    position_match = re.search(
        r'<td class="hauptlink"[\s\S]*?</td>\s*</tr>\s*<tr>\s*<td>([\s\S]*?)</td>',
        block,
    )

    player_name = html.unescape(player_match.group(1)).strip()
    profile_path = html.unescape(player_match.group(2)).strip()
    value_path, value_text = value_matches[-1]
    primary_position = clean_html(html.unescape(position_match.group(1))) if position_match else "Unknown"
    club_name = normalize_transfermarkt_club(club_matches[-1] if club_matches else "")

    return {
        "transfermarkt_player_id": int(player_match.group(3)),
        "transfermarkt_name": player_name,
        "transfermarkt_name_key": normalize_external_name(player_name),
        "league_id": league_id,
        "club_name": club_name,
        "age": numeric_cells[1] if len(numeric_cells) > 1 else None,
        "nationality": normalize_transfermarkt_nationality(nationality_matches[0] if nationality_matches else ""),
        "primary_position": primary_position,
        "position_group": transfermarkt_position_group(primary_position),
        "market_value_eur": parse_transfermarkt_value(value_text),
        "profile_source_url": urljoin(TRANSFERMARKT_BASE_URL, profile_path),
        "value_source_url": urljoin(TRANSFERMARKT_BASE_URL, html.unescape(value_path)),
        "source_page_url": page_url,
        "matched_player_id": "",
        "matched_player_name": "",
        "match_method": "",
    }


def collect_transfermarkt_values():
    session = get_transfermarkt_session()
    values = []
    seen_ids = set()
    for league_id in [1, 2]:
        first_page = fetch_transfermarkt_html(session, transfermarkt_page_url(league_id, 1))
        page_numbers = {1}
        page_numbers.update(int(page) for page in re.findall(r"/page/(\d+)", first_page))

        for page in sorted(page_numbers):
            page_url = transfermarkt_page_url(league_id, page)
            page_html = first_page if page == 1 else fetch_transfermarkt_html(session, page_url)
            for block in transfermarkt_table_rows(page_html):
                row = parse_transfermarkt_row(block, league_id, page_url)
                if not row or row["transfermarkt_player_id"] in seen_ids:
                    continue
                seen_ids.add(row["transfermarkt_player_id"])
                values.append(row)
            time.sleep(0.25)
    return values


def apply_transfermarkt_values(players, transfermarkt_values):
    players_by_english_key = {}
    english_key_counts = {}
    for player in players:
        key = (player["club_name"], normalize_external_name(player.get("official_english_name")))
        if not key[1]:
            continue
        english_key_counts[key] = english_key_counts.get(key, 0) + 1
        players_by_english_key[key] = player

    transfermarkt_key_counts = {}
    for row in transfermarkt_values:
        key = (row["club_name"], row["transfermarkt_name_key"])
        transfermarkt_key_counts[key] = transfermarkt_key_counts.get(key, 0) + 1

    matched_player_ids = set()
    matched_count = 0
    for row in transfermarkt_values:
        key = (row["club_name"], row["transfermarkt_name_key"])
        player = players_by_english_key.get(key)
        if not player or english_key_counts.get(key) != 1 or transfermarkt_key_counts.get(key) != 1:
            continue
        player["market_value_eur"] = row["market_value_eur"]
        player["value_source_url"] = row["value_source_url"]
        row["matched_player_id"] = player["player_id"]
        row["matched_player_name"] = player["player_name"]
        row["match_method"] = "official_english_name_and_club"
        matched_player_ids.add(player["player_id"])
        matched_count += 1

    demographic_counts = {}
    for row in transfermarkt_values:
        if row["matched_player_id"]:
            continue
        key = (row["club_name"], row["age"], row["nationality"], row["position_group"])
        demographic_counts[key] = demographic_counts.get(key, 0) + 1

    players_by_demographic = {}
    player_demographic_counts = {}
    for player in players:
        if player["player_id"] in matched_player_ids:
            continue
        key = (player["club_name"], player["age"], player["nationality"], player["position_group"])
        player_demographic_counts[key] = player_demographic_counts.get(key, 0) + 1
        players_by_demographic[key] = player

    for row in transfermarkt_values:
        if row["matched_player_id"]:
            continue
        key = (row["club_name"], row["age"], row["nationality"], row["position_group"])
        player = players_by_demographic.get(key)
        if not player or demographic_counts.get(key) != 1 or player_demographic_counts.get(key) != 1:
            continue
        player["market_value_eur"] = row["market_value_eur"]
        player["value_source_url"] = row["value_source_url"]
        row["matched_player_id"] = player["player_id"]
        row["matched_player_name"] = player["player_name"]
        row["match_method"] = "unique_club_age_nationality_position"
        matched_player_ids.add(player["player_id"])
        matched_count += 1

    return matched_count


def parse_player_cards(html, fallback_position_group):
    cards = []
    for block in re.findall(r'<div class="cont-box[^"]*player-hover"[\s\S]*?</div>\s*</div>\s*</div>', html):
        id_match = re.search(r"onPlayerClicked\((\d+)\)", block)
        team_match = re.search(r"emblem_(K\d+)\.png", block)
        name_match = re.search(r'<span class="name">([\s\S]*?)<span class="small">([\s\S]*?)</span></span>', block)
        number_match = re.search(r"No\.(\d+)", block)
        img_match = re.search(r'<img src="(https://d2tfp74nsbbrkr\.cloudfront\.net[^"]*)"', block)
        if not id_match or not team_match or not name_match:
            continue
        cards.append({
            "player_id": int(id_match.group(1)),
            "source_team_id": team_match.group(1),
            "player_name": clean_html(name_match.group(1)),
            "club_name_ko": clean_html(name_match.group(2)),
            "squad_number": int(number_match.group(1)) if number_match else None,
            "position_group": fallback_position_group,
            "photo_url": img_match.group(1) if img_match else "",
        })
    return cards


def collect_cards():
    session = get_session()
    cards_by_id = {}
    for league_id in [1, 2]:
        for position in ["gk", "df", "mf", "fw"]:
            page = 1
            while True:
                html = fetch_html(session, "/player.do", {
                    "leagueId": league_id,
                    "type": "active",
                    "pos": position,
                    "page": page,
                })
                cards = parse_player_cards(html, position.upper())
                for card in cards:
                    card["league_id"] = league_id
                    cards_by_id[card["player_id"]] = card
                last_match = re.search(r'class="last[^"]*"\s+onclick="goToPage\((\d+)\)', html)
                last_page = int(last_match.group(1)) if last_match else page
                if page >= last_page:
                    break
                page += 1
    return list(cards_by_id.values())


def detail_fields(player_id):
    session = get_session()
    html = fetch_html(session, "/record/playerDetail.do", {"playerId": player_id})
    fields = {}
    for key, value in re.findall(r"<th[^>]*>([\s\S]*?)</th>\s*<td[^>]*>([\s\S]*?)</td>", html):
        fields[clean_html(key)] = clean_html(value)
    return player_id, fields


def collect_details(player_ids):
    details = {}
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(detail_fields, player_id) for player_id in player_ids]
        for future in as_completed(futures):
            player_id, fields = future.result()
            details[player_id] = fields
    return details


def collect_team_stats():
    session = get_session()
    stats = {}
    for team in TEAMS:
        response = session.post(
            BASE_URL + "/record/selectPersonalRecordByClub.do",
            json={"year": "2026", "leagueId": str(team["league_id"]), "teamId": team["source_team_id"]},
            headers={"Content-Type": "application/json; charset=utf-8", "X-Requested-With": "XMLHttpRequest"},
            timeout=25,
        )
        data = response.json().get("data", {}).get("list", [])
        for item in data:
            name = str(item.get("name") or "").strip()
            if name:
                stats[(team["source_team_id"], name)] = item
    return stats


def collect_managers():
    session = get_session()
    managers = {}
    for league_id in [1, 2]:
        page = 1
        while True:
            html = fetch_html(session, "/player.do", {
                "leagueId": league_id,
                "type": "active",
                "pos": "manager",
                "page": page,
            })
            for block in re.findall(r'<div class="cont-box[^"]*player-hover"[\s\S]*?</div>\s*</div>\s*</div>', html):
                if "감독" not in block:
                    continue
                team_match = re.search(r"emblem_(K\d+)\.png", block)
                name_match = re.search(r'<span class="name">([\s\S]*?)<span class="small">([\s\S]*?)</span></span>', block)
                if team_match and name_match and team_match.group(1) not in managers:
                    managers[team_match.group(1)] = clean_html(name_match.group(1))
            last_match = re.search(r'class="last[^"]*"\s+onclick="goToPage\((\d+)\)', html)
            last_page = int(last_match.group(1)) if last_match else page
            if page >= last_page:
                break
            page += 1
    return managers


def parse_birth_date(value):
    if not value:
        return None, None
    try:
        parsed = datetime.strptime(value.replace(".", "/"), "%Y/%m/%d").date()
        age = REFERENCE_DATE.year - parsed.year - ((REFERENCE_DATE.month, REFERENCE_DATE.day) < (parsed.month, parsed.day))
        return parsed.isoformat(), age
    except ValueError:
        return None, None


def normalize_nationality(value):
    mapping = {
        "한국": "South Korea",
        "대한민국": "South Korea",
        "브라질": "Brazil",
        "포르투갈": "Portugal",
        "콜롬비아": "Colombia",
        "스웨덴": "Sweden",
        "일본": "Japan",
        "호주": "Australia",
        "스페인": "Spain",
        "몬테네그로": "Montenegro",
        "영국": "United Kingdom",
        "프랑스": "France",
        "가나": "Ghana",
        "크로아티아": "Croatia",
        "폴란드": "Poland",
        "아이슬란드": "Iceland",
        "네덜란드": "Netherlands",
        "세르비아": "Serbia",
        "조지아": "Georgia",
        "이탈리아": "Italy",
        "미국": "United States",
        "독일": "Germany",
        "나이지리아": "Nigeria",
        "태국": "Thailand",
        "말리": "Mali",
        "세네갈": "Senegal",
        "요르단": "Jordan",
        "파라과이": "Paraguay",
        "노르웨이": "Norway",
        "우크라이나": "Ukraine",
        "리투아니아": "Lithuania",
        "이스라엘": "Israel",
        "코소보": "Kosovo",
        "코트디부아르": "Ivory Coast",
        "보스니아 헤르체고비나": "Bosnia and Herzegovina",
    }
    return mapping.get(value, value or "Unknown")


def stat_int(item, key):
    try:
        return int(item.get(key) or 0)
    except (TypeError, ValueError):
        return 0


def ability_from_public_stats(player, stats_item):
    position = player["position_group"]
    league_bonus = 4 if player["league_id"] == 1 else 0
    age = player.get("age") or 25
    appearances = stat_int(stats_item, "gameQty")
    starts = max(0, appearances - stat_int(stats_item, "changeIqty"))
    goals = stat_int(stats_item, "goalQty")
    assists = stat_int(stats_item, "assistQty")
    shots = stat_int(stats_item, "stQty")
    yellow = stat_int(stats_item, "warnQty")
    red = stat_int(stats_item, "exitQty")
    clean = stat_int(stats_item, "clQty")
    conceded = stat_int(stats_item, "lossQoal")
    height = player.get("height_cm") or 178
    weight = player.get("weight_kg") or 74
    game_bonus = min(appearances, 25) * 0.9 + min(starts, 25) * 0.25
    youth_bonus = 2 if age <= 23 else (-2 if age >= 35 else 0)
    physical_base = 52 + (height - 175) * 0.16 + (weight - 72) * 0.12 + league_bonus * 0.4

    if position == "GK":
        return {
            "pace": clamp(43 + league_bonus + appearances * 0.18),
            "shooting": clamp(18 + league_bonus * 0.3, 10, 70),
            "passing": clamp(50 + league_bonus + game_bonus * 0.28),
            "defending": clamp(58 + league_bonus + game_bonus * 0.65 + clean * 1.8 - conceded * 0.08),
            "physical": clamp(physical_base + 5 + appearances * 0.15),
        }
    if position == "DF":
        return {
            "pace": clamp(54 + league_bonus + game_bonus * 0.25 + youth_bonus),
            "shooting": clamp(35 + league_bonus + goals * 2.6 + shots * 0.16),
            "passing": clamp(50 + league_bonus + assists * 2.2 + game_bonus * 0.35),
            "defending": clamp(58 + league_bonus + game_bonus * 0.65 - yellow * 0.25 - red * 1.5),
            "physical": clamp(physical_base + 4 + game_bonus * 0.18),
        }
    if position == "MF":
        return {
            "pace": clamp(56 + league_bonus + game_bonus * 0.27 + youth_bonus),
            "shooting": clamp(45 + league_bonus + goals * 2.5 + shots * 0.18),
            "passing": clamp(58 + league_bonus + assists * 2.8 + game_bonus * 0.55),
            "defending": clamp(50 + league_bonus + game_bonus * 0.33 - yellow * 0.15),
            "physical": clamp(physical_base + game_bonus * 0.16),
        }
    return {
        "pace": clamp(58 + league_bonus + game_bonus * 0.3 + youth_bonus),
        "shooting": clamp(56 + league_bonus + goals * 2.9 + shots * 0.22),
        "passing": clamp(48 + league_bonus + assists * 2.5 + game_bonus * 0.32),
        "defending": clamp(38 + league_bonus + game_bonus * 0.18),
        "physical": clamp(physical_base + 2 + game_bonus * 0.18),
    }


def build_dataset():
    print("Collecting official active player list...")
    cards = collect_cards()
    print(f"Collected {len(cards)} active players.")
    if len(cards) < 1000:
        raise RuntimeError(
            f"K League player collection returned only {len(cards)} cards. "
            "This is likely a transient source-page response; rerun before regenerating data."
        )
    details = collect_details([card["player_id"] for card in cards])
    stats = collect_team_stats()
    manager_names = collect_managers()
    print("Collecting Transfermarkt public market values...")
    transfermarkt_values = collect_transfermarkt_values()
    print(f"Collected {len(transfermarkt_values)} Transfermarkt market value rows.")

    old_players = {}
    old_stats = {}
    old_players_path = DATA_DIR / "cleaned_players.csv"
    old_stats_path = DATA_DIR / "player_stats.csv"
    if old_players_path.exists():
        old_players = pd.read_csv(old_players_path).set_index("player_id").to_dict("index")
    if old_stats_path.exists():
        old_stats = pd.read_csv(old_stats_path).set_index("player_id").to_dict("index")

    clubs = []
    for team in TEAMS:
        clubs.append({
            "club_id": team["club_id"],
            "source_team_id": team["source_team_id"],
            "league_id": team["league_id"],
            "league_name": f"K League {team['league_id']}",
            "club_name": team["club_name"],
            "city": team["city"],
            "founded_year": team["founded_year"],
            "stadium_name": team["stadium_name"],
            "stadium_capacity": team["stadium_capacity"],
            "initial_budget_krw": eur_to_krw(team["budget"]),
            "current_budget_krw": eur_to_krw(team["budget"]),
            "club_homepage": team["homepage"],
            "data_source_url": f"{BASE_URL}/player.do?leagueId={team['league_id']}&teamId={team['source_team_id']}&type=active",
        })

    players = []
    player_stats = []
    contracts = []
    transfer_market = []
    seen_player_identities = set()
    for card in sorted(cards, key=lambda item: (TEAM_BY_ID[item["source_team_id"]]["club_id"], item["position_group"], item["player_name"], -int(item["player_id"]))):
        fields = details.get(card["player_id"], {})
        team = TEAM_BY_ID[card["source_team_id"]]
        birth_date, age = parse_birth_date(fields.get(FIELD_BIRTH_DATE))
        height_value = fields.get(FIELD_HEIGHT)
        weight_value = fields.get(FIELD_WEIGHT)
        height = int(height_value) if str(height_value or "").isdigit() else None
        weight = int(weight_value) if str(weight_value or "").isdigit() else None
        position_group = fields.get(FIELD_POSITION) or card["position_group"]
        if position_group not in {"GK", "DF", "MF", "FW"}:
            position_group = card["position_group"]

        old_player = old_players.get(card["player_id"], {})
        row = {
            "player_id": card["player_id"],
            "source_player_id": str(card["player_id"]),
            "club_id": team["club_id"],
            "club_name": team["club_name"],
            "original_club_id": team["club_id"],
            "player_name": fields.get(FIELD_NAME) or card["player_name"],
            "official_english_name": fields.get(FIELD_ENGLISH_NAME) or "",
            "nationality": normalize_nationality(fields.get(FIELD_NATIONALITY)),
            "birth_date": birth_date,
            "age": age,
            "position_group": position_group,
            "primary_position": old_player.get("primary_position") or position_group,
            "squad_number": int(fields.get(FIELD_NUMBER) or card.get("squad_number") or 0) or None,
            "height_cm": height,
            "weight_kg": weight,
            "preferred_foot": old_player.get("preferred_foot") or "Unknown",
            "market_value_eur": 0,
            "market_value_krw": 0,
            "contract_until": None,
            "joined_date": "2026-01-01",
            "profile_source_url": f"{BASE_URL}/record/playerDetail.do?playerId={card['player_id']}",
            "value_source_url": "NO_CONFIDENT_TRANSFERMARKT_MATCH",
            "league_id": team["league_id"],
        }
        identity = (
            row["club_id"],
            row["player_name"],
            row["birth_date"],
            row["nationality"],
            row["squad_number"],
            row["height_cm"],
            row["weight_kg"],
        )
        if all(identity) and identity in seen_player_identities:
            continue
        seen_player_identities.add(identity)

        stat_item = stats.get((card["source_team_id"], row["player_name"]), {})
        abilities = ability_from_public_stats(row, stat_item)
        row.update(abilities)

        players.append(row)
        player_stats.append({
            "player_id": row["player_id"],
            "appearances": stat_int(stat_item, "gameQty"),
            "starts_estimated": max(0, stat_int(stat_item, "gameQty") - stat_int(stat_item, "changeIqty")),
            "goals": stat_int(stat_item, "goalQty"),
            "assists": stat_int(stat_item, "assistQty"),
            "shots": stat_int(stat_item, "stQty"),
            "yellow_cards": stat_int(stat_item, "warnQty"),
            "red_cards": stat_int(stat_item, "exitQty"),
            "pace": row["pace"],
            "shooting": row["shooting"],
            "passing": row["passing"],
            "defending": row["defending"],
            "physical": row["physical"],
            "rating_source": "DERIVED_FROM_KLEAGUE_2026_PUBLIC_RECORDS",
        })
    matched_count = apply_transfermarkt_values(players, transfermarkt_values)
    print(f"Matched {matched_count} K League players to Transfermarkt market values.")

    for row in players:
        row["market_value_krw"] = eur_to_krw(row["market_value_eur"])
        contracts.append({
            "player_id": row["player_id"],
            "club_id": row["club_id"],
            "start_date": "2026-01-01",
            "end_date": "2028-01-01",
            "salary_krw": eur_to_krw(money_round(max(row["market_value_eur"] * 0.08, 20000))),
            "status": "active",
        })
        if row["market_value_eur"] > 0:
            transfer_market.append({
                "listing_id": len(transfer_market) + 1,
                "player_id": row["player_id"],
                "seller_club_id": row["club_id"],
                "asking_fee_krw": row["market_value_krw"],
                "listed_date": "2026-01-01",
                "status": "listed",
            })

    managers = []
    for index, team in enumerate(TEAMS, start=1):
        managers.append({
            "manager_id": index,
            "club_id": team["club_id"],
            "manager_name": manager_names.get(team["source_team_id"], f"{team['club_name']} Manager"),
            "nationality": "Unknown",
            "preferred_formation": FORMATION_CYCLE[(index - 1) % len(FORMATION_CYCLE)],
            "rating": 82 if team["league_id"] == 1 else 76,
            "rating_source": "OFFICIAL_MANAGER_LIST_SIM_RULE",
        })

    app_users = [{
        "user_id": team["club_id"],
        "username": "manager_" + re.sub(r"[^a-z0-9]+", "_", team["club_name"].lower()).strip("_"),
        "club_id": team["club_id"],
    } for team in TEAMS]

    return clubs, managers, players, player_stats, contracts, transfer_market, app_users, transfermarkt_values


def write_csv(path, rows, columns):
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column, "") for column in columns})


def build_dml(clubs, managers, players, player_stats, contracts, transfer_market, app_users, transfermarkt_values):
    data_sources = [
        {"source_id": "SRC_KLEAGUE_OFFICIAL", "source_name": "K League official website", "source_url": "https://www.kleague.com/player.do", "used_for": "active K League 1 and K League 2 player rosters, official player profile fields, official 2026 public records"},
        {"source_id": "SRC_TRANSFERMARKT_K1", "source_name": "Transfermarkt K League 1 market values", "source_url": "https://www.transfermarkt.com/k-league-1/marktwerte/wettbewerb/RSK1", "used_for": f"public player market values; inserted only when confidently matched to the K League official roster; EUR converted at 1 EUR = {EUR_TO_KRW} KRW"},
        {"source_id": "SRC_TRANSFERMARKT_K2", "source_name": "Transfermarkt K League 2 market values", "source_url": "https://www.transfermarkt.com/k-league-2/marktwerte/wettbewerb/RSK2", "used_for": f"public player market values; inserted only when confidently matched to the K League official roster; EUR converted at 1 EUR = {EUR_TO_KRW} KRW"},
        {"source_id": "SRC_SIM_RULE", "source_name": "Simulation rules", "source_url": "local project rule", "used_for": "budgets, salary estimates, player ratings, manager ratings, squad scores, and recommendation rules; player market values are not estimated locally"},
    ]
    seasons = [{"season_id": 1, "season_name": "2026", "start_date": "2026-01-01", "status": "active"}]

    player_columns = ["player_id", "source_player_id", "club_id", "original_club_id", "player_name", "nationality", "birth_date", "age", "position_group", "primary_position", "squad_number", "height_cm", "weight_kg", "preferred_foot", "market_value_krw", "contract_until", "joined_date", "profile_source_url", "value_source_url"]
    csv_player_columns = ["player_id", "source_player_id", "club_id", "club_name", "original_club_id", "player_name", "official_english_name", "nationality", "birth_date", "age", "position_group", "primary_position", "squad_number", "height_cm", "weight_kg", "preferred_foot", "market_value_krw", "contract_until", "joined_date", "profile_source_url", "value_source_url"]
    transfermarkt_columns = ["transfermarkt_player_id", "transfermarkt_name", "league_id", "club_name", "age", "nationality", "primary_position", "position_group", "market_value_eur", "profile_source_url", "value_source_url", "source_page_url", "matched_player_id", "matched_player_name", "match_method"]

    parts = [
        "USE kleague_db;",
        insert_sql("data_sources", ["source_id", "source_name", "source_url", "used_for"], data_sources),
        insert_sql("clubs", ["club_id", "source_team_id", "league_id", "league_name", "club_name", "city", "founded_year", "stadium_name", "stadium_capacity", "initial_budget_krw", "current_budget_krw", "club_homepage", "data_source_url"], clubs),
        insert_sql("managers", ["manager_id", "club_id", "manager_name", "nationality", "preferred_formation", "rating", "rating_source"], managers),
        insert_sql("seasons", ["season_id", "season_name", "start_date", "status"], seasons),
        insert_sql("players", player_columns, players),
        insert_sql("player_stats", ["player_id", "appearances", "starts_estimated", "goals", "assists", "shots", "yellow_cards", "red_cards", "pace", "shooting", "passing", "defending", "physical", "rating_source"], player_stats),
        insert_sql("contracts", ["player_id", "club_id", "start_date", "end_date", "salary_krw", "status"], contracts),
        insert_sql("transfer_market", ["listing_id", "player_id", "seller_club_id", "asking_fee_krw", "listed_date", "status"], transfer_market),
        insert_sql("app_users", ["user_id", "username", "club_id"], app_users),
    ]
    dml = "\n\n".join(part for part in parts if part)

    write_csv(DATA_DIR / "data_sources.csv", data_sources, ["source_id", "source_name", "source_url", "used_for"])
    write_csv(DATA_DIR / "cleaned_clubs.csv", clubs, ["club_id", "source_team_id", "league_id", "league_name", "club_name", "city", "founded_year", "stadium_name", "stadium_capacity", "initial_budget_krw", "current_budget_krw", "club_homepage", "data_source_url"])
    write_csv(DATA_DIR / "managers.csv", managers, ["manager_id", "club_id", "manager_name", "nationality", "preferred_formation", "rating", "rating_source"])
    write_csv(DATA_DIR / "cleaned_players.csv", players, csv_player_columns)
    write_csv(DATA_DIR / "player_stats.csv", player_stats, ["player_id", "appearances", "starts_estimated", "goals", "assists", "shots", "yellow_cards", "red_cards", "pace", "shooting", "passing", "defending", "physical", "rating_source"])
    write_csv(DATA_DIR / "contracts.csv", contracts, ["player_id", "club_id", "start_date", "end_date", "salary_krw", "status"])
    write_csv(DATA_DIR / "transfer_market.csv", transfer_market, ["listing_id", "player_id", "seller_club_id", "asking_fee_krw", "listed_date", "status"])
    write_csv(DATA_DIR / "app_users.csv", app_users, ["user_id", "username", "club_id"])
    write_csv(DATA_DIR / "transfermarkt_values.csv", transfermarkt_values, transfermarkt_columns)

    (ROOT / "kleague_dml.sql").write_text(dml + "\n", encoding="utf-8")
    (ROOT / "kleague_dml_kor.sql").write_text(dml + "\n", encoding="utf-8")
    ddl = (ROOT / "kleague_ddl.sql").read_text(encoding="utf-8")
    procedures = (ROOT / "kleague_procedures.sql").read_text(encoding="utf-8")
    (ROOT / "kleague_full_setup.sql").write_text(ddl.rstrip() + "\n\n" + dml.rstrip() + "\n\n" + procedures.rstrip() + "\n", encoding="utf-8")


def main():
    DATA_DIR.mkdir(exist_ok=True)
    clubs, managers, players, player_stats, contracts, transfer_market, app_users, transfermarkt_values = build_dataset()
    build_dml(clubs, managers, players, player_stats, contracts, transfer_market, app_users, transfermarkt_values)
    by_league = pd.DataFrame(players).merge(pd.DataFrame(clubs)[["club_id", "source_team_id"]], on="club_id")
    matched_values = sum(1 for item in transfermarkt_values if item.get("matched_player_id"))
    print(f"Wrote {len(clubs)} clubs, {len(players)} players, {len(transfer_market)} market listings.")
    print(f"Transfermarkt values: {matched_values}/{len(transfermarkt_values)} rows matched to K League official players.")


if __name__ == "__main__":
    main()
