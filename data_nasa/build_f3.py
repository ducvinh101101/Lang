# build_f3.py — biến dữ liệu thật trong raw/ thành dữ liệu cho app F3 (giống data_audios.json + audios/ của F2).
# Chạy SAU crawl_f3.py:   python build_f3.py            (thêm --csv-all để xuất CSV cả 34 tỉnh)
# Đầu ra:
#   data_touch.json        mục lục: các cấp bản đồ, link file, thẻ dữ liệu, nguồn, kết quả kiểm tra
#   touch/vn/, touch/p01…  ids.png elev.png slope.png pop.png water.png basemap.png grid.json regions.json|wards.json
#   touch/credits.csv
#   exports/cells_vn.csv   mỗi ô một dòng (nộp bài, phân tích)
import argparse, csv, glob, json, os, sys
import numpy as np
from PIL import Image
from touchmap import (Grid, Raster, grid_for, rasterize_ids, save_ids_png, read_gtopo_dem, read_geotiff, mask_open_sea,
                      block_sample, encode_u8, region_stats, render_basemap, centroid, polygons,
                      slope_raster, water_fraction_raster)
from crawl_f3 import find_province_files, MANIFEST, VN_BBOX
import sys as _sys
for _s in (_sys.stdout, _sys.stderr):   # console Windows mặc định cp1252, không in được tiếng Việt
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8", errors="replace")

NAME, CODE = "name", "code"            # trường trong GeoJSON bản v4.1.0+ (code, name, nameEn, fullName, …)
OUT, EXP = "touch", "exports"
BASE_URL = os.environ.get("TOUCH_BASE_URL", "")   # vd https://raw.githubusercontent.com/<org>/<repo>/f3/test
EXPECT_PROVINCES, EXPECT_WARDS, MAX_ASSET_MB = 34, 3321, 3.0

ELEV = {"name": "elev", "label_vi": "độ cao", "file": "elev.png", "scale": 12.5, "offset": 0,
        "log": False, "unit": "m", "nodata_byte": 255, "nodata_meaning_vi": "biển"}
POP = {"name": "pop", "label_vi": "mật độ dân số", "file": "pop.png", "scale": 0.025, "offset": 0,
       "log": True, "unit": "người/km2", "nodata_byte": 255, "nodata_meaning_vi": "không có số liệu"}
SLOPE = {"name": "slope", "label_vi": "độ dốc", "file": "slope.png", "scale": 0.25, "offset": 0,
         "log": False, "unit": "độ", "nodata_byte": 255, "nodata_meaning_vi": "biển"}
WATER = {"name": "water", "label_vi": "mặt nước", "file": "water.png", "scale": 0.004, "offset": 0,
         "log": False, "unit": "tỉ lệ 0–1", "nodata_byte": 255, "nodata_meaning_vi": "biển hoặc không có số liệu"}
WATER_ON = 0.5            # app: ô có ≥ 50% mặt nước coi như đang ở trên sông, hồ
REQUIRED = ["dataset", "provider", "url", "accessed", "spatial", "temporal", "processing", "limitation_vi", "citation"]
warnings, qc = [], {}


def warn(m):
    warnings.append(m); print("CẢNH BÁO:", m)


def url(rel):
    return f"{BASE_URL.rstrip('/')}/{OUT}/{rel}" if BASE_URL else f"{OUT}/{rel}"


