"""Verify and package the retained Vietnam POWER snapshot and fetch an online sample."""

import calendar
from collections import Counter
import csv
from datetime import date, datetime, timezone
from hashlib import sha256
import json
import math
from pathlib import Path
import re

from . import archive as monthly
from .io import download, require, save_raw

REPO = Path(__file__).resolve().parents[3]
ROOT = REPO / "local-private" / "f1-data" / "vn"
OUTPUT = REPO / "f1" / "data" / "deliverables" / "vn"
SNAPSHOT = REPO / "f1" / "data" / "monthly" / "vietnam" / "climate.json"
ADMIN = REPO / "f1" / "data" / "admin" / "all-ward.json"
MONTHS = [f"{y}-{m:02d}" for y in range(1977, 2027) for m in range(1, 13)]
COLUMNS = ("month", "temperature_c", "precipitation_mm_day", "wind_speed_m_s",
           "precipitation_total_mm_derived")
LOCATION_FIELDS = ("ward_code", "ward_name", "province_code", "province_name", "latitude",
                   "longitude", "series_id", "source_url", "fetched_at", "time_standard")
PILOT = {"01": ("ha_noi", "00004"), "24": ("bac_ninh", "07210")}
PROVINCE_PACKAGES = {code: label for code, (label, _) in PILOT.items()} | {
    "48": "da_nang",
    "68": "lam_dong",
}
BUDGET = 250 * 1024**2
KHANH_HOA_BOUNDARIES = "https://tinhthanhpho.com/data/wards-56.geojson"


def checksum(content):
    return sha256(content).hexdigest()


def read_snapshot():
    raw = SNAPSHOT.read_bytes()
    data = json.loads(raw)
    admin_bytes = ADMIN.read_bytes()
    require(checksum(admin_bytes.replace(b"\r\n", b"\n")) == data["metadata"]["admin_sha256"],
            "Administrative source checksum differs from snapshot")
    admin = json.loads(admin_bytes)
    wards = {ward["id"]: ward for ward in admin}
    locations = data["locations"]
    require(len(wards) == len(admin) == len(locations) == 3321
            and {row["ward_code"] for row in locations} == set(wards)
            and len({row["province_code"] for row in locations}) == 34,
            "Expected all 3,321 unique localities in 34 provinces")
    require({row["series_id"] for row in locations} == set(data["series"]), "Broken series references")
    for row in locations:
        ward = wards[row["ward_code"]]
        lat, lon = float(ward["geo"]["lat"]), float(ward["geo"]["lon"])
        require((row["latitude"], row["longitude"], row["province_code"], row["ward_name"], row["province_name"])
                == (lat, lon, ward["parent"]["id"], ward["name"]["local"], ward["parent"]["name"]["local"])
                and -90 <= lat <= 90 and -180 <= lon <= 180
                and row["source_url"] == monthly.request_url(lat, lon, 1981, 2026),
                f"Location or request mismatch for {row['ward_code']}")
    cutoff = data["metadata"]["as_of"][:7]
    for series_id, rows in data["series"].items():
        require(checksum(monthly.compact(rows)) == series_id, f"Series checksum mismatch: {series_id}")
        require([row[0] for row in rows] == MONTHS, f"Expected 600 months: {series_id}")
        for month, temp, rain, wind, _, total in rows:
            values = (temp, rain, wind, total)
            require(all(v is None or type(v) in (int, float) and math.isfinite(v) and v != -999
                        for v in values), f"Invalid value for {series_id} at {month}")
            require(not (month < "1981-01" or month >= cutoff) or all(v is None for v in values),
                    f"Non-null data in unavailable month {month}")
            require(rain is None or rain >= 0, f"Negative rain at {month}")
            require(wind is None or wind >= 0, f"Negative wind at {month}")
            days = calendar.monthrange(int(month[:4]), int(month[-2:]))[1]
            require(total == (None if rain is None else round(rain * days, 4)), f"Rain total mismatch at {month}")
    return data, checksum(raw)


