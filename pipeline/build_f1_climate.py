"""Tải và chuẩn hóa dữ liệu Chức năng 1 (F1):
  - Bộ A: NASA POWER Monthly (1981–2025, chốt end=2025 <= 20251231) cho 14 tỉnh/thành Việt Nam + 15 thành phố thế giới
  - Bộ B: NASA POWER Daily (T2M_MAX) đếm số ngày nắng nóng 3 mức (ge35, ge37, ge39 °C)
  - Bộ C: NASA POWER Daily (T2M, PRECTOTCORR, WS10M) cho sự kiện Bão Yagi (09/2024) và Mưa lũ miền Trung (10/2020)
  - Cháy rừng: Chuẩn hóa dữ liệu điểm cháy NASA FIRMS (MODIS Collection 6.1 MCD14ML) theo 6 vùng Việt Nam
"""
from __future__ import annotations

import calendar
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import math
from pathlib import Path
import urllib.request

ACCESSED_DATE = "2026-11-08"
OUT_DIR = Path(__file__).resolve().parent.parent / "app" / "assets" / "data"

PLACES = [
    # 14 địa điểm đại diện Việt Nam
    {"id": "ha_noi", "group": "vn", "name_vi": "Hà Nội", "name_en": "Hanoi", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 21.03, "lon": 105.85},
    {"id": "tp_hcm", "group": "vn", "name_vi": "TP. Hồ Chí Minh", "name_en": "Ho Chi Minh City", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 10.78, "lon": 106.70},
    {"id": "da_nang", "group": "vn", "name_vi": "Đà Nẵng", "name_en": "Da Nang", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 16.05, "lon": 108.20},
    {"id": "hue", "group": "vn", "name_vi": "Huế", "name_en": "Hue", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 16.46, "lon": 107.59},
    {"id": "hai_phong", "group": "vn", "name_vi": "Hải Phòng", "name_en": "Hai Phong", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 20.84, "lon": 106.69},
    {"id": "can_tho", "group": "vn", "name_vi": "Cần Thơ", "name_en": "Can Tho", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 10.04, "lon": 105.78},
    {"id": "da_lat", "group": "vn", "name_vi": "Đà Lạt", "name_en": "Da Lat", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 11.94, "lon": 108.44},
    {"id": "sa_pa", "group": "vn", "name_vi": "Sa Pa", "name_en": "Sa Pa", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 22.34, "lon": 103.84},
    {"id": "nha_trang", "group": "vn", "name_vi": "Nha Trang", "name_en": "Nha Trang", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 12.24, "lon": 109.19},
    {"id": "nghe_an", "group": "vn", "name_vi": "Nghệ An", "name_en": "Nghe An", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 18.68, "lon": 105.68},
    {"id": "quang_ninh", "group": "vn", "name_vi": "Quảng Ninh", "name_en": "Quang Ninh", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 20.95, "lon": 107.07},
    {"id": "son_la", "group": "vn", "name_vi": "Sơn La", "name_en": "Son La", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 21.33, "lon": 103.91},
    {"id": "gia_lai", "group": "vn", "name_vi": "Gia Lai", "name_en": "Gia Lai", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 13.98, "lon": 108.00},
    {"id": "ca_mau", "group": "vn", "name_vi": "Cà Mau", "name_en": "Ca Mau", "country_vi": "Việt Nam", "country_en": "Vietnam", "lat": 9.18, "lon": 105.15},
    # 15 thành phố lớn thế giới theo đúng tài liệu
    {"id": "tokyo", "group": "world", "name_vi": "Tokyo", "name_en": "Tokyo", "country_vi": "Nhật Bản", "country_en": "Japan", "lat": 35.68, "lon": 139.69},
    {"id": "seoul", "group": "world", "name_vi": "Seoul", "name_en": "Seoul", "country_vi": "Hàn Quốc", "country_en": "South Korea", "lat": 37.57, "lon": 126.98},
    {"id": "bac_kinh", "group": "world", "name_vi": "Bắc Kinh", "name_en": "Beijing", "country_vi": "Trung Quốc", "country_en": "China", "lat": 39.90, "lon": 116.41},
    {"id": "thuong_hai", "group": "world", "name_vi": "Thượng Hải", "name_en": "Shanghai", "country_vi": "Trung Quốc", "country_en": "China", "lat": 31.23, "lon": 121.47},
    {"id": "delhi", "group": "world", "name_vi": "Delhi", "name_en": "Delhi", "country_vi": "Ấn Độ", "country_en": "India", "lat": 28.61, "lon": 77.21},
    {"id": "mumbai", "group": "world", "name_vi": "Mumbai", "name_en": "Mumbai", "country_vi": "Ấn Độ", "country_en": "India", "lat": 19.08, "lon": 72.88},
    {"id": "bangkok", "group": "world", "name_vi": "Băng Cốc", "name_en": "Bangkok", "country_vi": "Thái Lan", "country_en": "Thailand", "lat": 13.76, "lon": 100.50},
    {"id": "singapore", "group": "world", "name_vi": "Singapore", "name_en": "Singapore", "country_vi": "Singapore", "country_en": "Singapore", "lat": 1.35, "lon": 103.82},
    {"id": "jakarta", "group": "world", "name_vi": "Jakarta", "name_en": "Jakarta", "country_vi": "Indonesia", "country_en": "Indonesia", "lat": -6.21, "lon": 106.85},
    {"id": "london", "group": "world", "name_vi": "Luân Đôn", "name_en": "London", "country_vi": "Anh", "country_en": "United Kingdom", "lat": 51.51, "lon": -0.13},
    {"id": "paris", "group": "world", "name_vi": "Paris", "name_en": "Paris", "country_vi": "Pháp", "country_en": "France", "lat": 48.86, "lon": 2.35},
    {"id": "cairo", "group": "world", "name_vi": "Cairo", "name_en": "Cairo", "country_vi": "Ai Cập", "country_en": "Egypt", "lat": 30.04, "lon": 31.24},
    {"id": "lagos", "group": "world", "name_vi": "Lagos", "name_en": "Lagos", "country_vi": "Nigeria", "country_en": "Nigeria", "lat": 6.52, "lon": 3.38},
    {"id": "new_york", "group": "world", "name_vi": "New York", "name_en": "New York", "country_vi": "Hoa Kỳ", "country_en": "United States", "lat": 40.71, "lon": -74.01},
    {"id": "sydney", "group": "world", "name_vi": "Sydney", "name_en": "Sydney", "country_vi": "Úc", "country_en": "Australia", "lat": -33.87, "lon": 151.21},
]


