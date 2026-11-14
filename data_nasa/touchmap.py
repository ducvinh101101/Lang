# touchmap.py — thư viện cho F3 "di tay đọc vùng"
# Dựa trên file 6 của đội, có 3 thay đổi chính:
#   1. block_sample(): lấy TRUNG BÌNH thật của mọi điểm nguồn nằm trong ô (file 6 cũ chỉ lấy 1 điểm gần tâm).
#      Nếu ô app nhỏ hơn điểm nguồn (cấp 2), tự rơi về điểm gần nhất.
#   2. Viết bằng numpy (bảng tổng cộng dồn), nhanh hơn vòng lặp Python lồng nhau hàng trăm lần.
#   3. read_geotiff(): đọc GeoTIFF bằng rasterio nếu có, nếu không thì bằng Pillow (không cần cài rasterio).
import json, math
import numpy as np
from PIL import Image, ImageDraw


class Grid:
    """Lưới đều theo kinh/vĩ độ. Ô (c, r): c tăng sang Đông, r tăng xuống Nam."""

    def __init__(self, lon0, lat_top, step, cols, rows):
        self.lon0, self.lat_top, self.step, self.cols, self.rows = lon0, lat_top, step, cols, rows

    def px(self, lon, lat):
        return ((lon - self.lon0) / self.step, (self.lat_top - lat) / self.step)

    def cell(self, lon, lat):
        c, r = self.px(lon, lat)
        c, r = int(math.floor(c)), int(math.floor(r))
        return (c, r) if 0 <= c < self.cols and 0 <= r < self.rows else None

    def center(self, c, r):
        return (self.lon0 + (c + 0.5) * self.step, self.lat_top - (r + 0.5) * self.step)

    def bounds(self):
        return (self.lon0, self.lat_top - self.rows * self.step,
                self.lon0 + self.cols * self.step, self.lat_top)

    def meta(self):
        return {"lon0": round(self.lon0, 6), "lat_top": round(self.lat_top, 6),
                "step": round(self.step, 8), "cols": self.cols, "rows": self.rows,
                "crs": "EPSG:4326", "projection_note_vi":
                "Lưới kinh/vĩ độ đều (equirectangular). Bản đồ nền phải vẽ theo đúng lưới này, không dùng Mercator."}


# ---------- Ranh giới ----------

def polygons(geom):
    if geom["type"] == "Polygon":
        return [(geom["coordinates"][0], geom["coordinates"][1:])]
    if geom["type"] == "MultiPolygon":
        return [(p[0], p[1:]) for p in geom["coordinates"]]
    return []


def centroid(geom):
    """Tâm theo diện tích của vỏ ngoài lớn nhất (ổn định hơn trung bình các đỉnh)."""
    best, best_a = None, -1
    for outer, _ in polygons(geom):
        pts = np.asarray(outer, float)
        x, y = pts[:, 0], pts[:, 1]
        a = 0.5 * (np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))
        if abs(a) > best_a:
            best_a = abs(a)
            if abs(a) < 1e-12:
                best = (float(x.mean()), float(y.mean()))
            else:
                cx = ((x + np.roll(x, -1)) * (x * np.roll(y, -1) - np.roll(x, -1) * y)).sum() / (6 * a)
                cy = ((y + np.roll(y, -1)) * (x * np.roll(y, -1) - np.roll(x, -1) * y)).sum() / (6 * a)
                best = (float(cx), float(cy))
    return best


def rasterize_ids(features, grid, id_of):
    """Tô mỗi vùng bằng mã của nó. uint16, 0 = không thuộc vùng nào.
       Vùng quá nhỏ vẫn được tô ít nhất ô chứa tâm."""
    img = Image.new("I", (grid.cols, grid.rows), 0)
    d = ImageDraw.Draw(img)
    for f in features:
        vid = id_of(f)
        for outer, holes in polygons(f["geometry"]):
            d.polygon([grid.px(x, y) for x, y in outer], fill=vid)
            for h in holes:
                d.polygon([grid.px(x, y) for x, y in h], fill=0)
    ids = np.array(img, dtype=np.int64)
    present = set(np.unique(ids).tolist())
    for f in features:
        vid = id_of(f)
        if vid not in present:
            cell = grid.cell(*centroid(f["geometry"]))
            if cell:
                c, r = cell
                ids[r, c] = vid
    return ids.astype(np.uint16)