def load_power(label, lat, lon, end, as_of, fetch_missing):
    url = monthly.request_url(lat, lon, 1981, end)
    path = ROOT / "raw" / f"{label}-{end}.json"
    missing = not path.exists() and fetch_missing
    content = download(url) if missing else path.read_bytes()
    data = json.loads(content)
    actual_lon, actual_lat, *_ = data["geometry"]["coordinates"]
    header = data["header"]
    require(math.isclose(actual_lat, lat, abs_tol=1e-6) and math.isclose(actual_lon, lon, abs_tol=1e-6),
            f"POWER coordinates mismatch for {label}: requested {(lat, lon)}, received {(actual_lat, actual_lon)}")
    require(header["start"].startswith("1981") and header["end"].startswith(str(end))
            and header["time_standard"] == "LST", f"POWER date/time standard mismatch for {label}")
    require(all(data["parameters"][key]["units"] == unit for key, unit in monthly.UNITS.items()),
            f"POWER units mismatch for {label}")
    rows = monthly.normalize(data, 1977, end, as_of)
    if missing:
        save_raw(path, content)
    return rows, {"raw_file": path.name, "raw_bytes": len(content), "sha256": checksum(content),
                  "url": url, "fetched_at": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
                  "time_standard": header["time_standard"]}


def check_pilot(data, fetch_missing):
    verified = {}
    as_of = date.fromisoformat(data["metadata"]["as_of"])
    by_code = {row["ward_code"]: row for row in data["locations"]}
    for code, (_, ward) in PILOT.items():
        location = by_code[ward]
        coord = (location["latitude"], location["longitude"])
        base, base_source = load_power(ward, *coord, 2025, as_of, fetch_missing)
        current, current_source = load_power(ward, *coord, 2026, as_of, fetch_missing)
        stored = data["series"][location["series_id"]]
        require([r[:4] for r in base] == [r[:4] for r in current[:len(base)]],
                f"{ward}: overlapping POWER values changed when end=2026")
        require([r[:4] for r in stored] == [r[:4] for r in current],
                f"{ward}: retained values differ from the fresh POWER request")
        verified[code] = {"ward_code": ward, "ward_name": location["ward_name"],
                          "historical_months_checked_per_metric": 540, "snapshot_months_checked_per_metric": 600,
                          "sources": [base_source, current_source],
                          "qa_raw_bytes": base_source["raw_bytes"] + current_source["raw_bytes"]}
    return verified


def export_package(directory, locations, series, card):
    directory.mkdir(parents=True, exist_ok=True)
    json_path = directory / "vn_monthly.json"
    locations_path = directory / "locations.csv"
    series_path = directory / "series.csv"
    json_path.write_bytes(monthly.compact({"schema_version": 1, "data_card": card, "columns": COLUMNS,
                                          "locations": locations, "series": series}) + b"\n")
    with locations_path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=LOCATION_FIELDS)
        writer.writeheader()
        writer.writerows(locations)
    with series_path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(("series_id", *COLUMNS))
        for key, rows in series.items():
            writer.writerows((key, *row) for row in rows)

    decoded = json.loads(json_path.read_bytes())
    with locations_path.open(encoding="utf-8", newline="") as stream:
        require(list(csv.DictReader(stream)) == [
            {key: str(value) for key, value in row.items()} for row in decoded["locations"]
        ], "JSON and locations.csv differ")
    count = 0
    with series_path.open(encoding="utf-8", newline="") as stream:
        reader = csv.reader(stream)
        require(next(reader) == ["series_id", *COLUMNS], "Unexpected series.csv header")
        for key, rows in decoded["series"].items():
            for row in rows:
                require(next(reader, None) == [key, *["" if value is None else str(value) for value in row]],
                        f"JSON and series.csv differ: {key}/{row[0]}")
                count += 1
        require(next(reader, None) is None, "Extra CSV series rows")
    usage = Counter(row["series_id"] for row in locations)
    require(set(usage) == set(series), "CSV join is missing a series")
    coverage = {}
    for i, column in enumerate(COLUMNS[1:], 1):
        months = Counter()
        for key, rows in series.items():
            for row in rows:
                if row[i] is not None:
                    months[row[0]] += usage[key]
        coverage[column] = {
            "first_month": min(months) if months else None, "last_month": max(months) if months else None,
            "valid_location_months": sum(months.values()),
            "missing_location_months": len(locations) * len(MONTHS) - sum(months.values()),
            "valid_locations_2026": {m: months[m] for m in MONTHS[-12:]},
        }
    return {
        "locations": len(locations), "series": len(series), "stored_series_rows": count,
        "logical_location_months": len(locations) * len(MONTHS), "coverage": coverage,
        "json_bytes": json_path.stat().st_size,
        "csv_bytes": locations_path.stat().st_size + series_path.stat().st_size,
        "sha256": {p.name: checksum(p.read_bytes()) for p in (json_path, locations_path, series_path)},
    }