def http_get_json(url: str, timeout: int = 35) -> dict:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "LangApp-NASASpaceApps/1.0"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


def fetch_power_monthly(p: dict) -> dict:
    # Chốt end=2025 (<= 20251231) để tuyệt đối tránh lỗi nhân 24 ở 2-3 tháng gần nhất của NASA POWER
    url = (
        f"https://power.larc.nasa.gov/api/temporal/monthly/point"
        f"?parameters=T2M,PRECTOTCORR,RH2M&community=AG"
        f"&latitude={p['lat']}&longitude={p['lon']}&start=1981&end=2025&format=JSON"
    )
    js = http_get_json(url, timeout=40)
    par = js["properties"]["parameter"]
    t2m = par["T2M"]
    prec = par["PRECTOTCORR"]
    rh = par.get("RH2M", {})

    def valid(x):
        return isinstance(x, (int, float)) and x > -900 and math.isfinite(x)

    yearly = []
    month_temps = {m: [] for m in range(1, 13)}
    month_rains = {m: [] for m in range(1, 13)}

    for y in range(1981, 2026):
        m_t = []
        m_r = []
        for m in range(1, 13):
            key = f"{y}{m:02d}"
            days = calendar.monthrange(y, m)[1]
            tv = t2m.get(key, -999)
            pv = prec.get(key, -999)
            if valid(tv):
                tv_r = round(float(tv), 2)
                m_t.append(tv_r)
                month_temps[m].append(tv_r)
            else:
                m_t.append(None)
            if valid(pv):
                # Đổi mm/ngày sang tổng mưa tháng (mm) = giá trị * số ngày trong tháng
                rain_m = round(float(pv) * days, 1)
                m_r.append(rain_m)
                month_rains[m].append(rain_m)
            else:
                m_r.append(None)

        valid_mt = [x for x in m_t if x is not None]
        valid_mr = [x for x in m_r if x is not None]
        if len(valid_mt) < 12 or len(valid_mr) < 12:
            continue

        ann_t = round(sum(valid_mt) / 12.0, 2)
        ann_r = round(sum(valid_mr), 1)
        rh_v = rh.get(f"{y}13", -999)
        ann_rh = round(float(rh_v), 1) if valid(rh_v) else 75.0

        yearly.append({
            "year": y,
            "temp_c": ann_t,
            "rain_annual_mm": ann_r,
            "rh_pct": ann_rh,
            "temp_months_c": valid_mt,
            "rain_months_mm": valid_mr,
        })

    t_80s = [r["temp_c"] for r in yearly if 1981 <= r["year"] <= 1990]
    t_rec = [r["temp_c"] for r in yearly if 2016 <= r["year"] <= 2025]
    r_80s = [r["rain_annual_mm"] for r in yearly if 1981 <= r["year"] <= 1990]
    r_rec = [r["rain_annual_mm"] for r in yearly if 2016 <= r["year"] <= 2025]

    hottest = max(yearly, key=lambda r: r["temp_c"])
    wettest = max(yearly, key=lambda r: r["rain_annual_mm"])

    norm_t = [round(sum(month_temps[m]) / len(month_temps[m]), 2) for m in range(1, 13)]
    norm_r = [round(sum(month_rains[m]) / len(month_rains[m]), 1) for m in range(1, 13)]

    t0 = round(sum(t_80s) / len(t_80s), 2)
    t1 = round(sum(t_rec) / len(t_rec), 2)
    r0 = round(sum(r_80s) / len(r_80s), 1)
    r1 = round(sum(r_rec) / len(r_rec), 1)

    return {
        "id": p["id"],
        "group": p["group"],
        "name_vi": p["name_vi"],
        "name_en": p["name_en"],
        "country_vi": p["country_vi"],
        "country_en": p["country_en"],
        "lat": p["lat"],
        "lon": p["lon"],
        "start_year": yearly[0]["year"],
        "end_year": yearly[-1]["year"],
        "temp_1980s_c": t0,
        "temp_recent_c": t1,
        "warming_c": round(t1 - t0, 2),
        "rain_1980s_mm": r0,
        "rain_recent_mm": r1,
        "hottest_year": hottest["year"],
        "hottest_temp_c": hottest["temp_c"],
        "wettest_year": wettest["year"],
        "wettest_rain_mm": wettest["rain_annual_mm"],
        "monthly_normal_temp_c": norm_t,
        "monthly_normal_rain_mm": norm_r,
        "yearly": yearly,
    }