def save_ids_png(ids, path):
    rgb = np.zeros(ids.shape + (3,), np.uint8)
    rgb[..., 0] = ids >> 8
    rgb[..., 1] = ids & 255
    Image.fromarray(rgb, "RGB").save(path, optimize=True)


def load_ids_png(path):
    a = np.array(Image.open(path).convert("RGB")).astype(np.uint16)
    return a[..., 0] * 256 + a[..., 1]


# ---------- Đọc lưới nguồn ----------

class Raster:
    """Lưới nguồn: arr[i, j], (ulx, uly) = TÂM điểm ảnh góc trên trái, xdim/ydim > 0 (độ)."""

    def __init__(self, arr, ulx, uly, xdim, ydim, nodata=None):
        self.arr, self.ulx, self.uly, self.xdim, self.ydim, self.nodata = arr, ulx, uly, xdim, ydim, nodata

    def valid_float(self):
        a = self.arr.astype(np.float64)
        bad = ~np.isfinite(a)
        if self.nodata is not None:
            bad |= a == self.nodata
        bad |= a < -1e30            # GPW và nhiều GeoTIFF dùng -3.4e38 làm nodata
        a[bad] = np.nan
        return a

    def value_at(self, lon, lat):
        j = int(round((lon - self.ulx) / self.xdim)); i = int(round((self.uly - lat) / self.ydim))
        if 0 <= i < self.arr.shape[0] and 0 <= j < self.arr.shape[1]:
            v = float(self.valid_float()[i, j])
            return None if math.isnan(v) else v
        return None


GTOPO30_STEP = 1 / 120  # 30 giây cung


def gtopo30_header(dem_path):
    """Dựng nội dung .hdr cho một ô GTOPO30/SRTMGL30 khi nguồn chỉ phát file .DEM (bản trên LP DAAC Cloud không kèm .hdr).
    Tên ô cho góc tây bắc (vd E100N40 = 100°E, 40°N); ô thường 40° × 50° = 4800 × 6000 điểm, số nguyên 16-bit big-endian.
    Kiểm tra kích thước file để không đọc sai."""
    import os
    import re
    m = re.search(r"([EW])(\d{3})([NS])(\d{2})", os.path.basename(dem_path).upper())
    if not m:
        raise ValueError(f"Không đoán được ô GTOPO30 từ tên file {dem_path}")
    lon = int(m.group(2)) * (1 if m.group(1) == "E" else -1)
    lat = int(m.group(4)) * (1 if m.group(3) == "N" else -1)
    ncols, nrows = 4800, 6000
    size = os.path.getsize(dem_path)
    if size != ncols * nrows * 2:
        raise ValueError(f"{dem_path}: {size} byte, không phải ô GTOPO30 chuẩn 4800 × 6000 (cần file .hdr đi kèm)")
    return {"BYTEORDER": "M", "NROWS": str(nrows), "NCOLS": str(ncols), "NODATA": "-9999",
            "ULXMAP": str(lon + GTOPO30_STEP / 2), "ULYMAP": str(lat - GTOPO30_STEP / 2),
            "XDIM": str(GTOPO30_STEP), "YDIM": str(GTOPO30_STEP)}


def mask_open_sea(raster, seeds, sea_value=0):
    """Bản SRTMGL30 hiện nay ghi BIỂN bằng 0 m (không phải NODATA). Đánh dấu biển = các ô bằng [sea_value] NỐI LIỀN
    (4 hướng) với một trong các điểm [seeds] (lon, lat) ngoài khơi; vùng 0 m bị đất bao quanh (đất trũng) giữ là đất.
    Trả về Raster kiểu float với biển = NaN."""
    a = raster.arr.astype(float)
    zero = raster.arr == sea_value
    sea = np.zeros_like(zero)
    left, top = raster.ulx - raster.xdim / 2, raster.uly + raster.ydim / 2
    for lon, lat in seeds:
        c, r = int((lon - left) / raster.xdim), int((top - lat) / raster.ydim)
        if 0 <= r < zero.shape[0] and 0 <= c < zero.shape[1] and zero[r, c]:
            sea[r, c] = True
    if sea.any():
        prev = -1
        while True:
            # lan nhanh: mỗi vòng lan tối đa 64 ô theo từng hướng (cộng dồn), lặp tới khi không đổi
            for _ in range(64):
                d = sea.copy()
                d[1:] |= sea[:-1]
                d[:-1] |= sea[1:]
                d[:, 1:] |= sea[:, :-1]
                d[:, :-1] |= sea[:, 1:]
                sea = d & zero
            n = int(sea.sum())
            if n == prev:
                break
            prev = n
    a[sea] = np.nan
    if raster.nodata is not None:
        a[raster.arr == raster.nodata] = np.nan
    return Raster(a, raster.ulx, raster.uly, raster.xdim, raster.ydim, np.nan)


