# Dữ liệu NASA: lấy dữ liệu thật, nhận dữ liệu mới, đưa vào app

```
 NASA POWER API ─┐
 NASA FIRMS API ─┤                         ┌─> app/assets/data/  (đóng gói trong app, chạy offline)
 NASA NEO ───────┼─> data/raw/<biến>/<YYYY>-<MM>.npz ─> build ─> validate ─┤
 data/inbox/ ────┘   (định dạng chuẩn, lưới 0,1°)                          └─> web/data/  (đăng lên web → app tải qua URL)
 (file NASA gửi)
```

Mọi nguồn được chuyển về **một định dạng chuẩn**, nên bước build, kiểm chứng và app không cần biết dữ liệu từ đâu.
Đổi nguồn của một biến là sửa một dòng `source` trong `pipeline/config.py`.

## 1. Chạy với dữ liệu thật ngay bây giờ

```powershell
pip install -r requirements.txt

# (tuỳ chọn) mã FIRMS cho dữ liệu điểm cháy — lấy miễn phí tại https://firms.modaps.eosdis.nasa.gov/api/map_key/
$env:FIRMS_MAP_KEY = "mã_của_bạn"          # PowerShell;  bash: export FIRMS_MAP_KEY=...

python -m pipeline.update --years 2018-2025   # thử nhanh vài năm (vài phút)
python -m pipeline.update                     # đủ 2001–2025
```

Chưa có mã FIRMS: chạy `python -m pipeline.update --only temp rain`. App sẽ chỉ hiện Nhiệt độ và Mưa.

| Biến | Nguồn mặc định | Ghi chú |
|---|---|---|
| `temp` | NASA POWER `T2M` | Nhiệt độ **không khí** ở 2 m (°C), lưới gốc 0,5° × 0,625°. ⚠️ Ở Việt Nam chuỗi POWER không đồng nhất theo thời gian: không dùng để nói xu hướng dài hạn (xem `HUONG_DAN_DU_LIEU_NASA.md` mục 5.4) |
| `rain` | NASA POWER `PRECTOTCORR` | Đổi tự động mm/ngày → mm/tháng theo đơn vị trong phản hồi |
| `fire` | NASA FIRMS `MODIS_SP` | Đếm điểm cháy (độ tin cậy ≥ 30) theo ô 0,1° và tháng |

`update` làm lần lượt: tải dữ liệu (có cache trong `data/cache/`, chạy lại chỉ tải phần thiếu) → chuyển về định dạng chuẩn
→ in **dòng kiểm tra** (vd tổng mưa năm nên khoảng 1.200–3.000 mm; nếu ra 50 mm thì đơn vị đã sai) → build
→ `validate` → chép sang `app/assets/data/` và `web/data/`.

Sau đó chạy lại app. Ở chế độ **Tự động**, app dùng dữ liệu NASA trong `assets/data/` nếu có.

Dán 3 điểm kiểm tra mà `validate` in ra vào README nộp bài để làm bằng chứng cho tiêu chí Validity.

## 2. Khi NASA (hoặc cố vấn) gửi thêm dữ liệu

Không cần viết code. Bỏ file vào hộp thư:

```
data/inbox/<tên-tuỳ-ý>/
    source.json        ← mô tả file (xem ví dụ dưới)
    file1.nc4 / .HDF5 / .tif / .csv …
```

Chạy `python -m pipeline.update --only <biến> --inbox <tên-tuỳ-ý>`.
Muốn dùng lâu dài thì đặt `VARS["<biến>"]["source"] = {"type": "inbox", "dir": "<tên-tuỳ-ý>"}` trong `config.py`.

### Ví dụ `source.json`

**IMERG tháng (HDF5)**, lượng mưa chính xác hơn POWER:
```json
{"format": "hdf5", "files": "3B-MO*.HDF5", "group": "Grid", "variable": "precipitation",
 "time": "filename", "date_regex": "3IMERG\\.(\\d{4})(\\d{2})\\d{2}", "units": "mm/hr"}
```

**MERRA-2 tháng (NetCDF)**, nhiệt độ không khí (Kelvin, tự đổi sang °C):
```json
{"format": "netcdf", "files": "MERRA2_*.nc4", "variable": "T2M", "time": "dim", "units": "K"}
```

**GeoTIFF toàn cầu từ NEO** (một file mỗi tháng, tên có năm-tháng):
```json
{"format": "geotiff", "files": "*.tif", "date_regex": "(\\d{4})-(\\d{2})", "fill_values": [99999], "bbox": [-180, -90, 180, 90]}
```

**CSV dạng điểm** (vd FIRMS tải tay, trạm đo):
```json
{"format": "csv_points", "files": "*.csv", "aggregate": "count",
 "columns": {"lat": "latitude", "lon": "longitude", "date": "acq_date"}}
```

Các khoá đầy đủ (`lon`, `lat`, `scale`, `offset`, `fill_values`, `aggregate`, `bbox`…) có trong đầu file
`pipeline/sources/inbox.py`. Đọc NetCDF/HDF5 cần thêm: `pip install xarray netCDF4 h5netcdf h5py`.

Dữ liệu được tự cắt quanh Việt Nam, tự đổi về lưới 0,1°: nguồn mịn hơn thì lấy trung bình, nguồn thô hơn thì lấy ô gần nhất.
Kinh độ 0–360 và trục (lon, lat) bị đảo như IMERG cũng được xử lý tự động.

