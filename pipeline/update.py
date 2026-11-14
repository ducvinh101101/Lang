"""MỘT LỆNH: tải dữ liệu thật → chuyển chuẩn → build → kiểm chứng → chép sang app và web.

  python -m pipeline.update                        # mọi biến theo nguồn khai báo trong config.py
  python -m pipeline.update --only temp rain       # chỉ vài biến (vd chưa có FIRMS_MAP_KEY)
  python -m pipeline.update --years 2015-2025      # thử nhanh ít năm trước
  python -m pipeline.update --only rain --inbox mua-imerg   # dùng file NASA gửi trong data/inbox/mua-imerg/
  python -m pipeline.update --skip-fetch           # chỉ build lại từ data/raw đã có

Chạy lại an toàn: phản hồi API được cache trong data/cache/, chỉ tải phần còn thiếu.
Kết quả: app/assets/data/ (đóng gói trong app) và web/data/ (đăng lên web để app tải qua URL).
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np

from . import config
from .build import build, find_raw, parse_years
from .io_neo import read_any
from .sources import fetch_var
from .validate import validate


def sanity(raw: Path, var: str, years: list[int], log=print) -> None:
    """In vài con số để người làm dự án tự nhìn xem có hợp lý không (đơn vị sai thường lộ ra ở đây)."""
    vals = []
    for y in years[-3:]:
        for m in range(1, 13):
            p = find_raw(raw, var, y, m)
            if p is None:
                continue
            a = read_any(p, var).data
            vals.append(np.nanmean(a) if np.isfinite(a).any() else np.nan)
    if not vals:
        return
    v = np.array(vals)
    unit = config.VARS[var]["unit"]
    msg = f"[kiểm tra] {var}: trung bình tháng {np.nanmean(v):.1f} {unit}, thấp nhất {np.nanmin(v):.1f}, cao nhất {np.nanmax(v):.1f}"
    if var == "rain":
        msg += f" → tổng năm ≈ {np.nanmean(v) * 12:.0f} mm (Việt Nam thường 1.200–3.000 mm)"
    if var == "temp":
        msg += " (Việt Nam thường 15–30 °C)"
    log(msg)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="+", default=list(config.VARS), help="các biến cần cập nhật")
    ap.add_argument("--years", default=f"{config.YEARS[0]}-{config.YEARS[-1]}")
    ap.add_argument("--clim-years", default=f"{config.CLIM_YEARS[0]}-{config.CLIM_YEARS[-1]}")
    ap.add_argument("--raw", default="data/raw", type=Path)
    ap.add_argument("--cache", default="data/cache", type=Path)
    ap.add_argument("--inbox", help="dùng thư mục data/inbox/<tên> làm nguồn cho các biến trong --only")
    ap.add_argument("--skip-fetch", action="store_true")
    ap.add_argument("--boundaries", type=Path)
    ap.add_argument("--merge-map", type=Path)
    ap.add_argument("--out", nargs="+", default=["app/assets/data", "web/data"], type=Path,
                    help="nơi chép kết quả (thư mục đầu tiên là nơi build)")
    a = ap.parse_args(argv)
    years = parse_years(a.years)
    clim = [y for y in parse_years(a.clim_years) if y in years] or years

    if not a.skip_fetch:
        for var in a.only:
            if var not in config.VARS:
                ap.error(f"không có biến '{var}' trong config.VARS")
            src = {"type": "inbox", "dir": a.inbox} if a.inbox else None
            print(f"== {var}: nguồn {(src or config.VARS[var]['source'])['type']}")
            rep = fetch_var(var, years, a.raw, a.cache, source=src)
            if rep.get("failed"):
                print(f"   lỗi {len(rep['failed'])}: {', '.join(map(str, rep['failed'][:8]))}")
    for var in config.VARS:
        sanity(a.raw, var, years)

    out0 = Path(a.out[0])
    if out0.exists():
        shutil.rmtree(out0 / "frames", ignore_errors=True)
    rep = build(a.raw, out0, years, clim, a.boundaries, a.merge_map)
    ok = validate(a.raw, out0, samples=3)
    for extra in a.out[1:]:
        extra_p = Path(extra)
        shutil.rmtree(extra_p, ignore_errors=True)
        shutil.copytree(out0, extra_p, ignore=shutil.ignore_patterns("README.txt"))
        print(f"[update] đã chép sang {extra_p}")
    total = sum(rep["files"].values())
    print(f"[update] xong: {total / 1024:.0f} KB JSON + frames; kiểm chứng {'ĐẠT' if ok else 'KHÔNG ĐẠT'}")
    print("[update] Chạy lại app (flutter run) và bật 'Dùng dữ liệu NASA' trong Cài đặt.")


if __name__ == "__main__":
    main()