def read_gtopo_dem(dem_path, hdr_path=None):
    """Ô SRTMGL30 (định dạng GTOPO30: .dem số nguyên 16-bit + .hdr). Không có .hdr → dựng từ tên ô."""
    h = {}
    if hdr_path is None:
        h = gtopo30_header(dem_path)
    for line in open(hdr_path) if hdr_path else []:
        parts = line.split()
        if len(parts) == 2:
            h[parts[0].upper()] = parts[1]
    dtype = ">i2" if h.get("BYTEORDER", "M").upper() == "M" else "<i2"
    a = np.fromfile(dem_path, dtype=dtype).reshape(int(h["NROWS"]), int(h["NCOLS"]))
    nod = float(h["NODATA"]) if "NODATA" in h else -9999.0
    return Raster(a, float(h["ULXMAP"]), float(h["ULYMAP"]), float(h["XDIM"]), float(h["YDIM"]), nod)


def read_geotiff(path, bounds=None, pad=1.0):
    """Đọc GeoTIFF hệ kinh/vĩ độ. bounds=(W,S,E,N) để chỉ đọc một mảnh (đỡ tốn RAM)."""
    try:
        import rasterio
        from rasterio.windows import from_bounds
        with rasterio.open(path) as src:
            if bounds:
                w, s, e, n = bounds
                win = from_bounds(w - pad, s - pad, e + pad, n + pad, src.transform).round_offsets().round_lengths()
                a = src.read(1, window=win, boundless=True, fill_value=src.nodata if src.nodata is not None else np.nan)
                t = src.window_transform(win)
            else:
                a = src.read(1); t = src.transform
            return Raster(a, t.c + t.a / 2, t.f + t.e / 2, t.a, -t.e, src.nodata)
    except ImportError:
        pass
    Image.MAX_IMAGE_PIXELS = None
    im = Image.open(path)
    scale = im.tag_v2.get(33550)          # ModelPixelScaleTag
    tie = im.tag_v2.get(33922)            # ModelTiepointTag: (i, j, k, x, y, z)
    if not scale or not tie:
        raise RuntimeError("GeoTIFF thiếu thẻ toạ độ; hãy cài rasterio: pip install rasterio")
    xdim, ydim = float(scale[0]), float(scale[1])
    left, top = float(tie[3]) - float(tie[0]) * xdim, float(tie[4]) + float(tie[1]) * ydim
    nodata = im.tag_v2.get(42113)         # GDAL_NODATA
    nodata = float(str(nodata).strip("\x00")) if nodata is not None else None
    a = np.array(im)
    if bounds:
        w, s, e, n = bounds
        j0 = max(0, int((w - pad - left) / xdim)); j1 = min(a.shape[1], int(math.ceil((e + pad - left) / xdim)))
        i0 = max(0, int((top - n - pad) / ydim)); i1 = min(a.shape[0], int(math.ceil((top - s + pad) / ydim)))
        a = a[i0:i1, j0:j1]; left += j0 * xdim; top -= i0 * ydim
    return Raster(a, left + xdim / 2, top - ydim / 2, xdim, ydim, nodata)


# ---------- Lớp suy ra từ lưới nguồn ----------

M_PER_DEG_LAT = 110_574.0
M_PER_DEG_LON_EQ = 111_320.0


def slope_raster(dem):
    """Độ dốc (độ) tại từng điểm DEM, tính bằng sai phân trung tâm trên lưới kinh/vĩ độ.
       Khoảng cách theo kinh độ co theo cos(vĩ độ). Điểm biển/thiếu dữ liệu -> NaN.
       Tính ở độ phân giải gốc (~1 km) rồi mới lấy trung bình theo ô app, nên phản ánh độ gồ ghề
       thật của địa hình, không bị làm phẳng như khi tính trên độ cao đã trung bình."""
    z = dem.valid_float()
    rows = np.arange(z.shape[0])
    lat = dem.uly - rows * dem.ydim
    dx = dem.xdim * M_PER_DEG_LON_EQ * np.cos(np.radians(lat))[:, None]
    dy = dem.ydim * M_PER_DEG_LAT
    gy, gx = np.gradient(z)                      # theo hàng (Bắc->Nam), theo cột (Tây->Đông), NaN lan sang lân cận
    s = np.degrees(np.arctan(np.hypot(gx / dx, gy / dy)))
    return Raster(s, dem.ulx, dem.uly, dem.xdim, dem.ydim)


