#!/usr/bin/env python3
"""
nasa_crawler.py - Crawl dữ liệu NASA cho ứng dụng câu đố không gian.

Cài đặt:
    pip install requests beautifulsoup4

Cách dùng:
    # Mục 4: tìm audio trên NASA Image and Video Library
    python nasa_crawler.py audio --queries Saturn Voyager Mars --max-per-query 20
    python nasa_crawler.py audio --queries "Apollo 11" --download   # tải cả file MP3

    # Mục 5: bảng số liệu 8 hành tinh (NSSDCA, hệ mét)
    python nasa_crawler.py planets

Biến môi trường (tuỳ chọn):
    NASA_API_KEY   Khoá miễn phí từ https://api.nasa.gov, chỉ cần khi gặp lỗi 401/403.
"""

import argparse
import csv
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

IMAGES_API = "https://images-api.nasa.gov"
FACTSHEET_URL = "https://nssdc.gsfc.nasa.gov/planetary/factsheet/"
USER_AGENT = "space-quiz-accessibility-crawler/1.0 (educational project)"
AUDIO_EXTS = (".mp3", ".m4a", ".wav")
REQUEST_DELAY = 0.4  # giây, giữ nhịp lịch sự với máy chủ NASA


# --------------------------------------------------------------------------
# Tiện ích chung
# --------------------------------------------------------------------------
def make_session() -> requests.Session:
    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT
    retry = Retry(
        total=5,
        backoff_factor=1.0,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("GET",),
    )
    session.mount("https://", HTTPAdapter(max_retries=retry))
    session.mount("http://", HTTPAdapter(max_retries=retry))
    return session


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def api_get_json(session: requests.Session, url: str, params: dict | None = None) -> dict:
    """GET JSON; tự thêm api_key nếu có; báo lỗi rõ ràng khi 401/403."""
    params = dict(params or {})
    key = os.environ.get("NASA_API_KEY")
    if key:
        params["api_key"] = key
    resp = session.get(url, params=params, timeout=30)
    if resp.status_code in (401, 403):
        raise SystemExit(
            f"Lỗi {resp.status_code} từ {url}. Hãy xin khoá miễn phí tại "
            "https://api.nasa.gov rồi đặt biến môi trường NASA_API_KEY."
        )
    resp.raise_for_status()
    return resp.json()


