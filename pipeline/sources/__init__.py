"""Bộ chuyển đổi nguồn dữ liệu → định dạng chuẩn data/raw/<biến>/<YYYY>-<MM>.npz.

Thêm nguồn mới: viết module có hàm fetch(var, spec, years, raw_root, cache_root, session=None, log=print) -> dict
rồi đăng ký vào ADAPTERS. Không cần sửa build.py hay app.
"""
from __future__ import annotations

from pathlib import Path

from .. import config


def _neo(var, spec, years, raw_root, cache_root, session=None, log=print):
    """NEO: tải CSV/GeoTIFF toàn cầu theo NEO_URL_TEMPLATE; build đọc trực tiếp (không cần chuyển npz)."""
    from ..io_neo import fetch_month
    ext = spec.get("ext", "csv")
    n, failed = 0, []
    for y in years:
        for m in range(1, 13):
            p = fetch_month(var, y, m, raw_root, ext=ext, session=session, neo_id=spec.get("neo_id"))
            if p is None:
                failed.append(f"{y}-{m:02d}")
            else:
                n += 1
    log(f"[neo] {var}: {n} tháng, lỗi {len(failed)}")
    return {"months": n, "failed": failed}


def _power(*a, **k):
    from .power import fetch
    return fetch(*a, **k)


def _firms(*a, **k):
    from .firms import fetch
    return fetch(*a, **k)


def _inbox(*a, **k):
    from .inbox import fetch
    return fetch(*a, **k)


def _synthetic(var, spec, years, raw_root, cache_root, session=None, log=print):
    from ..synthetic import make
    make(Path(raw_root), years)
    return {"months": len(years) * 12, "failed": []}


ADAPTERS = {"power": _power, "firms": _firms, "neo": _neo, "inbox": _inbox, "synthetic": _synthetic}


def fetch_var(var: str, years: list[int], raw_root: Path, cache_root: Path, session=None, log=print,
              source: dict | None = None) -> dict:
    spec = source or config.VARS[var]["source"]
    kind = spec.get("type")
    if kind not in ADAPTERS:
        raise ValueError(f"{var}: nguồn '{kind}' không có. Có: {', '.join(ADAPTERS)}")
    return ADAPTERS[kind](var, spec, years, Path(raw_root), Path(cache_root), session=session, log=log)
