# Máy hát Trái Đất: nghe các hình ảnh dữ liệu NASA

Thử thách NASA Space Apps 2026 số 14, *The Earth Information Jukebox*, đặt bài toán sau. Các hình ảnh trong Earth Information Center (EIC) của NASA rất đẹp nhưng chỉ dành cho người nhìn được. Hãy biến chúng thành âm thanh để người khiếm thị cũng hiểu được, và **giải thích vì sao chọn từng âm thanh**.

Chế độ **Máy hát Trái Đất** của Lắng làm đúng việc đó. Người dùng chỉ cần nói. Các hình NASA SVS được chuyển thành số liệu. Từ số liệu đó, app hát bằng nhạc cụ Việt Nam, đọc mô tả hình theo kiểu Section 508, và cho rê tay lên hình để nghe từng nơi.

## 1. Năm hình NASA đang có

Mỗi hình được cắt thành 12 hoặc 16 khung. Ảnh mỗi khung có cỡ 768 × 384. Mỗi khung kèm lưới rê tay 64 × 32 ô.

| Lệnh nói | Hình NASA (SVS) | Dữ liệu gốc | Mỗi khung là | Nhạc cụ |
|---|---|---|---|---|
| "nghe ánh đèn ban đêm" | [5475](https://svs.gsfc.nasa.gov/5475): Black Marble, đèn đêm 2012–2023 | VIIRS, trung bình năm | 1 năm | đàn bầu + t'rưng |
| "nghe sét" | [5011](https://svs.gsfc.nasa.gov/5011): sét nhìn từ ISS | LIS trên ISS, 2017–2023 | 1 tháng (trung bình 2017–2023) | đàn bầu + trống + sấm |
| "nghe khí CO2" | [5436](https://svs.gsfc.nasa.gov/5436) / [5196](https://svs.gsfc.nasa.gov/5196): CO₂ DYAMOND | GEOS, 1–3/2020 | 1 ngày (cách 3 ngày) | đàn bầu + lách tách + gió |
| "nghe nhiệt độ biển" | [3912](https://svs.gsfc.nasa.gov/3912): dòng chảy và nhiệt độ mặt biển | mô hình ECCO2, 2007–2008 | 1 tháng | đàn bầu (Biển Đông) + sóng |
| "nghe chiều cao rừng" | [4950](https://svs.gsfc.nasa.gov/4950): chiều cao tán rừng GEDI | laser GEDI trên ISS, 2019–2020 | 1 dải kinh độ 30° | sáo + t'rưng |

Ngoài các lệnh trên còn có câu "máy hát Trái Đất" (chọn hình đầu và đọc danh sách) và nút **🎼 Máy hát Trái Đất** ở hàng nút nhanh.

## 2. Nghe gì là gì (chung cho mọi hình)

| Âm thanh | Nghĩa | Vì sao |
|---|---|---|
| **Giọng chính liền hơi** (đàn bầu, hoặc sáo với rừng) cao hay thấp | Giá trị chính của khung. Cao độ trải trên 3 quãng tám ngũ cung, từ khung thấp nhất đến khung cao nhất của bộ | Tai theo dõi cao độ tốt nhất. Đàn bầu luyến liền nên nghe được cả xu hướng chứ không chỉ từng nốt. Thang ngũ cung không có nốt nghịch tai |
| **Nhịp gõ** (t'rưng, trống hoặc lách tách), số tiếng trong một khung | Diện tích có giá trị đáng kể: càng phủ rộng tiếng gõ càng dày (0 đến 6 tiếng) | Đếm tiếng gõ chính là đếm "bao nhiêu nơi" |
| **Tai trái hay tai phải** | Vùng mạnh nhất đang ở phía Tây hay phía Đông | Người nghe có ngay bản đồ trong đầu: trái là Tây, phải là Đông |
| **Nền** (sấm, gió, sóng) | Khung này thay đổi nhiều so với khung trước | Đánh dấu bước ngoặt mà không cần đọc số |
| **Một tiếng chiêng nhỏ** | Vùng Việt Nam và Biển Đông đổi rõ | Người nghe ở Việt Nam biết ngay có chuyện xảy ra gần nhà |
| **Rê tay** trên hình | Giọng chính theo giá trị của điểm đang chạm. Dừng tay chừng 0,6 giây thì app đọc tên vùng và giá trị, có đơn vị nếu có | Nghe tự do, giống người sáng mắt đưa mắt nhìn quanh hình. Qua ngưỡng mức (rất thấp, thấp, vừa, cao, rất cao) thì máy rung nhẹ |

Lý do riêng của từng hình nằm trong `assets/eic/<id>/meta.json`, ở các trường `why_vi` và `why_en`. Khi người dùng nói **"giải thích"** hoặc **"tại sao"**, app đọc lý do đó:

- **Ánh đèn.** Ánh đèn là nhiều điểm sáng rời nhau, nên t'rưng gõ rời từng nốt, như đếm từng ngọn đèn. Mỗi năm một nhịp để nghe ra đô thị hoá.
- **Sét.** Sét đi cùng sấm, nên dùng trống và sấm. Số tiếng trống chính là số chớp. Mỗi tháng một nhịp để nghe mùa bão dịch chuyển.
- **CO₂.** Khí vô hình, giống khói. Tiếng lách tách như lửa cho biết vùng phát thải, tiếng gió cho biết khí đang di chuyển. Lấy trung bình cả ngày để bỏ dao động ngày đêm.
- **Nhiệt độ biển.** Giọng chính theo **Biển Đông**, vùng biển của người nghe. Dòng chảy là nước chuyển động nên dùng tiếng sóng.
- **Rừng.** Rừng khác nhau theo nơi chứ ít đổi theo năm, nên quét theo **không gian** từ Tây sang Đông. Dùng sáo và t'rưng bằng tre nứa để gợi rừng. Cây càng cao thì tiếng càng cao.

## 3. Điều khiển bằng giọng nói

| Nói | App làm |
|---|---|
| dừng · tạm dừng | dừng (giữ nguyên khung đang nghe) |
| tiếp tục · nghe tiếp | hát tiếp |
| nhanh hơn · chậm lại | 5 mức tốc độ, mỗi khung từ 1,6 giây đến 0,45 giây |
| nghe lại · từ đầu | hát lại cả bộ |
| năm 2020 · khung sau · khung trước | nhảy tới khung đó, đọc nhãn và mô tả rồi hát riêng khung ấy |
| mô tả · hình gì | đọc mô tả kiểu Section 508, gồm cả khung đang nghe |
| chú giải · nghe gì là gì | đọc chú giải âm thanh |
| giải thích · tại sao | đọc lý do chọn âm |
| nguồn | đọc nguồn và mã SVS |
| đổi sang sét · nghe rừng… | chuyển hình |
| danh sách | đọc các hình đang có |
| quay lại · thoát · xong rồi | rời máy hát |
| một lệnh khác (vd "thời tiết Huế") | rời máy hát rồi làm lệnh đó |

Hát hết một bộ, app tóm tắt bằng lời. Ví dụ với ánh đèn: *"Từ năm 2012 đến năm 2023, mức toàn cầu tăng khoảng 17 phần trăm. Riêng vùng Việt Nam và Biển Đông tăng khoảng 44 phần trăm. Mạnh nhất lúc năm 2023…"*

## 4. Mô tả hình theo Section 508

Mỗi hình có `describe_vi` và `describe_en`. Đây là 2 đến 3 câu ngắn theo hướng dẫn mô tả hình của Section 508:

1. Nói hình là gì: bản đồ thế giới, nền màu gì.
2. Nói các phần tử mang dữ liệu trông thế nào, so với vật quen thuộc. Ví dụ: "như hạt cát vàng rắc trên tấm vải đen", "sợi chỉ màu chảy như tóc rối", "khói lan".
3. Nói chỗ nhiều và chỗ ít.

Không mô tả màu đơn thuần. Màu luôn đi kèm nghĩa ("đỏ cam ở vùng xích đạo **nóng**"). Mô tả cũng gắn vào khung hình làm nhãn ngữ nghĩa (`Semantics.label`) cho TalkBack và VoiceOver.

## 5. Từ video NASA ra số liệu (`pipeline/build_eic.py`)

```powershell
data_nasa\svs\tai_svs.bat                # tải đủ 4 video SVS (curl, tự nối lại khi rớt mạng) vào data_nasa\svs\full\
python pipeline/build_eic.py             # cần ffmpeg + numpy + pillow; ghi app/assets/eic/
python pipeline/build_eic.py --only ocean
```

| Hình | Đổi màu ra số |
|---|---|
| Ánh đèn | Lấy độ sáng của điểm trừ đi trung vị 15 × 15 điểm xung quanh. Điểm sáng nhỏ nổi lên, nền mịn bị trừ đi. Che chữ số năm in trên hình, chỉ tính trên đất liền. Chuẩn hoá theo bách phân vị 99,5 của cả 12 năm để so được giữa các năm |
| Sét | Video lặp từng năm 2017–2023 (cửa sổ trượt 10 ngày) mà không in ngày tháng. Bước 1: đếm chấm sét vàng trên mọi khung thứ 6. Bước 2: mỗi lần tỉ lệ sét ở Bắc bán cầu vượt lên 50 % được coi là giữa tháng 3, mở đầu một năm (tìm được 7 lần, mỗi năm khoảng 726 khung). Bước 3: gộp các khung cùng tháng của mọi năm thành 12 tháng trung bình. Kiểm tra lại: sét toàn cầu nhiều nhất tháng 7, sét vùng Việt Nam nhiều nhất tháng 5, đúng với hiểu biết về mùa giông |
| CO₂ | Video tổng hợp trừ video nền **cùng khung** (SVS có cả hai). Phần "cam" còn lại, (R − B), chính là lớp CO₂. Mỗi ngày lấy trung bình 6 khung cách 4 giờ. Ngày tháng lấy từ `dyamond_timestamps.txt` của SVS |
| Nhiệt độ biển | Tự tìm thang màu 0–32 °C in ở góc hình. Mỗi điểm được khớp với màu gần nhất trên thang để ra °C. Bỏ đất liền (mặt nạ ETOPO) và vùng chữ. Ngày tháng lấy từ `flat_ecco2_dates.txt` |
| Rừng GEDI | Video là quả cầu xoay, không phải bản đồ phẳng. Cách làm: (1) tìm tâm và bán kính quả cầu từ vùng biển xanh; (2) mỗi khung dò kinh độ và vĩ độ tâm sao cho viền lục địa khớp nhất với lưới độ cao ETOPO của app (khớp 75–94 %); (3) chiếu ngược phép chiếu trực giao về lưới 2°; (4) so màu với thang 0–50 m của SVS; (5) lấy trung bình mọi lần một ô được nhìn thấy |

Kết quả của mỗi khung:

- `v`: giá trị chính toàn cầu. Đã nhân để khung cao nhất bằng 0,9, nhưng **giữ tỉ lệ** giữa các khung nên con số "tăng 17 %" vẫn đúng.
- `area`: tỉ lệ diện tích "đáng kể".
- `cx`: vị trí Đông–Tây của 10 % ô mạnh nhất.
- `d`: mức đổi so với khung trước.
- `vn`: giá trị riêng vùng 6–24°N, 102–118°E.
- `grid`: lưới 64 × 32 giá trị 0–254, trong đó 255 nghĩa là không có số liệu.

**Giới hạn cần nói rõ.** Đây là số liệu **đọc từ hình** chứ không phải số đo gốc. Số này đủ để nghe xu hướng và so nơi này với nơi khác, nhưng không dùng để tính toán khoa học:

- Nhiệt độ biển đọc từ những sợi chỉ màu, mà ở gần hai cực sợi rất thưa nên trung bình toàn cầu bị lệch lên. Chu kỳ mùa của Biển Đông vẫn đúng dạng: nóng nhất tháng 6–7, mát nhất tháng 1–3.
- Ánh sáng ở rìa quả cầu GEDI làm màu tối đi, nên chiều cao ở vĩ độ cao kém chính xác hơn.

Muốn số đo gốc thì dùng các sản phẩm tương ứng: Black Marble VNP46A4, LIS/ISS, GEOS, ECCO2, GEDI L2A/L3. Hướng dẫn tải nằm trong `docs/HUONG_DAN_DU_LIEU_NASA.md`.

## 6. Mã nguồn

| File | Việc |
|---|---|
| `app/lib/features/eic/eic_data.dart` | đọc `assets/eic/index.json` và `meta.json`; tra lưới rê tay |
| `app/lib/features/eic/eic_player.dart` | hát từng khung, điều khiển, rê tay, lời đọc và tóm tắt |
| `app/lib/features/eic/eic_view.dart` | màn hình: khung hình, vạch tiến trình, chú giải, nút Thoát to ở góc trái |
| `app/lib/features/eic/eic_commands.dart` | hiểu câu nói khi mở và khi đang ở trong chế độ |
| `app/lib/features/globe/globe_page.dart` | `_eicRoute`, `_eicOpen`, `_closeEic`; chạy trước bộ hỏi–đáp NASA; tự đóng khi sang lệnh khác |
| `app/test/eic_jukebox_test.dart` | kiểm thử câu nói, đọc dữ liệu, lưới, tên vùng, và dữ liệu đóng gói |
| `pipeline/build_eic.py` | video SVS → `app/assets/eic/` |

Chế độ này chạy được cả trên app và web, không cần mạng và không cần khoá API, vì toàn bộ dữ liệu nằm trong `assets/eic` (khoảng 2,5 MB).
