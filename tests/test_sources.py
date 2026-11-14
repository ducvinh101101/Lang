"""Test các nguồn dữ liệu bằng phản hồi giả có cùng cấu trúc với API thật (không cần mạng)."""
import json

import numpy as np
import pytest

from pipeline import config
from pipeline.build import build
from pipeline.canonical import resample_to_grid, to_target_units
from pipeline.geo import Grid, builtin_sea_mask
from pipeline.io_neo import read_npz
from pipeline.sources import fetch_var
from pipeline.sources import firms, inbox, power
from pipeline.validate import validate

GRID = Grid.from_bbox()


class FakeResp:
    def __init__(self, text, status=200):
        self.text, self.status_code = text, status

    def raise_for_status(self):
        if self.status_code >= 400:
            err = RuntimeError(f"HTTP {self.status_code}")
            err.response = self
            raise err


class FakeSession:
    def __init__(self, handler):
        self.handler, self.urls = handler, []

    def get(self, url, timeout=None):
        self.urls.append(url)
        return self.handler(url)


def _power_json(param, lon_range, lat_range, years, value_fn, units):
    """Phản hồi POWER regional dạng GeoJSON, lưới 0,5° × 0,625°."""
    feats = []
    for lat in np.arange(lat_range[0] + 0.25, lat_range[1], 0.5):
        for lon in np.arange(lon_range[0] + 0.3125, lon_range[1], 0.625):
            vals = {}
            for y in years:
                for m in range(1, 13):
                    vals[f"{y}{m:02d}"] = round(value_fn(lon, lat, y, m), 3)
                vals[f"{y}13"] = 0.0  # trung bình năm, phải bị bỏ qua
            feats.append({"type": "Feature", "geometry": {"type": "Point", "coordinates": [lon, lat, 10.0]},
                          "properties": {"parameter": {param: vals}}})
    return json.dumps({"type": "FeatureCollection", "header": {"fill_value": -999.0},
                       "parameters": {param: {"units": units, "longname": param}}, "features": feats})


def _qs(url):
    from urllib.parse import parse_qs, urlparse
    return {k: v[0] for k, v in parse_qs(urlparse(url).query).items()}


def test_power_tiles_cover_bbox():
    t = power.tiles(config.BBOX, 5.0)
    assert len(t) == 2 * 4
    assert min(x[0] for x in t) == 102.0 and max(x[2] for x in t) == 112.0
    assert all(x[2] - x[0] <= 5.0 + 1e-9 and x[3] - x[1] <= 5.0 + 1e-9 for x in t)


def test_power_fetch_converts_and_regrids(tmp_path):
    years = [2019, 2020]

    def handler(url):
        q = _qs(url)
        param = q["parameters"]
        lo = (float(q["longitude-min"]), float(q["longitude-max"]))
        la = (float(q["latitude-min"]), float(q["latitude-max"]))
        ys = list(range(int(q["start"]), int(q["end"]) + 1))
        if param == "T2M":
            return FakeResp(_power_json(param, lo, la, ys, lambda x, y, yy, m: 30 - 0.5 * (y - 8), "C"))
        return FakeResp(_power_json(param, lo, la, ys, lambda x, y, yy, m: 10.0 if m == 10 else 2.0, "mm/day"))

    s = FakeSession(handler)
    raw, cache = tmp_path / "raw", tmp_path / "cache"
    r1 = fetch_var("temp", years, raw, cache, session=s)
    r2 = fetch_var("rain", years, raw, cache, session=s)
    assert r1["months"] == 24 and r2["months"] == 24
    t = read_npz(raw / "temp" / "2020-01.npz", "temp").data
    hanoi = (int((23.6 - 21.03) / 0.1), int((105.85 - 102) / 0.1))
    assert abs(t[hanoi] - (30 - 0.5 * (21.03 - 8))) < 0.6     # lấy đúng điểm gần nhất
    assert np.isfinite(t).mean() > 0.95                        # lưới thô phủ kín lưới 0,1°
    rain_oct = read_npz(raw / "rain" / "2020-10.npz", "rain").data
    assert np.nanmedian(rain_oct) == pytest.approx(310.0)     # 10 mm/ngày × 31 ngày
    n_before = len(s.urls)
    fetch_var("rain", years, raw, cache, session=s)            # chạy lại: dùng cache, không tải
    assert len(s.urls) == n_before
    # build + validate trên dữ liệu POWER giả
    out = tmp_path / "web"
    build(raw, out, years=years, clim_years=years, verbose=False)
    tg = json.loads((out / "touchgrid.json").read_text(encoding="utf-8"))
    assert tg["vars"]["temp"]["instrument"] == "danbau" and tg["vars"]["rain"]["source"] == "power"
    assert (out / "frames" / "rain_2020.bin").exists()
    assert validate(raw, out, samples=2, verbose=False)