def project_rows(rows):
    return [[*row[:4], row[5]] for row in rows]


def in_ring(ring, lon, lat):
    inside = False
    for (ax, ay), (bx, by) in zip(ring, ring[1:]):
        if (ay > lat) != (by > lat) and lon < ax + (bx - ax) * (lat - ay) / (by - ay):
            inside = not inside
    return inside


def in_polygon(polygon, lon, lat):
    return in_ring(polygon[0], lon, lat) and not any(in_ring(ring, lon, lat) for ring in polygon[1:])


def representative_point(polygons):
    bounds = []
    for polygon in polygons:
        lon, lat = zip(*polygon[0])
        bounds.append((min(lon), min(lat), max(lon), max(lat), polygon))
    for west, south, east, north, polygon in sorted(
        bounds, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]), reverse=True
    ):
        # Prefer the bounding-box center, then look for an interior point on a regular grid.
        fractions = [0.5, *(i / 20 for i in range(1, 20) if i != 10)]
        for fx in fractions:
            for fy in fractions:
                lon, lat = round(west + fx * (east - west), 3), round(south + fy * (north - south), 3)
                if in_polygon(polygon, lon, lat):
                    return lat, lon
    raise ValueError("Cannot choose an interior representative point")


def fix_khanh_hoa(locations, series, as_of, fetch_missing):
    path = ROOT / "raw" / "wards-56.geojson"
    missing = fetch_missing and not path.exists()
    content = download(KHANH_HOA_BOUNDARIES) if missing else path.read_bytes()
    features = json.loads(content)["features"]
    boundaries = {}
    for feature in features:
        geometry = feature["geometry"]
        require(geometry["type"] in ("Polygon", "MultiPolygon"), "Unexpected ward geometry type")
        boundaries[feature["properties"]["code"]] = (
            geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
        )
    wards = [row for row in locations if row["province_code"] == "56"]
    require(len(boundaries) == len(features) == len(wards)
            and set(boundaries) == {row["ward_code"] for row in wards}, "Khánh Hòa boundary codes differ")
    if missing:
        save_raw(path, content)
    corrections = []
    for row in wards:
        code = row["ward_code"]
        polygons = boundaries[code]
        old = (row["latitude"], row["longitude"])
        if any(in_polygon(polygon, old[1], old[0]) for polygon in polygons):
            continue
        lat, lon = representative_point(polygons)
        raw_rows, source = load_power(f"ward-{code}", lat, lon, 2026, as_of, fetch_missing)
        projected = project_rows(raw_rows)
        key = checksum(monthly.compact(projected))
        series[key] = projected
        row.update(latitude=lat, longitude=lon, series_id=key, source_url=source["url"],
                   fetched_at=source["fetched_at"], time_standard=source["time_standard"])
        corrections.append({"ward_code": code, "ward_name": row["ward_name"],
                            "original_lat_lon": old, "revised_lat_lon": [lat, lon], "power": source})
    return {"province_code": "56", "wards_checked": len(wards), "boundary_url": KHANH_HOA_BOUNDARIES,
            "boundary_sha256": checksum(content), "boundary_license": "CC BY 4.0", "corrections": corrections}


