# Dữ liệu thời tiết F1

Đầu ra JSON và CSV nằm trong [`data/deliverables/`](data/deliverables/). Dữ liệu POWER được lấy tại tọa độ đại diện theo ô lưới. Mã hành chính lưu dạng chuỗi để giữ số 0 đầu.

Ba thư mục còn lại chứa đầu vào và báo cáo kiểm định. [`data/admin/`](data/admin/) lưu danh mục mã và tọa độ hành chính. [`data/disasters/`](data/disasters/) lưu bản trích sạt lở NASA GLC, metadata và snapshot đa nguồn dùng để tái tạo bộ C. [`data/monthly/`](data/monthly/) lưu snapshot khí hậu đầu vào của kho Việt Nam, có thêm bức xạ mặt trời, và các báo cáo thử nghiệm hoặc toàn quốc.

```text
data/deliverables/
├── demo/
│   ├── a_climate/provinces/    # A · 6 tỉnh/thành, một cặp file mỗi tỉnh
│   ├── b_heat_days/            # B · Số ngày nắng nóng
│   ├── c_disasters/            # C · Danh mục thiên tai, thống kê và hồ sơ Yagi
│   ├── d_global_temp/          # D · Dị thường nhiệt toàn cầu
│   └── credits.csv            # Nguồn và đường dẫn file tương đối trong demo/
├── a_34/provinces/             # A mở rộng · một cặp file mỗi tỉnh/thành
└── vn/
    ├── vietnam/                # Kho offline toàn quốc
    ├── pilot/                  # Gói riêng Hà Nội, Bắc Ninh, Đà Nẵng và Lâm Đồng
    └── online/                 # Mẫu truy vấn ngoài Việt Nam
```

## Demo A–D

| Bộ | Nguồn và thông số | Phạm vi và đầu ra |
|---|---|---|
| **A · Khí hậu** | POWER Monthly. `T2M` (°C), `PRECTOTCORR` (mm/ngày) và tổng mưa kỳ (mm). | 6 điểm, 1981–2025. Mỗi điểm có 540 dòng tháng và 45 dòng năm. [`demo/a_climate/provinces/`](data/deliverables/demo/a_climate/provinces/) |
| **B · Ngày nắng nóng** | POWER Daily. Đếm lũy tích số ngày `T2M_MAX` đạt ≥35, ≥37 và ≥39 °C. | Cùng 6 điểm, 1981–2025. 98.616 giá trị ngày nguồn, 270 dòng điểm–năm. [JSON](data/deliverables/demo/b_heat_days/heat_days.json) · [CSV](data/deliverables/demo/b_heat_days/heat_days.csv) |
| **C · Thiên tai Việt Nam** | DMC, DesInventar Việt Nam, NASA SEDAC GDIS, NASA GLC và hồ sơ bổ sung. POWER và IMERG cung cấp chuỗi mưa/gió cho Yagi. | Danh mục theo năm và nguồn, thống kê Hà Nội, Lâm Đồng và Đà Nẵng, kèm hồ sơ Yagi. [Các cặp JSON/CSV](data/deliverables/demo/c_disasters/) |
| **D · Nhiệt độ toàn cầu** | NASA GISTEMP v4, cột `J-D`. Độ lệch (°C) so với trung bình 1951–1980. | 146 dòng năm, 1880–2025. [JSON](data/deliverables/demo/d_global_temp/global_temp.json) · [CSV](data/deliverables/demo/d_global_temp/global_temp.csv) |

Tọa độ A/B theo thứ tự vĩ độ, kinh độ. Hà Nội (21.03, 105.85), Lào Cai (22.48, 103.97), Huế (16.46, 107.59), Đà Nẵng (16.05, 108.20), TP.HCM (10.78, 106.70), Cần Thơ (10.03, 105.78).

JSON chứa `records` tương ứng với các dòng CSV và `data_card` ghi nguồn, phạm vi, cách xử lý, giới hạn và checksum file gốc. Bộ A tính tổng mưa bằng giá trị mm/ngày nhân số ngày thực tế của kỳ. Tổng hợp năm ưu tiên `YYYY13` của POWER khi có giá trị hợp lệ. [`credits.csv`](data/deliverables/demo/credits.csv)

## Bộ C · Thiên tai Việt Nam

