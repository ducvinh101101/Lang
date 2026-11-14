"""F1: dữ liệu chuẩn (data/raw) → touchgrid.json + series.json + frames/<var>_<năm>.bin cho app và web.

Chạy:  python -m pipeline.build --raw data/raw --out web/data
Tùy chọn: --boundaries gadm41_VNM_1.json  --merge-map merge_map.csv  --years 2001-2025
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import warnings
from pathlib import Path

import numpy as np

from . import config
from .encode import b64, quantize
from .geo import Grid, build_geo, builtin_sea_mask
from .io_neo import convert_units, read_any, regrid

EXTS = (".csv", ".tif", ".tiff", ".npz", ".png")


def find_raw(raw_dir: Path, var: str, y: int, m: int) -> Path | None:
    base = Path(raw_dir) / config.RAW_PATTERN.format(var=var, yyyy=y, mm=m)
    for ext in EXTS:
        p = base.parent / (base.name + ext)
        if p.exists():
            return p
    return None


def load_stack(raw_dir: Path, var: str, years: list[int], grid: Grid, legend=None):
    """Trả về mảng (năm, 12, h, w) và danh sách tháng thiếu."""
    stack = np.full((len(years), 12, grid.h, grid.w), np.nan, dtype="float32")
    missing = []
    for yi, y in enumerate(years):
        for m in range(1, 13):
            p = find_raw(raw_dir, var, y, m)
            if p is None:
                missing.append(f"{y}-{m:02d}")
                continue
            r = read_any(p, var, legend)
            stack[yi, m - 1] = convert_units(regrid(r, grid), var, y, m)
    return stack, missing


def nanmean(a, axis):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)
        return np.nanmean(a, axis=axis)


def nanstd(a, axis):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)
        return np.nanstd(a, axis=axis, ddof=1)


def sea_from_temp(stack: np.ndarray) -> np.ndarray:
    """Nhiệt độ bề mặt đất (LST) không có giá trị trên biển → dùng làm mặt nạ biển."""
    valid = np.isfinite(stack).reshape(-1, *stack.shape[2:]).mean(axis=0)
    return valid < 0.2


def series_for(stack: np.ndarray, mask: np.ndarray, clim_idx: list[int]):
    """Trung bình theo ô của một vùng → chuỗi (năm*12), cùng z so với chuẩn từng tháng."""
    cells = stack[:, :, mask]                           # (Y, 12, n)
    s = nanmean(cells, axis=2)                          # (Y, 12)
    base = s[clim_idx] if clim_idx else s
    mu, sd = nanmean(base, axis=0), nanstd(base, axis=0)
    sd = np.where(np.isfinite(sd) & (sd > 0), sd, np.nan)
    z = (s - mu) / sd
    r2 = lambda a: [None if not np.isfinite(x) else round(float(x), 2) for x in a.ravel()]
    return {"values": r2(s), "z": r2(z)}


def build(raw_dir: Path, out_dir: Path, years=None, clim_years=None, boundaries: Path | None = None,
          merge_map: Path | None = None, legends: dict | None = None, verbose: bool = True) -> dict:
    years = list(years or config.YEARS)
    clim_years = [y for y in (clim_years or config.CLIM_YEARS) if y in years]
    clim_idx = [years.index(y) for y in clim_years]
    grid = Grid.from_bbox()
    out_dir = Path(out_dir)
    (out_dir / "frames").mkdir(parents=True, exist_ok=True)

    stacks, report = {}, {"missing": {}, "files": {}}
    for var in config.VARS:
        stack, missing = load_stack(raw_dir, var, years, grid, (legends or {}).get(var))
        if len(missing) == len(years) * 12:
            if verbose:
                print(f"[build] {var}: không có file nào, bỏ qua")
            continue
        stacks[var] = stack
        report["missing"][var] = missing
        if verbose:
            print(f"[build] {var}: {len(years) * 12 - len(missing)} tháng, thiếu {len(missing)}")

    if config.SEA_MASK == "temp" and "temp" in stacks:
        sea = sea_from_temp(stacks["temp"])
    else:
        sea = builtin_sea_mask(grid)
    geo = build_geo(boundaries, merge_map, sea, grid)
    land_flat = geo.land.ravel() == 1
    idx = np.flatnonzero(land_flat)
    n = len(idx)

    def u8(a, none=255):
        a = np.asarray(a)
        out = np.where(a < 0, none, np.clip(a, 0, 254)).astype(np.uint8)
        return b64(out.ravel())

    tg = {
        "version": 1,
        "generated": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "bbox": list(config.BBOX), "res": grid.res, "w": grid.w, "h": grid.h,
        "n_land": int(n),
        "land_order": "row-major, chỉ các ô land == 1",
        "land": b64(geo.land.ravel().astype(np.uint8)),
        "region": u8(geo.region),
        "prov": u8(geo.prov),
        "border": b64(geo.border.ravel().astype(np.uint8)),
        "coast_km": b64(np.clip(np.rint(geo.coast_km), 0, 254).astype(np.uint8).ravel()),
        "regions": config.REGIONS,
        "provinces": geo.prov_names,
        "years": years, "clim_years": clim_years,
        "vars": {},
        "sources": config.sources_list(),
        "dataset_version": dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d%H%M"),
    }
    series = {"years": years, "regions": [], "provinces": []}

    for var, stack in stacks.items():
        V = config.VARS[var]
        land_vals = stack.reshape(len(years), 12, -1)[:, :, idx]          # (Y, 12, n)
        base = land_vals[clim_idx] if clim_idx else land_vals
        clim = nanmean(base, axis=0)                                       # (12, n)
        # Độ lệch chuẩn theo ô và tháng: app dùng để nói "cao/thấp hơn bình thường" (|z| ≥ 1)
        sd = nanstd(base, axis=0)
        sd_max = float(np.nanmax(sd)) if np.isfinite(sd).any() else 1.0
        sd_max = max(sd_max, 1e-6)
        vdir = out_dir / "frames"  # phẳng một thư mục: Flutter chỉ cần khai báo assets/data/frames/
        vdir.mkdir(parents=True, exist_ok=True)
        for yi, y in enumerate(years):
            q = quantize(land_vals[yi], V["min"], V["max"], V["scale"])
            (vdir / f"{var}_{y}.bin").write_bytes(q.tobytes())
        tg["vars"][var] = {
            "name_vi": V["name_vi"], "name_en": V["name_en"], "unit": V["unit"],
            "instrument": V.get("instrument", "danbau"),
            "source": V.get("source", {}).get("type", ""), "credit": V.get("credit", ""),
            "scale": V["scale"], "min": V["min"], "max": V["max"],
            "clim": b64(quantize(clim, V["min"], V["max"], V["scale"])),
            "sd": b64(quantize(sd, 0.0, sd_max, "linear")),
            "sd_max": round(sd_max, 4),
            "sd_layout": "uint8[12][n_land], tuyến tính 0..sd_max; 255 = thiếu",
            "frames": f"frames/{var}_{{year}}.bin",
            "frame_layout": "uint8[12][n_land]; 255 = thiếu dữ liệu",
        }

    for k, R in enumerate(config.REGIONS):
        mask = geo.region == k
        if not mask.any():
            continue
        series["regions"].append({"id": k, "vi": R["vi"], "en": R["en"],
                                  "vars": {v: series_for(s, mask, clim_idx) for v, s in stacks.items()}})
    for p, name in enumerate(geo.prov_names):
        mask = geo.prov == p
        if mask.any():
            series["provinces"].append({"id": p, "name": name,
                                        "vars": {v: series_for(s, mask, clim_idx) for v, s in stacks.items()}})

    tg_path, se_path = out_dir / "touchgrid.json", out_dir / "series.json"
    tg_path.write_text(json.dumps(tg, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    se_path.write_text(json.dumps(series, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    report["files"] = {p.name: p.stat().st_size for p in (tg_path, se_path)}
    report["n_land"] = int(n)
    if verbose:
        for name, size in report["files"].items():
            print(f"[build] {name}: {size / 1024:.0f} KB")
        print(f"[build] {n} ô đất liền; frames trong {out_dir / 'frames'}")
    return report


def parse_years(s: str) -> list[int]:
    a, _, b = s.partition("-")
    return list(range(int(a), int(b or a) + 1))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw", default="data/raw", type=Path)
    ap.add_argument("--out", default="web/data", type=Path)
    ap.add_argument("--years", default=f"{config.YEARS[0]}-{config.YEARS[-1]}")
    ap.add_argument("--clim-years", default=f"{config.CLIM_YEARS[0]}-{config.CLIM_YEARS[-1]}")
    ap.add_argument("--boundaries", type=Path, help="GeoJSON ranh giới tỉnh (ví dụ GADM cấp 1)")
    ap.add_argument("--merge-map", type=Path, help="CSV old_name,new_name để gộp tỉnh theo đơn vị hành chính mới")
    a = ap.parse_args(argv)
    rep = build(a.raw, a.out, parse_years(a.years), parse_years(a.clim_years), a.boundaries, a.merge_map)
    total = sum(rep["files"].values())
    if total > 2 * 1024 * 1024:
        print(f"[build] CẢNH BÁO: tổng JSON {total / 1024:.0f} KB > 2 MB")


if __name__ == "__main__":
    main()