def water_fraction_raster(water_km2):
    """GPWv4 Land and Water Area: diện tích mặt nước nội địa (km²) của mỗi điểm 2,5'
       -> tỉ lệ mặt nước 0..1 = diện tích nước / diện tích điểm ảnh (tính theo vĩ độ).
       Biển không thuộc lãnh thổ là nodata trong nguồn -> NaN."""
    a = water_km2.valid_float()
    lat = water_km2.uly - np.arange(a.shape[0]) * water_km2.ydim
    cell_km2 = (water_km2.xdim * M_PER_DEG_LON_EQ * np.cos(np.radians(lat))) * (water_km2.ydim * M_PER_DEG_LAT) / 1e6
    frac = np.clip(a / cell_km2[:, None], 0, 1)
    return Raster(frac, water_km2.ulx, water_km2.uly, water_km2.xdim, water_km2.ydim)


# ---------- Lấy mẫu lưới nguồn về lưới app ----------

def block_sample(grid, src, min_valid=0.5):
    """Trung bình mọi điểm nguồn hợp lệ nằm trong mỗi ô app.
       Ô có tỉ lệ điểm hợp lệ < min_valid -> NaN (với độ cao: coi là biển).
       Ô nhỏ hơn một điểm nguồn -> lấy điểm nguồn chứa tâm ô.
       Trả về (mean, max)."""
    a = src.valid_float()
    H, W = a.shape
    left, top = src.ulx - src.xdim / 2, src.uly + src.ydim / 2
    edges_lon = grid.lon0 + np.arange(grid.cols + 1) * grid.step
    edges_lat = grid.lat_top - np.arange(grid.rows + 1) * grid.step
    j_edges = np.clip(np.round((edges_lon - left) / src.xdim).astype(int), 0, W)
    i_edges = np.clip(np.round((top - edges_lat) / src.ydim).astype(int), 0, H)
    j0, j1 = j_edges[:-1], j_edges[1:]
    i0, i1 = i_edges[:-1], i_edges[1:]
    # ô nhỏ hơn điểm nguồn: mở rộng thành đúng 1 điểm chứa tâm ô
    cj = np.clip(np.floor((edges_lon[:-1] + grid.step / 2 - left) / src.xdim).astype(int), 0, W - 1)
    ci = np.clip(np.floor((top - (edges_lat[:-1] - grid.step / 2)) / src.ydim).astype(int), 0, H - 1)
    small_j, small_i = j1 <= j0, i1 <= i0
    j0 = np.where(small_j, cj, j0); j1 = np.where(small_j, cj + 1, j1)
    i0 = np.where(small_i, ci, i0); i1 = np.where(small_i, ci + 1, i1)

    valid = np.isfinite(a)
    filled = np.where(valid, a, 0.0)
    S = np.zeros((H + 1, W + 1)); S[1:, 1:] = filled.cumsum(0).cumsum(1)
    N = np.zeros((H + 1, W + 1)); N[1:, 1:] = valid.cumsum(0).cumsum(1)

    def box(T):
        return (T[np.ix_(i1, j1)] - T[np.ix_(i0, j1)]
                - T[np.ix_(i1, j0)] + T[np.ix_(i0, j0)])

    total = (i1 - i0)[:, None] * (j1 - j0)[None, :]
    s, n = box(S), box(N)
    with np.errstate(invalid="ignore", divide="ignore"):
        mean = s / n
    mean[(n == 0) | (n < min_valid * total)] = np.nan

    # max theo ô (để đọc "điểm cao nhất của vùng"); vòng lặp theo hàng là đủ nhanh
    mx = np.full((grid.rows, grid.cols), np.nan)
    for r in range(grid.rows):
        strip = a[i0[r]:i1[r]]
        if strip.size == 0:
            continue
        for c in range(grid.cols):
            blk = strip[:, j0[c]:j1[c]]
            if blk.size and np.isfinite(blk).any():
                mx[r, c] = np.nanmax(blk)
    mx[np.isnan(mean)] = np.nan
    return mean, mx


# ---------- Mã hoá 1 byte ----------

