"""Hộp thư dữ liệu: nhận file NASA gửi hoặc tải tay, không cần viết code mới.

Cách dùng:
  1. Tạo thư mục data/inbox/<tên>/ và chép file vào (NetCDF .nc/.nc4, HDF5 .h5/.HDF5, GeoTIFF .tif, CSV).
  2. Tạo data/inbox/<tên>/source.json mô tả file (xem các ví dụ trong docs/DATA_SOURCES.md).
  3. Trong pipeline/config.py đặt VARS["<biến>"]["source"] = {"type": "inbox", "dir": "<tên>"}
     (hoặc chạy: python -m pipeline.update --only <biến> --inbox <tên>)

Các khoá trong source.json:
  format       netcdf | hdf5 | geotiff | csv_points | csv_grid
  files        mẫu tên file, ví dụ "*.nc4"
  variable     tên biến trong file NetCDF/HDF5 (vd "precipitation", "T2M", "LST_Day_CMG")
  lon, lat     tên toạ độ (mặc định tự dò: lon/longitude/x, lat/latitude/y)
  time         "dim" (lấy từ chiều thời gian trong file) | "filename" (lấy từ tên file bằng date_regex)
  date_regex   regex có 2 nhóm (năm, tháng), mặc định "(\\d{4})[-_]?(\\d{2})"
  units        đơn vị gốc (vd "mm/hr", "K", "kg m-2 s-1") — để tự đổi về đơn vị của biến
  scale, offset  áp dụng: giá trị = gốc * scale + offset (trước khi đổi đơn vị)
  fill_values  danh sách giá trị thiếu
  aggregate    với csv_points: "count" | "sum" | "mean" (mặc định count)
  columns      với csv_points: {"lat": "...", "lon": "...", "date": "...", "value": "..."}
  bbox         với geotiff/csv_grid không có toạ độ: [lon_min, lat_min, lon_max, lat_max] (mặc định toàn cầu)
"""
from __future__ import annotations

import csv
import io
import json
import re
from collections import defaultdict
from pathlib import Path

import numpy as np

from .. import config
from ..canonical import resample_to_grid, save_month, to_target_units

INBOX = Path("data/inbox")
_LON = ("lon", "longitude", "x", "Longitude", "LON")
_LAT = ("lat", "latitude", "y", "Latitude", "LAT")


def load_spec(dirname: str, inbox: Path = INBOX) -> tuple[Path, dict]:
    d = Path(inbox) / dirname
    f = d / "source.json"
    if not f.exists():
        raise FileNotFoundError(f"Thiếu {f}. Xem hướng dẫn trong docs/DATA_SOURCES.md")
    return d, json.loads(f.read_text(encoding="utf-8"))


def _ym_from_name(name: str, regex: str) -> tuple[int, int] | None:
    m = re.search(regex, name)
    if not m:
        return None
    y, mo = int(m.group(1)), int(m.group(2))
    return (y, mo) if 1 <= mo <= 12 else None


def _clean(a: np.ndarray, spec: dict) -> np.ndarray:
    a = np.asarray(a, dtype="float64")
    for fv in spec.get("fill_values", []):
        a[np.isclose(a, fv)] = np.nan
    return a * float(spec.get("scale", 1.0)) + float(spec.get("offset", 0.0))


def _rectilinear(lon1d, lat1d, data2d, lon_first: bool):
    """Toạ độ 1D + dữ liệu 2D → điểm phẳng (lon, lat, value), cắt quanh BBOX cho nhẹ."""
    lon1d = np.asarray(lon1d, dtype="float64")
    lat1d = np.asarray(lat1d, dtype="float64")
    lon1d = np.where(lon1d > 180, lon1d - 360, lon1d)  # 0..360 → -180..180
    data2d = np.asarray(data2d)
    if lon_first:
        data2d = data2d.T
    lo0, la0, lo1, la1 = config.BBOX
    mx = 1.0
    ci = np.where((lon1d >= lo0 - mx) & (lon1d <= lo1 + mx))[0]
    ri = np.where((lat1d >= la0 - mx) & (lat1d <= la1 + mx))[0]
    sub = data2d[np.ix_(ri, ci)]
    LON, LAT = np.meshgrid(lon1d[ci], lat1d[ri])
    return LON, LAT, sub


