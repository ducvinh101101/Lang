# check_points.py — kiểm tra 10 điểm mẫu bằng ĐÚNG cách app đọc (giải mã PNG)
# Chạy sau build_f3.py: python check_points.py
import json
from PIL import Image
import numpy as np
from touchmap import Grid, load_ids_png, decode_u8
import sys as _sys
for _s in (_sys.stdout, _sys.stderr):   # console Windows mặc định cp1252, không in được tiếng Việt
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8", errors="replace")

D = "touch/vn"
POINTS = [  # tên, vĩ độ, kinh độ, tỉnh mong đợi (một phần tên), khoảng độ cao hợp lý của ô (m)
    ("Hồ Gươm", 21.0288, 105.8522, "Hà Nội", (0, 100)),
    ("Sa Pa", 22.3364, 103.8438, "Lào Cai", (600, 2600)),
    ("Đỉnh Fansipan", 22.3033, 103.7750, "Lào Cai", (800, 3143)),
    ("Huế", 16.4637, 107.5909, "Huế", (0, 150)),
    ("Hội An", 15.8801, 108.3380, "Đà Nẵng", (0, 100)),
    ("Đà Lạt", 11.9404, 108.4583, "Lâm Đồng", (900, 1800)),
    ("Chợ Bến Thành", 10.7725, 106.6980, "Hồ Chí Minh", (0, 50)),
    ("Cần Thơ", 10.0341, 105.7880, "Cần Thơ", (0, 30)),
    ("Mũi Cà Mau", 8.6150, 104.7230, "Cà Mau", (0, 30)),
    ("Phú Quốc", 10.2170, 103.9600, "An Giang", (0, 400)),
]
meta = json.load(open(f"{D}/grid.json", encoding="utf-8"))
g = Grid(**{k: meta["grid"][k] for k in ("lon0", "lat_top", "step", "cols", "rows")})
names = {r["id"]: r["name_vi"] for r in json.load(open(f"{D}/regions.json", encoding="utf-8"))}
ids = load_ids_png(f"{D}/ids.png")
lay = {l["name"]: decode_u8(np.array(Image.open(f"{D}/{l['file']}")), l["scale"], l["offset"], l["log"])
       for l in meta["layers"]}
bad = 0
for name, lat, lon, prov, (lo, hi) in POINTS:
    cell = g.cell(lon, lat)
    if cell is None:
        print("XEM", name, "nằm ngoài khung lưới"); bad += 1; continue
    c, r = cell
    vid = int(ids[r, c]); e = lay["elev"][r, c]
    p = lay["pop"][r, c] if "pop" in lay else np.nan
    sl = lay["slope"][r, c] if "slope" in lay else np.nan
    wf = lay["water"][r, c] if "water" in lay else np.nan
    pname = names.get(vid, "(ngoài vùng)" if np.isfinite(e) else "(biển)")
    ok_p = prov.lower() in pname.lower()
    ok_e = (not np.isfinite(e) and lo == 0) or (np.isfinite(e) and lo <= e <= hi)
    bad += (not ok_p) + (not ok_e)
    print(f"{'OK ' if ok_p and ok_e else 'XEM'} {name:14s} ô({c},{r}) -> {pname:22s} "
          f"độ cao {'biển' if not np.isfinite(e) else f'{e:.0f} m':>8s}  "
          f"dốc {'' if not np.isfinite(sl) else f'{sl:.1f}°':>6s}  nước {'' if not np.isfinite(wf) else f'{wf:.0%}':>4s}  "
          f"dân số {'' if not np.isfinite(p) else f'{p:.0f}/km2'}")
print(f"\n{bad} chỗ cần xem lại. Điểm ven biển (Cà Mau, Phú Quốc) rơi ra biển ở ô 5 km là chuyện bình thường; ghi lại để biết.")
