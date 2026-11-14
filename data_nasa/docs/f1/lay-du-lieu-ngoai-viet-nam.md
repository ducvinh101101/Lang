# Lấy dữ liệu khí hậu ngoài Việt Nam

Profile `vietnam` với `--point` lấy dữ liệu tháng của **một điểm theo tọa độ** từ NASA POWER Monthly và xuất JSON/CSV cùng cấu trúc với kho Việt Nam. Giá trị thuộc ô lưới chứa điểm yêu cầu. [NASA POWER Monthly API](https://power.larc.nasa.gov/docs/services/api/temporal/monthly/)

## Chạy bằng PowerShell

Cần Python **3.10 trở lên**, `curl` trên `PATH` và kết nối mạng cho lần tải đầu tiên. Chạy từ thư mục gốc repo:

```powershell
Push-Location .\f1
python -X utf8 -B -m src.f1 run --profile vietnam --point tokyo 35.68 139.69
Pop-Location
```

Nếu dùng môi trường ảo trong `f1/.venv/`, thay `python` trong lệnh bằng `& .\.venv\Scripts\python.exe`.

Thứ tự tham số sau `--point` là **`ID LAT LON`**:

| Tham số | Cách nhập | Ví dụ |
|---|---|---|
| `ID` | Mã điểm bắt đầu bằng chữ thường, dùng chữ thường, số, dấu gạch dưới hoặc gạch ngang. Dùng mã riêng cho mỗi tọa độ. | `tokyo` |
| `LAT` | Vĩ độ từ −90 đến 90. Bắc dương, Nam âm. | `35.68` |
| `LON` | Kinh độ từ −180 đến 180. Đông dương, Tây âm. | `139.69` |

Dùng dấu chấm cho phần thập phân. Ví dụ Sydney dùng `--point sydney -33.87 151.21`. Lệnh tự tải nếu mã điểm chưa có raw. Nếu chạy lại cùng mã và tọa độ, lệnh dùng file raw đã lưu. Thêm `--offline` để chỉ dùng raw đã lưu. Để kiểm một lần tải mới mà vẫn giữ bản cũ, đặt mã mới, ví dụ `tokyo_refresh`.

## Phạm vi và đơn vị

Script gửi truy vấn POWER Monthly từ **1981 đến 2026**. Đầu ra giữ trục **600 tháng từ 01/1977 đến 12/2026**. Kỳ trước độ phủ nguồn, kỳ chưa hoàn tất và kỳ chưa có số liệu được biểu diễn bằng `null` trong JSON và ô rỗng trong CSV. Chuẩn thời gian của mẫu là **LST**.

| Cột đầu ra | Ý nghĩa |
|---|---|
| `month` | Tháng dạng `YYYY-MM` |
| `temperature_c` | Nhiệt độ trung bình ở độ cao 2 m, °C (`T2M`) |
| `precipitation_mm_day` | Lượng mưa trung bình ngày trong tháng, mm/ngày (`PRECTOTCORR`) |
| `wind_speed_m_s` | Tốc độ gió ở độ cao 10 m, m/s (`WS10M`) |
| `precipitation_total_mm_derived` | Tổng mưa tháng quy đổi bằng mưa trung bình ngày nhân số ngày thực tế của tháng, mm |

## Đọc và kiểm tra đầu ra

- **`f1/data/deliverables/vn/online/<id>/vn_monthly.json`** chứa `data_card`, điểm trong `locations`, thứ tự cột trong `columns` và chuỗi tháng trong `series`.
- **`locations.csv`** chứa tọa độ, nguồn và `series_id`. Nối với **`series.csv`** bằng `series_id` để đọc các tháng.
- **`local-private/f1-data/vn/raw/<id>-2026.json`** là phản hồi gốc. **`local-private/f1-data/vn/online/<id>/report.json`** ghi URL truy vấn, SHA-256 và độ phủ từng chỉ tiêu.

Từ gốc repo, kiểm tra mẫu Tokyo:

```powershell
$out = '.\f1\data\deliverables\vn\online\tokyo'
Import-Csv "$out\locations.csv" | Format-List latitude, longitude, time_standard
Import-Csv "$out\series.csv" | Where-Object month -eq '2026-09' | Format-List
$report = Get-Content -Raw '.\local-private\f1-data\vn\online\tokyo\report.json' | ConvertFrom-Json
$report.coverage.temperature_c | Format-List first_month, last_month, valid_location_months
```

Đối chiếu tọa độ trả về, đơn vị và tháng cuối có giá trị. Mẫu Tokyo đã lưu có **549 tháng có số liệu** từ **01/1981 đến 09/2026** cho nhiệt độ, mưa và gió. Dòng thông báo `600 months` là số kỳ trong trục lịch. [File mẫu Tokyo](../../f1/data/deliverables/vn/online/tokyo/) · [Tài liệu kỹ thuật F1](../../f1/README.md)
