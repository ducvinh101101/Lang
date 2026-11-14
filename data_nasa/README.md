# Data NASA

Repo lưu dữ liệu và công cụ cho ba chức năng của app:

- **F1 · Lịch sử thời tiết và thiên tai:** khí hậu theo tháng và danh mục thiên tai Việt Nam. Nguồn chính là NASA POWER, GPM IMERG Final Daily, GISTEMP v4, NASA GDIS, GLC và EONET.
- **F2 · Khám phá vũ trụ:** sự thật, truyện, minigame và âm thanh NASA trong [assets/content/](assets/content/).
- **F3 · Khám phá địa lý bằng tay:** độ cao, độ dốc, mặt nước và dân cư cho màn di tay đọc vùng, cùng chức năng quét mặt cắt địa hình.

## F1 — Lịch sử thời tiết và thiên tai

### Dữ liệu bàn giao

| Bộ | Phạm vi | Đường dẫn |
|---|---|---|
| A · Khí hậu demo | Nhiệt độ và lượng mưa theo tháng và năm tại 6 điểm, 1981–2025 | [A demo](f1/data/deliverables/demo/a_climate/provinces/) |
| A · Khí hậu mở rộng | 34 điểm đại diện cho 34 tỉnh/thành, 1981–2025. Mỗi tỉnh/thành có một cặp JSON/CSV. | [A mở rộng](f1/data/deliverables/a_34/provinces/) |
| B · Ngày nắng nóng | Số ngày đạt ≥35, ≥37 và ≥39 °C theo năm tại 6 điểm, 1981–2025 | [B](f1/data/deliverables/demo/b_heat_days/) |
| C · Thiên tai Việt Nam | Danh sách ưu tiên NASA từ GDIS, GLC và EONET. Danh mục mở rộng và thống kê theo năm có thêm DMC, DesInventar và hồ sơ bổ sung. | [Danh sách ưu tiên NASA](f1/data/deliverables/demo/c_disasters/events_nasa.json) · [Bộ C](f1/data/deliverables/demo/c_disasters/) |
| D · Nhiệt độ toàn cầu | Độ lệch nhiệt độ hằng năm so với trung bình 1951–1980, giai đoạn 1880–2025 | [D](f1/data/deliverables/demo/d_global_temp/) |
| Kho Việt Nam offline | Nhiệt độ, mưa và gió theo tháng tại 3.321 xã/phường/đặc khu. Khung 1977–2026, có giá trị từ 01/1981 đến 09/2026. | [Toàn quốc](f1/data/deliverables/vn/vietnam/) · [Hai tỉnh mẫu](f1/data/deliverables/vn/pilot/) |
| Mẫu tra cứu online | Một điểm ngoài Việt Nam tại Tokyo | [Tokyo](f1/data/deliverables/vn/online/tokyo/) · [Hướng dẫn lấy điểm khác](docs/f1/lay-du-lieu-ngoai-viet-nam.md) |

### Thiên tai theo tháng

Khi phát lịch sử theo tháng (khoảng thời gian ≤ 3 năm), app xếp sự kiện theo trường `start_month` (`YYYY-MM`) và sắp từ nhẹ đến nặng theo `severity_1_10`.

- Hồ sơ có ngày: `start_month` lấy từ `start_date`.
- 131 hồ sơ NASA GDIS chỉ có năm. 44 hồ sơ đã được bổ sung tháng, cách xác định ghi ở `date_basis`, căn cứ ghi ở `date_reference`:
  - `glide_same_emdat_number` (22 hồ sơ): số GLIDE trùng mã EM-DAT mà GDIS dùng, ví dụ `gdis-1997-0267` → `ST-1997-000267-VNM`, tháng 11/1997. Nguồn là [glide_vietnam.json](f1/data/disasters/glide_vietnam.json).
  - `unique_matching_record_month` (22 hồ sơ): chỉ có đúng một tháng trong các hồ sơ DMC/DesInventar cùng năm, cùng loại, cùng tỉnh. Ngày 1/1 bị bỏ qua vì thường là ngày điền tạm.
