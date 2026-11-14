"""Build the Vietnamese disaster catalog and Yagi summaries from sourced records."""

from collections import Counter
from datetime import date, timedelta
from hashlib import sha256
import json
from pathlib import Path
import re
import unicodedata

from .demo import Product
from .io import require

PROJECT = Path(__file__).resolve().parents[2]
GLC = PROJECT / "data" / "disasters"
CURATED = PROJECT / "config" / "disaster_events.json"
COLLECTED = GLC / "catalog_sources.json"
GLIDE_FILE = GLC / "glide_vietnam.json"
GLIDE_SEARCH = "https://www.glidenumber.net/glide/public/search/search.jsp"
# Hazard families used to date year-only NASA GDIS events.
GDIS_GLIDE_TYPES = {"storm": {"TC", "ST"}, "flood": {"FL", "FF"}}
GDIS_FAMILIES = {"storm": {"typhoon", "tropical_depression", "storm"},
                 "flood": {"flood", "flash_flood", "heavy_rain"}}
CATALOG = "c_disasters/events"
NASA_FIRST = "c_disasters/events_nasa"
ANNUAL = "c_disasters/annual_summary"
PROVINCES = "c_disasters/province_summary"
YAGI_IMPACT = "c_disasters/yagi/province_impact"
YAGI_TRACK = "c_disasters/yagi/eonet_track"
YAGI_ID = "dmc-1975"
YAGI_EONET_ID = "EONET_10740"
YAGI_NASA_IMAGE = "https://science.nasa.gov/earth/earth-observatory/southeast-china-braces-for-yagi-153288/"
TARGETS = ("Hà Nội", "Lâm Đồng", "Đà Nẵng")
NASA_CATALOGS = {"nasa_glc", "nasa_gdis"}
HANOI_REPORT = (
    "https://vov.gov.vn/thiet-hai-ban-dau-do-bao-so-3-gay-ra-o-ha-noi-hai-phong-mobiledtnew-1021513?keyDevice=true"
)


def event(raw):
    start = raw.get("start_date")
    year = date.fromisoformat(start).year if start else raw.get("year")
    metric = raw.get("metric_name")
    value = raw.get("metric_value")
    score, method = 3, "default_no_comparable_metric"
    if metric == "peak_sustained_wind_force":
        require(type(value) is int and 6 <= value <= 17, "Wind force must be within 6–17")
        score, method = 1 + ((value - 6) * 9 + 5) // 11, "wind_force_6_to_17_v1"
    elif metric == "earthquake_magnitude":
        require(type(value) in (int, float) and 0 < value <= 10, "Invalid earthquake magnitude")
        score, method = max(1, int(value + 0.5)), "magnitude_rounded_v1"
    source = raw.get("source", "curated")
    nasa_reference = raw.get("nasa_reference_url")
    nasa_kind = raw.get("nasa_evidence_kind")
    if source in NASA_CATALOGS:
        nasa_reference = raw["source_url"]
        nasa_kind = "catalog"
    name = raw.get("name")
    area = raw.get("main_affected_area")
    provinces = raw.get("provinces")
    province_basis = "source_structured_or_verified" if provinces else None
    if source == "dmc" and not provinces:
        provinces = provinces_mentioned(area)
        province_basis = "area_text_mention" if provinces else None
    return {
        "event_id": raw["event_id"], "name": name, "event_code": raw.get("event_code"),
        "hazard_type": raw["hazard_type"], "type_original": raw.get("type_original"),
        "year": year, "start_date": start,
        "date_basis": raw.get("date_basis", "source_event_date" if start else
                              "source_year_only" if year else "unknown"),
        "start_month": start[:7] if start else None, "date_reference": None,
        "record_kind": ("bulletin" if source == "dmc" and name and name.casefold().startswith(
            ("tin ", "bản tin", "cảnh báo", "dự báo")) else "event_record"),
        "main_affected_area": area, "provinces": provinces or None, "province_basis": province_basis,
        "latitude": raw.get("latitude"), "longitude": raw.get("longitude"),
        "location_accuracy": raw.get("location_accuracy"),
        "metric_name": metric, "metric_value": value, "metric_unit": raw.get("metric_unit"),
        "severity_1_10": score, "severity_method": method,
        "related_event_id": raw.get("related_event_id"), "source": source,
        "source_url": raw["source_url"], "source_record_count": raw.get("source_record_count", 1),
        "nasa_evidence_kind": nasa_kind, "nasa_reference_url": nasa_reference,
        "nasa_event_id": raw.get("nasa_event_id"), "nasa_first_track_date": raw.get("nasa_first_track_date"),
        "nasa_track_max_wind_kts": raw.get("nasa_track_max_wind_kts"),
    }