def make_cards(man):
    b, s, g, wa = man.get("boundaries", {}), man["srtm"], man.get("gpw"), man.get("water")
    cards = {
        "ids": {"dataset": f"Ranh giới 34 tỉnh, 3.321 xã — vietnamese-provinces-database {b.get('release', '')}",
                "provider": "thanglequoc/vietnamese-provinces-database (MIT)", "url": b.get("release_url", ""),
                "accessed": b.get("downloaded_at", "")[:10], "spatial": "vector, tô lên lưới app",
                "temporal": "đơn vị hành chính từ 1/7/2025",
                "processing": "Tô mỗi vùng lên lưới; vùng nhỏ hơn một ô vẫn giữ ô chứa tâm; đặc khu ngoài khơi đặt ở dải quần đảo.",
                "limitation_vi": "Ranh giới chỉ để biết ngón tay đang ở đâu, không phải dữ liệu NASA, không có giá trị pháp lý.",
                "citation": f"thanglequoc. vietnamese-provinces-database, {b.get('release', '')}. GitHub. {b.get('release_url', '')}"},
        "elev": {"dataset": "NASA SRTMGL30 v002 (Shuttle Radar Topography Mission Global 30 arc second)",
                 "provider": "NASA JPL; phân phối bởi NASA LP DAAC", "url": s["url"],
                 "accessed": s["downloaded_at"][:10], "spatial": "30 giây cung (~1 km)",
                 "temporal": "dữ liệu chụp tháng 2/2000",
                 "processing": "Trung bình mọi điểm 1 km trong mỗi ô lưới app; ô có dưới 50% điểm đất coi là biển; 12,5 m mỗi bậc.",
                 "limitation_vi": "Độ cao là trung bình cả ô, thấp hơn đỉnh núi thật; ở bản đồ cả nước mỗi ô rộng khoảng 5 km.",
                 "citation": "NASA JPL (2013). NASA Shuttle Radar Topography Mission Global 30 arc second. NASA EOSDIS Land Processes DAAC. https://doi.org/10.5067/MEaSUREs/SRTM/SRTMGL30.002"},
    }
    cards["slope"] = {**cards["elev"], "dataset": "Độ dốc tính từ NASA SRTMGL30 v002",
                      "processing": "Độ dốc từng điểm 1 km bằng sai phân trung tâm (khoảng cách theo kinh độ nhân "
                                    "cos vĩ độ), rồi lấy trung bình trong mỗi ô lưới app; 0,25 độ mỗi bậc.",
                      "limitation_vi": "Độ dốc trung bình của cả ô, nhỏ hơn vách núi thật; "
                                       "ô sát biển thiếu một phía nên kém tin cậy hơn."}
    if wa:
        cards["water"] = {"dataset": "NASA SEDAC GPWv4 Land and Water Area, Revision 11 (diện tích mặt nước)",
                          "provider": "CIESIN, Columbia University; NASA SEDAC", "url": wa["url"],
                          "accessed": wa["downloaded_at"][:10], "spatial": "2,5 phút cung (~5 km)",
                          "temporal": "mặt nước nội địa dùng cho GPWv4 (bản 2018)",
                          "processing": "Tỉ lệ mặt nước = diện tích nước / diện tích điểm ảnh theo vĩ độ, "
                                        "trung bình trong mỗi ô app.",
                          "limitation_vi": "Chỉ có sông, hồ đủ lớn so với ô 5 km; sông nhỏ không hiện ra. "
                                           "Biển không thuộc lớp này.",
                          "citation": "Center for International Earth Science Information Network (CIESIN), Columbia "
                                      "University (2018). Gridded Population of the World, Version 4 (GPWv4): Land and "
                                      "Water Area, Revision 11. Palisades, NY: NASA SEDAC. https://doi.org/10.7927/H4Z60M4Z"}
    if g:
        cards["pop"] = {"dataset": "NASA SEDAC GPWv4 Population Density, Revision 11, năm 2020",
                        "provider": "CIESIN, Columbia University; NASA SEDAC", "url": g["url"],
                        "accessed": g["downloaded_at"][:10], "spatial": "2,5 phút cung (~5 km)", "temporal": "ước tính năm 2020",
                        "processing": "Trung bình mật độ trong mỗi ô lưới app; mã hoá thang logarit.",
                        "limitation_vi": "Số ước tính năm 2020, chia đều theo đơn vị hành chính cũ, không phải số điều tra từng xã.",
                        "citation": "Center for International Earth Science Information Network (CIESIN), Columbia University (2018). Gridded Population of the World, Version 4 (GPWv4): Population Density, Revision 11. Palisades, NY: NASA SEDAC. https://doi.org/10.7927/H49C6VHW"}
    for k, c in cards.items():
        miss = [f for f in REQUIRED if not str(c.get(f, "")).strip()]
        if miss:
            sys.exit(f"DỪNG: thẻ dữ liệu '{k}' thiếu {miss} — chạy lại crawl_f3.py")
    return cards


# điểm ngoài khơi chắc chắn là biển: Biển Đông, vịnh Bắc Bộ, vịnh Thái Lan, ngoài khơi Nam Bộ
SEA_SEEDS = [(110.0, 12.0), (107.8, 19.5), (103.0, 9.0), (109.0, 8.0)]


