"""Lưới 0,1°, mặt nạ đất liền, vùng/tỉnh, ranh giới và khoảng cách tới biển."""
from __future__ import annotations

import csv
import json
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from scipy.ndimage import distance_transform_edt

from . import config

# Đường viền Việt Nam giản lược (lon, lat), dùng khi chưa có GADM. Trùng với bản demo web.
VN_OUTLINE = np.array([
    [102.14, 22.40], [102.40, 22.65], [102.60, 22.73], [103.00, 22.45], [103.30, 22.80], [103.60, 22.75], [103.95, 22.50],
    [104.10, 22.75], [104.40, 22.70], [104.75, 22.85], [105.10, 23.05], [105.35, 23.38], [105.60, 23.15], [105.90, 22.95],
    [106.30, 22.95], [106.70, 22.85], [106.65, 22.45], [106.80, 22.10], [107.05, 21.80], [107.40, 21.65], [107.75, 21.62],
    [108.05, 21.55], [107.80, 21.40], [107.45, 21.25], [107.10, 20.95], [106.80, 20.75], [106.60, 20.35], [106.20, 19.95],
    [105.95, 19.65], [105.80, 19.25], [105.70, 18.95], [105.85, 18.60], [106.15, 18.25], [106.50, 17.80], [106.75, 17.35],
    [107.10, 16.95], [107.50, 16.65], [107.95, 16.35], [108.25, 16.10], [108.45, 15.80], [108.80, 15.40], [108.95, 15.00],
    [109.10, 14.40], [109.25, 13.80], [109.30, 13.30], [109.45, 12.90], [109.25, 12.40], [109.20, 11.95], [109.05, 11.60],
    [108.85, 11.25], [108.45, 11.00], [108.05, 10.75], [107.55, 10.55], [107.10, 10.35], [106.80, 10.35], [106.75, 10.05],
    [106.55, 9.70], [106.25, 9.45], [105.85, 9.20], [105.40, 8.85], [105.00, 8.60], [104.75, 8.60], [104.85, 9.00],
    [104.85, 9.60], [105.05, 10.00], [104.75, 10.20], [104.45, 10.40], [104.70, 10.55], [105.05, 10.90], [105.45, 10.95],
    [105.85, 10.85], [106.15, 11.10], [105.95, 11.55], [106.40, 11.95], [106.80, 12.10], [107.15, 12.25], [107.45, 12.40],
    [107.55, 12.90], [107.50, 13.45], [107.60, 13.80], [107.45, 14.30], [107.55, 14.70], [107.70, 15.25], [107.40, 15.50],
    [107.20, 15.85], [107.45, 16.10], [106.95, 16.40], [106.70, 16.65], [106.55, 17.00], [106.25, 17.30], [105.85, 17.65],
    [105.60, 18.05], [105.20, 18.40], [104.95, 18.75], [104.55, 18.95], [104.00, 19.30], [104.15, 19.70], [104.65, 19.85],
    [104.45, 20.20], [104.00, 20.45], [103.70, 20.70], [103.25, 20.80], [102.95, 21.10], [102.85, 21.55], [102.70, 21.75],
    [102.45, 21.95]])
HAINAN = np.array([[108.62, 19.15], [108.70, 18.50], [109.50, 18.20], [110.10, 18.40], [110.60, 18.80], [111.00, 19.60],
                   [110.70, 20.10], [110.20, 20.10], [109.60, 20.00], [109.20, 19.75], [108.65, 19.40]])
PHU_QUOC = np.array([[103.85, 10.42], [104.06, 10.44], [104.10, 10.18], [103.99, 10.00], [103.86, 10.20]])


@dataclass
class Grid:
    lon0: float
    lat1: float
    res: float
    w: int
    h: int

    @classmethod
    def from_bbox(cls, bbox=config.BBOX, res=config.RES) -> "Grid":
        lon0, lat0, lon1, lat1 = bbox
        return cls(lon0, lat1, res, int(round((lon1 - lon0) / res)), int(round((lat1 - lat0) / res)))

    def centers(self):
        lon = self.lon0 + (np.arange(self.w) + 0.5) * self.res
        lat = self.lat1 - (np.arange(self.h) + 0.5) * self.res
        return np.meshgrid(lon, lat)


def points_in_rings(x: np.ndarray, y: np.ndarray, rings) -> np.ndarray:
    """Ray casting chẵn–lẻ trên mọi vòng; lỗ (hole) tự được xử lý đúng."""
    inside = np.zeros(x.shape, dtype=bool)
    for ring in rings:
        ring = np.asarray(ring, dtype=float)
        if len(ring) < 3:
            continue
        xmin, ymin = ring.min(axis=0)
        xmax, ymax = ring.max(axis=0)
        sel = (x >= xmin) & (x <= xmax) & (y >= ymin) & (y <= ymax)
        if not sel.any():
            continue
        xs, ys = x[sel], y[sel]
        hit = np.zeros(xs.shape, dtype=bool)
        xi, yi = ring[:, 0], ring[:, 1]
        xj, yj = np.roll(xi, 1), np.roll(yi, 1)
        for a, b, c, d in zip(xi, yi, xj, yj):
            cond = ((b > ys) != (d > ys)) & (xs < (c - a) * (ys - b) / (d - b + 1e-300) + a)
            hit ^= cond
        inside[sel] ^= hit
    return inside