## 3. Thêm một biến hoàn toàn mới (vd độ ẩm đất, NDVI)

Thêm một mục vào `VARS` trong `config.py`:

```python
VARS["soil"] = {
    "name_vi": "Độ ẩm đất", "name_en": "Soil moisture", "unit": "%",
    "scale": "linear", "min": 0.0, "max": 60.0,
    "instrument": "danbau",          # danbau = cao độ | trung = mật độ nốt | fire = lách tách + trống
    "nodata": [], "convert": None,
    "source": {"type": "power", "parameter": "GWETROOT"},   # hoặc inbox
    "credit": "NASA POWER, GWETROOT",
}
```

App tự hiện thêm nút cho biến mới, tự biết phát bằng nhạc cụ đã khai báo, không cần sửa code Flutter.
Lời đọc cho trẻ em dùng mức tương đối (thấp/vừa/cao).

## 4. Cập nhật dữ liệu cho người dùng mà không phát hành lại app

1. Chạy `python -m pipeline.update` → thư mục `web/data/` có `touchgrid.json`, `series.json`, `frames/`.
2. Đăng lên GitHub Pages (Settings → Pages → nhánh `main`, thư mục `/`).
   URL dạng `https://<tài-khoản>.github.io/<repo>/web/data/`.
3. Trong app: **Cài đặt → Nguồn dữ liệu → Dữ liệu NASA từ URL**, dán URL rồi bấm **Tải**.

App chỉ tải frames của năm đang nghe nên nhẹ. Mỗi lần cập nhật dữ liệu, chỉ cần chạy lại bước 1–2.

## 5. Tham khảo

- NASA POWER Monthly API: https://power.larc.nasa.gov/docs/services/api/temporal/monthly/
- NASA FIRMS Area API: https://firms.modaps.eosdis.nasa.gov/api/area/csv
- Ghi nguồn khi nộp bài: app hiện danh sách nguồn trong Cài đặt; lấy cùng nội dung từ `touchgrid.json` → `sources`.

## 6. Dữ liệu nhập từ kho `data_nasa/` (F1–F3)

Chạy lại: `python pipeline/import_data_nasa.py` (đổi đường dẫn kho bằng biến môi trường `DATA_NASA`). Test: `python -m pytest tests/test_import_data_nasa.py`.

| Chức năng | File trong app | Nguồn trong `data_nasa/` | Ghi chú |
|---|---|---|---|
| F1 | `assets/data/vn_disasters_nasa.json` | `f1/data/deliverables/demo/c_disasters/events_nasa.json` | 282/301 sự kiện định vị được theo tâm tỉnh cũ (tên tỉnh so mờ, chịu lỗi mã hoá); mức nặng 1–10 → 1–5; sự kiện chỉ có năm ghi "trong năm …, chưa rõ tháng". |
| F1 | `assets/data/climate_34_provinces.json` | `f1/data/deliverables/a_34/provinces/*.json` | NASA POWER tháng 1981–2025 cho 34 tỉnh/thành → lịch sử thời tiết không cần mạng. |
| F2 | `assets/data/planets_nasa.json` → `fun_facts` | `assets/content/facts.json` | Chỉ câu gạch đầu dòng ngắn của NASA Space Place; bỏ câu còn độ F, dặm, câu hỏi. Chạy lại cho cùng kết quả. |
| F2 | `assets/sounds/nasa/*.mp3`, `catalog.json` | `assets/content/nasa/*.mp3`, `credits.csv` | 10 bản ghi NASA Historical Sounds; thời lượng đo từ khung MP3; lời giới thiệu và câu hỏi trò "Đố âm thanh NASA" viết trong `pipeline/nasa_sounds.py`. |
| F3 | `assets/touch/vn/` (`grid.json`, `elev.png`, `slope.png`, `water.png`, `pop.png`) | `touch/vn/` (do `crawl_f3.py` tải qua NASA Earthdata, `build_f3.py` xuất) | Lưới 152 × 306 ô, mỗi ô 0,05° (~5,5 km) toàn Việt Nam (~65 KB): độ cao và độ dốc từ NASA SRTMGL30 v002; mặt nước nội địa từ NASA SEDAC GPWv4 Land and Water Area rev11; mật độ dân số từ GPWv4 Population Density rev11 (2020). |

Truyện / minigame trong `assets/content/*_story`, `*_game` của `data_nasa` mới là khung (thoại ghi "Thu âm …", chưa có nội dung) nên không nhập; trò "Đố âm thanh NASA" của app dùng đúng khung đó (dẫn chuyện → bản ghi thật → câu hỏi 2 lựa chọn → đúng / sai / hết giờ).

## 7. Hình ảnh NASA SVS cho Máy hát Trái Đất (#14)

Chạy lại: `data_nasa\svs\tai_svs.bat` (tải video) rồi `python pipeline/build_eic.py` (cần ffmpeg). Kết quả: `app/assets/eic/` (5 bộ: `nightlights` SVS 5475, `lightning` 5011, `co2` 5436, `ocean` 3912, `forest` 4950). Cách đổi màu ra số và kiểm chứng: `docs/HUONG_DAN_DU_LIEU_NASA.md` mục 4–5; thiết kế âm thanh: `docs/MAY_HAT_TRAI_DAT.md`.