def load_dem():
    files = glob.glob("raw/srtm/**/*", recursive=True)
    for f in files:
        if f.lower().endswith(".dem"):
            hdr = [h for h in files if h.lower() == f.lower()[:-4] + ".hdr"]
            if hdr:
                return read_gtopo_dem(f, hdr[0])
            # Bản SRTMGL30 trên LP DAAC Cloud chỉ có .DEM (không .hdr) và ghi biển = 0 m:
            # dựng .hdr từ tên ô, rồi coi các ô 0 m nối liền biển khơi là biển (đất trũng 0 m giữ là đất).
            print(f"      {os.path.basename(f)}: không có .hdr → dựng từ tên ô; biển = vùng 0 m nối liền biển khơi")
            return mask_open_sea(crop(read_gtopo_dem(f), VN_BBOX), SEA_SEEDS)
    tif = [f for f in files if f.lower().endswith(".tif")]
    if tif:
        return read_geotiff(tif[0], bounds=VN_BBOX)
    sys.exit("Không thấy file độ cao trong raw/srtm — chạy: python crawl_f3.py --only srtm")


def crop(src, bounds, pad=1.0):
    """Cắt lưới nguồn quanh khung (tránh tính độ dốc cho cả ô SRTM 40×50 độ)."""
    w, s, e, n = bounds
    left, top = src.ulx - src.xdim / 2, src.uly + src.ydim / 2
    j0 = max(0, int((w - pad - left) / src.xdim))
    j1 = min(src.arr.shape[1], int(np.ceil((e + pad - left) / src.xdim)))
    i0 = max(0, int((top - n - pad) / src.ydim))
    i1 = min(src.arr.shape[0], int(np.ceil((top - s + pad) / src.ydim)))
    return Raster(src.arr[i0:i1, j0:j1], src.ulx + j0 * src.xdim, src.uly - i0 * src.ydim,
                  src.xdim, src.ydim, src.nodata)


def fine_enough_grid(feats, sizes=(256, 384, 512, 768, 1024)):
    """Lưới cấp 2 mặc định 256 ô; tăng dần khi có xã nhỏ hơn một ô bị xã khác che mất
       (ví dụ phường trung tâm TP.HCM). Dừng ở cỡ đầu tiên mà mọi xã đều có ô riêng."""
    for n in sizes:
        g = grid_for(feats, max_cells=n)
        num = {id(f): i for i, f in enumerate(feats, start=1)}
        ids = rasterize_ids(feats, g, lambda f: num[id(f)])
        if len(np.unique(ids[ids > 0])) == len(feats):
            if n != sizes[0]:
                print(f"      lưới {n} ô để đủ chỗ cho {len(feats)} xã")
            return g
    return g


def offshore(f):
    lon, lat = centroid(f["geometry"])
    w, s, e, n = VN_BBOX
    return not (w <= lon <= e and s <= lat <= n)


def geom_lat_range(f):
    lats = [p[1] for o, _ in polygons(f["geometry"]) for p in o]
    return max(lats), min(lats)


def write_csv(path, grid, ids, elev, pop, names, level, slope=None, water=None):
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["level", "col", "row", "lat", "lon", "region_id", "region_code", "region_name",
                    "elev_m", "slope_deg", "water_fraction", "pop_per_km2", "is_sea", "qc_flags"])
        for r in range(grid.rows):
            for c in range(grid.cols):
                lon, lat = grid.center(c, r); vid = int(ids[r, c]); e = elev[r, c]
                p = pop[r, c] if pop is not None else np.nan
                sl = slope[r, c] if slope is not None else np.nan
                wf = water[r, c] if water is not None else np.nan
                sea = not np.isfinite(e); info = names.get(vid, {})
                flags = (["OUTSIDE_BORDER"] if vid == 0 and not sea else []) + \
                        (["POP_MISSING"] if pop is not None and vid and not np.isfinite(p) else [])
                w.writerow([level, c, r, f"{lat:.6f}", f"{lon:.6f}", vid, info.get("code", ""), info.get("name_vi", ""),
                            "" if sea else int(round(e)), "" if not np.isfinite(sl) else round(float(sl), 2),
                            "" if not np.isfinite(wf) else round(float(wf), 3),
                            "" if not np.isfinite(p) else round(float(p), 1),
                            int(sea), "|".join(flags)])