# ---------- NetCDF / HDF5 (qua xarray) ----------
def _iter_xarray(files, spec):
    try:
        import xarray as xr  # type: ignore
    except ImportError as e:
        raise ImportError("Đọc NetCDF/HDF5 cần: pip install xarray netCDF4 h5netcdf") from e
    regex = spec.get("date_regex", r"(\d{4})[-_]?(\d{2})")
    for f in files:
        kw = {"engine": "h5netcdf", "phony_dims": "sort"} if spec.get("format") == "hdf5" else {}
        if spec.get("group"):
            kw["group"] = spec["group"]
        ds = xr.open_dataset(f, **kw)
        da = ds[spec["variable"]]
        lon_name = spec.get("lon") or next((n for n in _LON if n in da.coords or n in ds), None)
        lat_name = spec.get("lat") or next((n for n in _LAT if n in da.coords or n in ds), None)
        if lon_name is None or lat_name is None:
            raise ValueError(f"{f.name}: không tìm thấy toạ độ lon/lat, hãy khai báo 'lon','lat' trong source.json")
        lon = ds[lon_name].values
        lat = ds[lat_name].values
        if spec.get("time", "dim") == "dim" and "time" in da.dims:
            for t in da["time"].values:
                ts = np.datetime64(t, "M").astype(object)
                frame = da.sel(time=t).squeeze()
                lon_first = frame.dims.index(lon_name) < frame.dims.index(lat_name) if lon_name in frame.dims else False
                yield (ts.year, ts.month), _rectilinear(lon, lat, frame.values, lon_first)
        else:
            ym = _ym_from_name(f.name, regex)
            if ym is None:
                print(f"[inbox] bỏ qua {f.name}: không đọc được năm-tháng từ tên (date_regex)")
                continue
            frame = da.squeeze()
            lon_first = frame.dims.index(lon_name) < frame.dims.index(lat_name) if lon_name in frame.dims else False
            yield ym, _rectilinear(lon, lat, frame.values, lon_first)
        ds.close()


# ---------- GeoTIFF / lưới CSV toàn cầu ----------
def _grid_coords(shape, bbox):
    h, w = shape
    lo0, la0, lo1, la1 = bbox
    lon = lo0 + (np.arange(w) + 0.5) * (lo1 - lo0) / w
    lat = la1 - (np.arange(h) + 0.5) * (la1 - la0) / h
    return lon, lat


def _iter_grid_files(files, spec):
    regex = spec.get("date_regex", r"(\d{4})[-_]?(\d{2})")
    for f in files:
        ym = _ym_from_name(f.name, regex)
        if ym is None:
            print(f"[inbox] bỏ qua {f.name}: không đọc được năm-tháng từ tên (date_regex)")
            continue
        bbox = spec.get("bbox", [-180, -90, 180, 90])
        if spec["format"] == "geotiff":
            data, gt_bbox = _read_tif(f)
            bbox = spec.get("bbox") or gt_bbox or bbox
        else:
            data = np.loadtxt(f, delimiter=",", dtype="float64")
        lon, lat = _grid_coords(data.shape, bbox)
        yield ym, _rectilinear(lon, lat, data, False)