def fold(value):
    return "".join(ch for ch in unicodedata.normalize("NFD", value.casefold().replace("đ", "d"))
                   if not unicodedata.combining(ch))


def provinces_mentioned(area):
    return "; ".join(province for province in TARGETS
                     if area and re.search(rf"\b{re.escape(fold(province))}\b", fold(area)))


def track_rows(storm):
    rows = []
    for point in sorted(storm["geometry"], key=lambda value: value["date"]):
        if point["type"] != "Point":
            continue
        longitude, latitude = point["coordinates"]
        rows.append({
            "eonet_id": storm["id"], "observed_at_utc": point["date"],
            "longitude": longitude, "latitude": latitude,
            "wind_speed": point["magnitudeValue"], "wind_unit": point["magnitudeUnit"],
        })
    return rows


def match_eonet_storms(dmc, storms):
    for storm in storms:
        name = re.fullmatch(r"(?:super typhoon|typhoon|tropical storm|tropical cyclone) (.+)", fold(storm["title"]))
        track = track_rows(storm)
        if not name or not track:
            continue
        first = date.fromisoformat(track[0]["observed_at_utc"][:10])
        last = date.fromisoformat(track[-1]["observed_at_utc"][:10])
        key = re.escape(name[1]).replace(r"\-", r"[ -]")
        matches = [row for row in dmc.values()
                   if row["hazard_type"] == "typhoon" and row.get("start_date")
                   and first - timedelta(days=4) <= date.fromisoformat(row["start_date"]) <= last + timedelta(days=2)
                   and not fold(row["name"]).startswith(("tin ", "ban tin", "canh bao", "du bao"))
                   and re.search(rf"\b{key}\b", fold(row["name"]))]
        if len(matches) != 1:
            continue
        row = matches[0]
        require(not row.get("nasa_event_id"), f"Multiple EONET matches for {row['event_id']}")
        row.update(nasa_evidence_kind="event_tracker", nasa_reference_url=storm["link"],
                   nasa_event_id=storm["id"], nasa_first_track_date=first.isoformat(),
                   nasa_track_max_wind_kts=max((p["wind_speed"] for p in track
                                               if p["wind_unit"] == "kts" and p["wind_speed"] is not None),
                                              default=None))


def landslide(row, catalog_url):
    province = row["admin_division_name"]
    # The legacy catalog has a spelling variant for Hanoi.
    province = {"Ha Nội": "Hà Nội"}.get(province, province)
    area = ", ".join(part for part in (row["location_description"], province) if part)
    return event({
        "event_id": f"glc-{row['event_id']}", "event_code": row["event_id"],
        "hazard_type": "landslide", "start_date": row["event_date_iso"],
        "main_affected_area": area or "Việt Nam", "provinces": province,
        "latitude": float(row["latitude"]) if row["latitude"] else None,
        "longitude": float(row["longitude"]) if row["longitude"] else None,
        "location_accuracy": row["location_accuracy"] or None,
        "metric_name": "landslide_size" if row["landslide_size"] else None,
        "metric_value": row["landslide_size"] or None, "source_url": catalog_url, "source": "nasa_glc",
    })


def province_summary(rows):
    result = []
    for province in TARGETS:
        matches = [row for row in rows if row["record_kind"] == "event_record" and fold(province)
                   in fold(row["provinces"] or "").split("; ")]
        counts = Counter((row["source"], row["province_basis"], row["hazard_type"]) for row in matches)
        for (source, basis, hazard), count in sorted(counts.items()):
            result.append({"province": province, "source": source, "province_basis": basis,
                           "hazard_type": hazard, "reported_events": count})
    return result


def annual_summary(rows):
    counts = Counter((row["year"], row["source"], row["record_kind"], row["hazard_type"]) for row in rows)
    present = {row["year"] for row in rows if row["year"] is not None}
    for year in range(min(present), max(present) + 1):
        if year not in present:
            counts[year, "", "coverage_gap", ""] = 0
    return [{"year": year, "source": source or None, "record_kind": kind, "hazard_type": hazard or None,
             "record_count": count, "coverage_status": ("no_records_in_sources" if kind == "coverage_gap"
                                                        else "undated" if year is None else "records_available")}
            for (year, source, kind, hazard), count in sorted(
                counts.items(), key=lambda item: (item[0][0] or 0, *item[0][1:]))]


