"""Kiểm chứng: giá trị trong frames/*.bin khớp dữ liệu thô sau khi đổi lưới (tiêu chí Validity).

Chạy:  python -m pipeline.validate --raw data/raw --out web/data --samples 6
In ra sai số lớn nhất so với ngưỡng lượng tử hóa và 3 điểm kiểm tra ngẫu nhiên để dán vào README.
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

import numpy as np

from . import config
from .build import find_raw
from .encode import dequantize, max_error, unb64
from .geo import Grid
from .io_neo import convert_units, read_any, regrid


def validate(raw_dir: Path, out_dir: Path, samples: int = 6, seed: int = 1, verbose: bool = True) -> bool:
    tg = json.loads((Path(out_dir) / "touchgrid.json").read_text(encoding="utf-8"))
    grid = Grid.from_bbox(tuple(tg["bbox"]), tg["res"])
    land = unb64(tg["land"]).reshape(tg["h"], tg["w"])
    idx = np.flatnonzero(land.ravel() == 1)
    rng = random.Random(seed)
    ok = True
    for var, meta in tg["vars"].items():
        for _ in range(samples):
            y, m = rng.choice(tg["years"]), rng.randint(1, 12)
            p = find_raw(raw_dir, var, y, m)
            if p is None:
                continue
            truth = convert_units(regrid(read_any(p, var), grid), var, y, m).ravel()[idx]
            frame = np.frombuffer((Path(out_dir) / meta["frames"].format(year=y)).read_bytes(), np.uint8).reshape(12, -1)[m - 1]
            got = dequantize(frame, meta["min"], meta["max"], meta["scale"])
            clipped = np.clip(truth, meta["min"], meta["max"])
            both = np.isfinite(clipped) & np.isfinite(got)
            err = np.abs(got[both] - clipped[both])
            bound = np.array([max_error(meta["min"], meta["max"], meta["scale"], at=v) for v in clipped[both]]) + 1e-4
            bad = int((err > bound).sum())
            if verbose:
                print(f"[validate] {var} {y}-{m:02d}: {both.sum()} ô, sai số lớn nhất {err.max():.3f} {meta['unit']}, vượt ngưỡng {bad}")
            ok &= bad == 0
            if verbose and _ == 0:
                for k in rng.sample(list(np.flatnonzero(both)), k=min(3, int(both.sum()))):
                    r, c = divmod(int(idx[k]), tg["w"])
                    lon = grid.lon0 + (c + 0.5) * grid.res
                    lat = grid.lat1 - (r + 0.5) * grid.res
                    print(f"           điểm {lat:.2f}°N {lon:.2f}°E: gốc {truth[k]:.2f}, web {got[k]:.2f}")
    if verbose:
        print("[validate] ĐẠT" if ok else "[validate] KHÔNG ĐẠT")
    return ok


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--raw", default="data/raw", type=Path)
    ap.add_argument("--out", default="web/data", type=Path)
    ap.add_argument("--samples", default=6, type=int)
    a = ap.parse_args(argv)
    sys.exit(0 if validate(a.raw, a.out, a.samples) else 1)


if __name__ == "__main__":
    main()