- 87 hồ sơ còn lại vẫn `date_basis = source_year_only` và `start_month = null`. Ở chế độ theo tháng, app nên phát các hồ sơ này ở cuối năm kèm câu "trong năm", không gán tháng.
- Động đất (130 trận, có độ lớn) nằm trong [danh mục mở rộng](f1/data/deliverables/demo/c_disasters/events.json), không nằm trong danh sách ưu tiên NASA.

Build lại bộ C từ nguồn trong repo: `cd f1 && PYTHONPATH=src python -m f1.disasters`. Cập nhật bản lưu GLIDE: `PYTHONPATH=src python -m f1.disaster_sources --glide`.

### Kiểm định

- JSON và CSV của demo A–D được đối chiếu từng bản ghi. Danh sách ưu tiên NASA nằm trong ngân sách 1 MB của gói demo (hiện 961.829 byte). Danh mục mở rộng và bảng năm được tính riêng.
- A mở rộng có **34 cặp JSON/CSV khớp**, tổng **19.890 bản ghi**. Bộ này lưu riêng với demo.
- Kho Việt Nam có **145 chuỗi tháng dùng chung**, liên kết với địa bàn bằng `series_id`. Tổng JSON và hai CSV là **13.892.374 byte**. Kỳ thiếu dùng `null` trong JSON và ô rỗng trong CSV.
- Kiểm chéo mưa Yagi cho tương quan Pearson **0,769**. Ngày mưa cực đại của POWER và IMERG lệch **2 ngày**, vượt kỳ vọng tối đa 1 ngày.
- Test: `cd f1 && python -m pytest -q tests`. Test `test_published_disaster_files_match_sources` báo lỗi nếu file bộ C lệch với nguồn.

Xem [tài liệu kỹ thuật F1](f1/README.md) để biết tham số, đơn vị, lệnh tái tạo và giới hạn kiểm định. [Nguồn dữ liệu demo](f1/data/deliverables/demo/credits.csv)

[Pipeline F1 A–D](docs/f1/pipeline-f1.md) hướng dẫn chạy từ tải nguồn đến bàn giao. [Profile NASA POWER theo cấu hình](docs/f1/pipeline-nasa-power.md) hướng dẫn thêm tọa độ và xuất dữ liệu tháng cho app.

---

## F2 — Khám phá vũ trụ

| File | Nội dung |
|---|---|
| [facts.json](assets/content/facts.json) | 157 sự thật về 11 thiên thể và hệ Mặt Trời, tách từng câu từ NASA Space Place |
| [planets_extended.json](assets/content/planets_extended.json) | Thông số 11 thiên thể, chia 10 nhóm |
| [fact.md](assets/content/fact.md) | Bản gốc đã dịch của NASA Space Place, đầu vào cho `facts.json` |
| `assets/content/*_story/`, `*_game/` | Truyện và minigame. Âm thanh NASA ở [assets/content/nasa/](assets/content/nasa/) |

**Khẩu lệnh "sự thật thú vị về <hành tinh>":** tra tên tiếng Việt trong `aliases_vi` để lấy `id`, rồi chọn ngẫu nhiên một phần tử của `planets[id].facts` và đọc `text`. Nên ưu tiên `kind = "bullet"` vì câu ngắn, hợp để đọc. Mỗi sự thật có `source_urls` để ghi nguồn.

Build lại sau khi sửa `fact.md`: `python build_facts.py`. Script bỏ chú thích ảnh, câu điều hướng web, câu chỉ có nghĩa khi nhìn hình và phương án câu đố. Nội dung trùng giữa hai lần cào (có và không có `/en/`) được gộp, giữ cả hai link.

---

## F3 — Khám phá địa lý bằng tay

Làm theo khuôn nhánh F2: **crawl** tải từ nguồn chính thức vào `raw/`, sau đó **build** xuất `data_touch.json` và thư mục `touch/` cho app.
`build_f3.py` không dùng dữ liệu giả: script từ chối chạy nếu chưa có `raw/manifest.json` do `crawl_f3.py` ghi.

### Tương tác