def encode_u8(values, scale, offset=0.0, log=False):
    """Giá trị thật -> 1 byte; 255 = không có dữ liệu.
       Giải mã: v = byte*scale + offset (log=True: v = 10**(byte*scale+offset) - 1)."""
    v = np.log10(1 + np.clip(values, 0, None)) if log else values
    b = np.round((v - offset) / scale)
    b = np.where(np.isnan(b), 255, np.clip(b, 0, 254))
    return b.astype(np.uint8)


def decode_u8(b, scale, offset=0.0, log=False):
    v = b.astype(np.float64) * scale + offset
    if log:
        v = 10 ** v - 1
    v[b == 255] = np.nan
    return v


def grid_for(features, max_cells=256, pad_cells=2):
    pts = [p for f in features for outer, _ in polygons(f["geometry"]) for p in outer]
    lon_min = min(p[0] for p in pts); lon_max = max(p[0] for p in pts)
    lat_min = min(p[1] for p in pts); lat_max = max(p[1] for p in pts)
    step = max(lon_max - lon_min, lat_max - lat_min) / (max_cells - 2 * pad_cells)
    lon0, lat_top = lon_min - pad_cells * step, lat_max + pad_cells * step
    return Grid(lon0, lat_top, step,
                math.ceil((lon_max - lon0) / step) + pad_cells,
                math.ceil((lat_top - lat_min) / step) + pad_cells)


def region_stats(ids, elev, elev_max, pop, vid, grid, slope=None, water=None):
    m = ids == vid
    extra = {}
    if slope is not None:
        s = slope[m]; s = s[np.isfinite(s)]
        extra["slope_mean_deg"] = round(float(s.mean()), 1) if s.size else None
    if water is not None:
        w = water[m]; w = w[np.isfinite(w)]
        extra["water_share"] = round(float(w.mean()), 3) if w.size else None
    e = elev[m]; e = e[np.isfinite(e)]
    out = {"cells": int(m.sum())}
    if e.size:
        out.update({"elev_mean_m": int(round(e.mean())),
                    "share_ge_500m": round(float((e >= 500).mean()), 2)})
        em = np.where(m, elev_max, np.nan)
        if np.isfinite(em).any():
            r, c = np.unravel_index(np.nanargmax(em), em.shape)
            lon, lat = grid.center(c, r)
            out.update({"elev_max_m": int(round(em[r, c])),
                        "elev_max_at": {"lat": round(lat, 4), "lon": round(lon, 4)}})
    else:
        out.update({"elev_mean_m": None, "share_ge_500m": None, "elev_max_m": None})
    if pop is not None:
        p = pop[m]; p = p[np.isfinite(p)]
        out["pop_density_median"] = int(round(float(np.median(p)))) if p.size else None
    out.update(extra)
    return out


# ---------- Ảnh nền cho người nhìn thấy ----------

def render_basemap(ids, elev, path, scale=4, water=None, water_on=0.5):
    """Ảnh nền đúng lưới: biển xanh, đất tô màu theo độ cao, sông hồ lớn xanh đậm, đường ranh giới đậm."""
    rows, cols = ids.shape
    stops = [(0, (98, 160, 90)), (200, (170, 195, 110)), (500, (220, 200, 130)),
             (1000, (190, 140, 90)), (2000, (150, 110, 90)), (3200, (245, 245, 245))]
    rgb = np.zeros((rows, cols, 3), np.float64)
    e = np.nan_to_num(elev, nan=-1)
    for k in range(3):
        xs = [s[0] for s in stops]; ys = [s[1][k] for s in stops]
        rgb[..., k] = np.interp(e, xs, ys)
    sea = ~np.isfinite(elev)
    rgb[sea] = (170, 205, 235)
    if water is not None:
        wet = np.nan_to_num(water, nan=0) >= water_on
        rgb[wet & ~sea] = (90, 150, 210)
    rgb[(ids == 0) & ~sea] = rgb[(ids == 0) & ~sea] * 0.55 + 255 * 0.45   # ngoài biên giới: nhạt
    big = np.repeat(np.repeat(rgb, scale, 0), scale, 1)
    idb = np.repeat(np.repeat(ids, scale, 0), scale, 1)
    edge = np.zeros(idb.shape, bool)
    edge[1:, :] |= idb[1:, :] != idb[:-1, :]
    edge[:, 1:] |= idb[:, 1:] != idb[:, :-1]
    big[edge] = (60, 60, 60)
    Image.fromarray(big.astype(np.uint8), "RGB").save(path, optimize=True)