def build_level(rel, grid, feats, dem, slope_src, pop_src, water_src, cards, level, islands=None):
    folder = f"{OUT}/{rel}"; os.makedirs(folder, exist_ok=True)
    order = sorted(feats, key=lambda f: str(f["properties"].get(CODE)))
    for i, f in enumerate(order, start=1):
        f["app_id"] = i
    ids = rasterize_ids(order, grid, lambda f: f["app_id"])
    save_ids_png(ids, f"{folder}/ids.png")
    elev, elev_max = block_sample(grid, dem)
    elev = np.where(np.isfinite(elev), np.clip(elev, 0, None), np.nan)
    Image.fromarray(encode_u8(elev, ELEV["scale"])).save(f"{folder}/elev.png", optimize=True)
    layers = [dict(ELEV, url=url(f"{rel}/elev.png"))]
    slope, _ = block_sample(grid, slope_src)
    slope[~np.isfinite(elev)] = np.nan                   # biển: không có độ dốc
    Image.fromarray(encode_u8(slope, SLOPE["scale"])).save(f"{folder}/slope.png", optimize=True)
    layers.append(dict(SLOPE, url=url(f"{rel}/slope.png")))
    water = None
    if water_src is not None:
        water, _ = block_sample(grid, water_src, min_valid=0.01)
        water[~np.isfinite(elev)] = np.nan
        Image.fromarray(encode_u8(water, WATER["scale"])).save(f"{folder}/water.png", optimize=True)
        layers.append(dict(WATER, url=url(f"{rel}/water.png"), on_threshold=WATER_ON))
    pop = None
    if pop_src is not None:
        pop, _ = block_sample(grid, pop_src, min_valid=0.01)
        Image.fromarray(encode_u8(pop, POP["scale"], log=True)).save(f"{folder}/pop.png", optimize=True)
        layers.append(dict(POP, url=url(f"{rel}/pop.png")))
    render_basemap(ids, elev, f"{folder}/basemap.png", water=water)
    names = [{"id": f["app_id"], "code": f["properties"].get(CODE), "name_vi": f["properties"].get(NAME, ""),
              "full_name_vi": f["properties"].get("fullName", ""),
              **region_stats(ids, elev, elev_max, pop, f["app_id"], grid, slope=slope, water=water)}
             for f in order]
    missing = [n["name_vi"] for n in names if n["cells"] == 0]
    if missing:
        sys.exit(f"DỪNG ({rel}): vùng không có ô nào: {missing}")
    use = {k: cards[k] for k in ["ids", "elev", "slope"] + (["water"] if water is not None else [])
           + (["pop"] if pop is not None else [])}
    meta = {"schema_version": "1.0", "level": level, "grid": grid.meta(),
            "ids": {"file": "ids.png", "url": url(f"{rel}/ids.png"), "encoding": "R*256+G; 0 = ngoài mọi vùng",
                    "names": "regions.json" if level == "vn" else "wards.json"},
            "basemap": {"file": "basemap.png", "url": url(f"{rel}/basemap.png"), "scale": 4},
            "layers": layers, "data_cards": use}
    if islands is not None:
        meta["islands"] = islands
    json.dump(meta, open(f"{folder}/grid.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return names, ids, elev, pop, meta, slope, water


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--csv-all", action="store_true"); a = ap.parse_args()
    if not os.path.exists(MANIFEST):
        sys.exit("Chưa có raw/manifest.json — chạy python crawl_f3.py trước (chỉ dùng dữ liệu thật).")
    man = json.load(open(MANIFEST, encoding="utf-8"))
    if "boundaries" not in man or "srtm" not in man:
        sys.exit("Thiếu ranh giới hoặc độ cao trong manifest — chạy lại crawl_f3.py.")
    cards = make_cards(man)
    os.makedirs(OUT, exist_ok=True); os.makedirs(EXP, exist_ok=True)

    dem = crop(load_dem(), VN_BBOX)
    slope_src = slope_raster(dem)
    vn = Grid(102.0, 23.5, 0.05, 152, 306)
    tif = glob.glob("raw/gpw/**/*.tif", recursive=True)
    if not tif:
        warn("không có dữ liệu GPWv4 trong raw/gpw — bỏ qua lớp dân số")
    wtif = glob.glob("raw/gpw_water/**/*waterareakm*.tif", recursive=True)
    if not wtif:
        warn("không có GPWv4 water area trong raw/gpw_water — bỏ qua lớp mặt nước (crawl_f3.py --only water)")
    water_src = water_fraction_raster(read_geotiff(wtif[0], bounds=vn.bounds())) if wtif else None

    prov_files = find_province_files("raw/geojson")
    provs = [json.load(open(f, encoding="utf-8"))["features"][0] for f in prov_files]
    wards_of = {}
    for pf, p in zip(prov_files, provs):
        wf = sorted(glob.glob(os.path.join(os.path.dirname(pf), "wards", "*.geojson")))
        wards_of[str(p["properties"][CODE])] = [json.load(open(f, encoding="utf-8"))["features"][0] for f in wf]

    # Đặc khu ngoài khơi (Hoàng Sa, Trường Sa…): lấy vĩ độ thật từ ranh giới để đặt trên dải bên phải
    islands = []
    for p in provs:
        for w in wards_of[str(p["properties"][CODE])]:
            if offshore(w):
                top, bot = geom_lat_range(w)
                islands.append({"name_vi": w["properties"].get(NAME, ""), "code": w["properties"].get(CODE),
                                "unit_vi": f"{w['properties'].get('fullName', w['properties'].get(NAME, ''))}, {p['properties'].get('fullName', p['properties'].get(NAME, ''))}",
                                "lat_top": round(min(top, vn.lat_top), 3),
                                "lat_bottom": round(max(bot, vn.lat_top - vn.rows * vn.step), 3),
                                "source": "ranh giới thật"})
    if not any("Hoàng Sa" in i["name_vi"] for i in islands) or not any("Trường Sa" in i["name_vi"] for i in islands):
        warn("không thấy đủ đặc khu Hoàng Sa và Trường Sa trong ranh giới — kiểm tra file tải về")
    print("Dải quần đảo:", [(i["name_vi"], i["lat_top"], i["lat_bottom"]) for i in islands])

    pop_vn = read_geotiff(tif[0], bounds=vn.bounds()) if tif else None
    regions, ids, elev, pop, meta_vn, slope, water = build_level(
        "vn", vn, provs, dem, slope_src, pop_vn, water_src, cards, "vn", islands)
    names_by_id = {r["id"]: r for r in regions}
    write_csv(f"{EXP}/cells_vn.csv", vn, ids, elev, pop, names_by_id, "vn", slope, water)

    levels = [{"id": "vn", "label_vi": "Cả nước", "grid_json": url("vn/grid.json"), "regions": len(regions)}]
    total_wards = 0
    for r in regions:
        wards = wards_of[str(r["code"])]
        on = [w for w in wards if not offshore(w)]
        off = [w for w in wards if offshore(w)]
        g = fine_enough_grid(on)
        folder = f"p{r['id']:02d}"
        sub_pop = read_geotiff(tif[0], bounds=g.bounds()) if tif else None
        wn, wids, welev, wpop, _, wslope, wwater = build_level(
            folder, g, on, dem, slope_src, sub_pop, water_src, cards, folder)
        wn += [{"id": 0, "code": w["properties"].get(CODE), "name_vi": w["properties"].get(NAME, ""),
                "full_name_vi": w["properties"].get("fullName", ""), "offshore": True, "cells": 0} for w in off]
        json.dump(wn, open(f"{OUT}/{folder}/wards.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        if a.csv_all:
            write_csv(f"{EXP}/cells_{folder}.csv", g, wids, welev, wpop, {w["id"]: w for w in wn if w["id"]},
                      folder, wslope, wwater)
        r["level2"] = folder
        total_wards += len(wards)
        levels.append({"id": folder, "label_vi": r["name_vi"], "grid_json": url(f"{folder}/grid.json"),
                       "regions": len(wn), "offshore": len(off)})
    for r in regions:
        r.setdefault("merged_from", []); r.setdefault("intro_vi", "")   # điền tay (README bước 4)
    json.dump(regions, open(f"{OUT}/vn/regions.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    # Kiểm tra
    if len(regions) != EXPECT_PROVINCES: warn(f"có {len(regions)} tỉnh, cần {EXPECT_PROVINCES}")
    if total_wards != EXPECT_WARDS: warn(f"có {total_wards} đơn vị cấp xã, cần {EXPECT_WARDS}")
    land = (ids > 0) & np.isfinite(elev); e = elev[land]
    rr, cc = np.unravel_index(np.nanargmax(np.where(land, elev, np.nan)), elev.shape)
    lon, lat = vn.center(cc, rr)
    if not (103.0 <= lon <= 104.8 and 21.5 <= lat <= 23.0):
        warn(f"ô cao nhất ở ({lat:.2f}, {lon:.2f}), không thuộc vùng Hoàng Liên Sơn")
    bands = [0, 200, 500, 1000, 2000, 10000]
    qc.update({
        "provinces": len(regions), "wards": total_wards, "offshore_units": [i["name_vi"] for i in islands],
        "highest_cell_vn": {"elev_mean_m": int(round(elev[rr, cc])), "lat": round(float(lat), 3), "lon": round(float(lon), 3)},
        "elevation_bands_pct": {f"{lo}-{hi}": round(float(((e >= lo) & (e < hi)).mean()) * 100, 1) for lo, hi in zip(bands, bands[1:])},
        "share_land_ge_200m_pct": round(float((e >= 200).mean()) * 100, 1),
        "pop_layer": pop is not None, "water_layer": water is not None,
        "slope_land_mean_deg": round(float(np.nanmean(slope[land])), 2),
        "water_cells_ge_threshold": int(np.sum(water[land] >= WATER_ON)) if water is not None else None})
    rr2, cc2 = np.unravel_index(np.nanargmax(np.where(land, slope, np.nan)), slope.shape)
    slon, slat = vn.center(cc2, rr2)
    qc["steepest_cell_vn"] = {"slope_deg": round(float(slope[rr2, cc2]), 1),
                              "lat": round(float(slat), 3), "lon": round(float(slon), 3)}
    if slat < 11.0:
        warn(f"ô dốc nhất ở ({slat:.2f}, {slon:.2f}), ngoài mọi vùng núi lớn — kiểm tra lớp độ dốc")
    with open(f"{OUT}/credits.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh); w.writerow(["file", "nguon", "link", "ngay_tai", "ghi_cong", "audio_kind"])
        for k, f in [("elev", "elev.png"), ("slope", "slope.png"), ("water", "water.png"),
                     ("pop", "pop.png"), ("ids", "ids.png")]:
            if k in cards:
                w.writerow([f, cards[k]["dataset"], cards[k]["url"], cards[k]["accessed"], cards[k]["provider"],
                            "app_sonification" if k != "ids" else ""])
    size = sum(os.path.getsize(p) for p in glob.glob(f"{OUT}/**/*", recursive=True) if os.path.isfile(p)) / 1e6
    if size > MAX_ASSET_MB: warn(f"touch/ nặng {size:.2f} MB, vượt {MAX_ASSET_MB} MB")
    qc.update({"assets_mb": round(size, 2), "warnings": warnings})

    index = {"schema_version": "1.0", "feature": "F3 - di tay đọc vùng",
             "generated_from": "raw/manifest.json", "levels": levels,
             "data_cards": cards,
             "sources": {k: {kk: v for kk, v in man[k].items() if kk != "files"} | {
                 "files": [{"name": os.path.basename(f["path"]), "sha256": f["sha256"], "bytes": f["bytes"]} for f in man[k]["files"]]}
                 for k in man},
             "exports": {"cells_vn_csv": "exports/cells_vn.csv"}, "qc": qc}
    json.dump(index, open("data_touch.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    print("\n=== KẾT QUẢ (dữ liệu thật) ===")
    print("Tỉnh:", len(regions), "| Xã, phường:", total_wards, "| touch/:", f"{size:.2f} MB")
    print("Đất liền theo đai độ cao (%):", qc["elevation_bands_pct"])
    print(f"=> Theo số liệu độ cao NASA SRTMGL30, {qc['share_land_ge_200m_pct']}% đất liền Việt Nam cao từ 200 m trở lên.")
    print("Ô cao nhất:", qc["highest_cell_vn"], "| Ô dốc nhất:", qc["steepest_cell_vn"],
          "| Cảnh báo:", len(warnings))


if __name__ == "__main__":
    main()
