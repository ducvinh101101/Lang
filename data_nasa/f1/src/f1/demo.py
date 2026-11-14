"""NASA source adapters and transformations for the four F1 demo datasets."""

import base64
import calendar
import csv
from datetime import date, datetime, timedelta, timezone
import gzip
from hashlib import sha256
import io
from itertools import product
import json
import math
from pathlib import Path
import re
from statistics import median
import unicodedata
from dataclasses import dataclass

from .io import download, require, save_raw
from .clean import monthly_rain, observation
from .fetch import unique_keys

ROOT = Path(__file__).resolve().parents[3] / "local-private" / "f1-data"
OUTPUT = Path(__file__).resolve().parents[2] / "data" / "deliverables" / "demo"
EXPANDED_A_OUTPUT = OUTPUT.parent / "a_34"
A_PROVINCES = "a_climate/provinces"
B_HEAT_DAYS = "b_heat_days/heat_days"
C_YAGI = "c_disasters/yagi/weather_daily"
C_YAGI_GRID = "c_disasters/yagi/rain_grid"
D_GLOBAL_TEMP = "d_global_temp/global_temp"
POINTS = {
    "ha_noi": (21.03, 105.85), "lao_cai": (22.48, 103.97),
    "hue": (16.46, 107.59), "da_nang": (16.05, 108.20),
    "tp_hcm": (10.78, 106.70), "can_tho": (10.03, 105.78),
}
DEMO_PROVINCES = {"01": "ha_noi", "15": "lao_cai", "46": "hue", "48": "da_nang", "79": "tp_hcm", "92": "can_tho"}
YEARS = range(1981, 2026)
MONTHS = [f"{year}{month:02d}" for year in YEARS for month in range(1, 13)]
ANNUAL = [f"{year}13" for year in YEARS]
UNITS = {"T2M": "C", "T2M_MAX": "C", "PRECTOTCORR": "mm/day", "WS10M": "m/s"}
GISTEMP_URL = "https://data.giss.nasa.gov/gistemp/tabledata_v4/GLB.Ts+dSST.csv"
IMERG_CATALOG = "https://gdex.ucar.edu/datasets/d734000/"
IMERG_BASE = ("https://tds.gdex.ucar.edu/thredds/dodsC/files/d734000/"
              "gpm_3imergdf_v07/2024/09/3B-DAY.MS.MRG.3IMERG.")
IMERG_SUBSET = "precipitation%5B0:1:0%5D%5B2825:1:2879%5D%5B1100:1:1134%5D"
YAGI_DATES = ("20240901", "20240915")
B_DATES = ("19810101", "20251231")
A_METRICS = ("T2M", "PRECTOTCORR")
C_METRICS = ("PRECTOTCORR", "WS10M")
C_POWER_LST_RAW = "C-ha_noi-20240901-20240915.json"
C_POWER_UTC_RAW = "C-ha_noi-20240901-20240915-utc.json"
C_IMERG_METADATA = "C-IMERG-metadata.das"
D_RAW = "D-GLB.Ts+dSST.csv"


@dataclass
class Product:
    records: list
    keys: tuple
    card: dict
    extra: dict
    quality: dict


def dates(first, last):
    return [(first + timedelta(days=i)).strftime("%Y%m%d") for i in range((last - first).days + 1)]


YAGI_DAYS = dates(date(2024, 9, 1), date(2024, 9, 15))


def imerg_url(day):
    return IMERG_BASE + day + "-S000000-E235959.V07B.nc4"


def imerg_raw(day):
    return f"C-IMERG-{day}.ascii"


def imerg_metadata_url():
    return imerg_url(YAGI_DATES[0]) + ".das?precipitation"


def power_url(place, kind, variables, start, end, time_standard=None, point=None):
    lat, lon = POINTS[place] if point is None else point
    latitude, longitude = (f"{lat:.2f}", f"{lon:.2f}") if point is None else (str(lat), str(lon))
    url = (f"https://power.larc.nasa.gov/api/temporal/{kind}/point?parameters={','.join(variables)}"
           f"&community=AG&latitude={latitude}&longitude={longitude}&start={start}&end={end}&format=JSON")
    return url + f"&time-standard={time_standard}" if time_standard else url


