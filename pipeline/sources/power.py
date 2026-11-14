"""NASA POWER — dữ liệu khí hậu theo tháng qua API, không cần đăng ký.

Tài liệu: https://power.larc.nasa.gov/docs/services/api/temporal/monthly/
Endpoint vùng: /api/temporal/monthly/regional?latitude-min=..&latitude-max=..&longitude-min=..&longitude-max=..
               &parameters=T2M&community=AG&start=2001&end=2024&format=JSON
Giới hạn: mỗi yêu cầu vùng chỉ MỘT tham số; khung vùng nên nhỏ → chia BBOX thành các ô ≤ 5°.
Phản hồi JSON (GeoJSON): features[i].geometry.coordinates = [lon, lat, (độ cao)],
features[i].properties.parameter.<THAM_SỐ> = {"YYYYMM": giá trị, …, "YYYY13": trung bình năm}, giá trị thiếu = -999.
Parser dưới đây chịu được các biến thể nhỏ (khoá 13, fill khác, đơn vị đặt ở header hoặc parameters).
"""
from __future__ import annotations

import json
import math
import time
from pathlib import Path

import numpy as np

from .. import config
from ..canonical import resample_to_grid, save_month, to_target_units

API = "https://power.larc.nasa.gov/api/temporal/monthly/regional"


def tiles(bbox=config.BBOX, max_deg: float = 5.0) -> list[tuple[float, float, float, float]]:
    """Chia khung thành các ô ≤ max_deg độ (POWER giới hạn kích thước vùng)."""
    lon0, lat0, lon1, lat1 = bbox
    nx = max(1, math.ceil((lon1 - lon0) / max_deg - 1e-9))
    ny = max(1, math.ceil((lat1 - lat0) / max_deg - 1e-9))
    xs = np.linspace(lon0, lon1, nx + 1)
    ys = np.linspace(lat0, lat1, ny + 1)
    return [(round(xs[i], 4), round(ys[j], 4), round(xs[i + 1], 4), round(ys[j + 1], 4))
            for j in range(ny) for i in range(nx)]


def year_chunks(years: list[int], size: int) -> list[tuple[int, int]]:
    ys = sorted(years)
    return [(ys[k], ys[min(k + size, len(ys)) - 1]) for k in range(0, len(ys), size)]


def request_url(param: str, tile, y0: int, y1: int, community: str = "AG") -> str:
    lo0, la0, lo1, la1 = tile
    return (f"{API}?latitude-min={la0}&latitude-max={la1}&longitude-min={lo0}&longitude-max={lo1}"
            f"&parameters={param}&community={community}&start={y0}&end={y1}&format=JSON")


def parse(js: dict, param: str):
    """→ (lon[], lat[], {(y, m): values[]}, units). Bỏ khoá tháng 13 (trung bình năm)."""
    feats = js.get("features")
    if feats is None and "properties" in js:  # phản hồi một điểm
        feats = [js]
    if not feats:
        raise ValueError(f"POWER: phản hồi không có features ({list(js)[:5]})")
    fill = (js.get("header") or {}).get("fill_value", -999.0)
    units = ""
    for holder in (js.get("parameters") or {}, (js.get("header") or {}).get("parameters") or {}):
        meta = holder.get(param)
        if isinstance(meta, dict) and meta.get("units"):
            units = str(meta["units"])
            break
    lons, lats = [], []
    series: dict[tuple[int, int], list[float]] = {}
    for f in feats:
        coords = (f.get("geometry") or {}).get("coordinates") or []
        vals = ((f.get("properties") or {}).get("parameter") or {}).get(param)
        if len(coords) < 2 or not isinstance(vals, dict):
            continue
        lons.append(float(coords[0]))
        lats.append(float(coords[1]))
        idx = len(lons) - 1
        for key, v in vals.items():
            key = str(key)
            if len(key) != 6 or not key.isdigit():
                continue
            y, m = int(key[:4]), int(key[4:])
            if not 1 <= m <= 12:
                continue  # 13 = trung bình năm
            arr = series.setdefault((y, m), [])
            while len(arr) < idx:
                arr.append(math.nan)
            x = float(v) if v is not None else math.nan
            arr.append(math.nan if (x == fill or x <= -990) else x)
    n = len(lons)
    for k, arr in series.items():
        arr.extend([math.nan] * (n - len(arr)))
    return np.array(lons), np.array(lats), {k: np.array(v) for k, v in series.items()}, units


