import base64
import json

import numpy as np
import pytest

from pipeline import config
from pipeline.build import build
from pipeline.encode import dequantize, max_error, quantize
from pipeline.geo import Grid, borders, build_geo, coast_distance_km, region_of
from pipeline.io_neo import Raster, decode_palette, global_raster, regrid
from pipeline.synthetic import make
from pipeline.validate import validate


def test_regrid_block_mean_from_finer_source():
    grid = Grid.from_bbox((102, 8.3, 112, 23.6), 0.1)
    src = np.zeros((grid.h * 2, grid.w * 2), dtype="float32")
    src[0::2, 0::2], src[0::2, 1::2], src[1::2, 0::2], src[1::2, 1::2] = 1, 2, 3, 6
    out = regrid(Raster(src, 102, 23.6, 0.05), grid)
    assert out.shape == (grid.h, grid.w)
    assert np.allclose(out, 3.0)


def test_regrid_repeats_coarser_source_and_ignores_nan():
    grid = Grid.from_bbox((102, 8.3, 112, 23.6), 0.1)
    src = np.arange(16, dtype="float32").reshape(4, 4)
    src[0, 0] = np.nan
    r = Raster(src, 100, 30, 5.0)                       # ô 5°: 100–120°E, 10–30°N
    out = regrid(r, grid)
    lon, lat = grid.centers()
    i = np.argmin(np.abs(lat[:, 0] - 16.45)); j = np.argmin(np.abs(lon[0] - 107.55))
    assert out[i, j] == src[2, 1]                        # 16,45°N → hàng 2; 107,55°E → cột 1


def test_global_raster_georeference():
    data = np.tile((90 - (np.arange(180) + 0.5))[:, None], (1, 360)).astype("float32")  # giá trị = vĩ độ tâm ô
    grid = Grid.from_bbox((102, 8.3, 112, 23.6), 0.1)
    out = regrid(global_raster(data), grid)
    _, lat = grid.centers()
    assert np.all(np.abs(out - np.floor(lat) - 0.5) < 1e-4)


@pytest.mark.parametrize("scale,vmin,vmax", [("linear", 5, 45), ("sqrt", 0, 1500)])
def test_quantize_roundtrip_within_bound(scale, vmin, vmax):
    x = np.linspace(vmin, vmax, 5000)
    back = dequantize(quantize(x, vmin, vmax, scale), vmin, vmax, scale)
    bound = np.array([max_error(vmin, vmax, scale, at=v) for v in x]) + 1e-9
    assert np.all(np.abs(back - x) <= bound)
    nan = quantize(np.array([np.nan]), vmin, vmax, scale)
    assert nan[0] == 255 and np.isnan(dequantize(nan, vmin, vmax, scale)[0])


def test_palette_decode_correlation():
    vals = np.linspace(0, 100, 32)
    t = vals / 100
    legend = np.stack([255 * t, 80 + 100 * np.sin(np.pi * t), 255 * (1 - t)], axis=1).astype(np.uint8)
    truth = np.random.default_rng(0).uniform(0, 100, (60, 80))
    k = np.clip(np.rint(truth / 100 * 31), 0, 31).astype(int)
    img = legend[k]
    img[0, :] = [0, 0, 0]                                 # đường viền đen phải thành NaN
    got = decode_palette(img, legend, vals)
    assert np.isnan(got[0]).all()
    r = np.corrcoef(got[1:].ravel(), truth[1:].ravel())[0, 1]
    assert r >= 0.98


def test_region_rules_for_known_cities():
    cities = {"Lào Cai": (103.97, 22.48, 0), "Hà Nội": (105.85, 21.03, 1), "Huế": (107.59, 16.46, 2),
              "Nha Trang": (109.19, 12.24, 3), "Đà Lạt": (108.44, 11.94, 4), "TP. Hồ Chí Minh": (106.66, 10.78, 5)}
    lon = np.array([v[0] for v in cities.values()]); lat = np.array([v[1] for v in cities.values()])
    assert list(region_of(lon, lat)) == [v[2] for v in cities.values()]


def test_borders_and_coast_on_toy_grid():
    labels = np.array([[-1, -1, -1, -1], [-1, 0, 0, 1], [-1, 0, 0, 1]])
    b = borders(labels)
    assert b.tolist() == [[0, 0, 0, 0], [0, 0, 1, 1], [0, 0, 1, 1]]
    land = (labels >= 0).astype(np.uint8)
    km = coast_distance_km(land, 0.1)
    assert km[1, 1] == pytest.approx(11.1, rel=1e-3) and km[0, 0] == 0


def test_builtin_geo_is_plausible():
    geo = build_geo()
    lon, lat = geo.grid.centers()
    at = lambda lo, la: (np.argmin(np.abs(lat[:, 0] - la)), np.argmin(np.abs(lon[0] - lo)))
    assert 2000 < int((geo.land == 1).sum()) < 4000
    assert geo.land[at(107.58, 16.45)] == 1                 # Huế là đất liền
    assert geo.land[at(111.6, 16.5)] == 0                    # Hoàng Sa: biển trên lưới 0,1°
    assert geo.coast_km[at(105.85, 21.03)] > 50              # Hà Nội cách biển hơn 50 km


def test_end_to_end_on_synthetic(tmp_path):
    raw, out = tmp_path / "raw", tmp_path / "web"
    make(raw, [2019, 2020])
    rep = build(raw, out, years=[2019, 2020], clim_years=[2019, 2020], verbose=False)
    tg = json.loads((out / "touchgrid.json").read_text(encoding="utf-8"))
    se = json.loads((out / "series.json").read_text(encoding="utf-8"))
    assert set(tg["vars"]) == {"temp", "rain", "fire"}
    for meta in tg["vars"].values():                         # sd theo ô cho app (z = (x - clim) / sd)
        assert len(base64.b64decode(meta["sd"])) == 12 * tg["n_land"] and meta["sd_max"] > 0
    assert sum(rep["files"].values()) < 2 * 1024 * 1024
    assert (out / "frames" / "rain_2020.bin").stat().st_size == 12 * tg["n_land"]
    assert len(se["regions"]) == 6 and len(se["regions"][2]["vars"]["rain"]["values"]) == 24
    hue = se["regions"][2]["vars"]["rain"]["values"]
    assert hue[9] > hue[3]                                   # tháng 10 mưa hơn tháng 4 ở Bắc Trung Bộ
    assert validate(raw, out, samples=3, verbose=False)