def source_files():
    for place in POINTS:
        yield f"A-{place}-1981-2025.json", power_url(place, "monthly", A_METRICS, "1981", "2025")
        yield f"B-{place}-1981-2025.json", power_url(place, "daily", ("T2M_MAX",), *B_DATES)
    yield C_POWER_UTC_RAW, power_url("ha_noi", "daily", C_METRICS, *YAGI_DATES, time_standard="UTC")
    yield C_IMERG_METADATA, imerg_metadata_url()
    for day in YAGI_DAYS:
        yield imerg_raw(day), imerg_url(day) + ".ascii?" + IMERG_SUBSET
    yield D_RAW, GISTEMP_URL


def load(filename, place, kind, variables, start, end, keys, optional=(), *,
         fetch_missing=False, time_standard=None, point=None):
    path = ROOT / "raw" / filename
    lat, lon = POINTS[place] if point is None else point
    url = power_url(place, kind, variables, start, end, time_standard, point)
    needs_download = fetch_missing and not path.exists()
    content = download(url) if needs_download else path.read_bytes()
    raw = json.loads(content, object_pairs_hook=unique_keys)
    xy = raw["geometry"]["coordinates"]
    require(all(math.isclose(a, b, abs_tol=1e-5) for a, b in zip(xy[:2], (lon, lat), strict=True)),
            f"{filename}: unexpected coordinates {xy}")
    header = raw["header"]
    if time_standard:
        require(header["time_standard"] == time_standard, f"{filename}: unexpected time standard")
    require(header["start"] == (start + "0101" if kind == "monthly" else start)
            and header["end"] == (end + "1231" if kind == "monthly" else end), f"{filename}: unexpected date range")
    fields = raw["properties"]["parameter"]
    require(set(fields) == set(variables), f"{filename}: unexpected parameters")
    fill = header["fill_value"]
    for name, values in fields.items():
        require(raw["parameters"][name]["units"] == UNITS[name], f"{filename}: incorrect units for {name}")
        require(values.keys() <= set(keys) | set(optional), f"{filename}: extra dates for {name}")
    if needs_download:
        save_raw(path, content)
    metadata = {
        "location_id": place, "latitude": lat, "longitude": lon, "url": url,
        "accessed": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
        "time_standard": header["time_standard"], "api": header["api"],
        "raw_file": filename, "raw_sha256": sha256(content).hexdigest(),
    }
    return fields, fill, metadata


def data_card(dataset, sources, period, processing, limitation):
    return {
        "dataset": dataset, "provider": "NASA POWER", "url": "https://power.larc.nasa.gov/",
        "accessed": max(s["accessed"] for s in sources),
        "spatial": "Ô lưới chứa tọa độ yêu cầu của từng điểm.",
        "temporal": period, "processing": processing, "limitation_vi": limitation,
        "citation": "NASA Langley Research Center (LaRC) POWER Project",
        "sources": sources,
    }


def render_pair(rows, keys, card, extra):
    require(len({tuple(row[k] for k in keys) for row in rows}) == len(rows), "Duplicate keys")
    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)
    csv_text = buffer.getvalue()
    document = json.dumps({"data_card": card, "records": rows, **extra}, ensure_ascii=False,
                          allow_nan=False, separators=(",", ":")) + "\n"
    csv_rows = list(csv.DictReader(io.StringIO(csv_text)))
    json_rows = json.loads(document)["records"]
    require(csv_rows == [{k: "" if v is None else str(v) for k, v in row.items()} for row in json_rows],
            "CSV and JSON do not match")
    return document.encode(), csv_text.encode()


def export(stem, rows, keys, card, *, output, **extra):
    document, csv_data = render_pair(rows, keys, card, extra)
    out = output / stem
    save_raw(out.with_suffix(".json"), document)
    save_raw(out.with_suffix(".csv"), csv_data)
    return {"rows": len(rows), "json_bytes": len(document), "csv_bytes": len(csv_data)}