def _download(session, param, tile, y0, y1, community, cache: Path, log, failed: list) -> list[Path]:
    """Tải một ô × một khoảng năm (có cache). Lỗi thì thử lại, rồi tách thành từng năm."""
    f = cache / f"{tile[0]}_{tile[1]}_{tile[2]}_{tile[3]}_{y0}-{y1}.json"
    if f.exists() and f.stat().st_size > 0:
        return [f]
    url = request_url(param, tile, y0, y1, community)
    for attempt in range(1, 4):
        try:
            r = session.get(url, timeout=180)
            r.raise_for_status()
            json.loads(r.text)  # bảo đảm là JSON hợp lệ trước khi lưu cache
            f.write_text(r.text, encoding="utf-8")
            return [f]
        except Exception as e:  # noqa: BLE001
            log(f"[power] {param} {tile} {y0}-{y1} lần {attempt}: {str(e)[:160]}")
            if getattr(getattr(e, "response", None), "status_code", 0) in (400, 422):
                break  # yêu cầu không hợp lệ: thử lại vô ích, tách năm
            time.sleep(3 * attempt)
    if y1 > y0:
        out = []
        for y in range(y0, y1 + 1):
            out += _download(session, param, tile, y, y, community, cache, log, failed)
        return out
    failed.append(f"{param} {tile} {y0}")
    return []


def fetch(var: str, spec: dict, years: list[int], raw_root: Path, cache_root: Path, session=None, log=print) -> dict:
    """Tải (có cache) rồi ghi file chuẩn cho mọi tháng có dữ liệu. Trả về báo cáo."""
    param = spec["parameter"]
    community = spec.get("community", "AG")
    cache = Path(cache_root) / "power" / param
    cache.mkdir(parents=True, exist_ok=True)
    all_lon, all_lat, all_series, units = [], [], {}, spec.get("units", "")
    failed = []
    if session is None:
        import requests
        session = requests.Session()
    for tile in tiles(config.BBOX, spec.get("tile_deg", 5.0)):
        for y0, y1 in year_chunks(years, spec.get("years_per_request", 10)):
            for f in _download(session, param, tile, y0, y1, community, cache, log, failed):
                lon, lat, ser, u = parse(json.loads(f.read_text(encoding="utf-8")), param)
                units = units or u
                off = sum(len(a) for a in all_lon)
                all_lon.append(lon)
                all_lat.append(lat)
                for k, v in ser.items():
                    all_series.setdefault(k, []).append((off, v))
    if not all_lon:
        return {"months": 0, "failed": failed, "units": units}
    lon = np.concatenate(all_lon)
    lat = np.concatenate(all_lat)
    target = config.VARS[var]["unit"]
    written = 0
    for (y, m), parts in sorted(all_series.items()):
        if y not in years:
            continue
        vals = np.full(len(lon), np.nan)
        for off, v in parts:
            vals[off:off + len(v)] = v
        if not np.isfinite(vals).any():
            continue
        grid_vals = resample_to_grid(lon, lat, vals)
        grid_vals = to_target_units(grid_vals, units, target, y, m)
        save_month(raw_root, var, y, m, grid_vals, units=target, source=f"NASA POWER {param}")
        written += 1
    log(f"[power] {var} ← {param} ({units or 'đơn vị ?'}): {written} tháng, {len(lon)} điểm lưới, lỗi {len(failed)}")
    return {"months": written, "failed": failed, "units": units}