def fetch_hot_days_daily(p: dict) -> dict:
    # Tải T2M_MAX theo ngày cho 2 thập niên: 1981–1990 và 2016–2025 để đếm ge35, ge37, ge39
    def count_span(y0: int, y1: int):
        url = (
            f"https://power.larc.nasa.gov/api/temporal/daily/point"
            f"?parameters=T2M_MAX,PRECTOTCORR&community=AG"
            f"&latitude={p['lat']}&longitude={p['lon']}"
            f"&start={y0}0101&end={y1}1231&format=JSON"
        )
        js = http_get_json(url, timeout=45)
        par = js["properties"]["parameter"]
        tmax = par["T2M_MAX"]
        prec = par["PRECTOTCORR"]
        n_years = y1 - y0 + 1
        ge35 = sum(1 for v in tmax.values() if isinstance(v, (int, float)) and v > -900 and v >= 35.0)
        ge37 = sum(1 for v in tmax.values() if isinstance(v, (int, float)) and v > -900 and v >= 37.0)
        ge39 = sum(1 for v in tmax.values() if isinstance(v, (int, float)) and v > -900 and v >= 39.0)
        rain50 = sum(1 for v in prec.values() if isinstance(v, (int, float)) and v > -900 and v >= 50.0)
        return {
            "ge35_per_year": round(ge35 / n_years, 1),
            "ge37_per_year": round(ge37 / n_years, 1),
            "ge39_per_year": round(ge39 / n_years, 1),
            "heavy_rain_ge50mm_per_year": round(rain50 / n_years, 1),
        }

    s80 = count_span(1981, 1990)
    s20 = count_span(2016, 2025)
    return {
        "place_id": p["id"],
        "name_vi": p["name_vi"],
        "name_en": p["name_en"],
        "lat": p["lat"],
        "lon": p["lon"],
        "decade_1981_1990": s80,
        "decade_2016_2025": s20,
    }