def global_temperature():
    raw_path = ROOT / "raw" / D_RAW
    content = raw_path.read_bytes()
    lines = content.decode("utf-8-sig").splitlines()
    reader = csv.DictReader(lines[1:])
    require(reader.fieldnames is not None and {"Year", "J-D"} <= set(reader.fieldnames), "Invalid GISTEMP CSV")
    anomalies = {}
    for record in reader:
        year = int(record["Year"])
        if 1880 <= year <= 2025:
            require(year not in anomalies, f"Duplicate GISTEMP year {year}")
            try:
                value = float(record["J-D"])
            except (ValueError, TypeError):
                value = None
            anomalies[year], _ = observation(value, -999, "T2M")
    rows = [{"year": year, "temperature_anomaly_c": anomalies.get(year)} for year in range(1880, 2026)]
    source = {"url": GISTEMP_URL, "raw_file": raw_path.name, "raw_sha256": sha256(content).hexdigest(),
              "accessed": datetime.fromtimestamp(raw_path.stat().st_mtime, timezone.utc).isoformat()}
    card = data_card("GISTEMP v4 Global Land-Ocean Temperature Index", [source], "1880 to 2025",
                     "Lấy cột J-D của bảng toàn cầu. Đơn vị °C so với trung bình 1951–1980.",
                     "Chênh lệch nhiệt độ toàn cầu so với mốc chuẩn, không phải nhiệt độ tuyệt đối.")
    card.update(provider="NASA GISS", url=GISTEMP_URL,
                spatial="Toàn cầu, nhiệt độ bề mặt đất và đại dương.",
                citation="NASA Goddard Institute for Space Studies, GISTEMP v4")
    extra = dict(baseline_years=[1951, 1980], years=[row["year"] for row in rows],
                 anomaly_c=[row["temperature_anomaly_c"] for row in rows])
    return Product(rows, ("year",), card, extra, {"sample": [rows[0], rows[-1]]})

def climate_records(place, fetch_missing, point=None):
    fields, fill, source = load(f"A-{place}-1981-2025.json", place, "monthly", A_METRICS,
                                "1981", "2025", MONTHS, ANNUAL, fetch_missing=fetch_missing, point=point)
    require(source["time_standard"] == "LST", f"{place}: expected LST for POWER Monthly")
    rows = []
    flags = []
    annual_rows = []
    for year in YEARS:
        monthly = []
        for month in range(1, 13):
            key = f"{year}{month:02d}"
            temp, _ = observation(fields["T2M"].get(key), fill, "T2M")
            rain_rate, _ = observation(fields["PRECTOTCORR"].get(key), fill, "PRECTOTCORR")
            period = f"{year}-{month:02d}"
            monthly.append({"location_id": place, "period_type": "month", "period": period,
                            "temperature_c": temp, "precipitation_mm_day": rain_rate,
                            "precipitation_total_mm": monthly_rain(rain_rate, period)})
        rows.extend(monthly)
        annual_key = f"{year}13"
        t_avg, _ = observation(fields["T2M"].get(annual_key), fill, "T2M")
        p_avg, _ = observation(fields["PRECTOTCORR"].get(annual_key), fill, "PRECTOTCORR")
        days = 365 + calendar.isleap(year)
        totals = [row["precipitation_total_mm"] for row in monthly]
        temperatures = [row["temperature_c"] for row in monthly]
        month_sum = round(sum(totals), 4) if None not in totals else None
        if t_avg is None and None not in temperatures:
            t_avg = round(sum(temperatures) / 12, 4)
        if p_avg is None:
            total = month_sum
            p_avg = round(total / days, 6) if total is not None else None
        else:
            total = round(p_avg * days, 4)
            if month_sum is not None and abs(total - month_sum) > 4:
                flags.append({"year": year, "ann_total_mm": total, "monthly_sum_mm": month_sum})
        if total is not None and not 800 < total < 4000:
            flags.append({"year": year, "annual_rain_mm": total, "check": "outside_800_4000"})
        annual_rows.append({"location_id": place, "period_type": "year", "period": str(year),
                            "temperature_c": t_avg, "precipitation_mm_day": p_avg,
                            "precipitation_total_mm": total})
    return rows, annual_rows, flags, source