def yagi_impact(source_url):
    rows = []
    for province in TARGETS:
        confirmed = province == "Hà Nội"
        rows.append({
            "event_id": YAGI_ID, "province": province,
            "impact_status": "confirmed" if confirmed else "not_confirmed_in_sources",
            "local_impact_date": "2024-09-07" if confirmed else None,
            "wind_force": 6 if confirmed else None, "gust_force": 10 if confirmed else None,
            "reported_rain_mm": 244 if confirmed else None,
            "rain_site": "Thượng Cát" if confirmed else None,
            "detail": ("Gió và mưa do bão được ghi nhận tại Hà Nội."
                       if confirmed else "Chưa có số đo hoặc thiệt hại quy cho Yagi trong các nguồn đã đối chiếu."),
            "source_url": source_url,
            "local_report_url": HANOI_REPORT if confirmed else None,
        })
    return rows


def province_keys(row):
    return {fold(name).replace(" ", "") for name in (row["provinces"] or "").split("; ") if name}


def date_year_only(rows, glide):
    """Give year-only NASA GDIS events a month only when another record pins it down.

    1. GLIDE reuses the EM-DAT number that GDIS carries (1991-0210 -> TC-1991-000210-VNM).
    2. Otherwise exactly one month among dated DMC/DesInventar event records of the same year,
       hazard family and at least one shared province. 1 January dates are skipped as placeholders.
    Events that match neither keep start_month = null and date_basis = source_year_only."""
    by_number = {}
    for item in glide:
        by_number.setdefault(item["number"], []).append(item)
    dated = [row for row in rows if row["start_date"] and row["record_kind"] == "event_record"
             and row["source"] in ("dmc", "desinventar", "curated") and not row["start_date"].endswith("-01-01")]
    for row in rows:
        if row["source"] != "nasa_gdis" or row["start_date"] or row["hazard_type"] not in GDIS_FAMILIES:
            continue
        year, serial = row["event_code"].split("-")
        hits = [item for item in by_number.get(f"{year}-{int(serial):06d}", [])
                if item["event"] in GDIS_GLIDE_TYPES[row["hazard_type"]] and item["year"] == row["year"]
                and item["month"]]
        if len(hits) == 1:
            row.update(start_month=f"{row['year']}-{hits[0]['month']:02d}",
                       date_basis="glide_same_emdat_number",
                       date_reference=f"GLIDE {hits[0]['glidenumber']}")
            continue
        provinces = province_keys(row)
        matches = [other for other in dated if other["year"] == row["year"] and provinces & province_keys(other)
                   and other["hazard_type"] in GDIS_FAMILIES[row["hazard_type"]]]
        months = {other["start_date"][:7] for other in matches}
        if len(months) == 1:
            first = min(matches, key=lambda other: (other["start_date"], other["event_id"]))
            row.update(start_month=months.pop(), date_basis="unique_matching_record_month",
                       date_reference=first["event_id"])


def lf(content):
    return content.replace(b"\r\n", b"\n")


