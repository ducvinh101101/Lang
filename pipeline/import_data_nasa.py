"""Nhập dữ liệu đã chuẩn bị trong kho `data_nasa/` vào app:

  F1 · data_nasa/f1/data/deliverables/demo/c_disasters/events_nasa.json
       → app/assets/data/vn_disasters_nasa.json
       Danh mục thiên tai Việt Nam có hồ sơ / quan sát NASA (GDIS, GLC, EONET; kèm DMC, DesInventar), 1971–2026,
       mức nặng 1–10, tháng bắt đầu. Mỗi sự kiện được ĐỊNH VỊ bằng tâm các tỉnh cũ bị ảnh hưởng (tính từ danh bạ
       hành chính vn_dvhc.json của app) để app phát đúng thiên tai quanh nơi người dùng hỏi, không cần mạng.

  F2 · data_nasa/assets/content/facts.json (NASA Space Place, bản dịch tiếng Việt)
       → thêm vào `fun_facts` của app/assets/data/planets_nasa.json (chỉ câu gạch đầu dòng ngắn, bỏ câu còn đơn vị
       Mỹ — độ F, dặm, pound — và câu hỏi), giữ nguyên các sự thật song ngữ đã có.

Chạy: python pipeline/import_data_nasa.py   (mặc định đọc data_nasa/ ở gốc repo; đổi bằng biến môi trường DATA_NASA)
"""
from __future__ import annotations

import difflib
import json
import os
import shutil
import re
import sys
import unicodedata
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

ROOT = Path(__file__).resolve().parent.parent
# đường dẫn kho data_nasa: biến môi trường DATA_NASA, mặc định ../data_nasa (không đọc sys.argv: pytest cũng dùng nó)
DATA_NASA = Path(os.environ.get("DATA_NASA", str(ROOT / "data_nasa")))
APP_DATA = ROOT / "app" / "assets" / "data"


def fold(s: str) -> str:
    """Bỏ dấu, chữ thường, chỉ giữ a-z (chịu được tên viết liền / không dấu / lỗi mã hoá mất chữ)."""
    s = s.replace("đ", "d").replace("Đ", "D").replace("Ð", "D")
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z]", "", s.lower())


# ----------------------------------------------------------------------------------------------- F1
def old_province_centroids() -> dict[str, tuple[str, float, float]]:
    """Tên tỉnh cũ (đã fold) → (tên đẹp, vĩ độ, kinh độ) = trung bình trụ sở các xã/phường mới thuộc tỉnh đó."""
    d = json.loads((APP_DATA / "vn_dvhc.json").read_text(encoding="utf-8"))
    wards = {w[0]: (w[4], w[5]) for w in d["w"]}
    acc: dict[str, list[float]] = {}
    for name, di, code in d["o"]:
        if code not in wards:
            continue
        prov = d["d"][di][1]
        la, lo = wards[code]
        a = acc.setdefault(prov, [0.0, 0.0, 0])
        a[0] += la
        a[1] += lo
        a[2] += 1
    out = {}
    for prov, (sla, slo, n) in acc.items():
        pretty = re.sub(r"^(Tỉnh|Thành phố)\s+", "", prov)
        out[fold(pretty)] = (pretty, sla / n, slo / n)
    # tên gọi khác thường gặp trong nguồn
    for alias, key in {
        "thuathienhue": "hue", "hochiminh": "hochiminh", "tphochiminh": "hochiminh", "saigon": "hochiminh",
        "bariavungtau": "bariavungtau", "daklak": "daklak", "daknong": "daknong",
    }.items():
        if key in out and alias not in out:
            out[alias] = out[key]
    return out


def locate(text: str, table: dict) -> list[tuple[str, float, float]]:
    """Tìm các tỉnh nhắc tới trong một chuỗi (danh sách tỉnh hoặc mô tả vùng ảnh hưởng)."""
    found: dict[str, tuple[str, float, float]] = {}
    if not text:
        return []
    parts = re.split(r"[;,/]|\s+-\s+|–|\bvà\b|\band\b", text)
    for p in parts:
        # bỏ phần mô tả đứng trước tên tỉnh: "Trên đất liền khu vực các tỉnh Lào Cai" → "Lào Cai"
        p = re.sub(r"^.*(?:[Tt]ỉnh|[Tt]hành phố|TP\.?|[Hh]uyện|[Kk]hu vực)\s+", "", p.strip())
        f = fold(p)
        if len(f) < 3:
            continue
        if f in table:
            found[f] = table[f]
            continue
        m = difflib.get_close_matches(f, table.keys(), n=1, cutoff=0.86)
        if m:
            found[m[0]] = table[m[0]]
    # mô tả dài ("Trên đất liền khu vực các tỉnh Lào Cai, Yên Bái…"): dò thêm từng tên tỉnh (≥ 5 chữ) trong cả câu
    ft = fold(text)
    for k, v in table.items():
        if len(k) >= 5 and k in ft:
            found[k] = v
    return list(found.values())