def test_power_splits_years_on_422(tmp_path):
    def handler(url):
        q = _qs(url)
        if q["start"] != q["end"]:
            return FakeResp('{"messages":["range too large"]}', 422)
        lo = (float(q["longitude-min"]), float(q["longitude-max"]))
        la = (float(q["latitude-min"]), float(q["latitude-max"]))
        return FakeResp(_power_json("T2M", lo, la, [int(q["start"])], lambda *a: 25.0, "C"))

    rep = fetch_var("temp", [2019, 2020], tmp_path / "raw", tmp_path / "c", session=FakeSession(handler), log=lambda *_: None)
    assert rep["months"] == 24 and not rep["failed"]


def test_firms_counts_per_cell_and_month(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "FIRMS_MAP_KEY", "TESTKEY")
    header = "latitude,longitude,brightness,scan,track,acq_date,acq_time,satellite,instrument,confidence,version,bright_t31,frp,daynight,type\n"

    def handler(url):
        start = url.rstrip("/").split("/")[-1]
        if start.startswith("2020-03-01"):
            rows = ["21.35,103.95,320,1,1,2020-03-02,0330,T,MODIS,80,6.1NRT,290,10,D,0"] * 1 + \
                   ["21.36,103.96,320,1,1,2020-03-05,0330,A,MODIS,90,6.1NRT,290,10,D,0",
                    "21.36,103.96,320,1,1,2020-03-05,0330,A,MODIS,10,6.1NRT,290,10,D,0",  # độ tin cậy thấp: bỏ
                    "21.36,103.96,320,1,1,2020-02-28,0330,A,MODIS,90,6.1NRT,290,10,D,0"]  # khác tháng: bỏ
            return FakeResp(header + "\n".join(rows))
        return FakeResp(header)

    s = FakeSession(handler)
    rep = fetch_var("fire", [2020], tmp_path / "raw", tmp_path / "c", session=s, log=lambda *_: None)
    assert rep["months"] == 12
    assert any("/TESTKEY/MODIS_SP/102.0,8.3,112.0,23.6/10/2020-03-01" in u for u in s.urls)
    a = read_npz(tmp_path / "raw" / "fire" / "2020-03.npz", "fire").data
    cell = (int((23.6 - 21.355) / 0.1), int((103.955 - 102) / 0.1))
    assert a.sum() == 2 and a[cell] == 2
    assert firms.month_windows(2020, 1)[-1] == (__import__("datetime").date(2020, 1, 21), 10) or \
        sum(d for _, d in firms.month_windows(2020, 1)) == 31


def test_firms_without_key_is_skipped(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "FIRMS_MAP_KEY", "")
    rep = fetch_var("fire", [2020], tmp_path / "raw", tmp_path / "c", log=lambda *_: None)
    assert rep.get("skipped") == "no_key"


def test_inbox_netcdf_with_time_dim(tmp_path):
    xr = pytest.importorskip("xarray")
    pytest.importorskip("netCDF4")
    lon = np.arange(100.05, 114, 0.1)
    lat = np.arange(25.95, 6, -0.1)
    times = np.array(["2020-09-01", "2020-10-01"], dtype="datetime64[ns]")
    data = np.stack([np.full((len(lat), len(lon)), 5.0), np.full((len(lat), len(lon)), 20.0)])  # mm/hr? dùng mm/day
    ds = xr.Dataset({"precip": (("time", "lat", "lon"), data)}, coords={"time": times, "lat": lat, "lon": lon})
    d = tmp_path / "inbox" / "nasa-gui"
    d.mkdir(parents=True)
    ds.to_netcdf(d / "precip_2020.nc")
    (d / "source.json").write_text(json.dumps({"format": "netcdf", "files": "*.nc", "variable": "precip",
                                               "time": "dim", "units": "mm/day"}), encoding="utf-8")
    rep = inbox.fetch("rain", {"type": "inbox", "dir": "nasa-gui"}, [2020], tmp_path / "raw", tmp_path / "c",
                      log=lambda *_: None, inbox=tmp_path / "inbox")
    assert rep["months"] == 2
    oct_ = read_npz(tmp_path / "raw" / "rain" / "2020-10.npz", "rain").data
    assert np.nanmean(oct_) == pytest.approx(20.0 * 31)