| Cặp JSON/CSV | Nội dung |
|---|---|
| [events](data/deliverables/demo/c_disasters/events.json) | Mỗi dòng là một hồ sơ đã chuẩn hóa theo nguồn, có mã, tên nếu có, loại, năm, ngày bắt đầu và căn cứ chọn ngày, vị trí chính, thang đo gốc, điểm 1–10 và URL nguồn. Lọc tháng theo phần `YYYY-MM` của `start_date` (`YYYY-MM-DD`), hoặc lọc năm theo `year`. Hồ sơ thiếu ngày để `null` trong JSON và ô trống trong CSV. Sự kiện Làng Nủ liên kết với Yagi bằng `related_event_id`. |
| [events_nasa](data/deliverables/demo/c_disasters/events_nasa.json) | Danh sách ưu tiên cho app. Có 301 hồ sơ, gồm 131 từ NASA SEDAC GDIS, 116 từ NASA GLC và 54 hồ sơ bão ghép được với NASA EONET. `nasa_evidence_kind` phân biệt danh mục và đường bão. Dùng `nasa_reference_url` để mở nguồn NASA, và `source_url` để mở nguồn của các trường sự kiện. |
| [annual_summary](data/deliverables/demo/c_disasters/annual_summary.json) | Đếm theo năm, nguồn, loại thiên tai và loại hồ sơ. `coverage_gap` đánh dấu năm chưa có bản ghi từ nguồn đã nhập. Hồ sơ chưa xác định được năm có `year = null`. |
| [province_summary](data/deliverables/demo/c_disasters/province_summary.json) | Thống kê hồ sơ tại Hà Nội, Lâm Đồng và Đà Nẵng theo nguồn. `province_basis` phân biệt địa danh có cấu trúc hoặc đã đối chiếu với địa danh chỉ được nhắc trong mô tả vùng. |
| [yagi/province_impact](data/deliverables/demo/c_disasters/yagi/province_impact.json) | Một dòng cho mỗi địa phương. Hà Nội có số đo được báo cáo. Lâm Đồng và Đà Nẵng có trạng thái `not_confirmed_in_sources` và số liệu trống. |
| [yagi/weather_daily](data/deliverables/demo/c_disasters/yagi/weather_daily.json) | Chuỗi NASA 01–15/09/2024 theo UTC. Gồm mưa và gió POWER tại Hà Nội, mưa ô IMERG gần Hà Nội, trung bình vùng và lượng mưa của ô lớn nhất từng ngày trong vùng hộp Bắc Bộ. |
| [yagi/rain_grid](data/deliverables/demo/c_disasters/yagi/rain_grid.json) | Lớp mưa NASA GPM IMERG Final Daily V07B gồm 28.875 ô–ngày, lưới 55 × 35 ô từ 01–15/09/2024 UTC. Tọa độ là tâm ô 0,1° × 0,1°. Dùng `precipitation_mm` để tô màu theo lượng mưa của ngày. [CSV theo ô–ngày](data/deliverables/demo/c_disasters/yagi/rain_grid.csv) |
| [yagi/eonet_track](data/deliverables/demo/c_disasters/yagi/eonet_track.json) | 24 mốc đường bão Yagi từ NASA EONET, nguồn gốc JTWC. Có thời điểm UTC, tọa độ tâm bão và gió theo knot. Mốc gió lớn nhất trong chuỗi là 130 knot. |

Pipeline gộp các địa điểm theo mã sự kiện trong GDIS và gộp các phiếu DesInventar theo số hồ sơ, loại và ngày. DMC có cả hồ sơ bão ngoài khơi và bản tin. Các tiêu đề nhận diện được là bản tin mang `record_kind = bulletin`. Số đếm theo nguồn có thể chồng lấn giữa các nguồn và chưa phản ánh toàn bộ số thiên tai thực tế. Địa danh giữ theo nguồn lịch sử. GDIS chỉ có năm nên `start_date` để trống cho các hồ sơ này.

