"""NASA FIRMS — điểm cháy (active fire) từ vệ tinh, đếm theo ô 0,1° và theo tháng.

Tài liệu: https://firms.modaps.eosdis.nasa.gov/api/area/csv
URL: /api/area/csv/[MAP_KEY]/[SOURCE]/[west,south,east,north]/[DAY_RANGE 1..10]/[YYYY-MM-DD]
Nguồn lưu trữ chuẩn (SP): MODIS_SP (từ 11/2000), VIIRS_SNPP_SP (từ 2012)…
Cần MAP_KEY miễn phí: đặt biến môi trường FIRMS_MAP_KEY.
Mỗi tháng = 3–4 yêu cầu (≤ 10 ngày/yêu cầu); 25 năm ≈ 900 yêu cầu, có cache nên chạy lại không tải lại.
"""
from __future__ import annotations

import calendar
import csv
import datetime as dt
import io
import time
from pathlib import Path

import numpy as np

from .. import config
from ..canonical import save_month
from ..geo import Grid

API = "https://firms.modaps.eosdis.nasa.gov/api/area/csv"


def month_windows(y: int, m: int) -> list[tuple[dt.date, int]]:
    """(ngày bắt đầu, số ngày ≤ 10) phủ kín tháng."""
    n = calendar.monthrange(y, m)[1]
    out, d = [], 1
    while d <= n:
        k = min(10, n - d + 1)
        out.append((dt.date(y, m, d), k))
        d += k
    return out


def request_url(key: str, product: str, start: dt.date, days: int, bbox=config.BBOX) -> str:
    w, s, e, n = bbox
    return f"{API}/{key}/{product}/{w},{s},{e},{n}/{days}/{start.isoformat()}"


def parse_csv(text: str, min_confidence: int = 30):
    """→ list[(lat, lon, 'YYYY-MM-DD', acq_time)] đã lọc độ tin cậy.
    MODIS: confidence 0–100. VIIRS: l/n/h (bỏ 'l')."""
    text = text.strip()
    if not text or text.lower().startswith(("invalid", "error", "<")):
        raise ValueError(f"FIRMS trả lời không phải CSV: {text[:120]}")
    rows = []
    for r in csv.DictReader(io.StringIO(text)):
        try:
            lat, lon = float(r["latitude"]), float(r["longitude"])
        except (KeyError, ValueError):
            continue
        conf = (r.get("confidence") or "").strip().lower()
        if conf.isdigit():
            if int(conf) < min_confidence:
                continue
        elif conf in ("l", "low"):
            continue
        rows.append((lat, lon, r.get("acq_date", ""), r.get("acq_time", "")))
    return rows


def count_grid(points, grid: Grid | None = None) -> np.ndarray:
    grid = grid or Grid.from_bbox()
    out = np.zeros((grid.h, grid.w), dtype="float32")
    for lat, lon, *_ in points:
        c = int(np.floor((lon - grid.lon0) / grid.res))
        r = int(np.floor((grid.lat1 - lat) / grid.res))
        if 0 <= c < grid.w and 0 <= r < grid.h:
            out[r, c] += 1
    return out


def fetch(var: str, spec: dict, years: list[int], raw_root: Path, cache_root: Path, session=None, log=print) -> dict:
    key = spec.get("map_key") or config.FIRMS_MAP_KEY
    if not key:
        log("[firms] BỎ QUA: chưa có MAP_KEY. Lấy miễn phí tại https://firms.modaps.eosdis.nasa.gov/api/map_key/ "
            "rồi đặt biến môi trường FIRMS_MAP_KEY.")
        return {"months": 0, "failed": [], "skipped": "no_key"}
    product = spec.get("product", "MODIS_SP")
    min_conf = int(spec.get("min_confidence", 30))
    cache = Path(cache_root) / "firms" / product
    cache.mkdir(parents=True, exist_ok=True)
    if session is None:
        import requests
        session = requests.Session()
    # Dữ liệu chuẩn (SP) có độ trễ vài tháng: tháng quá gần sẽ trả rỗng và bị hiểu nhầm là "không cháy"
    lag = int(spec.get("lag_months", 4))
    t = dt.date.today()
    cutoff = (t.year * 12 + t.month - 1) - lag
    written, failed, first_logged = 0, [], False
    for y in years:
        for m in range(1, 13):
            if y * 12 + m - 1 > cutoff:
                continue
            seen: set = set()
            pts, ok = [], True
            for start, days in month_windows(y, m):
                f = cache / f"{start.isoformat()}_{days}.csv"
                if not (f.exists() and f.stat().st_size > 0):
                    text = None
                    for attempt in range(1, 4):
                        try:
                            r = session.get(request_url(key, product, start, days), timeout=120)
                            r.raise_for_status()
                            text = r.text
                            parse_csv(text, min_conf)  # kiểm tra trước khi cache
                            f.write_text(text, encoding="utf-8")
                            break
                        except Exception as e:  # noqa: BLE001
                            log(f"[firms] {start} lần {attempt}: {str(e)[:160]}")
                            text = None
                            time.sleep(5 * attempt)
                    if text is None:
                        ok = False
                        failed.append(start.isoformat())
                        continue
                    time.sleep(0.3)  # lịch sự với giới hạn giao dịch của MAP_KEY
                rows = parse_csv(f.read_text(encoding="utf-8"), min_conf)
                if not first_logged and rows:
                    ds = sorted(r[2] for r in rows)
                    log(f"[firms] kiểm tra cửa sổ ngày: yêu cầu {start}+{days}d → dữ liệu {ds[0]}…{ds[-1]}")
                    first_logged = True
                for row in rows:
                    if not row[2].startswith(f"{y:04d}-{m:02d}"):
                        continue  # chỉ giữ điểm thuộc đúng tháng
                    k = (round(row[0], 4), round(row[1], 4), row[2], row[3])
                    if k in seen:
                        continue
                    seen.add(k)
                    pts.append(row)
            if not ok:
                continue  # tháng thiếu một phần: không ghi để khỏi đếm thiếu
            save_month(raw_root, var, y, m, count_grid(pts), units="điểm", source=f"NASA FIRMS {product}")
            written += 1
    log(f"[firms] {var} ← {product}: {written} tháng, lỗi {len(failed)} cửa sổ")
    return {"months": written, "failed": failed}
