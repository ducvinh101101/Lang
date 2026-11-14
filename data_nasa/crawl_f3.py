# crawl_f3.py — tải dữ liệu THẬT cho F3 "di tay đọc vùng" từ đúng các nguồn trong file 6 của đội.
#   1. Ranh giới 34 tỉnh + 3.321 xã: GitHub thanglequoc/vietnamese-provinces-database (bản phát hành mới nhất có GeoJSON)
#   2. Độ cao: NASA SRTMGL30 v002 (LP DAAC) — tải qua NASA Earthdata (earthaccess)
#   3. Mật độ dân số: NASA SEDAC GPWv4 Population Density rev11, năm 2020, 2,5 phút cung — qua NASA Earthdata
#   4. Mặt nước nội địa (sông, hồ): NASA SEDAC GPWv4 Land and Water Area rev11, 2,5 phút cung — qua NASA Earthdata
# Mọi file tải về được ghi vào raw/manifest.json: link gốc, ngày tải, kích thước, mã SHA-256.
#
# Chạy:   pip install -r requirements.txt
#         python crawl_f3.py            (lần đầu sẽ hỏi tài khoản Earthdata, tạo tại https://urs.earthdata.nasa.gov)
#         python crawl_f3.py --only boundaries|srtm|gpw|water   (tải lại một nguồn)
import argparse, datetime, glob, hashlib, json, os, re, shutil, sys, zipfile
import sys as _sys
for _s in (_sys.stdout, _sys.stderr):   # console Windows mặc định cp1252, không in được tiếng Việt
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8", errors="replace")

RAW = "raw"
MANIFEST = f"{RAW}/manifest.json"
VN_BBOX = (102.0, 8.2, 109.6, 23.5)            # W, S, E, N — khung lưới cấp 1 của file 6
GH_REPO = "thanglequoc/vietnamese-provinces-database"
GH_ASSET = re.compile(r"vn_provinces_wards_geojson_.*\.zip$")
GH_TREE_ZIP = re.compile(r"(^|/)vn_provinces_wards_geojson[^/]*\.zip$")
GPW_TITLE = "Gridded Population of the World, Version 4 (GPWv4): Population Density, Revision 11"
GPW_CONCEPT = "C3540910651-ESDIS"              # CIESIN_SEDAC_GPWv4_POPDENS_R11 trên NASA CMR (tra lại 10/11/2026;
                                               # mã cũ C3540929138 là bộ Urban Landsat, không phải mật độ dân số)
WATER_TITLE = "Gridded Population of the World, Version 4 (GPWv4): Land and Water Area, Revision 11"
WATER_CONCEPT = "C3540911087-ESDIS"            # CIESIN_SEDAC_GPWv4_LANDH2OAREA_R11 (tra 10/11/2026)


def now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def load_manifest():
    return json.load(open(MANIFEST, encoding="utf-8")) if os.path.exists(MANIFEST) else {}


