# Pipeline dữ liệu tháng NASA POWER

Pipeline tải NASA POWER Monthly theo danh sách tọa độ, chuẩn hóa lịch tháng và xuất JSON/CSV để tích hợp app. Thêm điểm, đổi kỳ hoặc chọn biến bằng file cấu hình. [NASA POWER Monthly API](https://power.larc.nasa.gov/docs/services/api/temporal/monthly/)

## Cấu hình đầu vào

Sao chép [cấu hình mẫu](../../f1/config/power_monthly.example.json) và sửa các trường sau:

| Trường | Giá trị |
|---|---|
| `start_month`, `end_month` | Khung tháng cần xuất, dạng `YYYY-MM`, bao gồm hai đầu mốc. |
| `as_of` | Ngày chốt bản dữ liệu, dạng `YYYY-MM-DD`. Tháng chứa ngày này và các tháng sau vẫn có dòng nhưng mang trạng thái chưa hoàn tất. Giữ ngày chốt khi cần tái lập cùng một bản. |
| `metrics` | Các mã hỗ trợ gồm `T2M` (nhiệt độ), `PRECTOTCORR` (mưa), `WS10M` (gió) và `ALLSKY_SFC_SW_DWN` (bức xạ). Khi chọn mưa, pipeline xuất thêm tổng mưa tháng theo số ngày thực tế. |
| `locations` | Danh sách `id`, `latitude`, `longitude`. ID duy nhất, bắt đầu bằng chữ thường, dùng chữ thường, số, gạch ngang hoặc gạch dưới. Tọa độ dùng số thập phân, vĩ độ trước và kinh độ sau. |

Cấu hình mẫu có hai điểm Hà Nội và Tokyo. Để lấy một điểm mới, thêm một phần tử vào `locations`, ví dụ `{"id":"sydney","latitude":-33.87,"longitude":151.21}`. Dữ liệu trả về là giá trị ô lưới tại điểm yêu cầu.

## Chạy từng bước hoặc chạy trọn quy trình

Cần Python **3.10+**, `curl` và mạng cho lần tải đầu. Chạy từ gốc repo trong PowerShell.

```powershell
Push-Location .\f1
$config = '.\config\power_monthly.example.json'
$output = '..\local-private\f1-data\pipeline\sample'

# Chạy trọn quy trình
python -X utf8 -B -m src.f1 run --config $config --output $output
Pop-Location
```

Nếu dùng môi trường ảo của repo, thay `python` bằng `& .\.venv\Scripts\python.exe` khi đang ở thư mục `f1`.

Muốn kiểm tra riêng từng bước, chạy các lệnh sau trong `f1/` với hai biến trên:

```powershell
python -X utf8 -B -m src.f1 fetch --config $config
python -X utf8 -B -m src.f1 clean --config $config
python -X utf8 -B -m src.f1 validate --config $config
python -X utf8 -B -m src.f1 export --config $config --output $output
```

| Bước | File code | Kết quả |
|---|---|---|
| Cấu hình | [`config.py`](../../f1/src/f1/config.py) | Kiểm mã điểm, tọa độ, ngày, tham số và lập trục tháng. |
| Tải | [`fetch.py`](../../f1/src/f1/fetch.py) | Kiểm cấu trúc phản hồi, tọa độ, đơn vị và kỳ NASA trả về. Lưu raw theo SHA-256 của URL, dùng chung cache cho truy vấn trùng. |
| Làm sạch | [`clean.py`](../../f1/src/f1/clean.py) | Tạo một dòng cho mỗi cặp điểm–tháng, gắn trạng thái riêng cho từng chỉ tiêu, tính tổng mưa. |
| Kiểm định | [`validate.py`](../../f1/src/f1/validate.py) | Đối chiếu từng bản ghi với raw, kiểm checksum, thứ tự khóa tháng, đơn vị và phép quy đổi. Báo số ô theo từng trạng thái. |
| Xuất | [`export.py`](../../f1/src/f1/export.py) | Kiểm JSON/CSV tương đương, lưu cả hai theo phiên bản và cập nhật `latest.json` sau cùng. |

Thêm `--refresh` vào `fetch` hoặc `run` để tải lại. Nếu tải riêng rồi raw thay đổi, chạy lại `clean` trước khi kiểm định và xuất. Mặc định raw và file trung gian nằm trong `local-private/f1-data/pipeline/`. Nếu dùng `--work-dir` riêng, truyền cùng đường dẫn ở mọi bước. Lỗi tải hoặc phản hồi sai cấu trúc làm lệnh dừng và báo lỗi. Nếu đã có bản bàn giao, app vẫn đọc được bản mà `latest.json` đang trỏ tới.

## Quy ước giá trị thiếu cho app

Mỗi dòng JSON có `location_id`, `month`, `values` và `status`. Một chỉ tiêu thiếu vẫn giữ tên trường và mang `null`. CSV dùng ô trống và cột `<tên_trường>_status`. Số **0** hợp lệ vẫn giữ nguyên.

| Trạng thái | Nghĩa | Cách hiển thị |
|---|---|---|
| `ok` | Có giá trị số | Hiển thị số và đơn vị, kể cả 0. |
| `out_of_coverage` | Tháng trước độ phủ của biến | Hiển thị “Ngoài độ phủ nguồn”. |
| `incomplete_period` | Tháng đang diễn ra hoặc sau ngày chốt | Hiển thị “Kỳ chưa hoàn tất”. |
| `missing_source` | Thiếu khóa tháng, giá trị rỗng hoặc gặp mã thiếu như `-999` | Hiển thị “Chưa có dữ liệu”. |
| `invalid_source` | Giá trị sai kiểu, vô hạn hoặc âm với biến mưa, gió hoặc bức xạ | Hiển thị “Dữ liệu chưa hợp lệ”. |

App tải **`latest.json`** rồi đọc URL tương đối trong `files["app.json"].path` để lấy đúng phiên bản. Cùng thư mục phiên bản có `data.csv` và `report.json`. Khi vẽ biểu đồ, giữ tháng thiếu thành khoảng trống. Với giá trị ở giao diện, kiểm kiểu trước khi định dạng:

```javascript
const value = row?.values?.temperature_c;
const messages = {
  out_of_coverage: "Ngoài độ phủ nguồn",
  incomplete_period: "Kỳ chưa hoàn tất",
  invalid_source: "Dữ liệu chưa hợp lệ",
};
const label = typeof value === "number" && Number.isFinite(value)
  ? `${value.toFixed(1)} °C`
  : (messages[row?.status?.temperature_c] ?? "Chưa có dữ liệu");
```

Muốn đưa một bản lên Git để app truy cập, chọn `--output` trong thư mục bàn giao hoặc chép cả `latest.json` và thư mục phiên bản tương ứng. Giữ nguyên cấu trúc đường dẫn tương đối. Khi cập nhật, tải lên thư mục phiên bản trước rồi cập nhật `latest.json`.

## Quan hệ với các bộ F1 hiện có

Profile `monthly` dùng schema tháng nhiều tọa độ. Cùng CLI có [profile `demo` cho A–D](pipeline-f1.md), gồm tổng hợp năm, đếm ngày nắng nóng, ghép IMERG cho Yagi và đọc GISTEMP. Profile `vietnam` kiểm và đóng gói snapshot Việt Nam.
