"""Cấu hình chung cho pipeline (Lắng).

Mỗi biến khai báo NGUỒN dữ liệu của nó (`source`). Đổi nguồn = sửa một dòng ở đây, không phải sửa code:
  - "power"  : NASA POWER API (không cần mã) — nhiệt độ không khí T2M, lượng mưa PRECTOTCORR …
  - "firms"  : NASA FIRMS API (cần MAP_KEY miễn phí) — đếm điểm cháy theo ô, theo tháng
  - "neo"    : NASA Earth Observations (CSV/GeoTIFF toàn cầu, cần NEO_URL_TEMPLATE)
  - "inbox"  : file NASA gửi/tải tay, bỏ vào data/inbox/<thư mục>/ kèm source.json (NetCDF, HDF5, GeoTIFF, CSV)
Mọi nguồn đều được chuyển về định dạng chuẩn data/raw/<biến>/<YYYY>-<MM>.npz trên lưới 0,1°,
nên bước build/validate và app không cần biết dữ liệu đến từ đâu.
"""
import os

# Khung Việt Nam (gồm khoảng biển phía đông để vẽ Hoàng Sa và khung phụ Trường Sa)
BBOX = (102.0, 8.3, 112.0, 23.6)  # lon_min, lat_min, lon_max, lat_max
RES = 0.1                          # độ

YEARS = list(range(2001, 2026))       # 25 năm, 300 tháng (tháng chưa có dữ liệu sẽ để trống)
CLIM_YEARS = list(range(2001, 2021))  # chuẩn khí hậu để tính bất thường z

# Mặt nạ biển/đất: "builtin" = đường viền dựng sẵn (dùng được với mọi nguồn),
# "temp" = suy từ ô không có nhiệt độ mặt đất (chỉ đúng khi temp là LST của NEO/MODIS).
SEA_MASK = "builtin"

# MAP_KEY của FIRMS: lấy miễn phí tại https://firms.modaps.eosdis.nasa.gov/api/map_key/
# Đặt biến môi trường FIRMS_MAP_KEY thay vì ghi thẳng vào file (đừng commit mã lên GitHub).
FIRMS_MAP_KEY = os.environ.get("FIRMS_MAP_KEY", "")

# Mỗi biến: tên, đơn vị (sau khi chuyển đổi), cách lượng tử hoá cho app, nhạc cụ và nguồn.
# instrument: "danbau" (cao độ liên tục) | "trung" (mật độ nốt) | "fire" (tiếng lửa + trống)
VARS = {
    "temp": {
        "name_vi": "Nhiệt độ không khí",
        "name_en": "Air temperature",
        "unit": "°C",
        "scale": "linear",
        "min": 5.0, "max": 35.0,
        "instrument": "danbau",
        "nodata": [-999.0],
        "convert": None,
        "source": {"type": "power", "parameter": "T2M"},
        "credit": "NASA POWER (MERRA-2), T2M nhiệt độ không khí ở độ cao 2 m",
    },
    "rain": {
        "name_vi": "Lượng mưa",
        "name_en": "Rainfall",
        "unit": "mm/tháng",
        "scale": "sqrt",                 # mưa lệch phải mạnh, căn bậc hai cho màu và âm thanh đều hơn
        "min": 0.0, "max": 1200.0,
        "instrument": "trung",
        "nodata": [-999.0],
        "convert": None,                 # adapter POWER tự đổi mm/ngày → mm/tháng theo đơn vị trong phản hồi
        "source": {"type": "power", "parameter": "PRECTOTCORR"},
        "credit": "NASA POWER, PRECTOTCORR lượng mưa đã hiệu chỉnh",
    },
    "fire": {
        "name_vi": "Điểm cháy",
        "name_en": "Fire hotspots",
        "unit": "điểm",
        "scale": "sqrt",
        "min": 0.0, "max": 40.0,         # số điểm cháy MODIS trong một ô 0,1° trong một tháng
        "instrument": "fire",
        "nodata": [],
        "convert": None,
        "source": {"type": "firms", "product": "MODIS_SP", "min_confidence": 30},
        "credit": "NASA FIRMS, MODIS Collection 6.1 (MCD14ML), điểm cháy chuẩn",
    },
}

# Cấu hình thay thế (bỏ comment để dùng). Ví dụ lấy nhiệt độ MẶT ĐẤT từ NEO như đề cương ban đầu:
# VARS["temp"]["source"] = {"type": "neo", "neo_id": "MOD_LSTD_M", "ext": "csv"}
# VARS["temp"].update(name_vi="Nhiệt độ mặt đất ban ngày", min=5.0, max=55.0, nodata=[99999.0])
# SEA_MASK = "temp"
#
# Ví dụ dữ liệu NASA gửi dạng NetCDF: tạo data/inbox/mua-imerg/source.json rồi đặt
# VARS["rain"]["source"] = {"type": "inbox", "dir": "mua-imerg"}

# Mẫu đường dẫn tải từ NEO (chỉ dùng khi source.type == "neo"). CHƯA KIỂM CHỨNG.
NEO_URL_TEMPLATE = None

# Tên file chuẩn sau khi tải/chuyển đổi: data/raw/<var>/<YYYY>-<MM>.npz
RAW_PATTERN = "{var}/{yyyy}-{mm:02d}"

# 6 vùng dùng cho bản tin và khi chưa có ranh giới tỉnh
REGIONS = [
    {"id": 0, "vi": "Tây Bắc", "en": "Northwest"},
    {"id": 1, "vi": "Đông Bắc và đồng bằng sông Hồng", "en": "Northeast & Red River Delta"},
    {"id": 2, "vi": "Bắc Trung Bộ", "en": "North Central Coast"},
    {"id": 3, "vi": "Nam Trung Bộ", "en": "South Central Coast"},
    {"id": 4, "vi": "Tây Nguyên", "en": "Central Highlands"},
    {"id": 5, "vi": "Nam Bộ", "en": "Southern Vietnam"},
]


def sources_list() -> list[str]:
    """Danh sách ghi nguồn cho app và README nộp bài."""
    out = [v["credit"] for v in VARS.values() if v.get("credit")]
    out.append("GADM 4.1 administrative boundaries, https://gadm.org (nếu dùng ranh giới tỉnh)")
    return out
