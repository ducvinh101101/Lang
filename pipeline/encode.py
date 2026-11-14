"""Lượng tử hóa giá trị về uint8 để file JSON cho web nhỏ gọn (< 2 MB)."""
from __future__ import annotations

import base64

import numpy as np

NODATA = 255  # 0..254 là giá trị, 255 là thiếu dữ liệu


def _fwd(x, scale):
    return np.sqrt(np.maximum(x, 0)) if scale == "sqrt" else x


def _inv(x, scale):
    return x ** 2 if scale == "sqrt" else x


def quantize(values: np.ndarray, vmin: float, vmax: float, scale: str = "linear") -> np.ndarray:
    lo, hi = _fwd(np.float64(vmin), scale), _fwd(np.float64(vmax), scale)
    t = (_fwd(values.astype("float64"), scale) - lo) / (hi - lo)
    q = np.clip(np.rint(t * 254), 0, 254)
    q[~np.isfinite(values)] = NODATA
    return q.astype(np.uint8)


def dequantize(q: np.ndarray, vmin: float, vmax: float, scale: str = "linear") -> np.ndarray:
    lo, hi = _fwd(np.float64(vmin), scale), _fwd(np.float64(vmax), scale)
    v = _inv(lo + (q.astype("float64") / 254) * (hi - lo), scale)
    v[q == NODATA] = np.nan
    return v


def max_error(vmin: float, vmax: float, scale: str = "linear", at: float | None = None) -> float:
    """Sai số lượng tử tối đa (nửa bước). Với thang sqrt sai số phụ thuộc giá trị, truyền `at`."""
    lo, hi = _fwd(np.float64(vmin), scale), _fwd(np.float64(vmax), scale)
    half = (hi - lo) / 254 / 2
    if scale == "sqrt":
        s = _fwd(np.float64(at if at is not None else vmax), scale)
        return float((s + half) ** 2 - s ** 2)
    return float(half)


def b64(a: np.ndarray) -> str:
    return base64.b64encode(np.ascontiguousarray(a).tobytes()).decode("ascii")


def unb64(s: str, dtype=np.uint8) -> np.ndarray:
    return np.frombuffer(base64.b64decode(s), dtype=dtype)