def record(man, key, **entry):
    for f in entry.get("files", []):
        f["sha256"] = sha256(f["path"]); f["bytes"] = os.path.getsize(f["path"])
    entry["downloaded_at"] = now()
    man[key] = entry
    json.dump(man, open(MANIFEST, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def unzip_all(zpath, dest):
    os.makedirs(dest, exist_ok=True)
    with zipfile.ZipFile(zpath) as z:
        z.extractall(dest)


# ---------- 1. Ranh giới ----------

def get_boundaries(man):
    import requests
    print("[1/4] Ranh giới: tìm bản phát hành mới nhất có GeoJSON trên GitHub…")
    r = requests.get(f"https://api.github.com/repos/{GH_REPO}/releases", timeout=60,
                     headers={"Accept": "application/vnd.github+json"})
    r.raise_for_status()
    rel = asset = None
    for rel in r.json():                          # API trả về mới nhất trước
        asset = next(({"name": a["name"], "url": a["browser_download_url"]}
                      for a in rel.get("assets", []) if GH_ASSET.search(a["name"])), None)
        if not asset:
            # Từ v4.x file zip nằm trong mã nguồn của bản phát hành (json/vn_provinces_wards_geojson.zip),
            # không còn là tệp đính kèm: tìm trong cây thư mục đúng tag đó.
            t = requests.get(f"https://api.github.com/repos/{GH_REPO}/git/trees/{rel['tag_name']}?recursive=1",
                             timeout=60, headers={"Accept": "application/vnd.github+json"})
            t.raise_for_status()
            path = next((x["path"] for x in t.json().get("tree", []) if GH_TREE_ZIP.search(x["path"])), None)
            if path:
                asset = {"name": os.path.basename(path),
                         "url": f"https://raw.githubusercontent.com/{GH_REPO}/{rel['tag_name']}/{path}"}
        if asset:
            break
    if not asset:
        sys.exit("Không tìm thấy file vn_provinces_wards_geojson*.zip trong các bản phát hành. Mở trang Releases kiểm tra lại.")
    print(f"      bản {rel['tag_name']} ({rel['published_at'][:10]}), file {asset['name']}")
    os.makedirs(f"{RAW}/boundaries", exist_ok=True)
    zpath = f"{RAW}/boundaries/{asset['name']}"
    with requests.get(asset["url"], stream=True, timeout=300) as d:
        d.raise_for_status()
        with open(zpath, "wb") as f:
            shutil.copyfileobj(d.raw, f)
    shutil.rmtree(f"{RAW}/geojson", ignore_errors=True)
    unzip_all(zpath, f"{RAW}/geojson")
    n_prov = len(find_province_files(f"{RAW}/geojson"))
    n_ward = len(glob.glob(f"{RAW}/geojson/**/wards/*.geojson", recursive=True))
    print(f"      giải nén: {n_prov} tỉnh, {n_ward} xã, phường")
    record(man, "boundaries", source="GitHub " + GH_REPO, release=rel["tag_name"],
           release_date=rel["published_at"], release_url=rel["html_url"], license="MIT",
           url=asset["url"], files=[{"path": zpath}],
           counts={"provinces": n_prov, "wards": n_ward})


def find_province_files(root):
    """File tỉnh = file .geojson nằm cạnh thư mục wards/ (cấu trúc của bản v4.1.0 trở đi)."""
    out = []
    for wd in glob.glob(f"{root}/**/wards", recursive=True):
        parent = os.path.dirname(wd)
        out += [f for f in glob.glob(f"{parent}/*.geojson")]
    return sorted(out)


# ---------- 2 & 3. NASA Earthdata ----------

def earthdata():
    import earthaccess
    has_netrc = any(os.path.exists(os.path.expanduser(f"~/{n}")) for n in (".netrc", "_netrc"))
    auth = earthaccess.login(strategy="netrc") if has_netrc else None
    if not auth or not auth.authenticated:
        auth = earthaccess.login(strategy="interactive", persist=True)
    if not auth.authenticated:
        sys.exit("Đăng nhập Earthdata thất bại.")
    return earthaccess


def links_of(granules):
    out = []
    for g in granules:
        out += [l for l in g.data_links() if l.startswith("http")]
    return out


def get_srtm(man):
    ea = earthdata()
    print("[2/4] Độ cao: tìm NASA SRTMGL30 v002 phủ Việt Nam trên Earthdata…")
    gr = ea.search_data(short_name="SRTMGL30", version="002", bounding_box=VN_BBOX)
    links = links_of(gr)
    if not links:
        sys.exit("Không tìm thấy hạt dữ liệu SRTMGL30 nào. Kiểm tra trang https://www.earthdata.nasa.gov/data/catalog/lpcloud-srtmgl30-002")
    print("      tìm thấy:", *[os.path.basename(l) for l in links], sep="\n        ")
    dest = f"{RAW}/srtm"; shutil.rmtree(dest, ignore_errors=True); os.makedirs(dest)
    files = ea.download(links, dest)
    for z in glob.glob(f"{dest}/*.zip"):
        unzip_all(z, dest)
    dem = [f for f in glob.glob(f"{dest}/**/*", recursive=True) if f.lower().endswith((".dem", ".tif"))]
    if not dem:
        sys.exit(f"Đã tải nhưng không thấy file .dem/.tif trong {dest}. Mở thư mục xem tên file.")
    print("      file độ cao:", *dem)
    record(man, "srtm", source="NASA SRTMGL30 v002, LP DAAC", short_name="SRTMGL30", version="002",
           url="https://www.earthdata.nasa.gov/data/catalog/lpcloud-srtmgl30-002", links=links,
           doi="10.5067/MEaSUREs/SRTM/SRTMGL30.002", files=[{"path": str(f)} for f in files])


def get_gpw(man):
    ea = earthdata()
    print("[3/4] Dân số: tìm NASA SEDAC GPWv4 Population Density rev11, năm 2020…")
    concept = find_collection(ea, GPW_CONCEPT, GPW_TITLE, "GPWv4 Population Density Revision 11")
    gr = ea.search_data(concept_id=concept, temporal=("2020-01-01", "2020-12-31"))
    links = [l for l in links_of(gr) if "2020" in l and "2pt5_min" in l and l.lower().endswith("tif.zip")]
    links = [l for l in links if "adjusted" not in l.lower()]   # bản gốc, không phải bản hiệu chỉnh theo LHQ
    if not links:
        print("Các file có trong kết quả:", *links_of(gr)[:40], sep="\n  ")
        sys.exit("Không thấy file GeoTIFF 2,5 phút cung năm 2020. Xem danh sách trên, sửa bộ lọc trong get_gpw().")
    print("      tải:", *[os.path.basename(l) for l in links])
    dest = f"{RAW}/gpw"; shutil.rmtree(dest, ignore_errors=True); os.makedirs(dest)
    files = ea.download(links[:1], dest)
    for z in glob.glob(f"{dest}/*.zip"):
        unzip_all(z, dest)
    tif = [f for f in glob.glob(f"{dest}/**/*.tif", recursive=True)]
    print("      file dân số:", *tif)
    record(man, "gpw", source="NASA SEDAC GPWv4 Population Density rev11", year=2020, resolution="2.5 arc-minute",
           url="https://doi.org/10.7927/H49C6VHW", links=links[:1], doi="10.7927/H49C6VHW",
           files=[{"path": str(f)} for f in files])


def find_collection(ea, concept, title, keyword):
    """Mã bộ sưu tập có thể đổi khi SEDAC chuyển vào Earthdata: kiểm tra tiêu đề, sai thì tìm lại theo tên."""
    cols = ea.search_datasets(concept_id=concept)
    if cols and cols[0]["umm"].get("EntryTitle", "").strip() == title:
        return concept
    cols = [c for c in ea.search_datasets(keyword=keyword) if c["umm"].get("EntryTitle", "").strip() == title]
    if not cols:
        sys.exit(f"Không tìm thấy bộ '{title}' trên Earthdata.")
    return cols[0]["meta"]["concept-id"]


def get_water(man):
    ea = earthdata()
    print("[4/4] Mặt nước: tìm NASA SEDAC GPWv4 Land and Water Area rev11 (diện tích nước, 2,5 phút cung)…")
    concept = find_collection(ea, WATER_CONCEPT, WATER_TITLE, "GPWv4 Land and Water Area Revision 11")
    links = [l for l in links_of(ea.search_data(concept_id=concept))
             if "waterareakm_2pt5_min" in l and l.lower().endswith("tif.zip")]
    if not links:
        sys.exit("Không thấy file waterareakm 2,5 phút cung GeoTIFF. Sửa bộ lọc trong get_water().")
    print("      tải:", os.path.basename(links[0]))
    dest = f"{RAW}/gpw_water"; shutil.rmtree(dest, ignore_errors=True); os.makedirs(dest)
    files = ea.download(links[:1], dest)
    for z in glob.glob(f"{dest}/*.zip"):
        unzip_all(z, dest)
    tif = [f for f in glob.glob(f"{dest}/**/*.tif", recursive=True)]
    if not tif:
        sys.exit(f"Đã tải nhưng không thấy .tif trong {dest}.")
    print("      file mặt nước:", *tif)
    record(man, "water", source="NASA SEDAC GPWv4 Land and Water Area rev11 (water area)",
           resolution="2.5 arc-minute", url="https://doi.org/10.7927/H4Z60M4Z", links=links[:1],
           doi="10.7927/H4Z60M4Z", files=[{"path": str(f)} for f in files])


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["boundaries", "srtm", "gpw", "water"])
    a = ap.parse_args()
    os.makedirs(RAW, exist_ok=True)
    man = load_manifest()
    steps = {"boundaries": get_boundaries, "srtm": get_srtm, "gpw": get_gpw, "water": get_water}
    for k, fn in steps.items():
        if a.only in (None, k):
            fn(man)
    print(f"\nXong. Nhật ký nguồn: {MANIFEST}. Bước tiếp: python build_f3.py")