KIND = {
    "storm": "storm", "typhoon": "storm", "tropical_depression": "storm", "tornado": "storm", "windstorm": "storm",
    "severe_thunderstorm": "storm", "lightning": "storm", "flood": "flood", "flash_flood": "flood",
    "heavy_rain": "heavyRain", "landslide": "landslide", "earthquake": "earthquake", "drought": "drought",
    "heat": "heat", "heatwave": "heat", "cold": "cold", "wildfire": "wildfire",
}
NAME_VI = {"storm": "Bão, áp thấp", "flood": "Lũ lụt", "heavyRain": "Mưa lớn", "landslide": "Sạt lở đất",
           "earthquake": "Động đất", "drought": "Hạn hán", "heat": "Nắng nóng", "cold": "Rét hại", "wildfire": "Cháy rừng"}
NAME_EN = {"storm": "Storm", "flood": "Flood", "heavyRain": "Heavy rain", "landslide": "Landslide",
           "earthquake": "Earthquake", "drought": "Drought", "heat": "Heat wave", "cold": "Cold spell", "wildfire": "Wildfire"}
SRC_NAME = {"nasa_gdis": "NASA GDIS", "nasa_glc": "NASA GLC", "dmc": "DMC", "desinventar": "DesInventar", "eonet": "NASA EONET"}


def build_f1() -> dict:
    src = DATA_NASA / "f1" / "data" / "deliverables" / "demo" / "c_disasters" / "events_nasa.json"
    j = json.loads(src.read_text(encoding="utf-8"))
    table = old_province_centroids()
    out, unplaced = [], 0
    for r in j["records"]:
        kind = KIND.get(r.get("hazard_type") or "")
        if not kind:
            continue
        pts: list[tuple[str, float, float]] = []
        if r.get("latitude") is not None and r.get("longitude") is not None:
            pts.append(("", float(r["latitude"]), float(r["longitude"])))
        pts += locate(r.get("provinces") or "", table)
        if len(pts) <= (1 if pts and pts[0][0] == "" else 0):
            pts += locate(r.get("main_affected_area") or "", table)
        if not pts:
            unplaced += 1
            continue
        year = int(r["year"])
        month = r.get("start_month")
        date = r.get("start_date") or (f"{month}-15" if month else f"{year}-12-31")
        year_only = not r.get("start_date") and not month
        names = [p[0] for p in pts if p[0]]
        area = ", ".join(dict.fromkeys(names)) or (r.get("main_affected_area") or "")
        title = (r.get("name") or "").strip()
        tvi = title if title else NAME_VI[kind]
        if area:
            tvi += f", ảnh hưởng {area}"
        metric = ""
        if r.get("metric_value") is not None and r.get("metric_unit"):
            metric = f", {r['metric_value']} {r['metric_unit']}"
        if year_only:
            tvi += f" (trong năm {year}, chưa rõ tháng)"
        ten = f"{NAME_EN[kind]}{(' ' + title) if title and title.isascii() else ''}, {fold_ascii(area)}"
        out.append({
            "id": r["event_id"],
            "kind": kind,
            "date": date,
            "year_only": year_only,
            "severity": round(max(1.0, min(5.0, float(r.get("severity_1_10") or 3) / 2)), 1),
            "title_vi": tvi + metric,
            "title_en": ten + (f" (sometime in {year})" if year_only else ""),
            "points": [[round(p[1], 3), round(p[2], 3)] for p in pts],
            "source": SRC_NAME.get(r.get("source") or "", r.get("source") or ""),
            "url": r.get("nasa_reference_url") or r.get("source_url") or "",
        })
    card = dict(j["data_card"])
    card["processing"] = (card.get("processing", "") +
                          " App: định vị theo tâm các tỉnh cũ bị ảnh hưởng (tính từ trụ sở xã/phường); mức nặng 1–10 quy về 1–5.")
    print(f"F1: {len(out)} sự kiện có vị trí, {unplaced} sự kiện không định vị được (bỏ qua)")
    return {"data_card": card, "records": out}


def fold_ascii(s: str) -> str:
    s = s.replace("đ", "d").replace("Đ", "D")
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


# ----------------------------------------------------------------------------------------------- F2
BAD = re.compile(r"(độ F|\bdặm\b|\bpound\b|\binch\b|\bfeet\b|\bfoot\b|\?|hình ảnh|ảnh trên|ảnh dưới|nhấp|bấm vào|video)", re.I)