| Khi di tay | Âm thanh / rung | Lớp dữ liệu |
|---|---|---|
| Đất càng cao | Nốt sáo càng cao (ngũ cung, 0 m → 2.000 m) | `elev` |
| Địa hình càng dốc | Rung ngắn 15–60 ms, càng dốc càng mạnh. Dưới 2° không rung. Rung 150 ms dành riêng cho lúc vượt biên giới. | `slope` |
| Qua sông, hồ lớn | Tiếng nước róc rách, đọc "Sông hồ". Ngoài khơi là tiếng sóng biển. | `water` (ô ≥ 50% mặt nước) |
| Qua vùng dân cư (lớp dân cư) | Tiếng xe chạy qua, càng đông dân càng nhiều xe | `pop` |

**Quét mặt cắt địa hình** (nút biểu đồ trên thanh công cụ, hoặc mở `ProfileScanPage`):

1. Lấy bản đồ độ cao của khu vực đang mở (cả nước hoặc một tỉnh).
2. Lát quét đi từ Bắc xuống Nam, sau đó từ Tây sang Đông. Màn hình vẽ vạch quét trên bản đồ và mặt cắt độ cao của lát đang quét.
3. Nốt sáo theo độ cao trung bình phần đất liền của lát; lát toàn biển phát tiếng sóng.
4. Mỗi lượt quét tối đa 8 giây. Hết mỗi lượt, app đọc vị trí của lát cao nhất. Chạm hai lần để quét lại.

### Nguồn

| Lớp | Nguồn | Cách tải |
|---|---|---|
| Ranh giới 34 tỉnh, 3.321 xã | GitHub `thanglequoc/vietnamese-provinces-database`, bản phát hành mới nhất có `vn_provinces_wards_geojson*.zip`. Từ v4.x file nằm trong mã nguồn (`json/`), không còn là tệp đính kèm. | GitHub, không cần tài khoản |
| Độ cao, độ dốc | NASA SRTMGL30 v002, LP DAAC. Độ dốc tính từ chính dữ liệu độ cao. | NASA Earthdata (`earthaccess`), cần tài khoản Earthdata |
| Mật độ dân số | NASA SEDAC GPWv4 Population Density rev11, năm 2020, 2,5 phút cung | NASA Earthdata, cùng tài khoản |
| Mặt nước (sông, hồ) | NASA SEDAC GPWv4 Land and Water Area rev11, diện tích nước, 2,5 phút cung | NASA Earthdata, cùng tài khoản |

### Chạy

```
pip install -r requirements.txt
python crawl_f3.py        # lần đầu hỏi tài khoản Earthdata (tạo tại https://urs.earthdata.nasa.gov), lưu vào ~/.netrc
python build_f3.py        # thêm --csv-all nếu cần CSV cho cả 34 tỉnh
python check_points.py    # kiểm 10 điểm mẫu đúng như cách app đọc
```

Tải lại một nguồn: `python crawl_f3.py --only boundaries` (hoặc `srtm`, `gpw`, `water`).

### Kết quả

```
raw/manifest.json      link gốc, bản phát hành, ngày tải, kích thước, SHA-256 của từng file đã tải
data_touch.json        mục lục: các cấp bản đồ, link file, thẻ dữ liệu, nguồn, kết quả kiểm tra (qc)
touch/vn/              cả nước: ids.png elev.png slope.png water.png pop.png basemap.png grid.json regions.json
touch/p01 … p34/       từng tỉnh: như trên, wards.json thay cho regions.json
touch/credits.csv      ghi công (file, nguon, link, ngay_tai, ghi_cong, audio_kind)
exports/cells_vn.csv   mỗi ô một dòng: toạ độ, mã vùng, tên, độ cao, độ dốc, tỉ lệ mặt nước, dân số, cờ kiểm tra
```

Mã hoá ảnh lớp (1 byte, 255 = không có số liệu): `elev` 12,5 m/bậc; `slope` 0,25°/bậc; `water` 0,004/bậc (tỉ lệ 0–1); `pop` thang log. Thông số đầy đủ ở mục `layers` của `grid.json`.