def _read_tif(path: Path):
    """Đọc GeoTIFF một kênh; lấy khung toạ độ từ thẻ GeoTIFF nếu có."""
    try:
        import tifffile  # type: ignore
    except ImportError as e:
        raise ImportError("Đọc GeoTIFF cần: pip install tifffile") from e
    with tifffile.TiffFile(path) as tif:
        data = tif.asarray().astype("float64")
        bbox = None
        try:
            tags = tif.pages[0].tags
            scale = tags["ModelPixelScaleTag"].value
            tie = tags["ModelTiepointTag"].value
            h, w = data.shape[:2]
            lon0, lat1 = tie[3], tie[4]
            bbox = [lon0, lat1 - scale[1] * h, lon0 + scale[0] * w, lat1]
        except Exception:  # noqa: BLE001
            pass
    if data.ndim == 3:
        data = data[..., 0]
    return data, bbox


# ---------- CSV dạng điểm (vd xuất từ FIRMS, trạm đo) ----------
def _iter_points(files, spec):
    cols = {"lat": "latitude", "lon": "longitude", "date": "acq_date", "value": None, **spec.get("columns", {})}
    agg = spec.get("aggregate", "count")
    buckets: dict = defaultdict(list)
    for f in files:
        for r in csv.DictReader(io.StringIO(Path(f).read_text(encoding="utf-8-sig"))):
            try:
                lat, lon = float(r[cols["lat"]]), float(r[cols["lon"]])
                y, m = int(r[cols["date"]][:4]), int(r[cols["date"]][5:7])
                v = float(r[cols["value"]]) if cols["value"] else 1.0
            except (KeyError, ValueError, TypeError):
                continue
            buckets[(y, m)].append((lon, lat, v))
    from ..geo import Grid
    grid = Grid.from_bbox()
    for ym, pts in sorted(buckets.items()):
        a = np.array(pts)
        sums = np.zeros((grid.h, grid.w))
        cnt = np.zeros((grid.h, grid.w))
        c = np.floor((a[:, 0] - grid.lon0) / grid.res).astype(int)
        r = np.floor((grid.lat1 - a[:, 1]) / grid.res).astype(int)
        ok = (c >= 0) & (c < grid.w) & (r >= 0) & (r < grid.h)
        np.add.at(sums, (r[ok], c[ok]), a[ok, 2])
        np.add.at(cnt, (r[ok], c[ok]), 1)
        if agg == "mean":
            out = np.where(cnt > 0, sums / np.maximum(cnt, 1), np.nan)
        elif agg == "sum":
            out = sums
        else:
            out = cnt
        yield ym, ("grid", out)


def fetch(var: str, spec: dict, years: list[int], raw_root: Path, cache_root: Path, session=None, log=print,
          inbox: Path = INBOX) -> dict:
    d, fs = load_spec(spec["dir"], inbox)
    fs = {**fs, **{k: v for k, v in spec.items() if k not in ("type", "dir")}}
    files = sorted(d.glob(fs.get("files", "*")))
    files = [f for f in files if f.name != "source.json"]
    if not files:
        log(f"[inbox] {d}: không có file nào khớp '{fs.get('files', '*')}'")
        return {"months": 0, "failed": []}
    fmt = fs.get("format", "netcdf")
    it = {"netcdf": _iter_xarray, "hdf5": _iter_xarray, "geotiff": _iter_grid_files,
          "csv_grid": _iter_grid_files, "csv_points": _iter_points}.get(fmt)
    if it is None:
        raise ValueError(f"format '{fmt}' chưa hỗ trợ (netcdf, hdf5, geotiff, csv_grid, csv_points)")
    target = config.VARS[var]["unit"]
    written = 0
    for (y, m), payload in it(files, fs):
        if y not in years:
            continue
        if isinstance(payload[0], str) and payload[0] == "grid":
            grid_vals = payload[1].astype("float32")
        else:
            lon, lat, vals = payload
            grid_vals = resample_to_grid(lon, lat, _clean(vals, fs))
        grid_vals = to_target_units(grid_vals, fs.get("units", ""), target, y, m)
        save_month(raw_root, var, y, m, grid_vals, units=target, source=f"inbox/{spec['dir']}")
        written += 1
    log(f"[inbox] {var} ← {d} ({fmt}, {len(files)} file): {written} tháng")
    return {"months": written, "failed": []}