def merge_f2() -> int:
    facts = json.loads((DATA_NASA / "assets" / "content" / "facts.json").read_text(encoding="utf-8"))
    pf = APP_DATA / "planets_nasa.json"
    p = json.loads(pf.read_text(encoding="utf-8"))
    added = 0
    for b in p["bodies"]:
        src = facts["planets"].get(b["id"])
        if not src:
            continue
        # chạy lại nhiều lần cho cùng kết quả: bỏ bản Space Place cũ rồi thêm lại
        keep = [f for f in b.get("fun_facts", []) if f.get("source") != "NASA Space Place"]
        have = {fold(f["vi"]) for f in keep}
        for f in src["facts"]:
            t = f["text"].strip()
            if f.get("kind") != "bullet" or BAD.search(t) or len(t) > 230 or len(t) < 25:
                continue
            if fold(t) in have:
                continue
            have.add(fold(t))
            keep.append({"vi": t, "en": "", "source": "NASA Space Place",
                         "url": (f.get("source_urls") or src.get("source_urls") or [""])[0]})
            added += 1
        b["fun_facts"] = keep
    pf.write_text(json.dumps(p, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"F2: thêm {added} sự thật NASA Space Place vào planets_nasa.json")
    return added


def main():
    if not DATA_NASA.exists():
        sys.exit(f"Không thấy kho data_nasa ở {DATA_NASA}")
    f1 = build_f1()
    (APP_DATA / "vn_disasters_nasa.json").write_text(json.dumps(f1, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    merge_f2()




# ----------------------------------------------------------------------------------------------- F1 · khí hậu 34 tỉnh
def build_climate34() -> dict:
    """data_nasa/f1/data/deliverables/a_34/provinces/*.json (NASA POWER tháng, 1981–2025, 34 tỉnh/thành mới)
    → app/assets/data/climate_34_provinces.json gọn: mỗi tỉnh hai chuỗi 12 × số năm (nhiệt độ °C, mưa mm/tháng)."""
    folder = DATA_NASA / "f1" / "data" / "deliverables" / "a_34" / "provinces"
    places, card = [], None
    for fp in sorted(folder.glob("*.json")):
        j = json.loads(fp.read_text(encoding="utf-8"))
        card = card or j["data_card"]
        loc = j["location"]
        months = sorted((r for r in j["records"] if r["period_type"] == "month"), key=lambda r: r["period"])
        y0, y1 = int(months[0]["period"][:4]), int(months[-1]["period"][:4])
        t = {r["period"]: r["temperature_c"] for r in months}
        rr = {r["period"]: r["precipitation_total_mm"] for r in months}
        keys = [f"{y}-{m:02d}" for y in range(y0, y1 + 1) for m in range(1, 13)]
        places.append({
            "id": loc["location_id"],
            "name_vi": loc["province_name"],
            "lat": loc["latitude"],
            "lon": loc["longitude"],
            "y0": y0,
            "y1": y1,
            "t": [t.get(k) for k in keys],
            "r": [rr.get(k) for k in keys],
        })
    card = {k: v for k, v in (card or {}).items() if k != "sources"}
    card["spatial"] = "34 điểm đại diện cho 34 tỉnh/thành Việt Nam (sau sáp nhập 2025)."
    print(f"F1: khí hậu {len(places)} tỉnh/thành")
    return {"data_card": card, "places": places}


def sync_web_data(src_dir: Path | None = None, dst_dir: Path | None = None) -> int:
    """Đồng bộ các tệp dữ liệu chuẩn hóa từ app/assets/data sang web/data."""
    src_dir = src_dir or APP_DATA
    dst_dir = dst_dir or (ROOT / "web" / "data")
    if not dst_dir.exists():
        return 0
    count = 0
    for name in (
        "vn_disasters_nasa.json",
        "climate_34_provinces.json",
        "planets_nasa.json",
        "credits.csv",
        "climate_history_nasa.json",
        "gistemp_global.json",
        "qa_bank.json",
        "space_media.json",
        "dalat_scene.json",
    ):
        s = src_dir / name
        if s.exists():
            shutil.copyfile(s, dst_dir / name)
            count += 1
    print(f"Web: đồng bộ {count} tệp dữ liệu chuẩn hóa → {dst_dir}")
    return count


def _main_all():
    main()
    try:
        from nasa_sounds import build as build_sounds
    except ImportError:
        from .nasa_sounds import build as build_sounds
    build_sounds(DATA_NASA, ROOT / "app")
    copy_touch()
    c34 = build_climate34()
    (APP_DATA / "climate_34_provinces.json").write_text(json.dumps(c34, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    sync_web_data()



# ----------------------------------------------------------------------------------------------- F3 · lưới địa lý thật
TOUCH_FILES = ["grid.json", "elev.png", "slope.png", "water.png", "pop.png"]


def copy_touch(src_root: Path | None = None, dst: Path | None = None) -> bool:
    """Chép lưới cả nước data_nasa/touch/vn (do build_f3.py xuất, cần chạy crawl_f3.py với tài khoản NASA Earthdata)
    vào app/assets/touch/vn. Chưa build thì bỏ qua (app dùng cách ước lượng)."""
    src = (src_root or DATA_NASA / "touch") / "vn"
    dst = dst or ROOT / "app" / "assets" / "touch" / "vn"
    if not (src / "grid.json").exists():
        print("F3: chưa có data_nasa/touch/vn/grid.json (chạy crawl_f3.py rồi build_f3.py) → bỏ qua")
        return False
    dst.mkdir(parents=True, exist_ok=True)
    meta = json.loads((src / "grid.json").read_text(encoding="utf-8"))
    names = {"grid.json"} | {l["file"] for l in meta.get("layers", [])}
    for f in sorted(names):
        if (src / f).exists():
            shutil.copyfile(src / f, dst / f)
    print(f"F3: chép {len(names)} file lưới địa lý thật → {dst}")
    return True


if __name__ == "__main__":
    _main_all()
