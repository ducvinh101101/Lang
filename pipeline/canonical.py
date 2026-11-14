"""Định dạng chuẩn giữa các nguồn dữ liệu và bước build.

Mọi adapter (POWER, FIRMS, NEO, inbox…) chỉ cần gọi `save_month()` với một mảng 2D trên lưới 0,1° của BBOX.
File: data/raw/<var>/<YYYY>-<MM>.npz gồm data (float32, hàng từ bắc xuống nam), lon0, lat1, res, units, source.
build.py/validate.py đọc file này qua io_neo.read_npz — không cần biết nguồn gốc.
"""
from __future__ import annotations

import calendar
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

from . import config
from .geo import Grid


def raw_path(out_root: Path, var: str, y: int, m: int) -> Path:
    return Path(out_root) / f"{config.RAW_PATTERN.format(var=var, yyyy=y, mm=m)}.npz"


def save_month(out_root: Path, var: str, y: int, m: int, data: np.ndarray, *, units: str = "", source: str = "",
               grid: Grid | None = None) -> Path:
    grid = grid or Grid.from_bbox()
    if data.shape != (grid.h, grid.w):
        raise ValueError(f"{var} {y}-{m:02d}: lưới {data.shape} khác {(grid.h, grid.w)}")
    p = raw_path(out_root, var, y, m)
    p.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(p, data=data.astype("float32"), lon0=grid.lon0, lat1=grid.lat1, res=grid.res,
                        units=np.array(units), source=np.array(source))
    return p


def resample_to_grid(lon: np.ndarray, lat: np.ndarray, values: np.ndarray, grid: Grid | None = None,
                     max_dist: float | None = None) -> np.ndarray:
    """Đưa các điểm (tâm ô của nguồn bất kỳ, lưới đều hay không) về lưới 0,1°.

    - Nguồn MỊN hơn 0,1°: lấy trung bình các điểm rơi vào mỗi ô đích.
    - Nguồn THÔ hơn (POWER 0,5°×0,625°…): ô đích lấy giá trị điểm nguồn gần nhất trong bán kính max_dist.
    lon, lat, values: mảng cùng kích thước (1D hoặc 2D). NaN bị bỏ qua.
    """
    grid = grid or Grid.from_bbox()
    lon = np.asarray(lon, dtype="float64").ravel()
    lat = np.asarray(lat, dtype="float64").ravel()
    v = np.asarray(values, dtype="float64").ravel()
    ok = np.isfinite(v) & np.isfinite(lon) & np.isfinite(lat)
    lon, lat, v = lon[ok], lat[ok], v[ok]
    out = np.full((grid.h, grid.w), np.nan, dtype="float64")
    if len(v) == 0:
        return out.astype("float32")

    # 1) trung bình theo ô (cho nguồn mịn)
    c = np.floor((lon - grid.lon0) / grid.res).astype(int)
    r = np.floor((grid.lat1 - lat) / grid.res).astype(int)
    inside = (c >= 0) & (c < grid.w) & (r >= 0) & (r < grid.h)
    sums = np.zeros((grid.h, grid.w))
    cnt = np.zeros((grid.h, grid.w))
    np.add.at(sums, (r[inside], c[inside]), v[inside])
    np.add.at(cnt, (r[inside], c[inside]), 1)
    has = cnt > 0
    out[has] = sums[has] / cnt[has]

    # 2) ô trống: lấy điểm gần nhất (cho nguồn thô)
    empty = ~has
    if empty.any():
        if max_dist is None:
            # bán kính = 0,9 × khoảng cách điển hình giữa các điểm nguồn (đủ phủ góc ô chữ nhật 0,5°×0,625°)
            if len(v) > 1:
                d, _ = cKDTree(np.c_[lon, lat]).query(np.c_[lon, lat], k=2)
                spacing = float(np.median(d[:, 1]))
            else:
                spacing = grid.res
            max_dist = max(grid.res, spacing * 0.9)
        X, Y = grid.centers()
        tree = cKDTree(np.c_[lon, lat])
        d, k = tree.query(np.c_[X[empty], Y[empty]], distance_upper_bound=max_dist)
        good = np.isfinite(d)
        vals = np.full(len(d), np.nan)
        vals[good] = v[k[good]]
        out[empty] = vals
    return out.astype("float32")


def to_target_units(a: np.ndarray, units: str, target: str, y: int, m: int) -> np.ndarray:
    """Đổi đơn vị phổ biến của dữ liệu NASA về đơn vị của biến trong config."""
    u = (units or "").strip().lower().replace(" ", "")
    t = (target or "").strip().lower()
    days = calendar.monthrange(y, m)[1]
    if t.startswith("mm/th") or t == "mm" or t.startswith("mm/month"):
        if u in ("mm/day", "mmday-1", "mm/d", "mmd-1", "mm_per_day"):
            return a * days
        if u in ("mm/hr", "mm/h", "mmhr-1", "mmh-1", "mm_per_hr"):
            return a * 24 * days
        if u in ("kgm-2s-1", "kg/m2/s", "kg/m^2/s"):
            return a * 86400 * days
        return a
    if t == "°c" or t == "c":
        if u in ("k", "kelvin"):
            return a - 273.15
        return a
    return a