def climate_card(sources):
    return data_card("POWER Monthly T2M and PRECTOTCORR", sources, "1981-01 to 2025-12",
                     "Mưa mm/ngày nhân số ngày của kỳ. Dùng YYYY13 cho năm nếu có. Dự phòng bằng trung bình "
                     "12 nhiệt độ tháng và tổng 12 lượng mưa tháng.", "Dữ liệu mô hình theo ô lưới.")


def climate(place):
    rows, annual_rows, flags, source = climate_records(place, False)
    card = climate_card([source])
    extra = dict(years=list(YEARS), t2m_annual=[row["temperature_c"] for row in annual_rows],
                 rain_annual_mm=[row["precipitation_total_mm"] for row in annual_rows])
    return Product(rows + annual_rows, ("location_id", "period_type", "period"), card, extra,
                   {"rain_flags": flags, "sample_2025": annual_rows[-1]})


def expanded_climate(fetch_missing, output=EXPANDED_A_OUTPUT):
    archive = OUTPUT.parent / "vn" / "vietnam" / "vn_monthly.json"
    locations = json.loads(archive.read_bytes())["locations"]
    provinces = {}
    for location in locations:
        provinces.setdefault(location["province_code"], []).append(location)
    require(len(provinces) == 34 and set(DEMO_PROVINCES) <= provinces.keys(), "Expected all 34 provinces")
    exports, flags = {}, {}
    for code, wards in sorted(provinces.items()):
        if code in DEMO_PROVINCES:
            place = DEMO_PROVINCES[code]
            point = None
            ward = None
        else:
            lat = median(ward["latitude"] for ward in wards)
            lon = median(ward["longitude"] for ward in wards)
            ward = min(wards, key=lambda w: (
                (w["latitude"] - lat)**2 + ((w["longitude"] - lon) * math.cos(math.radians(lat)))**2,
                w["ward_code"],
            ))
            place = f"province_{code}"
            point = (ward["latitude"], ward["longitude"])
        months, years, rain_flags, source = climate_records(place, fetch_missing, point)
        province = {"province_code": code, "province_name": wards[0]["province_name"]}
        if ward is None:
            name = place
        else:
            ascii_name = unicodedata.normalize("NFD", province["province_name"].lower().replace("đ", "d"))
            name = re.sub(r"[^a-z0-9]+", "_", ascii_name.encode("ascii", "ignore").decode("ascii")).strip("_")
        require(bool(name) and name not in exports, f"{code}: duplicate or invalid province filename")
        location = {**province, "location_id": place, "latitude": source["latitude"],
                    "longitude": source["longitude"], "ward_code": ward["ward_code"] if ward else None}
        rows = [{**province, **row} for row in months + years]
        exports[name] = (location, rows, years, source)
        if rain_flags:
            flags[code] = rain_flags
        print(f"{code} {province['province_name']}: {len(months)} months, {len(years)} years", flush=True)
    totals = {"rows": 0, "json_bytes": 0, "csv_bytes": 0}
    files = {}
    for name, (location, rows, annual, source) in exports.items():
        card = climate_card([source])
        result = export(name, rows, ("province_code", "period_type", "period"), card,
                        output=output / "provinces", location=location, years=list(YEARS),
                        t2m_annual=[row["temperature_c"] for row in annual],
                        rain_annual_mm=[row["precipitation_total_mm"] for row in annual])
        for key, value in result.items():
            totals[key] += value
        files[location["province_code"]] = name
    summary = {**totals, "provinces": len(files), "monthly_rows": len(files) * len(MONTHS),
               "annual_rows": len(files) * len(YEARS)}
    report = {**summary, "file_stems": files, "rain_flags": flags}
    (ROOT / "a-34-checks.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))


def yagi():
    fields, fill, source = load(C_POWER_LST_RAW, "ha_noi", "daily", C_METRICS, *YAGI_DATES, YAGI_DAYS)
    rows = [{"date": f"{k[:4]}-{k[4:6]}-{k[6:]}", "ha_noi_rain_mm": observation(fields["PRECTOTCORR"].get(k), fill, "PRECTOTCORR")[0],
             "ha_noi_wind_ms": observation(fields["WS10M"].get(k), fill, "WS10M")[0]} for k in YAGI_DAYS]
    card = data_card("POWER Daily PRECTOTCORR and WS10M", [source], "2024-09-01 to 2024-09-15",
                     "Lượng mưa trung bình ngày tính trên một ngày. Gió trung bình ngày tại 10 m.",
                     "Chỉ có điểm Hà Nội. Chưa gồm IMERG Bắc Bộ.")
    extra = dict(coverage="hanoi_only", days=[row["date"] for row in rows],
                 ha_noi_rain_mm=[row["ha_noi_rain_mm"] for row in rows],
                 ha_noi_wind_ms=[row["ha_noi_wind_ms"] for row in rows])
    valid = [row for row in rows if row["ha_noi_rain_mm"] is not None]
    return Product(rows, ("date",), card, extra,
                   {"rain_peak": max(valid, key=lambda row: row["ha_noi_rain_mm"], default=None)})


def imerg_day(day):
    url = imerg_url(day) + ".ascii?" + IMERG_SUBSET
    path = ROOT / "raw" / imerg_raw(day)
    content = path.read_bytes()
    header, marker, body = content.decode("ascii").partition("---------------------------------------------")
    require(bool(marker) and f"{day}-S000000-E235959.V07B.nc4" in header, f"{day}: wrong IMERG granule")
    blocks = {}
    for block in re.split(r"\n\s*\n", body.strip()):
        title, *values = block.splitlines()
        require(title not in blocks, f"{day}: duplicate IMERG array {title}")
        blocks[title] = values
    lon = [float(x) for x in blocks["precipitation.lon[55]"][0].split(",")]
    lat = [float(x) for x in blocks["precipitation.lat[35]"][0].split(",")]
    actual_day = date(1980, 1, 6) + timedelta(days=float(blocks["precipitation.time[1]"][0]))
    require(actual_day.strftime("%Y%m%d") == day, f"{day}: mismatched IMERG time coordinate")
    require([round(x * 100) for x in lon] == list(range(10255, 10796, 10)) and
            [round(x * 100) for x in lat] == list(range(2005, 2346, 10)), f"{day}: wrong IMERG bounds")
    grid = []
    for idx, line in enumerate(blocks["precipitation.precipitation[1][55][35]"]):
        index, *values = line.split(",")
        require(index == f"[0][{idx}]" and len(values) == len(lat), f"{day}: wrong IMERG grid row")
        grid.append([observation(float(x), -9999.9, "PRECTOTCORR")[0] for x in values])
    require(len(grid) == len(lon), f"{day}: incomplete IMERG grid")
    hanoi_lat, hanoi_lon = POINTS["ha_noi"]
    x = min(range(len(lon)), key=lambda i: abs(lon[i] - hanoi_lon))
    y = min(range(len(lat)), key=lambda i: abs(lat[i] - hanoi_lat))
    weights = [math.cos(math.radians(v)) for v in lat]
    complete_grid = all(None not in column for column in grid)
    region = (None if not complete_grid else
              sum(value * weight for column in grid for value, weight in zip(column, weights)) / (sum(weights) * len(lon)))
    peak = max(max(column) for column in grid) if complete_grid else None
    source = {"url": url, "raw_file": path.name, "raw_sha256": sha256(content).hexdigest(),
              "accessed": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
              "time_standard": "UTC", "date": actual_day.isoformat(), "unit": "mm/day"}
    summary = {
        "date": actual_day.isoformat(), "ha_noi_imerg_mm": round(grid[x][y], 4) if grid[x][y] is not None else None,
        "bac_bo_mean_rain_mm": round(region, 4) if region is not None else None,
        "bac_bo_max_rain_mm": round(peak, 4) if peak is not None else None,
    }
    cells = [
        {"date": summary["date"], "longitude": round(longitude, 2), "latitude": round(latitude, 2),
         "precipitation_mm": None if value is None else round(value, 4)}
        for longitude, column in zip(lon, grid, strict=True)
        for latitude, value in zip(lat, column, strict=True)
    ]
    return summary, cells, source


def yagi_products():
    fields, fill, power_source = load(C_POWER_UTC_RAW, "ha_noi", "daily", C_METRICS,
                                     *YAGI_DATES, YAGI_DAYS, time_standard="UTC")
    metadata_path = ROOT / "raw" / C_IMERG_METADATA
    metadata_url = imerg_metadata_url()
    content = metadata_path.read_bytes()
    metadata = content.decode("ascii")
    require(re.search(r'precipitation\s*\{\s*String units "mm/day"', metadata) is not None
            and 'days since 1980-01-06 00:00:00Z' in metadata, "Unexpected IMERG units or time encoding")
    metadata_source = {"url": metadata_url, "raw_file": metadata_path.name,
                       "raw_sha256": sha256(content).hexdigest(),
                       "accessed": datetime.fromtimestamp(metadata_path.stat().st_mtime, timezone.utc).isoformat()}
    rows, grid_rows, imerg_sources = [], [], [metadata_source]
    for day in YAGI_DAYS:
        imerg, cells, source = imerg_day(day)
        rain, _ = observation(fields["PRECTOTCORR"].get(day), fill, "PRECTOTCORR")
        wind, _ = observation(fields["WS10M"].get(day), fill, "WS10M")
        rows.append({"date": imerg["date"], "ha_noi_rain_mm": rain, "ha_noi_wind_ms": wind,
                     "ha_noi_imerg_mm": imerg["ha_noi_imerg_mm"],
                     "bac_bo_mean_rain_mm": imerg["bac_bo_mean_rain_mm"],
                     "bac_bo_max_rain_mm": imerg["bac_bo_max_rain_mm"]})
        grid_rows.extend(cells)
        imerg_sources.append(source)
    sources = [power_source, *imerg_sources]
    card = data_card("POWER Daily + GPM IMERG Final Daily V07B", sources, "2024-09-01 to 2024-09-15 UTC",
                     "Ghép ngày UTC. Tính trung bình mưa theo diện tích ô và lấy giá trị ô lớn nhất.",
                     "Mưa lưới và mưa POWER có độ phân giải khác nhau. Vùng là hộp tọa độ.")
    card.update(provider="NASA POWER; NASA GES DISC via NCAR GDEX", url=IMERG_CATALOG,
                spatial="20–23.5°N, 102.5–108°E; 1.925 ô IMERG, ô gần Hà Nội tại 21.05°N, 105.85°E.",
                citation="NASA GPM_3IMERGDF V07, doi:10.5067/GPM/IMERGDF/DAY/07; NASA LaRC POWER")
    extra = dict(id="yagi_2024", title_vi="Bão Yagi", coverage="power_hanoi_and_imerg_north_vietnam",
                 sources=["NASA POWER Daily PRECTOTCORR, WS10M", "NASA GPM IMERG Final Daily V07B"],
                 days=[row["date"] for row in rows],
                 **{k: [row[k] for row in rows] for k in rows[0] if k != "date"})
    weather = Product(rows, ("date",), card, extra, {"imerg_days": len(rows), "imerg_cells_per_day": 1925,
                      "extreme_rain": [r["date"] for r in rows if r["ha_noi_rain_mm"] is not None and r["ha_noi_rain_mm"] >= 500]})
    grid_card = {
        **card,
        "dataset": "NASA GPM IMERG Final Daily V07B",
        "provider": "NASA GES DISC via NCAR GDEX",
        "spatial": "20–23.5°N, 102.5–108°E, 55 × 35 ô, mỗi ô 0,1° × 0,1°.",
        "processing": "Tọa độ là tâm ô. Giá trị mm/ngày giữ nguyên cho kỳ một ngày UTC và làm tròn 4 chữ số thập phân.",
        "limitation_vi": "Vùng là hộp tọa độ. Giá trị thiếu hoặc không hợp lệ để trống.",
        "accessed": max(source["accessed"] for source in imerg_sources),
        "citation": "NASA GPM_3IMERGDF V07, doi:10.5067/GPM/IMERGDF/DAY/07",
        "sources": imerg_sources,
    }
    grid = Product(grid_rows, ("date", "longitude", "latitude"), grid_card,
                   {"id": "yagi_2024", "time_standard": "UTC", "bbox": [102.5, 20, 108, 23.5],
                    "cell_size_degrees": 0.1, "width": 55, "height": 35}, {})
    return {C_YAGI: weather, C_YAGI_GRID: grid}


def pack_rain_grid(grid):
    dates = list(dict.fromkeys(row["date"] for row in grid.records))
    longitudes = list(dict.fromkeys(row["longitude"] for row in grid.records))
    latitudes = list(dict.fromkeys(row["latitude"] for row in grid.records))
    require(all((row["date"], row["longitude"], row["latitude"]) == coordinates
                for row, coordinates in zip(grid.records, product(dates, longitudes, latitudes), strict=True)),
            "IMERG records do not match grid order")
    values = json.dumps([row["precipitation_mm"] for row in grid.records],
                        allow_nan=False, separators=(",", ":")).encode()
    buffer = io.BytesIO()
    with gzip.GzipFile(fileobj=buffer, mode="wb", mtime=0) as stream:
        stream.write(values)
    document = {
        "data_card": grid.card, **grid.extra,
        "dates": dates, "longitudes": longitudes, "latitudes": latitudes,
        "precipitation_mm": {
            "encoding": "base64+gzip+json",
            "axis_order": ["date", "longitude", "latitude"],
            "values": base64.b64encode(buffer.getvalue()).decode("ascii"),
        },
    }
    return (json.dumps(document, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def heat():
    keys = dates(date(1981, 1, 1), date(2025, 12, 31))
    year_keys = {year: [] for year in YEARS}
    for key in keys:
        year = int(key[:4])
        year_keys[year].append(key)
    sources, rows = [], []
    levels = (35, 37, 39)
    for place in POINTS:
        fields, fill, source = load(f"B-{place}-1981-2025.json", place, "daily", ("T2M_MAX",), *B_DATES, keys)
        sources.append(source)
        values = fields["T2M_MAX"]
        for year, day_keys in year_keys.items():
            year_values = [observation(values.get(k), fill, "T2M_MAX")[0] for k in day_keys]
            n = 365 + calendar.isleap(year)
            require(len(year_values) == n, f"{place}: incorrect date count in {year}")
            if None in year_values:
                ge35 = ge37 = ge39 = None
            else:
                ge35, ge37, ge39 = (sum(v >= threshold for v in year_values) for threshold in levels)
                require(0 <= ge39 <= ge37 <= ge35 <= n, f"{place}: invalid counts in {year}")
            rows.append({"location_id": place, "year": year, "ge35": ge35, "ge37": ge37, "ge39": ge39})
    card = data_card("POWER Daily T2M_MAX", sources, "1981-01-01 to 2025-12-31",
                     "Đếm lũy tích số ngày đạt từng ngưỡng ≥35, ≥37 và ≥39 °C trong mỗi năm.",
                     "Nhiệt độ tối đa ngày của ô lưới, khác thời lượng nắng và số đo trạm.")
    arrays = {place: {f"ge{th}": [row[f"ge{th}"] for row in rows if row["location_id"] == place]
                      for th in levels} for place in POINTS}
    return Product(rows, ("location_id", "year"), card, dict(levels_c=list(levels), years=list(YEARS), **arrays),
                   {"daily_rows_per_place": len(keys), "sample_2025": rows[len(YEARS) - 1]})