Ảnh chụp hiện có **1.195 hồ sơ**. Trong đó có 744 hồ sơ DMC (39 bản tin), 200 nhóm từ 1.470 phiếu DesInventar, 131 sự kiện từ 591 địa điểm GDIS, 116 bản ghi NASA GLC và 4 hồ sơ bổ sung. Các hồ sơ xác định được năm trải từ **1971 đến 2026**. Còn 21 hồ sơ DMC chưa có ngày đáng tin cậy. Bản DMC mới nhất trong ảnh chụp có ngày **12/09/2026**. [Danh mục DMC](https://dmc.gov.vn/Default.aspx?lang=vi-VN&portalid=32&tabkey=thong-tin-thien-tai) · [DesInventar Việt Nam](https://desinventar-api.undrr.org/DesInventar/country_profile.jsp?countrycode=vnm&lang=EN) · [GDIS, Rosvold và Buhaug, CC BY 4.0](https://doi.org/10.7910/DVN/7UW1YK)

`severity_1_10` là điểm quy ước của dự án. Cấp gió duy trì 6–17 được đổi tuyến tính sang 1–10 và làm tròn. Yagi cấp 16 tương ứng 9/10. Độ lớn động đất được làm tròn đến số nguyên, tối thiểu 1. Khi thiếu thước đo hoặc chưa có phép quy đổi, dùng 3 và ghi `severity_method = default_no_comparable_metric`. Điểm này mô tả cường độ quy ước. Giá trị gốc lưu trong `metric_name`, `metric_value` và `metric_unit`.

EONET được truy vấn trong khung tọa độ bao quanh Việt Nam. Pipeline chỉ ghép bão khi tên và khoảng thời gian khớp với đúng một hồ sơ DMC. Vị trí tâm bão và cường độ lấy từ đường bão EONET, còn vùng ảnh hưởng và ngày bắt đầu của hồ sơ vẫn ghi theo DMC. Trong giao diện ưu tiên NASA, dùng `nasa_track_max_wind_kts` để hiển thị gió lớn nhất trong chuỗi EONET. [NASA EONET](https://eonet.gsfc.nasa.gov/docs/v3) · [Yagi EONET](https://eonet.gsfc.nasa.gov/api/v3/events/EONET_10740)

Để cập nhật nguồn DMC, GDIS, EONET và DesInventar, chạy từ thư mục `f1/`. Bước `collect` kiểm danh mục trước khi lưu snapshot. Bộ thu thập dùng lại cache. Để lấy một ảnh chụp mới, truyền `--source-cache` trỏ tới thư mục trống trong `local-private/`. Thêm `--offline` vào `collect` để tái tạo từ cache.

```powershell
python -X utf8 -B -m src.f1 collect --profile demo
python -X utf8 -B -m src.f1 run --profile demo --offline
```

Nguồn lịch sử và ảnh chụp danh mục dùng để tái tạo được lưu ở [data/disasters](data/disasters/). Hồ sơ bổ sung hoặc đối chiếu thủ công nằm trong [disaster_events.json](config/disaster_events.json).

## Bộ A mở rộng

**34 điểm đại diện cho 34 tỉnh/thành**, mỗi điểm có 540 tháng và 45 năm trong kỳ **1981–2025**. Nhiệt độ `T2M` và mưa `PRECTOTCORR` đều lấy từ [NASA POWER Monthly](https://power.larc.nasa.gov/docs/services/api/temporal/monthly/). Bộ mở rộng có **18.360 dòng tháng và 1.530 dòng năm**, lưu riêng với gói demo A–D.

Giữ nguyên sáu tọa độ demo. Mỗi tỉnh còn lại chọn tọa độ cấp xã gần nhất với trung vị vĩ độ và kinh độ của tỉnh trong danh mục kho Việt Nam. Đây là số liệu ô lưới tại điểm đại diện. Mỗi tỉnh có một cặp JSON/CSV mang tên tỉnh, ví dụ `ha_noi.json` và `ha_noi.csv`. JSON ghi tọa độ trong `location`, nguồn NASA trong `data_card` và dữ liệu trong `records`. CSV có khóa `province_code`, `period_type` và `period`. [File theo tỉnh/thành](data/deliverables/a_34/provinces/)

**34 cặp JSON/CSV khớp đủ 19.890 bản ghi**. Tổng JSON **4.069.584 byte**, tổng CSV **1.137.804 byte**. Có 157 giá trị tổng mưa năm ngoài khoảng rà soát (800, 4.000 mm). Giữ nguyên giá trị NASA và lưu cờ trong `local-private/f1-data/a-34-checks.json`.

## Kho khí hậu Việt Nam và mẫu online

- **Việt Nam.** 3.321 xã/phường/đặc khu thuộc 34 tỉnh/thành. Mỗi địa bàn có 600 khóa tháng trong khung 1977–2026. POWER Monthly cung cấp nhiệt độ (°C), mưa (mm/ngày và tổng mm/tháng) và gió 10 m (m/s). Có số liệu từ **01/1981 đến 09/2026**. Các kỳ thiếu lưu `null` trong JSON và ô rỗng trong CSV.
- **Cấu trúc.** JSON chứa `locations`, `series` và `columns`. Hai CSV nối bằng `series_id`. Có **145 chuỗi dùng chung**, tương ứng **1.992.600 cặp địa bàn–tháng** khi tra theo mã. [JSON toàn quốc](data/deliverables/vn/vietnam/vn_monthly.json) · [CSV địa bàn](data/deliverables/vn/vietnam/locations.csv) · [CSV chuỗi tháng](data/deliverables/vn/vietnam/series.csv)
- **Online.** Mẫu Tokyo (35.68, 139.69) dùng POWER Monthly theo LST, cùng cấu trúc JSON/CSV và có 549 tháng có số liệu. [Đầu ra Tokyo](data/deliverables/vn/online/tokyo/) · [Hướng dẫn lấy điểm khác](../docs/f1/lay-du-lieu-ngoai-viet-nam.md)

| Phạm vi đo | Địa bàn | JSON (byte) | Hai CSV (byte) |
|---|---:|---:|---:|
| Hà Nội | 126 | 143.813 | 269.165 |
| Bắc Ninh | 99 | 171.111 | 373.141 |
| [Đà Nẵng](data/deliverables/vn/pilot/da_nang/) | 94 | 189.226 | 428.322 |
| [Lâm Đồng](data/deliverables/vn/pilot/lam_dong/) | 124 | 323.251 | 775.736 |
| Toàn quốc | 3.321 | 4.566.740 | 9.325.634 |

## Kiểm định và mức đáp ứng

| Tiêu chí | Kết quả |
|---|---|
| Tính nhất quán demo A–D | **16 cặp JSON/CSV** khớp. Gói demo gồm danh sách ưu tiên NASA và lưới mưa Yagi có **946.207 byte JSON**. Hai file JSON `events` và `annual_summary` của danh mục mở rộng có tổng **1.112.449 byte**, được tính riêng. |
| Kiểm lưới mưa Yagi | Đủ 1.925 ô cho mỗi ngày, không thiếu giá trị. Ô gần Hà Nội, cực đại vùng và trung bình vùng khớp chuỗi theo ngày ở 4 chữ số thập phân. JSON lưới nén có **84.254 byte**. |
| Ngân sách offline Việt Nam | JSON và hai CSV toàn quốc tổng **13.892.374 byte**, dưới ngưỡng **250 MiB** của kho offline. |
| Kiểm nguồn và tọa độ kho Việt Nam | Đóng gói từ snapshot có sẵn. Hai điểm mẫu Hà Nội và Bắc Ninh khớp POWER tải mới khi so mốc truy vấn 2025 và 2026. Kiểm ranh giới tham chiếu ở 65 địa bàn Khánh Hòa và tải lại POWER cho **14 tọa độ đã sửa**. |
| Kiểm chéo mưa Yagi | Pearson **r = 0,769**. POWER đạt đỉnh **07/09**, IMERG **09/09**. Lệch **2 ngày**, vượt kỳ vọng tối đa **1 ngày**. |
| Kiểm chéo nhiệt độ và ngày nóng | **1/6** điểm POWER cùng chiều xu hướng GISTEMP trong 1981–2025. Tại **5/6** điểm, ít nhất 3 trong 5 năm nhiều ngày ≥35 °C nhất cũng thuộc nhóm 10 năm có nhiệt độ trung bình cao nhất. |
| Rà soát mưa năm | Có **23 trường hợp dưới 800 mm**. Giá trị nguồn được giữ nguyên và ghi cờ kiểm tra. |

## Tái tạo

Xem [pipeline F1 A–D](../docs/f1/pipeline-f1.md) để chạy từng bước, kiểm raw và xuất JSON/CSV.

Để thêm nhiều tọa độ, chọn kỳ và xuất dữ liệu tháng có trạng thái thiếu cho app, xem [pipeline NASA POWER theo cấu hình](../docs/f1/pipeline-nasa-power.md).

Cần Python **3.10+** và `curl` khi tải dữ liệu. Chạy từ gốc repo.

```powershell
Push-Location .\f1
python -X utf8 -B -m src.f1 run --profile demo
python -X utf8 -B -m src.f1 run --profile a34
python -X utf8 -B -m src.f1 run --profile vietnam
python -X utf8 -B -m src.f1 run --profile vietnam --point tokyo 35.68 139.69
Pop-Location
```

Các lệnh `run` dùng lại raw đã lưu và tải file còn thiếu. Thêm `--offline` để chỉ đọc file đã lưu. Kho Việt Nam dùng snapshot `data/monthly/vietnam/climate.json` làm đầu vào. File gốc và báo cáo kiểm tra lưu dưới `local-private/f1-data/`.