def region_of(lon: np.ndarray, lat: np.ndarray) -> np.ndarray:
    """6 vùng theo quy tắc kinh–vĩ độ (giống bản demo). Trả về 0..5."""
    r = np.full(lon.shape, 5, dtype=np.int16)
    tn = (lat >= 11.4) & (lat < 15.3) & (lon < 108.55) & ((lat >= 12.4) | (lon >= 107.35))
    ntb = (lat >= 14.0) | ((lat >= 10.5) & (lon >= 107.35) & ((lat >= 11.4) | (lon >= 107.6)))
    r[ntb] = 3
    r[tn] = 4
    r[lat >= 16.0] = 2
    r[lat >= 20.0] = 1
    r[(lat >= 20.4) & (lon < 104.75)] = 0
    return r


def simplify_ring(ring, min_step: float):
    """Bỏ bớt đỉnh gần nhau hơn min_step độ để rasterize GADM nhanh hơn."""
    ring = np.asarray(ring, dtype=float)
    if len(ring) <= 8:
        return ring
    keep = [0]
    last = ring[0]
    for k in range(1, len(ring)):
        if np.hypot(*(ring[k] - last)) >= min_step:
            keep.append(k)
            last = ring[k]
    return ring[keep] if len(keep) >= 4 else ring


def feature_rings(geom: dict):
    t = geom.get("type")
    if t == "Polygon":
        return list(geom["coordinates"])
    if t == "MultiPolygon":
        return [ring for poly in geom["coordinates"] for ring in poly]
    return []


def load_merge_map(path: Path | None) -> dict[str, str]:
    """CSV hai cột old_name,new_name để gộp tỉnh cũ thành đơn vị hành chính mới."""
    if not path:
        return {}
    with open(path, newline="", encoding="utf-8") as f:
        return {row["old_name"].strip(): row["new_name"].strip() for row in csv.DictReader(f) if row.get("new_name")}


@dataclass
class Geo:
    grid: Grid
    land: np.ndarray            # uint8: 0 biển, 1 Việt Nam, 2 nước khác (nếu biết)
    region: np.ndarray          # int16: 0..5, -1 ngoài
    prov: np.ndarray            # int16: chỉ số tỉnh, -1 ngoài hoặc chưa có
    prov_names: list = field(default_factory=list)
    border: np.ndarray | None = None
    coast_km: np.ndarray | None = None


def builtin_sea_mask(grid: Grid | None = None) -> np.ndarray:
    """Mặt nạ biển dựng sẵn, giống bản web: ô không phải Việt Nam, không phải Trung Quốc (bắc 21,62°N),
    đảo Hải Nam hay Lào/Campuchia (phía tây đường biên mỗi hàng) thì là biển. Dùng được với mọi nguồn dữ liệu."""
    grid = grid or Grid.from_bbox()
    X, Y = grid.centers()
    vn_main = points_in_rings(X, Y, [VN_OUTLINE])
    vn = vn_main | points_in_rings(X, Y, [PHU_QUOC])
    row_min = np.where(vn_main, X, np.inf).min(axis=1, keepdims=True)  # mép tây của Việt Nam trên mỗi hàng
    has_row = np.isfinite(row_min)
    foreign = (Y > 21.62) | ((Y > 20.2) & (X > 109.55)) | points_in_rings(X, Y, [HAINAN])
    foreign |= (Y >= 10.42) & has_row & (X < row_min)
    return ~vn & ~foreign


def build_geo(boundaries: Path | None = None, merge_map: Path | None = None,
              sea_mask: np.ndarray | None = None, grid: Grid | None = None) -> Geo:
    grid = grid or Grid.from_bbox()
    X, Y = grid.centers()
    prov = np.full(X.shape, -1, dtype=np.int16)
    names: list[str] = []

    if boundaries:
        gj = json.loads(Path(boundaries).read_text(encoding="utf-8"))
        merge = load_merge_map(merge_map)
        for feat in gj["features"]:
            props = feat.get("properties", {})
            name = props.get("NAME_1") or props.get("name") or props.get("ten_tinh") or "?"
            name = merge.get(name, name)
            if name not in names:
                names.append(name)
            rings = [simplify_ring(r, grid.res / 10) for r in feature_rings(feat["geometry"])]
            hit = points_in_rings(X, Y, rings)
            prov[hit & (prov < 0)] = names.index(name)
        vn = prov >= 0
    else:
        vn = points_in_rings(X, Y, [VN_OUTLINE, PHU_QUOC])

    land = np.zeros(X.shape, dtype=np.uint8)
    land[vn] = 1
    if sea_mask is not None:
        # Ô không phải Việt Nam và không phải biển (theo dữ liệu NEO) là nước láng giềng
        land[(~vn) & (~sea_mask)] = 2
    region = np.where(vn, region_of(X, Y), -1).astype(np.int16)

    geo = Geo(grid, land, region, prov, names)
    labels = prov if boundaries else region
    geo.border = borders(labels)
    geo.coast_km = coast_distance_km(land, grid.res, sea_mask)
    return geo


def borders(labels: np.ndarray) -> np.ndarray:
    """Ô có láng giềng 4 hướng mang nhãn khác (cả hai đều >= 0)."""
    pad = np.pad(labels, 1, mode="edge")
    c = pad[1:-1, 1:-1]
    out = np.zeros(labels.shape, dtype=bool)
    for nb in (pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]):
        out |= (nb != c) & (nb >= 0)
    return (out & (c >= 0)).astype(np.uint8)


def coast_distance_km(land: np.ndarray, res: float, sea_mask: np.ndarray | None = None) -> np.ndarray:
    """Khoảng cách (km, xấp xỉ) từ mỗi ô đất liền Việt Nam tới ô biển gần nhất."""
    sea = sea_mask if sea_mask is not None else (land == 0)
    dist_cells = distance_transform_edt(~sea)
    km = dist_cells * res * 111.0
    km[land != 1] = 0
    return km
