# Dữ liệu tháng theo yêu cầu Lê Sơn

## Phạm vi và kết quả

Ưu tiên NASA POWER cho nhiệt độ, mưa, tốc độ gió và bức xạ mặt trời.
Khoảng yêu cầu được hiểu là **1977–2026, gồm 50 năm lịch**, không phải 1976–2026 (51 năm).
Mỗi xã có 600 dòng tháng khi tra theo mã xã; tháng không có dữ liệu giữ `null`, không thay bằng 0.
Tháng đang diễn ra và tháng tương lai cũng giữ `null` để tránh so sánh tháng chưa đủ ngày.

Địa bàn: 3.321 xã/phường/đặc khu thuộc 34 tỉnh/thành theo danh mục sau sắp xếp 2025.
Dùng tọa độ đại diện từng đơn vị để gọi API, không tính trung bình theo polygon.
Nguồn danh mục và giấy phép nằm trong `f1/data/admin/SOURCE.md`.
Danh mục này là nguồn cộng đồng, chưa được đối soát toàn bộ với dữ liệu hành chính chính thức.

Mẫu đo gồm **toàn bộ 126 xã/phường Hà Nội và 99 xã/phường Bắc Ninh**,
không phải hai điểm đại diện cho hai tỉnh. Số liệu đo máy nằm trong
`f1/data/monthly/sample/report.json`. Báo cáo toàn quốc đã hoàn tất tại
`f1/data/monthly/vietnam/report.json`.

## Dung lượng JSON thực đo

Chỉ xuất JSON, không có database hay file nén. Ngưỡng lưu offline mặc định là 250 MiB,
có thể thay bằng `--budget-mb`.

| Phạm vi | Số xã | JSON |
|---|---:|---:|
| Hà Nội + Bắc Ninh | 225 | 347.081 byte (~347 KB) |
| Toàn bộ 34 tỉnh/thành | 3.321 | 8.289.593 byte (~8,29 MB) |

Mẫu được đo bằng cách serialize cùng schema JSON từ tập con hai tỉnh; chỉ giữ báo cáo mẫu
vì dữ liệu đã có trong file toàn quốc. Dung lượng trên dùng MB thập phân.
Có 3.256 tọa độ khác nhau và 282 chuỗi khí hậu khác nhau; các xã cùng chuỗi tham chiếu
qua `series_id`. Tương đương 1.992.600 dòng xã × tháng, không nhân bản chuỗi trong file.
Danh mục hành chính gốc thêm khoảng 2,73 MB.

Đã đối chiếu toàn bộ giá trị tháng sau chuyển định dạng, kiểm tra đủ mã 3.321 xã,
34 tỉnh và 600 tháng/xã. 10 kiểm thử đạt, gồm kiểm tra xuất JSON từ cache không gọi mạng.

## Trường dữ liệu và ý nghĩa

| Cột JSON | Nguồn / đơn vị | Ý nghĩa |
|---|---|---|
| `temperature_c` | NASA `T2M`, °C | Nhiệt độ 2 m trung bình tháng |
| `precipitation_mm_day` | NASA `PRECTOTCORR`, mm/ngày | Lượng giáng thủy trung bình ngày trong tháng |
| `wind_speed_m_s` | NASA `WS10M`, m/s | Tốc độ gió 10 m trung bình tháng |
| `solar_mj_m2_day` | NASA `ALLSKY_SFC_SW_DWN`, MJ/m²/ngày | Bức xạ sóng ngắn trung bình ngày trong tháng; không phải số ngày nắng |
| `precipitation_total_mm_derived` | Tính từ NASA, mm/tháng | Trung bình ngày × số ngày đúng của tháng; gần đúng do API làm tròn |

API trả thêm khóa `YYYY13` là giá trị năm. Script chỉ lấy tháng 01–12.
Giá trị thiếu `-999` được chuyển thành `null`. Không suy ra thiên tai từ mưa/gió trung bình tháng.
Các đơn vị đo được kiểm tra theo metadata API; nếu NASA đổi đơn vị, script dừng thay vì gán sai.

## Giới hạn 50 năm và sai khác nhiệt độ