def package_snapshot(data, digest, pilot_checks, fetch_missing, output):
    # Re-key after dropping auxiliary solar radiation so identical delivered series are shared.
    series, ids = {}, {}
    for old_id, rows in data["series"].items():
        projected = project_rows(rows)
        new_id = checksum(monthly.compact(projected))
        ids[old_id] = new_id
        series[new_id] = projected
    locations = [{**row, "series_id": ids[row["series_id"]]} for row in data["locations"]]
    geometry = fix_khanh_hoa(locations, series, date.fromisoformat(data["metadata"]["as_of"]), fetch_missing)
    card = {
        "dataset": "NASA POWER Monthly T2M, PRECTOTCORR and WS10M",
        "provider": "NASA POWER", "url": monthly.ENDPOINT, "accessed": data["metadata"]["as_of"],
        "spatial": "Ô lưới POWER tại tọa độ đại diện của từng đơn vị.",
        "temporal": "1977-01 to 2026-12", "processing": "Đóng gói lại snapshot, chia sẻ chuỗi trùng, giữ null.",
        "limitation_vi": "Danh mục cộng đồng sau 2025. Dữ liệu theo điểm, không phải trung bình ranh giới. "
                         "Đối chiếu API trên mẫu hai tỉnh và kiểm ranh giới bổ sung ở Khánh Hòa.",
        "citation": "NASA Langley Research Center POWER Project; Open Admin Data, CC BY 4.0",
        "snapshot": "f1/data/monthly/vietnam/climate.json", "snapshot_checkout_sha256": digest,
        "admin_source": data["metadata"]["admin_source"], "admin_sha256_lf": data["metadata"]["admin_sha256"],
        "units": {column: monthly.UNITS[column] for column in monthly.PARAMETERS[:3]},
    }
    pilot = {}
    for code, label in PROVINCE_PACKAGES.items():
        subset = [row for row in locations if row["province_code"] == code]
        used = {row["series_id"] for row in subset}
        pilot[code] = {
            **export_package(output / "pilot" / label, subset, {k: series[k] for k in sorted(used)},
                             {**card, "scope": label}),
            **pilot_checks.get(code, {}),
        }
    used = {row["series_id"] for row in locations}
    national = export_package(output / "vietnam", locations, {k: series[k] for k in sorted(used)},
                              {**card, "scope": "Vietnam", "coordinate_check": geometry})
    samples = [pilot[code] for code in PILOT]
    sample_count = sum(row["locations"] for row in samples)
    estimates = {kind: round(sum(row[kind] for row in samples) * len(locations) / sample_count)
                 for kind in ("json_bytes", "csv_bytes")}
    require(national["json_bytes"] + national["csv_bytes"] <= BUDGET, "Offline package exceeds 250 MiB")
    return {"pilot": pilot, "national": national, "estimated_national": estimates,
            "budget_bytes": BUDGET, "coordinate_check": geometry}


def online_point(label, lat, lon, fetch_missing, output=OUTPUT):
    require(re.fullmatch(r"[a-z][a-z0-9_-]*", label) is not None and label not in {v[0] for v in PILOT.values()},
            "Use a lowercase point ID beginning with a letter")
    require(-90 <= lat <= 90 and -180 <= lon <= 180, "Coordinates out of range")
    rows, source = load_power(label, lat, lon, 2026, date.today(), fetch_missing=fetch_missing)
    series = project_rows(rows)
    key = checksum(monthly.compact(series))
    location = dict(ward_code=label, ward_name=label, province_code="", province_name="",
                    latitude=lat, longitude=lon, series_id=key, source_url=source["url"],
                    fetched_at=source["fetched_at"], time_standard=source["time_standard"])
    card = {"dataset": "NASA POWER Monthly", "provider": "NASA POWER", "url": source["url"],
            "accessed": source["fetched_at"], "spatial": "Ô lưới tại tọa độ yêu cầu.", "temporal": "1977–2026",
            "processing": "Chọn nhiệt, mưa, gió và quy đổi tổng mưa tháng. Giữ null.",
            "limitation_vi": "Điểm mô hình. Trước 1981 và tháng chưa có số liệu để null.",
            "citation": "NASA Langley Research Center POWER Project", "sources": [source]}
    result = export_package(output / "online" / label, [location], {key: series}, card)
    report = ROOT / "online" / label / "report.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_bytes(monthly.compact({**result, "source": source}) + b"\n")
    print(f"{label}: {result['logical_location_months']} months, {result['json_bytes']} JSON bytes")


def build_packages(fetch_missing, output=OUTPUT):
    data, digest = read_snapshot()
    report = package_snapshot(data, digest, check_pilot(data, fetch_missing), fetch_missing, output)
    (ROOT / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Vietnam: {report['national']['locations']} locations, {report['national']['json_bytes']} JSON bytes")