def safe_filename(text: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", text).strip("_")[:120]


def to_https(url: str) -> str:
    url = url.replace("http://", "https://", 1)
    # Một số href có khoảng trắng hoặc ký tự lạ
    return quote(url, safe=":/%?=&~+")


# --------------------------------------------------------------------------
# MỤC 4: NASA Image and Video Library (audio)
# --------------------------------------------------------------------------
def search_audio(session, query: str, max_items: int, page_size: int = 100) -> list[dict]:
    """Tìm audio theo từ khoá, tự phân trang."""
    records: list[dict] = []
    page = 1
    while len(records) < max_items:
        data = api_get_json(
            session,
            f"{IMAGES_API}/search",
            {
                "q": query,
                "media_type": "audio",
                "page": page,
                "page_size": min(page_size, max_items),
            },
        )
        collection = data.get("collection", {})
        items = collection.get("items", [])
        if not items:
            break

        for item in items:
            meta = (item.get("data") or [{}])[0]
            desc_508 = (meta.get("description_508") or "").strip()
            desc = (meta.get("description") or "").strip()
            records.append(
                {
                    "nasa_id": meta.get("nasa_id"),
                    "title": meta.get("title"),
                    "query": query,
                    "date_created": meta.get("date_created"),
                    "center": meta.get("center"),
                    "secondary_creator": meta.get("secondary_creator"),
                    "keywords": meta.get("keywords", []),
                    # Ưu tiên mô tả trợ năng; nếu trống dùng description
                    "description_508": desc_508 or None,
                    "description": desc or None,
                    "accessible_description": desc_508 or desc or None,
                    "description_source": (
                        "description_508" if desc_508 else ("description" if desc else None)
                    ),
                    "source_url": f"https://images.nasa.gov/details/{meta.get('nasa_id')}",
                    "credit": meta.get("secondary_creator") or meta.get("center") or "NASA",
                    "retrieved_at": now_iso(),
                }
            )
            if len(records) >= max_items:
                break

        has_next = any(l.get("rel") == "next" for l in collection.get("links", []) or [])
        if not has_next:
            break
        page += 1
        time.sleep(REQUEST_DELAY)
    return records


def get_audio_urls(session, nasa_id: str) -> list[str]:
    """Lấy danh sách file audio của một asset (ưu tiên MP3)."""
    data = api_get_json(session, f"{IMAGES_API}/asset/{quote(nasa_id)}")
    hrefs = [i.get("href", "") for i in data.get("collection", {}).get("items", [])]
    audio = [to_https(h) for h in hrefs if h.lower().endswith(AUDIO_EXTS)]
    # MP3 lên đầu, bỏ M4A/WAV xuống sau
    audio.sort(key=lambda u: (not u.lower().endswith(".mp3"), u))
    return audio


def download_file(session, url: str, dest: Path) -> bool:
    if dest.exists() and dest.stat().st_size > 0:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    with session.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(chunk_size=1 << 16):
                f.write(chunk)
    return True


def run_audio(args) -> None:
    session = make_session()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    seen: set[str] = set()
    all_records: list[dict] = []

    for query in args.queries:
        print(f"[audio] Tìm: {query!r}")
        for rec in search_audio(session, query, args.max_per_query):
            nid = rec["nasa_id"]
            if not nid or nid in seen:
                continue
            seen.add(nid)

            try:
                urls = get_audio_urls(session, nid)
            except requests.RequestException as e:
                print(f"  ! Không lấy được asset {nid}: {e}")
                urls = []
            time.sleep(REQUEST_DELAY)

            rec["audio_urls"] = urls
            rec["audio_url"] = urls[0] if urls else None
            rec["audio_file"] = None

            if args.download and rec["audio_url"]:
                ext = os.path.splitext(rec["audio_url"])[1] or ".mp3"
                dest = out / "audio" / f"{safe_filename(nid)}{ext}"
                try:
                    download_file(session, rec["audio_url"], dest)
                    rec["audio_file"] = str(dest)
                    print(f"  ✓ {dest.name}")
                except requests.RequestException as e:
                    print(f"  ! Tải lỗi {nid}: {e}")
                time.sleep(REQUEST_DELAY)

            all_records.append(rec)

    # Ghi JSONL (mỗi dòng một bản ghi, tiện nạp vào qa_bank)
    jsonl_path = out / "nasa_audio.jsonl"
    with open(jsonl_path, "w", encoding="utf-8") as f:
        for rec in all_records:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    no_desc = sum(1 for r in all_records if not r["accessible_description"])
    no_audio = sum(1 for r in all_records if not r["audio_url"])
    print(f"\nXong: {len(all_records)} bản ghi -> {jsonl_path}")
    print(f"  Thiếu mô tả: {no_desc} | Không có file audio: {no_audio}")


# --------------------------------------------------------------------------
# MỤC 5: NSSDCA Planetary Fact Sheet (metric)
# --------------------------------------------------------------------------
PLANETS = {
    "MERCURY": "Sao Thuỷ",
    "VENUS": "Sao Kim",
    "EARTH": "Trái Đất",
    "MARS": "Sao Hoả",
    "JUPITER": "Sao Mộc",
    "SATURN": "Sao Thổ",
    "URANUS": "Sao Thiên Vương",
    "NEPTUNE": "Sao Hải Vương",
}

# khoá đầu ra -> regex khớp nhãn dòng (không phân biệt hoa thường)
FIELDS = {
    "diameter_km": r"^diameter",
    "distance_from_sun_million_km": r"^distance from sun",
    "length_of_day_hours": r"^length of day",
    "orbital_period_days": r"^orbital period",
    "mean_temperature_c": r"^mean temperature",
    "number_of_moons": r"^number of moons",
}


def parse_number(text: str):
    """'1,407.6' -> 1407.6 ; 'Unknown' -> None."""
    m = re.search(r"-?\d+(?:\.\d+)?", text.replace(",", ""))
    if not m:
        return None
    val = float(m.group())
    return int(val) if val.is_integer() else val


def clean(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def parse_factsheet(html: str) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")
    col_index: dict[str, int] = {}
    raw: dict[str, dict[str, str]] = {p: {} for p in PLANETS}

    for tr in soup.find_all("tr"):
        cells = [clean(c.get_text(" ")) for c in tr.find_all(["td", "th"])]
        if not cells:
            continue

        # Dòng tiêu đề: chứa tên các hành tinh
        upper = [c.upper() for c in cells]
        if "MERCURY" in upper and "VENUS" in upper:
            col_index = {name: upper.index(name) for name in PLANETS if name in upper}
            continue
        if not col_index:
            continue

        label = cells[0].lower()
        for key, pattern in FIELDS.items():
            if re.search(pattern, label):
                for planet, idx in col_index.items():
                    if idx < len(cells) and key not in raw[planet]:
                        raw[planet][key] = cells[idx]
                break

    results = []
    for planet, vi_name in PLANETS.items():
        row = {"name_en": planet.title(), "name_vi": vi_name}
        for key in FIELDS:
            text = raw[planet].get(key, "")
            row[key] = parse_number(text) if text else None
            row[f"{key}_raw"] = text or None
        results.append(row)
    return results


def run_planets(args) -> None:
    session = make_session()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    print(f"[planets] Tải {FACTSHEET_URL}")
    resp = session.get(FACTSHEET_URL, timeout=30)
    resp.raise_for_status()
    planets = parse_factsheet(resp.text)

    missing = [
        (p["name_en"], k) for p in planets for k in FIELDS if p[k] is None
    ]
    if missing:
        print("  ! Cảnh báo: thiếu dữ liệu (có thể trang đổi cấu trúc):")
        for name, key in missing:
            print(f"    - {name}: {key}")

    payload = {
        "source": "NASA NSSDCA Planetary Fact Sheet (metric)",
        "source_url": FACTSHEET_URL,
        "credit": "NASA Goddard Space Flight Center, NSSDCA",
        "retrieved_at": now_iso(),
        "note": "Số vệ tinh theo NASA, tính đến năm 2026; đối chiếu lại trước khi phát hành.",
        "units": {
            "diameter_km": "km",
            "distance_from_sun_million_km": "10^6 km",
            "length_of_day_hours": "giờ",
            "orbital_period_days": "ngày Trái Đất",
            "mean_temperature_c": "°C",
            "number_of_moons": "vệ tinh",
        },
        "planets": planets,
    }

    json_path = out / "planetary_facts.json"
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    csv_path = out / "planetary_facts.csv"
    with open(csv_path, "w", newline="", encoding="utf-8-sig") as f:
        cols = ["name_en", "name_vi"] + list(FIELDS)
        writer = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(planets)

    print(f"Xong: {len(planets)} hành tinh -> {json_path}, {csv_path}")


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Crawl dữ liệu NASA cho app câu đố không gian")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_audio = sub.add_parser("audio", help="Mục 4: NASA Image and Video Library (audio)")
    p_audio.add_argument("--queries", nargs="+", required=True, help='Ví dụ: Saturn Voyager "Apollo 11"')
    p_audio.add_argument("--max-per-query", type=int, default=20)
    p_audio.add_argument("--download", action="store_true", help="Tải luôn file MP3")
    p_audio.add_argument("--out", default="data")
    p_audio.set_defaults(func=run_audio)

    p_planets = sub.add_parser("planets", help="Mục 5: NSSDCA Planetary Fact Sheet")
    p_planets.add_argument("--out", default="data")
    p_planets.set_defaults(func=run_planets)

    args = parser.parse_args()
    try:
        args.func(args)
    except requests.RequestException as e:
        sys.exit(f"Lỗi mạng: {e}")


if __name__ == "__main__":
    main()