Theo [NASA Monthly API](https://power.larc.nasa.gov/docs/services/api/temporal/monthly/),
khí tượng bắt đầu từ 1981, bức xạ từ 1984. Vì vậy không thể cung cấp đầy đủ 50 năm quan trắc
chỉ từ NASA POWER. Khoảng 1977–1980 và bức xạ 1977–1983 được giữ trống, có thể bổ sung
ERA5 bằng luồng riêng nếu cần; bộ NASA hiện tại không tự trộn nguồn.

Kiểm tra thực tế mẫu ngày 09/11/2026: khí tượng có giá trị từ 01/1981 đến 09/2026,
bức xạ từ 01/1984 đến 07/2026. Không dựa vào ngày cuối trong header để khẳng định dữ liệu đầy đủ:
header có thể kéo đến tháng 11 nhưng giá trị cuối là `-999`.
`report.json` ghi khoảng có giá trị theo từng chỉ tiêu; min/max không đảm bảo không có khoảng thiếu giữa chuỗi.

NASA trả `time_standard=LST` (giờ mặt trời địa phương) trong phản hồi tháng được kiểm tra.
Nhiệt độ tháng là giá trị tổng hợp cả tháng, không phải nhiệt độ lúc gọi API hay nhiệt độ một giờ cụ thể.
Do đó không so trực tiếp với OpenWeather hiện tại. Khi đối chiếu cần cùng tọa độ,
kỳ tổng hợp, độ cao, đơn vị và cách chia ngày/múi giờ.

Theo [phương pháp NASA](https://power.larc.nasa.gov/docs/methodology/), ô khí tượng
khoảng 0,5° vĩ độ × 0,625° kinh độ; ô bức xạ khoảng 1° × 1°.
Nhiều xã có cùng chuỗi dữ liệu là bình thường. Script gọi đúng tọa độ đã cung cấp,
không làm tròn về ô lưới tự suy đoán. Sau khi nhận phản hồi, chuỗi chuẩn hóa giống hệt nhau
được dùng chung qua SHA-256 để tiết kiệm dung lượng.

## Chạy tải online và sử dụng offline

Các script mới chỉ cần Python >=3.10 và `curl`, không cần API key hay cài thêm thư viện.
Chạy từ thư mục gốc repository:

```sh
# Đo hai tỉnh Hà Nội + Bắc Ninh
python f1/export_monthly_climate.py

# Tải toàn bộ Việt Nam; dùng lại cache từ mẫu
python f1/export_monthly_climate.py --provinces all --output f1/data/monthly/vietnam

# Chỉ dùng sau khi tải lại cache: xuất JSON không kết nối mạng
python f1/export_monthly_climate.py --provinces all --offline --output f1/data/monthly/vietnam

# Cập nhật dữ liệu mới từ nguồn (cache mặc định không tự hết hạn)
python f1/export_monthly_climate.py --provinces all --refresh --output f1/data/monthly/vietnam

# Kiểm thử
python -m unittest discover -s f1/tests -v
```

Đọc `climate.json` có sẵn không cần cache hay mạng. `--offline` là chế độ **xuất lại**
từ đầy đủ cache của lần tải trước; cache đã được dọn trong bản hiện tại.

Tối đa 5 kết nối đồng thời, timeout và retry có backoff. Cache JSON lưu URL, thời điểm tải,
header, đơn vị và phản hồi NASA. Nếu có điểm lỗi, giữ cache đã tải và ghi `errors.json`;
không thay thế file JSON cuối bằng bản thiếu. Chạy lại để tiếp tục. Không chạy hai tiến trình
cùng ghi một thư mục output/cache. Mạng yêu cầu proxy có thể cần bỏ `--noproxy '*'` trong script.

### Cấu trúc và cách đọc JSON

File chính: `f1/data/monthly/vietnam/climate.json`.

- `schema_version`: phiên bản định dạng (1).
- `metadata`: nguồn, khung năm, đơn vị và giới hạn dữ liệu.
- `columns`: tên các cột theo đúng thứ tự của mỗi dòng tháng.
- `locations`: mã xã/tỉnh, tọa độ, `series_id`, URL nguồn và thời điểm tải.
- `series`: ánh xạ `series_id` sang danh sách dòng tháng.

Mỗi dòng trong `series` có thứ tự:
`[month, temperature_c, precipitation_mm_day, wind_speed_m_s, solar_mj_m2_day, precipitation_total_mm_derived]`.
Mã hành chính giữ dạng chuỗi để không mất số 0 đầu; giá trị thiếu là `null`.

```python
import json
from pathlib import Path

archive = json.loads(Path('f1/data/monthly/vietnam/climate.json').read_text(encoding='utf-8'))
location = next(loc for loc in archive['locations'] if loc['ward_code'] == '00004')
months = [dict(zip(archive['columns'], row))
          for row in archive['series'][location['series_id']]]
print(location['ward_name'])
print([row for row in months if row['month'].startswith('2025-')])
```

Không lấy trung bình số học giữa các xã để gọi là trung bình toàn tỉnh: xã có diện tích khác nhau.
Muốn trung bình theo diện tích cần ranh giới và trọng số giao với ô dữ liệu.

### Tọa độ ngoài Việt Nam

NASA dùng cùng API toàn cầu. Ví dụ lấy một điểm, không cần tải thế giới về local:

```sh
curl --fail --get 'https://power.larc.nasa.gov/api/temporal/monthly/point' \
  --data-urlencode 'parameters=T2M,PRECTOTCORR,WS10M,ALLSKY_SFC_SW_DWN' \
  --data-urlencode 'community=AG' \
  --data-urlencode 'latitude=35.68' --data-urlencode 'longitude=139.69' \
  --data-urlencode 'start=1981' --data-urlencode 'end=2026' \
  --data-urlencode 'format=JSON' -o tokyo-monthly.json
```

Có thể truyền `--locations` với JSON cùng schema danh mục để dùng pipeline cho địa bàn khác.
Thay đổi khoảng năm bằng `--start-year`/`--end-year`; báo cáo và URL cache mang đúng khoảng yêu cầu.

## Số giờ nắng và “ngày nắng”

NASA POWER tháng không cung cấp số ngày nắng trực tiếp. Bổ sung một luồng riêng từ
[Open-Meteo Historical Weather / ERA5](https://open-meteo.com/en/docs/historical-weather-api),
lấy `sunshine_duration` theo ngày (giây) rồi tổng hợp số giờ nắng theo tháng.
ERA5 được chọn cố định để tránh thay mô hình giữa các thập kỷ.

```sh
python f1/export_sunshine.py --lat 21.03 --lon 105.85 --end-date 2026-10-31

# Chỉ dùng nếu nghiệp vụ quy ước “ngày nắng” là ngày có >=6 giờ nắng
python f1/export_sunshine.py --lat 21.03 --lon 105.85 --end-date 2026-10-31 \
  --sunny-day-hours 6 --output local-private/archive/sunshine/hanoi-threshold-6h.json
```

Mặc định không tự gán ngưỡng ngày nắng. File mẫu lưu local ở `local-private/archive/sunshine/hanoi.json`,
gồm 598 tháng từ 01/1977–10/2026 tại một điểm Hà Nội; chưa tải chỉ tiêu này cho toàn bộ xã.
Phản hồi ngày gốc lưu tại `local-private/archive/sunshine/hanoi.daily.json`, SHA-256 ghi trong file tháng. Tháng thiếu ngày hoặc giá trị
sẽ không có tổng/trung bình giả. Đây là thời lượng nắng mô hình, không phải quan trắc trạm.

## Lịch sử thiên tai

Đã tách riêng **116 sự kiện sạt lở tại Việt Nam, 07/05/2007–18/10/2016** từ
[NASA Global Landslide Catalog legacy export](https://data.nasa.gov/dataset/global-landslide-catalog-export-f07b6).
Nguồn tải là CSV của NASA, đầu ra là JSON. File `f1/data/disasters/nasa_glc_vietnam.json` giữ nguồn tin, ngày sự kiện,
tọa độ, độ chính xác vị trí và tên hành chính lịch sử. `metadata.json` ghi nguồn và SHA-256.

```sh
python f1/export_landslides.py
# Hoặc xử lý bản CSV NASA đã tải
python f1/export_landslides.py --input /path/to/Global_Landslide_Catalog_Export_rows.csv
```

Đây là **bản xuất một lần**, không phải danh sách thiên tai cập nhật đến 2026 hay đầy đủ 50 năm.
Không có sự kiện trong bảng không có nghĩa là không xảy ra thiên tai.
Chưa tự gán sự kiện sang xã mới vì cần ranh giới và phải xét độ chính xác tọa độ.

Dữ liệu sạt lở cập nhật có thể xuất từ [NASA COOLR](https://gpm.nasa.gov/applications/landslides/coolr).
Để có nhiều loại thiên tai hơn (bão, lũ, hạn hán…), xem
[EM-DAT Public Table](https://doc.emdat.be/docs/data-structure-and-content/emdat-public-table/):
mỗi dòng là sự kiện ảnh hưởng một quốc gia, không mặc định chi tiết tới xã.
Truy cập theo điều kiện của nguồn; pipeline hiện chưa tích hợp EM-DAT.
