# Quy trình thu thập và xử lý dữ liệu F1 A–D

Một lệnh chạy bốn bước **tải → làm sạch → kiểm định → xuất** cho cả A, B, C và D. Các bước cũng chạy riêng để xem raw, dữ liệu trung gian và kết quả kiểm định.

## Chạy pipeline

Cần Python **3.10+** và `curl` khi tải dữ liệu. Từ gốc repo, chạy PowerShell:

```powershell
Push-Location .\f1
python -X utf8 -B -m src.f1 run --profile demo
Pop-Location
```

Nếu dùng môi trường ảo của repo, thay `python` bằng `& .\.venv\Scripts\python.exe` khi đang ở thư mục `f1`.

Để kiểm từng bước, chạy trong thư mục `f1/`:

```powershell
python -X utf8 -B -m src.f1 fetch --profile demo
python -X utf8 -B -m src.f1 clean --profile demo
python -X utf8 -B -m src.f1 validate --profile demo
python -X utf8 -B -m src.f1 export --profile demo
```

## Từng bước xử lý

| Bước | Việc thực hiện | Kết quả |
|---|---|---|
| **Collect** | Cập nhật snapshot bộ C từ NASA GDIS, NASA EONET, DMC và DesInventar bằng `python -m src.f1 collect --profile demo`. Dùng `--offline` để chỉ đọc cache. Dùng `--source-cache` trỏ tới thư mục trống để lấy snapshot mới. | [Snapshot của bộ C](../../f1/data/disasters/catalog_sources.json) |
| **Fetch** | Tải phản hồi NASA còn thiếu và lưu nguyên bản. Thêm `--refresh` để tải lại dữ liệu thời tiết. | `local-private/f1-data/raw/` |
| **Clean** | Kiểm cấu trúc, tọa độ, thời gian và đơn vị theo nguồn. Tạo lịch cố định theo bộ. Chuẩn hóa giá trị, ghép nguồn hoặc tổng hợp theo quy tắc của từng bộ. | `local-private/f1-data/pipeline/demo/clean.json` |
| **Validate** | Tái xử lý từ nguồn rồi đối chiếu với bản trung gian. Kiểm số dòng, khóa trùng, JSON/CSV tương đương và ngân sách 1 MB của gói JSON bàn giao. Tính lại các phép kiểm chéo. | `local-private/f1-data/pipeline/demo/validation.json` |
| **Export** | Chạy lại bước kiểm định trước khi ghi. Xuất JSON, CSV và `credits.csv`. Ghi báo cáo kiểm định cuối. | [Thư mục demo](../../f1/data/deliverables/demo/) và `local-private/f1-data/handoff-checks.json` |

Raw và dữ liệu trung gian lưu ở `local-private/`. Dùng `--output <thư_mục>` ở `run` hoặc `export` để ghi bản thử ở vị trí riêng. `--work-dir` đổi nơi lưu dữ liệu trung gian. Các bước dùng chung `--work-dir` và cùng nguồn raw. Sau khi tải lại bằng `fetch --refresh`, chạy lại từ `clean` trước khi xuất. Lỗi tải, file nguồn vắng hoặc cấu trúc sai làm lệnh trả mã lỗi. Bước kiểm định hoàn tất trước khi ghi file bàn giao.

## Quy tắc riêng của bốn bộ

| Bộ | Nguồn và kỳ | Làm sạch và tổng hợp | Đầu ra |
|---|---|---|---|
| **A · Khí hậu** | NASA POWER Monthly, `T2M` và `PRECTOTCORR`, 6 điểm trong 1981–2025. | Tạo đủ 540 tháng và 45 năm mỗi điểm. Tổng mưa tháng bằng mm/ngày nhân số ngày thực tế. Ưu tiên số tổng hợp năm `YYYY13` hợp lệ. Nếu thiếu số năm, chỉ tính từ tháng khi đủ 12 giá trị của chỉ tiêu. | [`a_climate/provinces/`](../../f1/data/deliverables/demo/a_climate/provinces/) |
| **B · Ngày nắng nóng** | NASA POWER Daily, `T2M_MAX`, cùng 6 điểm và kỳ với A. | Đếm lũy tích số ngày ≥35, ≥37 và ≥39 °C. Nếu năm thiếu ngày hợp lệ, giữ dòng năm và để cả ba số đếm là `null`. | [`b_heat_days/`](../../f1/data/deliverables/demo/b_heat_days/) |
| **C · Thiên tai Việt Nam** | NASA GLC và các hồ sơ sự kiện được đối chiếu theo từng nguồn. Với Yagi, dùng thêm NASA POWER Daily và NASA GPM IMERG Final Daily V07B, 01–15/09/2024. | Chuẩn hóa tên, mã, loại, ngày, vùng ảnh hưởng, thang đo gốc và điểm mức độ. Thống kê ba địa phương từ danh mục và lưu riêng ảnh hưởng Yagi. Ghép chuỗi mưa và gió theo ngày UTC. | [`c_disasters/`](../../f1/data/deliverables/demo/c_disasters/) |
| **D · Nhiệt độ toàn cầu** | NASA GISTEMP v4, cột `J-D`, 1880–2025. | Giữ đủ 146 dòng năm. Giá trị là độ lệch °C so với 1951–1980. Năm thiếu hoặc có mã `***` để `null`. | [`d_global_temp/`](../../f1/data/deliverables/demo/d_global_temp/) |