Trong `grid.json`, mỗi ảnh có trường `url`. Đặt `TOUCH_BASE_URL` (ví dụ link raw GitHub của nhánh) trước khi build để link thành địa chỉ đầy đủ.
Ngày tải trong thẻ dữ liệu lấy tự động từ `raw/manifest.json`.

### Xử lý đặc biệt

- **Hoàng Sa, Trường Sa**: là đặc khu nằm ngoài khung bản đồ. Script tự nhận ra, lấy vĩ độ **từ ranh giới thật** để đặt lên dải bên phải, và ghi vào `wards.json` với `"offshore": true`. Bản đồ cấp 2 của Đà Nẵng, Khánh Hòa chỉ vẽ phần đất liền nên không bị co nhỏ.
- **Độ cao, mặt nước, dân số** là trung bình thật của mọi điểm nguồn trong ô.
- **Độ dốc** được tính ở độ phân giải gốc ~1 km rồi mới lấy trung bình theo ô, nên phản ánh địa hình gồ ghề thật. Nếu tính từ độ cao đã trung bình, địa hình sẽ bị làm phẳng.
- **Xã nhỏ hơn một ô** (ví dụ phường trung tâm TP.HCM): lưới cấp 2 tự tăng từ 256 lên 384/512/768/1024 ô cho đến khi mọi xã đều có ô riêng.

### Kiểm tra trước khi giao cho lập trình

Xem dòng `CẢNH BÁO` khi chạy `build_f3.py` và mục `qc` trong `data_touch.json`. Cần đạt:
- đủ 34 tỉnh, 3.321 xã, có đủ Hoàng Sa và Trường Sa;
- ô cao nhất ở vùng Hoàng Liên Sơn;
- ô dốc nhất ở vùng núi;
- `touch/` dưới 3 MB.

Chạy `check_points.py`: dòng `XEM` ở mũi đất, đảo nhỏ rơi ra biển ở ô 5 km là bình thường.

### Việc vẫn phải làm tay

1. Điền `merged_from` và `intro_vi` cho 34 tỉnh trong `touch/vn/regions.json` (theo bảng Viet Nam News, đối chiếu nghị quyết). `build_f3.py` ghi đè file này, nên điền sau lần build cuối.
2. Thu giọng thật cho tên 34 tỉnh (tên xã dùng máy đọc).

### Ghép vào app Flutter

1. Chép `flutter/lib/touch/` vào `lib/touch/`; chép `touch/` vào `assets/touch/` của app.
2. Thêm thư viện và assets theo [flutter/pubspec_snippet.yaml](flutter/pubspec_snippet.yaml) (`python print_assets.py` in danh sách thư mục).
3. Mở màn: `Navigator.push(context, MaterialPageRoute(builder: (_) => const TouchMapPage()));`
4. Chép `flutter/test/touch_rules_test.dart` vào `test/`, chạy `flutter analyze` và `flutter test`. Sau đó chạy trên điện thoại thật và thử TalkBack theo file 6 mục 7.
5. Web: `flutter build web`. Trên iPhone, bản web không rung được. iOS không chỉnh được cường độ rung, nên app dùng 3 mức rung có sẵn.

### File

```
crawl_f3.py                     tải dữ liệu thật + ghi manifest
build_f3.py                     xử lý thành data_touch.json, touch/, exports/
touchmap.py                     thư viện: lưới, tô ranh giới, độ dốc, tỉ lệ mặt nước, trung bình ô, mã hoá, đọc DEM/GeoTIFF
check_points.py                 kiểm 10 điểm mẫu
print_assets.py                 danh sách assets cho pubspec.yaml
flutter/lib/touch/
  touch_rules.dart              luật đổi số liệu thành âm thanh / rung (thuần Dart, có test)
  touch_map.dart                đọc grid.json + PNG, tra giá trị theo ô, lấy mặt cắt
  touch_sound.dart              tạo âm (sáo, sóng, nước, xe), rung, đọc tiếng Việt
  finger_reader.dart            xử lý ngón tay
  touch_map_page.dart           màn di tay đọc vùng
  profile_scan.dart             màn quét mặt cắt địa hình
flutter/test/touch_rules_test.dart
```