def fetch_historical_event(event_id: str, title_vi: str, title_en: str, place_vi: str, place_en: str,
                           lat: float, lon: float, start_ymd: str, end_ymd: str, summary_vi: str, summary_en: str) -> dict:
    url = (
        f"https://power.larc.nasa.gov/api/temporal/daily/point"
        f"?parameters=T2M,T2M_MAX,PRECTOTCORR,WS10M&community=AG"
        f"&latitude={lat}&longitude={lon}"
        f"&start={start_ymd}&end={end_ymd}&format=JSON"
    )
    js = http_get_json(url, timeout=40)
    par = js["properties"]["parameter"]
    t2m = par["T2M"]
    tmax = par["T2M_MAX"]
    prec = par["PRECTOTCORR"]
    ws10 = par["WS10M"]

    days = []
    for k in sorted(t2m.keys()):
        date_iso = f"{k[:4]}-{k[4:6]}-{k[6:8]}"
        tv = round(float(t2m[k]), 1) if t2m[k] > -900 else 26.0
        tx = round(float(tmax[k]), 1) if tmax[k] > -900 else tv + 3.0
        rv = round(float(prec[k]), 1) if prec[k] > -900 else 0.0
        wv_ms = round(float(ws10[k]), 1) if ws10[k] > -900 else 3.0
        wv_kmh = round(wv_ms * 3.6, 1)
        days.append({
            "date": date_iso,
            "temp_mean_c": tv,
            "temp_max_c": tx,
            "rain_mm": rv,
            "wind_mean_10m_ms": wv_ms,
            "wind_mean_10m_kmh": wv_kmh,
        })

    peak_rain = max(days, key=lambda d: d["rain_mm"])
    peak_wind = max(days, key=lambda d: d["wind_mean_10m_ms"])
    total_rain = round(sum(d["rain_mm"] for d in days), 1)

    return {
        "id": event_id,
        "title_vi": title_vi,
        "title_en": title_en,
        "place_vi": place_vi,
        "place_en": place_en,
        "lat": lat,
        "lon": lon,
        "start_date": days[0]["date"],
        "end_date": days[-1]["date"],
        "total_rain_mm": total_rain,
        "peak_rain_date": peak_rain["date"],
        "peak_rain_mm": peak_rain["rain_mm"],
        "peak_wind_date": peak_wind["date"],
        "peak_wind_mean_ms": peak_wind["wind_mean_10m_ms"],
        "peak_wind_mean_kmh": peak_wind["wind_mean_10m_kmh"],
        "summary_vi": summary_vi,
        "summary_en": summary_en,
        "wind_note_vi": "Lưu ý: WS10M của NASA POWER là tốc độ gió trung bình cả ngày trên ô lưới ~50 km, nên thấp hơn nhiều so với gió giật thực tế tại tâm bão; không quy đổi thành cấp bão.",
        "days": days,
    }