[POWER Monthly](https://power.larc.nasa.gov/docs/services/api/temporal/monthly/) · [POWER Daily](https://power.larc.nasa.gov/docs/services/api/temporal/daily/) · [IMERG Final Daily](https://gdex.ucar.edu/datasets/d734000/) · [GISTEMP v4](https://data.giss.nasa.gov/gistemp/data_v4.html)

## Cách app đọc dữ liệu thiếu

JSON dạng bảng giữ `data_card` và `records`, CSV giữ cùng các bản ghi. Tháng, ngày hoặc năm thiếu giá trị vẫn có khóa thời gian. Từng giá trị thiếu là `null` trong JSON và ô rỗng trong CSV. Số **0** hợp lệ vẫn là số 0. Báo cáo `missing_values` đếm số giá trị thiếu theo từng file và chỉ tiêu.

### Lớp mưa Yagi

[JSON lưới mưa](../../f1/data/deliverables/demo/c_disasters/yagi/rain_grid.json) có ba trục `dates`, `longitudes`, `latitudes`. Giải mã Base64 trường `precipitation_mm.values`, giải nén gzip rồi đọc mảng JSON số hoặc `null`. Thứ tự là ngày, kinh độ, vĩ độ, với vĩ độ thay đổi nhanh nhất. Chỉ số của ô ở ngày `d`, kinh độ `x` và vĩ độ `y` là `(d * width + x) * height + y`, tính từ 0. Để tô ô, lấy tâm theo hai trục tọa độ và mở rộng 0,05° về mỗi phía. `bbox` ghi rìa ngoài của lưới theo thứ tự tây, nam, đông, bắc.

[CSV lưới mưa](../../f1/data/deliverables/demo/c_disasters/yagi/rain_grid.csv) ghi một dòng cho mỗi tổ hợp ngày UTC, kinh độ và vĩ độ, với cùng lượng mưa tính bằng mm trong ngày. Lệnh `run --profile demo --offline` tạo cả hai file từ 15 phản hồi IMERG có trong cache.

```javascript
const value = row?.temperature_c;
const display = typeof value === "number" && Number.isFinite(value)
  ? `${value.toFixed(1)} °C`
  : "Chưa có dữ liệu";
```

Khi vẽ chuỗi thời gian, giữ `null` thành khoảng trống. Các phép kiểm chéo dùng các giá trị có mặt. Tương quan để `null` khi số cặp hợp lệ hoặc độ biến thiên chưa đủ để tính.

## Vị trí code và cách mở rộng

- [`__main__.py`](../../f1/src/f1/__main__.py) là lệnh chung.
- [`demo_stages.py`](../../f1/src/f1/demo_stages.py) điều phối bốn bước cho A–D, kiểm chứng chéo và ghi đầu ra.
- [`demo.py`](../../f1/src/f1/demo.py) chứa danh sách nguồn NASA và các quy tắc biến đổi riêng của từng bộ.
- [`disasters.py`](../../f1/src/f1/disasters.py) chuẩn hóa danh mục C và tạo thống kê ba địa phương cùng bảng ảnh hưởng Yagi.
- [`disaster_sources.py`](../../f1/src/f1/disaster_sources.py) tải, đọc và kiểm nguồn của danh mục C trước khi ghi snapshot.
- [`io.py`](../../f1/src/f1/io.py) tải qua `curl` và ghi file qua file tạm rồi thay thế.
- [`archive.py`](../../f1/src/f1/archive.py) cung cấp truy vấn POWER Monthly và xử lý snapshot khí hậu.
- [`vietnam.py`](../../f1/src/f1/vietnam.py) kiểm, đóng gói kho Việt Nam và xuất mẫu theo tọa độ.

Dùng [profile tháng theo cấu hình](pipeline-nasa-power.md) khi thêm tọa độ hoặc đổi kỳ POWER Monthly. Profile đó dùng chung lệnh `src.f1` và xuất schema có trạng thái thiếu cho từng chỉ tiêu. Profile demo giữ tọa độ, kỳ, ngưỡng và schema A–D theo yêu cầu bàn giao hiện tại. Bộ A mở rộng chạy bằng `run --profile a34`, kho Việt Nam chạy bằng `run --profile vietnam`. Thêm `--offline` vào lệnh `run` để chỉ dùng raw đã lưu.
