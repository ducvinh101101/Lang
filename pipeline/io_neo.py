"""Tải và đọc dữ liệu NEO: CSV toàn cầu, GeoTIFF số thực, ảnh màu (giải mã bảng màu), npz khu vực."""
from __future__ import annotations

import gzip
import io
import time
from pathlib import Path

import numpy as np

from . import config
from .geo import Grid


# ---------- Tải ----------
def fetch_month(var: str, yyyy: int, mm: int, out_dir: Path, template: str | None = None,
                ext: str = "csv", retries: int = 3, session=None, neo_id: str | None = None) -> Path | None:
    """Tải một tháng. Bỏ qua nếu file đã có. Trả về đường dẫn hoặc None nếu thất bại."""
    template = template or config.NEO_URL_TEMPLATE
    if not template:
        raise RuntimeError("Chưa đặt NEO_URL_TEMPLATE trong pipeline/config.py (xem hướng dẫn trong file).")
    import requests

    session = session or requests.Session()
    out = Path(out_dir) / f"{config.RAW_PATTERN.format(var=var, yyyy=yyyy, mm=mm)}.{ext}"
    if out.exists() and out.stat().st_size > 0:
        return out
    out.parent.mkdir(parents=True, exist_ok=True)
    V = config.VARS[var]
    neo_id = neo_id or V.get("source", {}).get("neo_id") or V.get("neo_id")
    if not neo_id:
        raise RuntimeError(f"{var}: chưa khai báo neo_id trong config.VARS['{var}']['source']")
    url = template.format(neo_id=neo_id, yyyy=yyyy, mm=f"{mm:02d}", ext=ext)
    for attempt in range(1, retries + 1):
        try:
            r = session.get(url, timeout=120)
            r.raise_for_status()
            data = r.content
            if url.endswith(".gz") or data[:2] == b"\x1f\x8b":
                data = gzip.decompress(data)
            out.write_bytes(data)
            return out
        except Exception as e:  # noqa: BLE001 — ghi log rồi thử lại
            print(f"[fetch] {var} {yyyy}-{mm:02d} lần {attempt}: {e}")
            time.sleep(2 * attempt)
    return None


# ---------- Đọc ----------
class Raster:
    """Mảng 2D kèm thông tin địa lý (góc trên trái và độ phân giải)."""

    def __init__(self, data: np.ndarray, lon0: float, lat1: float, res: float):
        self.data, self.lon0, self.lat1, self.res = data, lon0, lat1, res


def global_raster(data: np.ndarray) -> Raster:
    """NEO toàn cầu: hàng từ 90°N xuống -90°, cột từ -180° sang 180°."""
    h, w = data.shape
    res = 360.0 / w
    if abs(180.0 / h - res) > 1e-6:
        raise ValueError(f"Lưới không phải toàn cầu đều: {w}x{h}")
    return Raster(data, -180.0, 90.0, res)


def clean(data: np.ndarray, var: str) -> np.ndarray:
    data = data.astype("float32")
    for nd in config.VARS[var]["nodata"]:
        data[np.isclose(data, nd)] = np.nan
    return data


def read_csv(path: Path, var: str) -> Raster:
    data = np.loadtxt(path, delimiter=",", dtype="float32")
    return global_raster(clean(data, var))


def read_tif(path: Path, var: str) -> Raster:
    try:
        import tifffile  # type: ignore
        data = tifffile.imread(path)
    except ImportError:
        from PIL import Image
        data = np.array(Image.open(path))
    if data.ndim == 3:
        raise ValueError(f"{path}: GeoTIFF nhiều kênh, cần bản số thực một kênh")
    return global_raster(clean(data, var))


def read_npz(path: Path, var: str) -> Raster:
    """Định dạng nội bộ (dùng cho dữ liệu giả lập hoặc cache): data, lon0, lat1, res."""
    z = np.load(path)
    return Raster(clean(z["data"], var), float(z["lon0"]), float(z["lat1"]), float(z["res"]))


# ---------- Giải mã ảnh màu ----------
def srgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    c = rgb.astype("float64") / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > (6 / 29) ** 3, np.cbrt(xyz), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def decode_palette(rgb: np.ndarray, legend_rgb: np.ndarray, legend_values: np.ndarray, max_de: float = 12.0) -> np.ndarray:
    """Màu → giá trị bằng màu gần nhất trong không gian Lab. Màu xa bảng màu (biển, chữ) thành NaN."""
    lab = srgb_to_lab(rgb.reshape(-1, 3))
    leg = srgb_to_lab(np.asarray(legend_rgb).reshape(-1, 3))
    out = np.empty(len(lab), dtype="float32")
    for s in range(0, len(lab), 200_000):  # chia khối để không tốn bộ nhớ
        d = np.linalg.norm(lab[s:s + 200_000, None, :] - leg[None, :, :], axis=-1)
        k = d.argmin(axis=1)
        v = np.asarray(legend_values, dtype="float32")[k]
        v[d[np.arange(len(k)), k] > max_de] = np.nan
        out[s:s + 200_000] = v
    return out.reshape(rgb.shape[:2])


def read_png(path: Path, var: str, legend_rgb, legend_values) -> Raster:
    from PIL import Image
    rgb = np.array(Image.open(path).convert("RGB"))
    return global_raster(decode_palette(rgb, np.asarray(legend_rgb), np.asarray(legend_values)))


def read_any(path: Path, var: str, legend=None) -> Raster:
    ext = Path(path).suffix.lower()
    if ext == ".csv":
        return read_csv(path, var)
    if ext in (".tif", ".tiff"):
        return read_tif(path, var)
    if ext == ".npz":
        return read_npz(path, var)
    if ext == ".png":
        if legend is None:
            raise ValueError("Ảnh PNG cần bảng màu (legend) để giải mã")
        return read_png(path, var, *legend)
    raise ValueError(f"Định dạng không hỗ trợ: {path}")


# ---------- Đưa về lưới 0,1° ----------
def regrid(r: Raster, grid: Grid, sub: int | None = None) -> np.ndarray:
    """Lấy mẫu k×k điểm trong mỗi ô đích rồi lấy trung bình bỏ NaN.
    Dùng được cho cả nguồn mịn hơn (trung bình khối) và thô hơn (lặp giá trị)."""
    k = sub or max(1, int(np.ceil(grid.res / r.res - 1e-9)))
    offs = (np.arange(k) + 0.5) / k
    lon = grid.lon0 + (np.arange(grid.w)[:, None] + offs[None, :]).ravel() * grid.res
    lat = grid.lat1 - (np.arange(grid.h)[:, None] + offs[None, :]).ravel() * grid.res
    ci = np.floor((lon - r.lon0) / r.res).astype(int)
    ri = np.floor((r.lat1 - lat) / r.res).astype(int)
    H, W = r.data.shape
    ok_c = (ci >= 0) & (ci < W)
    ok_r = (ri >= 0) & (ri < H)
    sample = np.full((len(ri), len(ci)), np.nan, dtype="float32")
    sample[np.ix_(ok_r, ok_c)] = r.data[np.ix_(ri[ok_r], ci[ok_c])]
    sample = sample.reshape(grid.h, k, grid.w, k)
    with np.errstate(all="ignore"):
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", RuntimeWarning)
            return np.nanmean(sample, axis=(1, 3)).astype("float32")


def convert_units(a: np.ndarray, var: str, yyyy: int, mm: int) -> np.ndarray:
    conv = config.VARS[var].get("convert")
    if conv == "mm_per_hr_to_month":
        import calendar
        return a * 24 * calendar.monthrange(yyyy, mm)[1]
    return a