def products(collected=None):
    metadata = json.loads((GLC / "metadata.json").read_bytes())
    # Hash fixed line endings so Windows (CRLF) and Unix (LF) checkouts record the same SHA-256.
    # The NASA GLC export was published with CRLF; the other two files are written with LF.
    legacy = lf((GLC / "nasa_glc_vietnam.json").read_bytes()).replace(b"\n", b"\r\n")
    curated = lf(CURATED.read_bytes())
    if collected is None:
        collected = lf(COLLECTED.read_bytes())
    glide = lf(GLIDE_FILE.read_bytes()) if GLIDE_FILE.exists() else None
    catalog = json.loads(collected)
    legacy_rows = json.loads(legacy)
    require(len(legacy_rows) == metadata["event_count"], "NASA GLC count differs from metadata")
    dmc = {row["event_id"]: row for row in catalog["dmc_records"]}
    for row in json.loads(curated):
        key = row["event_id"]
        dmc[key] = {**dmc.get(key, {}), **row}
    storms = catalog["eonet_storms"]
    match_eonet_storms(dmc, storms)
    yagi_track = next(storm for storm in storms if storm["id"] == YAGI_EONET_ID)
    rows = [landslide(row, metadata["source_url"]) for row in legacy_rows]
    rows.extend(event(row) for row in [*dmc.values(), *catalog["gdis_records"], *catalog["desinventar_records"]])
    date_year_only(rows, json.loads(glide)["records"] if glide else [])
    rows.sort(key=lambda row: (row["year"] is None, row["year"] or 0, row["start_date"] or "", row["event_id"]))
    ids = {row["event_id"] for row in rows}
    require(len(ids) == len(rows), "Duplicate disaster IDs")
    require(all(row["related_event_id"] in ids | {None} for row in rows), "Unknown related disaster")
    yagi = next(row for row in rows if row["event_id"] == YAGI_ID)
    require(yagi["nasa_event_id"] == YAGI_EONET_ID, "NASA EONET Yagi match is missing")
    card = {
        "dataset": "Danh mục thiên tai Việt Nam từ các nguồn đã đối chiếu",
        "provider": "NASA SEDAC GDIS; NASA GLC; NASA EONET; DMC; DesInventar Việt Nam; nguồn chuyên ngành",
        "url": yagi["source_url"], "accessed": catalog["snapshot_date"],
        "spatial": "Việt Nam và các vùng biển liên quan theo hồ sơ nguồn.",
        "temporal": f"{min(row['year'] for row in rows if row['year'])}–"
                    f"{max(row['year'] for row in rows if row['year'])}; một số hồ sơ thiếu ngày.",
        "processing": "Gộp theo mã trong từng nguồn. Thống kê theo nguồn để tránh coi mọi hồ sơ là sự kiện riêng. "
                      "start_month của hồ sơ GDIS chỉ có năm lấy từ GLIDE cùng mã EM-DAT, hoặc từ hồ sơ "
                      "DMC/DesInventar duy nhất cùng năm, loại và tỉnh; cách xác định ghi ở date_basis, "
                      f"căn cứ ở date_reference (số GLIDE tra tại {GLIDE_SEARCH} hoặc event_id).",
        "limitation_vi": "Các nguồn có độ phủ khác nhau và có thể trùng sự kiện. Danh mục gồm cả hồ sơ ngoài khơi "
                         "và bản tin. Số đếm theo nguồn chưa phải tổng số thiên tai toàn quốc.",
        "citation": "DMC; DesInventar Việt Nam; Rosvold và Buhaug, GDIS, CC BY 4.0; NASA GLC; URL từng bản ghi.",
        "sources": [{"path": path.relative_to(PROJECT).as_posix(), "sha256": sha256(raw).hexdigest()}
                    for path, raw in ((GLC / "nasa_glc_vietnam.json", legacy), (CURATED, curated),
                                      (COLLECTED, collected), *([(GLIDE_FILE, glide)] if glide else []))],
    }
    return {
        CATALOG: Product(rows, ("event_id",), card, {}, {}),
        NASA_FIRST: Product([row for row in rows if row["nasa_reference_url"]], ("event_id",),
                            {**card, "dataset": "Thiên tai có hồ sơ hoặc quan sát NASA",
                             "url": "https://eonet.gsfc.nasa.gov/",
                             "processing": "Lọc theo hồ sơ NASA. Ghép đường bão EONET theo tên và thời gian.",
                             "limitation_vi": "Có hồ sơ hoặc ảnh NASA không phải là xếp hạng mức độ ảnh hưởng."}, {}, {}),
        ANNUAL: Product(annual_summary(rows), ("year", "source", "record_kind", "hazard_type"),
                        {**card, "dataset": "Số hồ sơ theo năm, loại và nguồn"}, {}, {}),
        PROVINCES: Product(province_summary(rows), ("province", "source", "province_basis", "hazard_type"),
                           {**card, "dataset": "Hồ sơ theo địa phương, loại và nguồn"}, {}, {}),
        YAGI_IMPACT: Product(yagi_impact(yagi["source_url"]), ("event_id", "province"),
                             {**card, "dataset": "Ảnh hưởng Yagi tại ba địa phương",
                              "temporal": "2024-09", "citation": "DMC và báo cáo nhanh Hà Nội qua VOV"}, {}, {}),
        YAGI_TRACK: Product(track_rows(yagi_track), ("eonet_id", "observed_at_utc"),
                            {**card, "dataset": "NASA EONET – Super Typhoon Yagi",
                             "provider": "NASA EONET; JTWC", "url": yagi_track["link"],
                             "temporal": "Các mốc đường bão EONET (UTC)",
                             "spatial": "Đường đi của tâm bão ở Tây Bắc Thái Bình Dương.",
                             "processing": "Giữ tọa độ, thời gian và tốc độ gió gốc theo điểm.",
                             "limitation_vi": "Tốc độ gió trên đường bão, không phải số đo tại từng tỉnh.",
                             "citation": "NASA EONET, dữ liệu đường bão từ JTWC",
                             "sources": yagi_track["sources"] + [{"url": YAGI_NASA_IMAGE}]}, {}, {}),
    }


def export_products(output=None):
    """Rebuild only the disaster files (C) from the sources committed in data/ and config/."""
    from .demo import OUTPUT, export
    for stem, product in products().items():
        stats = export(stem, product.records, product.keys, product.card,
                       output=output or OUTPUT, **product.extra)
        print(f"{stem}: {stats['rows']} rows, {stats['json_bytes']} JSON bytes")


if __name__ == "__main__":
    export_products()