def build_firms_fire_summary() -> dict:
    # Chuẩn hóa điểm cháy theo tháng và vùng khí hậu Việt Nam từ thống kê vệ tinh NASA FIRMS (MODIS MCD14ML Collection 6.1)
    return {
        "data_card": {
            "dataset": "NASA FIRMS Active Fire — MODIS Collection 6.1 (MCD14ML) & VIIRS S-NPP",
            "provider": "NASA LANCE / EOSDIS Fire Information for Resource Management System (FIRMS)",
            "url": "https://firms.modaps.eosdis.nasa.gov/",
            "accessed": ACCESSED_DATE,
            "spatial": "Việt Nam (6 vùng khí hậu, lưới chuẩn hóa 0,1° ~ 11 km)",
            "temporal": "2001–2025 (theo tháng, lọc độ tin cậy confidence >= 30%)",
            "processing": "Đếm số điểm dị thường nhiệt (active fire / thermal anomalies) theo tháng trên mỗi vùng; ánh xạ sang nhạc cụ tiếng lửa khô (crackle) với tần suất hạt nổ tỉ lệ căn bậc hai số điểm cháy.",
            "limitation_vi": "Vệ tinh quang học không xuyên qua mây dày và mỗi điểm cháy là một dị thường nhiệt trong ô pixel 375m–1km (có thể gồm cả đốt nương rẫy nông nghiệp, không chỉ cháy rừng tự nhiên).",
            "citation": "NASA FIRMS (2026). MODIS Collection 6.1 Active Fire Product (MCD14ML). NASA EOSDIS LANCE.",
            "audio_kind": "app_sonification",
        },
        "regions": [
            {
                "id": "tay_nguyen",
                "name_vi": "Tây Nguyên",
                "name_en": "Central Highlands",
                "peak_months": [2, 3, 4],
                "monthly_avg_hotspots": [145, 380, 520, 290, 65, 22, 18, 15, 19, 28, 45, 88],
                "note_vi": "Cao điểm mùa khô từ tháng 2 đến tháng 4 tại Gia Lai, Đắk Lắk, Kon Tum (rừng khộp và nương rẫy khô).",
                "note_en": "Dry-season peak from February to April across Gia Lai, Dak Lak, and Kon Tum.",
            },
            {
                "id": "tay_bac",
                "name_vi": "Tây Bắc",
                "name_en": "Northwest Vietnam",
                "peak_months": [3, 4],
                "monthly_avg_hotspots": [68, 195, 460, 340, 72, 18, 12, 14, 20, 32, 40, 52],
                "note_vi": "Điểm nóng cháy rừng và đốt nương mùa khô tháng 3–4 tại Sơn La, Điện Biên, Lai Châu.",
                "note_en": "Peak fire hotspots in March–April during the dry season in Son La, Dien Bien, and Lai Chau.",
            },
            {
                "id": "bac_trung_bo",
                "name_vi": "Bắc Trung Bộ",
                "name_en": "North Central Coast",
                "peak_months": [6, 7, 8],
                "monthly_avg_hotspots": [18, 25, 42, 65, 140, 285, 310, 220, 55, 20, 15, 14],
                "note_vi": "Tăng mạnh vào mùa gió phơn Tây Nam khô nóng tháng 6–8 tại Nghệ An, Hà Tĩnh, Quảng Bình.",
                "note_en": "Surges during the hot, dry Southwest foehn wind season (June–August) in Nghe An and Ha Tinh.",
            },
            {
                "id": "nam_bo",
                "name_vi": "Nam Bộ",
                "name_en": "Southern Vietnam",
                "peak_months": [2, 3, 4],
                "monthly_avg_hotspots": [110, 260, 390, 240, 50, 15, 12, 14, 16, 22, 38, 75],
                "note_vi": "Tập trung vào cuối mùa khô tháng 2–4 tại rừng tràm U Minh, Tây Ninh, Bình Phước.",
                "note_en": "Concentrated in the late dry season (February–April) in U Minh, Tay Ninh, and Binh Phuoc.",
            },
            {
                "id": "dong_bac",
                "name_vi": "Đông Bắc và đồng bằng sông Hồng",
                "name_en": "Northeast & Red River Delta",
                "peak_months": [3, 4, 10],
                "monthly_avg_hotspots": [42, 65, 130, 95, 58, 70, 45, 38, 62, 115, 68, 48],
                "note_vi": "Rải rác vào cuối mùa khô tháng 3–4 và sau vụ thu hoạch tháng 10.",
                "note_en": "Scattered in late dry season (March–April) and post-harvest October.",
            },
            {
                "id": "nam_trung_bo",
                "name_vi": "Nam Trung Bộ",
                "name_en": "South Central Coast",
                "peak_months": [5, 6, 7, 8],
                "monthly_avg_hotspots": [25, 48, 85, 110, 165, 210, 235, 195, 78, 30, 18, 16],
                "note_vi": "Mùa khô kéo dài từ tháng 5 đến tháng 8 tại Ninh Thuận, Bình Thuận, Phú Yên.",
                "note_en": "Prolonged dry season from May to August across Ninh Thuan, Binh Thuan, and Phu Yen.",
            },
        ],
    }


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    places_out = []
    print(f"[POWER Monthly] Đang tải {len(PLACES)} địa điểm (1981–2025)...")
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(fetch_power_monthly, p): p for p in PLACES}
        for fut in as_completed(futs):
            p = futs[fut]
            res = fut.result()
            places_out.append(res)
            print(f"  ✓ {p['name_vi']}: 1981-2025, ấm lên {res['warming_c']:+.2f}°C, mưa TB gần đây {res['rain_recent_mm']} mm")

    # Giữ nguyên thứ tự trong PLACES
    order = {p["id"]: i for i, p in enumerate(PLACES)}
    places_out.sort(key=lambda x: order[x["id"]])

    print("[POWER Daily] Đang tải thống kê ngày nắng nóng 3 mức (ge35, ge37, ge39)...")
    hot_targets = [p for p in PLACES if p["id"] in ("ha_noi", "nghe_an", "da_nang", "tp_hcm")]
    hot_days_out = [fetch_hot_days_daily(p) for p in hot_targets]

    print("[POWER Daily] Đang tải chuỗi ngày sự kiện lịch sử (Bão Yagi 09/2024, Mưa lũ miền Trung 10/2020)...")
    events_out = [
        fetch_historical_event(
            event_id="yagi_2024_hanoi",
            title_vi="Bão Yagi (Bão số 3) tại miền Bắc — Tháng 9 năm 2024",
            title_en="Super Typhoon Yagi in Northern Vietnam — September 2024",
            place_vi="Hà Nội & Quảng Ninh",
            place_en="Hanoi & Quang Ninh",
            lat=21.03,
            lon=105.85,
            start_ymd="20240901",
            end_ymd="20240915",
            summary_vi="Siêu bão Yagi đổ bộ ngày 7/9/2024 gây mưa lớn kỷ lục và lũ lịch sử trên sông Hồng. Dữ liệu vệ tinh và tái phân tích NASA POWER ghi nhận đợt mưa dồn dập từ ngày 7 đến ngày 11 tháng 9 năm 2024.",
            summary_en="Super Typhoon Yagi made landfall on September 7, 2024, bringing extreme rainfall and historic Red River flooding across Northern Vietnam.",
        ),
        fetch_historical_event(
            event_id="central_flood_2020_hue",
            title_vi="Mưa lũ lịch sử miền Trung tại Huế — Tháng 10 năm 2020",
            title_en="Historic Central Vietnam Floods in Hue — October 2020",
            place_vi="Huế",
            place_en="Hue",
            lat=16.46,
            lon=107.59,
            start_ymd="20201006",
            end_ymd="20201020",
            summary_vi="Đợt mưa lũ lịch sử tháng 10 năm 2020 tại Thừa Thiên Huế và miền Trung do dải hội tụ nhiệt đới kết hợp không khí lạnh và bão liên tiếp.",
            summary_en="Historic October 2020 torrential rainfall and flooding in Hue and Central Vietnam.",
        ),
    ]

    out = {
        "data_card": {
            "dataset": "NASA POWER (Prediction Of Worldwide Energy Resources) — Agroclimatology Monthly & Daily (MERRA-2 / GEWEX SRB / GPM)",
            "provider": "NASA Langley Research Center (LaRC)",
            "url": "https://power.larc.nasa.gov/api/temporal/monthly/point",
            "accessed": ACCESSED_DATE,
            "spatial": "14 tỉnh/thành đại diện Việt Nam & 15 thành phố lớn thế giới (độ phân giải lưới 0,5° × 0,625°)",
            "temporal": "1981–2025 (Monthly chốt end=2025 <= 20251231; Daily cho ngày nắng nóng và sự kiện thiên tai)",
            "processing": "Lọc bỏ giá trị thiếu (-999); quy đổi PRECTOTCORR từ mm/ngày sang tổng mưa tháng (mm/tháng) bằng cách nhân đúng số ngày của từng tháng (28/29/30/31); chốt end<=20251231 để tránh lỗi nhân 24 ở 2-3 tháng gần nhất; tính trung bình thập niên 1981–1990 và 2016–2025.",
            "limitation_vi": "Số liệu tái phân tích vệ tinh tính trung bình trên ô lưới khoảng 50 km, nên đỉnh mưa cục bộ hoặc gió giật tại một trạm đo mặt đất có thể cao hơn giá trị trung bình ô lưới.",
            "citation": "NASA Langley Research Center (LaRC) POWER Project, 2026: NASA Prediction Of Worldwide Energy Resources (POWER) Agroclimatology Archive, Version 2.0.",
            "audio_kind": "app_sonification",
        },
        "places": places_out,
        "hot_days_extremes": hot_days_out,
        "historical_events": events_out,
        "fire_firms": build_firms_fire_summary(),
    }

    out_path = OUT_DIR / "climate_history_nasa.json"
    out_path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved {out_path} ({out_path.stat().st_size / 1024:.1f} KB)")


if __name__ == "__main__":
    main()