def test_inbox_hdf5_lon_first_filename_date(tmp_path):
    xr = pytest.importorskip("xarray")
    pytest.importorskip("h5netcdf")
    pytest.importorskip("h5py")
    # Kiểu IMERG: chiều (lon, lat), ngày tháng nằm trong tên file
    lon = np.arange(101.05, 113, 0.1)
    lat = np.arange(7.05, 25, 0.1)
    LON, LAT = np.meshgrid(lon, lat, indexing="ij")
    ds = xr.Dataset({"precipitation": (("lon", "lat"), (LAT > 16).astype(float))}, coords={"lon": lon, "lat": lat})
    d = tmp_path / "inbox" / "imerg"
    d.mkdir(parents=True)
    ds.to_netcdf(d / "3B-MO.MS.MRG.3IMERG.20201001-S000000-E235959.10.V07B.HDF5", engine="h5netcdf")
    (d / "source.json").write_text(json.dumps({
        "format": "hdf5", "files": "*.HDF5", "variable": "precipitation", "time": "filename",
        "date_regex": r"3IMERG\.(\d{4})(\d{2})\d{2}", "units": "mm/hr"}), encoding="utf-8")
    rep = inbox.fetch("rain", {"type": "inbox", "dir": "imerg"}, [2020], tmp_path / "raw", tmp_path / "c",
                      log=lambda *_: None, inbox=tmp_path / "inbox")
    assert rep["months"] == 1
    a = read_npz(tmp_path / "raw" / "rain" / "2020-10.npz", "rain").data
    hue = (int((23.6 - 16.46) / 0.1), int((107.59 - 102) / 0.1))
    hcm = (int((23.6 - 10.78) / 0.1), int((106.66 - 102) / 0.1))
    assert a[hue] == pytest.approx(24 * 31) and a[hcm] == 0   # đúng hướng trục (không bị xoay)


def test_inbox_csv_points(tmp_path):
    d = tmp_path / "inbox" / "tram"
    d.mkdir(parents=True)
    (d / "a.csv").write_text("lat,lon,ngay,mua\n21.03,105.85,2020-07-03,100\n21.03,105.85,2020-07-20,50\n",
                             encoding="utf-8")
    (d / "source.json").write_text(json.dumps({"format": "csv_points", "files": "*.csv", "aggregate": "sum",
                                               "columns": {"lat": "lat", "lon": "lon", "date": "ngay",
                                                           "value": "mua"}}), encoding="utf-8")
    rep = inbox.fetch("rain", {"type": "inbox", "dir": "tram"}, [2020], tmp_path / "raw", tmp_path / "c",
                      log=lambda *_: None, inbox=tmp_path / "inbox")
    a = read_npz(tmp_path / "raw" / "rain" / "2020-07.npz", "rain").data
    assert rep["months"] == 1 and np.nansum(a) == 150


def test_resample_finer_source_is_block_mean():
    lon = np.arange(102.025, 112, 0.05)
    lat = np.arange(23.575, 8.3, -0.05)
    LON, LAT = np.meshgrid(lon, lat)
    out = resample_to_grid(LON, LAT, LON)
    X, _ = GRID.centers()
    assert np.nanmax(np.abs(out - X)) < 1e-4


def test_units():
    a = np.array([1.0])
    assert to_target_units(a, "mm/day", "mm/tháng", 2020, 2)[0] == 29
    assert to_target_units(a, "mm/hr", "mm/tháng", 2021, 2)[0] == 24 * 28
    assert to_target_units(np.array([300.0]), "K", "°C", 2020, 1)[0] == pytest.approx(26.85)
    assert to_target_units(a, "C", "°C", 2020, 1)[0] == 1


def test_builtin_sea_mask():
    sea = builtin_sea_mask(GRID)
    at = lambda lon, lat: sea[int((23.6 - lat) / 0.1), int((lon - 102) / 0.1)]
    assert at(111.5, 16.5)          # Hoàng Sa: biển
    assert at(109.5, 12.0)          # ngoài khơi Nha Trang: biển
    assert not at(105.85, 21.03)    # Hà Nội: đất
    assert not at(106.0, 23.0)      # Trung Quốc: không phải biển
    assert not at(102.5, 18.0)      # Lào: không phải biển
    assert not at(109.8, 19.0)      # đảo Hải Nam
