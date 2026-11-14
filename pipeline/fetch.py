"""Tải dữ liệu tháng từ NASA NEO về data/raw/<var>/<YYYY>-<MM>.<ext>.

Chạy:  python -m pipeline.fetch --vars rain temp fire --years 2001-2025 --ext csv
Yêu cầu: đã điền NEO_URL_TEMPLATE trong pipeline/config.py (xem hướng dẫn trong file đó).
File đã có sẽ được bỏ qua, nên chạy lại sau khi lỗi mạng là an toàn.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from . import config
from .io_neo import fetch_month


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--vars", nargs="+", default=list(config.VARS))
    ap.add_argument("--years", default=f"{config.YEARS[0]}-{config.YEARS[-1]}")
    ap.add_argument("--ext", default="csv", choices=["csv", "tif", "png"])
    ap.add_argument("--out", default="data/raw", type=Path)
    a = ap.parse_args(argv)
    s, _, e = a.years.partition("-")
    years = range(int(s), int(e or s) + 1)
    import requests
    sess = requests.Session()
    failed = []
    for var in a.vars:
        for y in years:
            for m in range(1, 13):
                if fetch_month(var, y, m, a.out, ext=a.ext, session=sess) is None:
                    failed.append(f"{var} {y}-{m:02d}")
    print(f"[fetch] xong; lỗi {len(failed)} tháng" + (": " + ", ".join(failed[:20]) if failed else ""))


if __name__ == "__main__":
    main()
