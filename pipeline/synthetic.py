"""Sinh dữ liệu thô GIẢ LẬP để chạy thử toàn bộ pipeline khi chưa tải được NEO.

Chạy:  python -m pipeline.synthetic --out data/raw_synthetic --years 2019-2020
Dữ liệu này chỉ để kiểm tra code. Không dùng cho bài nộp.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from . import config
from .geo import PHU_QUOC, VN_OUTLINE, points_in_rings, region_of

LON0, LAT1, RES = 95.0, 30.0, 0.25          # lưới thô hơn 0,1° để kiểm tra bước đổi lưới
W, H = int(25 / RES), int(30 / RES)          # 95–120°E, 0–30°N


def _bump(m, c, w):
    d = ((m - c + 6) % 12) - 6
    return np.exp(-0.5 * (d / w) ** 2)


def make(out: Path, years: list[int], seed: int = 0) -> int:
    rng = np.random.default_rng(seed)
    lon = LON0 + (np.arange(W) + 0.5) * RES
    lat = LAT1 - (np.arange(H) + 0.5) * RES
    X, Y = np.meshgrid(lon, lat)
    vn = points_in_rings(X, Y, [VN_OUTLINE, PHU_QUOC])
    # Đất liền láng giềng thô: phía tây Việt Nam và phía bắc 21,6°N
    land = vn | (X < 104.5) & (Y > 10.5) | (Y > 21.6)
    reg = region_of(X, Y)
    count = 0
    for y in years:
        for m in range(12):
            n = (Y - 10.5) / 11.5
            temp = 27.5 - 0.24 * np.maximum(0, Y - 11) + np.clip(n, 0, 1) * 6.6 * np.cos(2 * np.pi * (m - 6.2) / 12)
            temp = temp + 4 + 0.03 * (y - 2013) + rng.normal(0, 0.6, temp.shape)
            temp[~land] = config.VARS["temp"]["nodata"][0]
            peak = np.select([reg == 2, reg == 3], [9.3, 9.8], 7.2)
            amp = np.select([reg == 2, reg == 3], [700, 450], 290)
            rain = 20 + amp * _bump(m, peak, 1.4) * rng.lognormal(0, 0.3, X.shape)
            fire = np.where(land, np.select([reg == 0, reg == 4], [0.6, 0.4], 0.15) * _bump(m, 2.3, 1.0), 0)
            fire = np.clip(fire * rng.lognormal(0, 0.4, X.shape), 0, 1)
            for var, data in (("temp", temp), ("rain", rain), ("fire", fire)):
                p = Path(out) / f"{config.RAW_PATTERN.format(var=var, yyyy=y, mm=m + 1)}.npz"
                p.parent.mkdir(parents=True, exist_ok=True)
                np.savez_compressed(p, data=data.astype("float32"), lon0=LON0, lat1=LAT1, res=RES)
                count += 1
    return count


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default="data/raw_synthetic", type=Path)
    ap.add_argument("--years", default="2019-2020")
    a = ap.parse_args(argv)
    s, _, e = a.years.partition("-")
    n = make(a.out, list(range(int(s), int(e or s) + 1)))
    print(f"[synthetic] đã ghi {n} file vào {a.out}")


if __name__ == "__main__":
    main()
