# LẮNG — TÀI LIỆU CHO THÀNH VIÊN NHÓM

> **App và web làm gì, có những gì, dùng dữ liệu nào và khai thác dữ liệu ra sao**
> Cập nhật: 14/11/2026 (thêm Máy hát Trái Đất; xu hướng khí hậu chuyển sang ERA5; số mặt trăng mới) · Áp dụng cho mã nguồn hiện tại trong thư mục `app/` (Flutter) · Bản web: <https://sense-app-two.vercel.app>
> NASA Space Apps Challenge 2026 — Thử thách #14 *The Earth Information Jukebox* — Đội "Lắng"

---

## 0. Đọc nhanh trong 1 phút

- **Lắng là gì:** một quả địa cầu biết nói cho **người khiếm thị**. Người dùng **chỉ cần nói** (không gõ phím, không cần nhìn). App trả lời bằng giọng đọc tiếng Việt và **âm thanh hóa** số liệu bằng nhạc cụ dân tộc (đàn bầu, đàn t'rưng, sáo trúc, trống, mõ, chiêng…). Máy rung theo địa hình.
- **App và web là cùng một mã nguồn Flutter** (`app/lib`). Web build ra `app/build/web` và chạy trên Vercel. Android, iOS và Windows build từ cùng thư mục. Hai bản chỉ khác nhau ở **phần nghe/nói** (mục 6.2) và ở chỗ gọi mạng: web đi qua các hàm `/api/*` trên Vercel.
- **Ba phần chính, nói để chuyển phần:**
  1. **Thời tiết và khí hậu** (F1): thời tiết thật bây giờ và dự báo, lịch sử thời tiết và thiên tai, 146 năm ấm lên toàn cầu.
  2. **Địa lý quanh bạn** (F3): rê tay khám phá địa hình thật, quét mặt cắt địa hình, quanh đây có gì (chỗ tham quan, vui chơi). *Phần quán ăn và chỗ ở tại Hà Nội đang tạm ẩn.*
  3. **Khám phá vũ trụ** (F2): Hệ Mặt Trời, 10 thiên thể, sự thật thú vị, âm thanh thật của NASA, ảnh thiên văn hôm nay, trò chơi.
  4. **Máy hát Trái Đất** (thử thách #14): 5 hình ảnh dữ liệu NASA SVS (ánh đèn ban đêm, sét, CO₂, nhiệt độ biển, chiều cao rừng) phát thành âm thanh, có mô tả hình, điều khiển bằng giọng, rê tay trên hình (mục 3.6).
- **Dữ liệu:** phần lớn là dữ liệu NASA **đã chuẩn hóa và đóng gói sẵn** trong `app/assets/` nên trả lời ngay và chạy cả khi mất mạng. Khi có mạng, app lấy thêm dữ liệu **trực tuyến**: thời tiết hôm nay, ô bản đồ địa hình, OpenStreetMap, NASA EONET/APOD/POWER.
- **AI (Gemma 4) chỉ dùng khi câu hỏi không có sẵn đáp án trong dữ liệu.** Khi gọi AI, app gửi kèm số liệu thật (RAG) để AI không bịa số.

---

## 1. Lắng dành cho ai, giải quyết việc gì

Biểu đồ khí hậu và ảnh vệ tinh của NASA là dữ liệu *để nhìn*, nên người khiếm thị gần như không tiếp cận được. Lắng chuyển các dữ liệu đó sang **tai** (giọng đọc và nhạc cụ) và **tay** (rê ngón tay, rung):

| Người dùng muốn… | Lắng làm |
|---|---|
| Biết thời tiết bây giờ, chiều nay có mưa không, mai đi chơi được không | Đọc câu ngắn dễ hiểu kèm lời khuyên đi lại, đồng thời đàn bầu và đàn t'rưng diễn tấu nhiệt độ và mưa |
| Nghe lại một trận bão, lũ, hay 3 năm thời tiết của một nơi | Phát lại từng tháng hoặc từng năm bằng âm thanh. Hình ảnh khớp với âm (mưa rơi, rung màn hình khi bão). Chạm vào màn hình để nghe giải thích |
| "Cảm" được núi, sông, rừng, phố quanh mình | Mở **bản đồ địa hình thật**. Rê ngón tay nghe tiếng sáo cao thấp theo độ cao, máy rung theo độ dốc, tiếng sóng ở mặt nước, lá xào xạc ở rừng, tiếng xe ở khu dân cư |
| Học về vũ trụ | Nghe truyện từng hành tinh, sự thật thú vị của NASA, bản ghi âm thật (Apollo 11, Sputnik…), chơi đố vui bằng giọng nói |

---

## 2. Cách dùng: 100% bằng giọng nói

### 2.1. Luồng cơ bản

1. Mở app hoặc web. App đọc lời chào và giới thiệu 3 phần, rồi **tự bật mic nghe liên tục** (không phải bấm nút).
2. Người dùng nói một câu. App phát tiếng "ding" báo đã nhận lệnh, rồi trả lời.
3. Muốn ngắt lời app thì nói "dừng lại", "thôi" hoặc "im lặng" bất cứ lúc nào.
4. Câu nói lặp lại lời app vừa đọc (loa dội vào mic) sẽ bị bỏ qua, để không hiểu nhầm thành lệnh.

### 2.2. Câu nói mẫu theo phần

| Phần | Ví dụ câu nói |
|---|---|
| Thời tiết | "thời tiết Hà Nội", "chiều nay có mưa không", "mai đi Đà Lạt có hợp không", "có bão không", "nghe nhạc" (đàn bầu diễn tấu nhiệt độ), "còn Huế thì sao" |
| Lịch sử, khí hậu | "lịch sử thời tiết Huế 3 năm qua", "bão Yagi", "lũ miền Trung 2020", "Trái Đất nóng lên bao nhiêu", "cháy rừng Tây Nguyên mùa nào" |
| Địa lý quanh bạn | "rê tay khám phá" (hoặc "chạm địa hình"), "quét mặt cắt địa hình Đà Lạt", "quanh đây có gì", "phường Hoàn Kiếm có gì chơi" |
| Ăn, ở Hà Nội | **Đang tạm ẩn.** Hỏi quán ăn, khách sạn thì app chỉ nói ngắn "phần này đang tạm ẩn" và gợi ý hỏi chỗ tham quan |
| Máy hát Trái Đất | "máy hát Trái Đất", "nghe ánh đèn ban đêm", "nghe sét", "nghe khí CO2", "nghe nhiệt độ biển", "nghe chiều cao rừng"; trong lúc nghe: "dừng", "tiếp tục", "nhanh hơn", "năm 2020", "giải thích", "nguồn" |
| Vũ trụ | "khám phá vũ trụ", "kể về Sao Hỏa", "sự thật thú vị về Sao Thổ", "âm thanh thật của NASA", "ảnh thiên văn hôm nay", "trò chơi" rồi "chọn trò thứ 3" |
| Chung | "nguồn dữ liệu" (đọc nguồn NASA đang dùng), "trợ giúp", "nói chậm lại", "nhỏ thôi", "về màn hình chính" |

> **Trò chơi chỉ chạy trong phần Khám phá vũ trụ.** Đang ở phần khác mà nói "trò chơi" thì app hướng dẫn sang phần vũ trụ trước.

### 2.3. Luôn có đường thoát (không bị kẹt)

- **Đang rê tay, quét mặt cắt hay nghe lịch sử:** nói "quay lại", "trở về", "về thôi", "đóng", "ra ngoài", "xong rồi", "thoát", "tắt bản đồ"… để về quả địa cầu. Ở màn quả địa cầu bình thường, "quay lại" vẫn có nghĩa là thu nhỏ.
- **Vẽ chữ Z bằng một ngón, trong dưới 1 giây, ở bất kỳ màn nào:** về **màn hình chính** của nhánh đang dùng.
  - Nhánh Trái Đất: quả địa cầu toàn cảnh, Việt Nam ở giữa.
  - Nhánh vũ trụ (kể cả đang chơi trò chơi): bản đồ Hệ Mặt Trời.
  - Nói "về màn hình chính" có tác dụng giống hệt.
- Nút "Thoát" trên màn rê tay vẫn còn cho người nhìn được hoặc người đi cùng.

### 2.4. Nút gợi ý trên màn hình

Hàng nút ngang phía dưới (Vị trí của tôi, Hà Nội, Lịch sử thời tiết, 🎼 Máy hát Trái Đất, Quét địa hình, **Rê tay khám phá**, Sao Hỏa, Âm thanh NASA…) dành cho **người nhìn được hoặc người đi cùng**. Bấm một nút tương đương với nói câu lệnh đó.

---

## 3. Chức năng chi tiết: dùng dữ liệu nào, mã ở đâu

Ký hiệu nguồn dữ liệu: 📦 = đóng gói sẵn trong app (offline) · 🌐 = tải trực tuyến khi có mạng.

### 3.1. Thời tiết thật và dự báo

- **Làm gì:** đọc thời tiết hiện tại, theo giờ (48 giờ) và theo ngày (10 ngày). Trả lời các câu như "chiều nay mưa không", "mai đi chơi có hợp không" kèm lời khuyên (đường trơn, dông sét, nắng nóng, UV, bụi mịn). Đồng thời diễn tấu bằng nhạc cụ.
- **Dữ liệu:**
  - 🌐 **Open-Meteo** (mặc định, không cần khoá): dự báo, chất lượng không khí, tìm tên nơi.
  - 🌐 **Google Weather API**: tuỳ chọn, cần khoá Google trong Cài đặt.
  - 📦 `vn_dvhc.json`: tìm đúng xã/phường. Có 34 tỉnh, 3.321 xã/phường mới từ 1/7/2025 và 10.035 xã/phường cũ, để "xã Đặng Xá" hay "huyện Gia Lâm" vẫn ra đúng nơi mới.
  - Vị trí GPS (`geolocator`) cho "nơi tôi đứng".
- Máy chủ thời tiết bận (lỗi 429/5xx) thì app tự thử lại một lần; vẫn lỗi thì nói "Máy chủ thời tiết đang bận, bạn nói lại sau ít giây nhé".
- **Mã:** `lib/live/live_weather.dart`, `lib/live/weather_talk.dart`, `lib/live/vn_gazetteer.dart`, `lib/features/globe/world_sound.dart`.

### 3.2. F1 — Lịch sử thời tiết và thiên tai, biến đổi khí hậu

- **Phát lại lịch sử** ("lịch sử thời tiết Huế 3 năm qua"):
  - Khoảng ≤ 3 năm phát theo tháng, dài hơn thì phát theo năm, từ bản ghi sớm nhất đến bản ghi cuối.
  - **Thời tiết:** nắng nóng là âm nắng rát, lạnh là gió lạnh, mưa là tiếng mưa to/nhỏ theo lượng mưa. Loại chiếm chủ đạo phát to hơn.
  - **Thiên tai:** phát từ nhẹ đến nặng, mỗi loại một tiếng riêng.
  - Hình ảnh khớp với âm (phủ sáng khi nóng, mưa rơi, gió xoáy, rung màn hình khi bão hoặc động đất). Có thanh timeline. Chạm màn hình thì app tạm dừng và giải thích bản ghi đang phát.
  - Dữ liệu:
    - 📦 `climate_34_provinces.json`: NASA POWER theo tháng, 1981–2025, 34 tỉnh/thành.
    - 📦 `vn_disasters_nasa.json`: 282 sự kiện thiên tai tại Việt Nam (107 bão, 59 lũ, 116 sạt lở) từ **NASA SEDAC GDIS**, định vị theo tỉnh.
    - 🌐 NASA POWER (web gọi qua `/api/nasa`) và Open-Meteo Archive cho nơi ngoài danh sách.
    - 🌐 NASA EONET (lưu trữ) và USGS (động đất ≥ 4,5 độ) cho thiên tai quanh một nơi.
  - Mã: `lib/features/history/`, `lib/live/hazard_history.dart`, `lib/live/nasa_power.dart`.
- **Sự kiện tái hiện 15 ngày** ("bão Yagi", "lũ miền Trung"):
  - 📦 `climate_history_nasa.json` → `historical_events`: Bão Yagi 9/2024 ở miền Bắc, Mưa lũ Huế 10/2020.
  - Số liệu theo ngày của NASA POWER (nhiệt, mưa, gió giật).
  - App luôn nói rõ giới hạn: mỗi ô lưới khoảng 50 km.
- **Ấm lên toàn cầu:** 📦 `gistemp_global.json`, NASA GISTEMP v4, 146 năm 1880–2025.
  - Năm nóng nhất là 2024 với +1,28 °C.
  - Ấm thêm khoảng 1,23 °C so với 1880–1900.
  - Đàn bầu lướt qua các thập kỷ, cao độ tăng theo mức ấm lên.
- **Xưa và nay** ("khí hậu Hà Nội", "Hà Nội xưa và nay"):
  - So sánh 1981–1990 với 10 năm gần nhất: nhiệt độ, số ngày ≥ 35, ≥ 37, ≥ 39 °C (3 ngưỡng của KTTV Việt Nam), số ngày mưa ≥ 50 mm, mưa cả năm, năm nóng nhất. Kèm âm thanh mỗi năm một nốt.
  - 🌐 **Nguồn: ERA5** (Copernicus, qua Open-Meteo Archive), một chuỗi liền mạch, tải trong `NasaPowerService.extremes()` → `EraTrend`.
  - **Vì sao không dùng NASA POWER cho xu hướng:** kiểm tra ngày 14/11/2026, chuỗi POWER ở Việt Nam không đồng nhất theo thời gian. Mưa thập niên 1980 thấp bất thường, nhiệt độ thập niên 1980 cao bất thường, mưa nhảy bậc quanh 2016. Hệ quả: Hà Nội tính ra "mát đi 0,97 °C", trong khi ERA5 cho "ấm lên 1,02 °C". Chi tiết ở `HUONG_DAN_DU_LIEU_NASA.md` mục 5.4.
  - `hot_days_extremes`, `warming_c` trong `climate_history_nasa.json` (POWER) vẫn còn trong file nhưng **không dùng để nói xu hướng**. Mất mạng thì app không nói xu hướng.
- **Cháy rừng:** `fire_firms` theo 12 tháng cho các vùng khí hậu Việt Nam, phát bằng tiếng lửa khô. ⚠️ Số hiện tại **viết tay** trong `build_f1_climate.py`, chưa đếm từ API FIRMS; cần thay trước khi trình bày.
- **Khí hậu 29 địa điểm** (14 tỉnh/thành Việt Nam và 15 thành phố thế giới): `climate_history_nasa.json` → `places`. Dùng cho số liệu từng tháng, từng năm.
- **Còn mở:** F1 so mỗi tháng với "trung bình cùng kỳ" của cả chuỗi POWER. Với khoảng dài trước 2016, F1 có thể gắn nhãn "khô hạn" sai. Cần chọn: đổi chuỗi dài hạn của F1 sang ERA5, hay chỉ dùng POWER từ 2016.
- **Thiên tai đang diễn ra:** 🌐 NASA EONET (web gọi qua `/api/eonet`).

### 3.3. F3 — Địa lý quanh bạn

**a) Rê tay khám phá** (nói "rê tay khám phá" hoặc "chạm địa hình")

- Mở một **bản đồ địa hình thật**, khung khoảng 2,4 × 2,4 km, phía bắc ở trên. Bản đồ mở ngay, tên sông, đường điền vào sau vài giây.
- **Chọn vị trí theo thứ tự:** nơi nói trong câu ("rê tay khám phá Đà Lạt") → "quanh tôi" thì dùng GPS → nơi đang xem trên quả địa cầu → GPS → nhà đã lưu → nếu không biết thì mở Hà Nội và nói rõ điều đó.
- Bản đồ vẽ **liền mạch, có bóng đổ**. Sông, suối, hồ, rừng, đường từ OpenStreetMap vẽ đè lên trên, chỉ trong khung bản đồ.
- **Rê ngón tay:**
  - tiếng **sáo** cao thấp theo độ cao;
  - máy **rung** mạnh dần theo độ dốc;
  - **sóng** ở sông, hồ, biển;
  - **lá xào xạc / t'rưng trầm** ở rừng, công viên;
  - **trống nhẹ** ở đồng ruộng;
  - **tiếng xe** ở khu dân cư;
  - **lách tách** ở đường lớn.
  - Sang chỗ mới thì app đọc tên chỗ đó, độ cao và độ dốc.
- **Dữ liệu (theo thứ tự ưu tiên):**
  1. 🌐 **Ô độ cao Terrarium** (AWS Open Data, dựng từ NASA SRTM): mức 13, khoảng 18 m mỗi điểm. Chỉ cần tải 1–4 ô ảnh nhỏ nên mở nhanh.
  2. 🌐 **NASA GIBS – MODIS MCD12Q1 (IGBP)**: lớp phủ đất, 17 lớp (rừng, ruộng, đô thị, mặt nước…), khoảng 500 m.
  3. 🌐 **OpenStreetMap qua ô vector** (OpenFreeMap, chuẩn OpenMapTiles, mức 14): sông, suối, hồ, rừng, công viên, đường, đỉnh núi kèm độ cao. App tự giải mã ô (`lib/live/vector_tiles.dart`). Kiểm chứng: Suối Cam Ly, Hồ Xuân Hương, Đồi Cù (Đà Lạt); Hồ Hoàn Kiếm, sông Hồng (Hà Nội). Nếu ô vector không có gì thì dùng dự phòng **Overpass** (web gọi qua `/api/osm`).
  4. 📦 Dự phòng khi mất mạng: lưới độ cao thô (vẫn vẽ mượt), `assets/touch/vn` (độ cao/dốc SRTMGL30, mặt nước, dân số GPWv4, khoảng 1 km/ô toàn Việt Nam), `dalat_scene.json` (lưới đa lớp 12 × 12 quanh Đà Lạt).
- **Mã:**
  - `lib/features/globe/local_map.dart`: màn rê tay.
  - `lib/live/terrain_tiles.dart`: tải ô bản đồ.
  - `lib/live/terrain_patch.dart`: giải mã độ cao, lớp phủ, vẽ ảnh.
  - `lib/live/vector_tiles.dart`: giải mã ô vector OSM.
  - `lib/live/geo_around.dart`: gom dữ liệu quanh một điểm, phân loại chỗ ngón tay chạm.

**b) Quét mặt cắt địa hình** ("quét mặt cắt địa hình Đà Lạt")

- Vùng quét khoảng 100 km quanh nơi được hỏi (ví dụ Đà Lạt ≈ 107 km mỗi chiều). Lát cắt chạy Bắc → Nam rồi Tây → Đông, mỗi lượt không quá 8 giây. Có nút "Thoát" ở góc trái cho người đi cùng.
- Tiếng sáo theo độ cao trung bình của lát cắt. Hình mặt cắt vẽ cùng lúc.
- Dữ liệu: 📦 `assets/touch/vn` và `dalat_scene.json`, 🌐 ô độ cao Terrarium.
- Mã: `lib/features/terrain_scan/`.

**c) Quanh đây có gì / địa điểm theo xã, phường**

- Cẩm nang du lịch Hà Nội theo từng xã/phường (offline, `lib/features/globe/hanoi_guide.dart`).
- Ngoài Hà Nội thì dùng 🌐 OpenStreetMap.

**d) Quán ăn và chỗ ở tại Hà Nội — ĐANG TẠM ẨN**

> Tắt bằng cờ `kHanoiFoodStayEnabled = false` trong `lib/features/globe/hanoi_guide.dart`. Khi tắt: hỏi quán ăn hay khách sạn thì app nói ngắn là phần này tạm ẩn; cẩm nang theo khu chỉ kể tham quan, vui chơi; trợ lý AI không nhận dữ liệu món ăn. Dữ liệu và mã vẫn giữ nguyên, đổi cờ thành `true` là bật lại. Mô tả bên dưới là khi bật.

- Dữ liệu 📦 `assets/data/hanoi_places.json`:
  - 127 nơi: 69 quán ăn, 58 chỗ ở;
  - 22 khu vực, 21 loại (phở, bún chả, cà phê, chay, hostel, resort…), 4 mức giá.
  - Mỗi nơi có **một địa chỉ ngắn**, toạ độ, khoảng giá, giờ mở cửa, món, ghi chú.
- **Hiểu câu:** món, khu vực, "gần đây" (dùng GPS), số sao, mức giá, "đang mở", "ăn đêm", tên riêng một quán.
  - Phân biệt được "phở" với "phố".
  - Hỏi nơi ngoài Hà Nội thì app không lấy dữ liệu Hà Nội để trả lời.
- **Trả lời:** đếm số kết quả, đọc 3 nơi đầu, gợi ý "còn nữa" và "chi tiết số N".
- **Tách phần thời tiết và phần địa điểm** (`lib/features/globe/intent_domain.dart`): câu chỉ có tên nơi ("còn Hồ Tây thì sao") đi đúng phần người dùng đang hỏi trước đó, để không nhầm thời tiết Hồ Tây với quán ở Hồ Tây.
- **Mã:** `lib/features/globe/hanoi_places.dart`.

### 3.4. F2 — Khám phá vũ trụ

- **Màn Hệ Mặt Trời:** Mặt Trời và 8 hành tinh chạy trên quỹ đạo. Mỗi thiên thể có một âm riêng.
- **Truyện và thông số 10 thiên thể** (Mặt Trời, 8 hành tinh, Mặt Trăng):
  - 📦 `planets_nasa.json`: NASA NSSDCA Planetary Fact Sheet (hệ mét) kèm **135 sự thật thú vị** từ NASA Space Place, đã đổi sang hệ mét.
  - Số mặt trăng theo trang NASA Science (8/2026): Sao Thổ 293, Sao Mộc 115, Sao Thiên Vương 29, Sao Hải Vương 16. Đã sửa ngày 14/11/2026 (trước ghi 146, 95, 28).
- **Hỏi đáp kiểm chứng:** 📦 `qa_bank.json`, 35 cặp hỏi–đáp có nguồn NASA, trong đó 12 câu đính chính hiểu lầm phổ biến (Trái Đất phẳng, vì sao có mùa…).
- **Âm thanh thật của NASA:** 📦 `assets/sounds/nasa/` có 10 bản ghi (Sputnik, Apollo 11, Apollo 13, sóng radio Sao Thổ, Enceladus, sét Sao Mộc, plasma liên sao, Juno, Kepler, Stardust).
  - 📦 `space_media.json`: 6 bản âm thanh và mô tả vũ trụ theo chuẩn mô tả ảnh Section 508.
  - Nhãn `audio_kind` phân biệt 3 loại: `recording` (thu thật), `nasa_sonification` (NASA chuyển dữ liệu thành âm) và `app_sonification` (Lắng tự tổng hợp).
- **Ảnh thiên văn hôm nay:** 🌐 NASA APOD (web gọi qua `/api/apod`). App đọc phần giải thích của ảnh.
- **Trò chơi** (chỉ trong phần vũ trụ):
  1. Đố vui.
  2. "Tôi là ai" (nghe gợi ý rồi đoán hành tinh).
  3. Nghe tiếng đoán hành tinh.
  - Ngoài ra có "Đố âm thanh NASA".
  - Chọn trò bằng câu như "chọn trò thứ 3" hoặc "trò số ba". Trong lúc chơi nói "nhắc lại", "gợi ý", "bỏ qua", "dừng". Kỷ lục lưu trên máy.
  - Người đi cùng có thể gõ câu trả lời vào ô "Gõ lệnh" (dùng khi máy không có mic). Gõ một lệnh khác (ví dụ "thời tiết Huế") thì trò chơi dừng và app làm lệnh đó.
- **Mã:** `lib/features/space/` (`planets.dart`, `planet_facts.dart`, `planet_games.dart`), `lib/live/apod.dart`, `lib/live/nasa_sounds.dart`.

### 3.5. Trợ lý AI (khi dữ liệu có sẵn không trả lời được)

- **Model:** Google **Gemma 4 26B** (`gemma-4-26b-a4b-it`), có thể đổi sang Gemma 4 31B trong Cài đặt.
  - Lỗi 500/502 thì thử lại 1 lần.
  - Vẫn lỗi (hoặc 504) thì chuyển sang model dự phòng `gemini-flash-lite-latest`.
  - Hết cách thì báo lỗi bằng câu thân thiện.
- **RAG** (`lib/live/earth_rag.dart`): trước khi hỏi AI, app lấy số liệu thật liên quan (thời tiết nơi đang xem, khí hậu NASA, thông số hành tinh, hỏi–đáp kiểm chứng, địa danh) đưa vào câu hỏi. AI chỉ diễn đạt lại, không tự bịa số.
- **Web:** khoá Gemini nằm trên Vercel (`/api/gemini`), trình duyệt không thấy khoá. Mỗi người tối đa 8 câu/phút để hạn mức chung không bị một người dùng hết.
- **Mã:** `lib/live/gemini_assistant.dart`, `api/gemini.mjs`.

### 3.6. Máy hát Trái Đất (thử thách #14)

- **Làm gì:** phát 5 hình ảnh dữ liệu của NASA Scientific Visualization Studio thành âm thanh theo thời gian (hoặc theo không gian, với hình rừng). Có mô tả hình kiểu Section 508, chú giải âm thanh, lý do chọn âm ("giải thích"), tóm tắt sau khi nghe, và rê tay trên hình để nghe từng nơi.
- **Dữ liệu:** 📦 `assets/eic/<mã>/meta.json` và `f00.jpg`… (768 × 384, lưới rê tay 64 × 32), tổng khoảng 2,4 MB:

| Mã | NASA SVS | Mỗi nhịp | Nhạc cụ |
|---|---|---|---|
| `nightlights` | 5475 / 5313 Black Marble | 1 năm, 2012–2023 | đàn bầu + t'rưng |
| `lightning` | 5011 LIS trên ISS | 1 tháng, trung bình 2017–2023 | đàn bầu + trống + sấm |
| `co2` | 5436 / 5196 GEOS DYAMOND | 1 ngày, 1–3/2020 | đàn bầu + lách tách + gió |
| `ocean` | 3912 ECCO2 | 1 tháng, 2007–2008, giọng chính theo Biển Đông | đàn bầu + sóng |
| `forest` | 4950 GEDI | 1 dải kinh độ 30°, Tây → Đông | sáo + t'rưng |

- **Tạo dữ liệu:** `data_nasa\svs\tai_svs.bat` (tải video SVS), rồi `python pipeline/build_eic.py` (cần ffmpeg). Video là màu, nên pipeline đổi màu ra số theo từng bộ: độ sáng vượt nền, hiệu hai video, khớp thang màu, chiếu ngược quả cầu xoay. Chi tiết ở `HUONG_DAN_DU_LIEU_NASA.md` mục 4.
- **Kết quả nghe được:** đèn đêm toàn cầu tăng khoảng 17 %, vùng Việt Nam khoảng 44 %; sét toàn cầu nhiều nhất tháng 7, Việt Nam tháng 5; Biển Đông nóng nhất tháng 6–7.
- **Giới hạn:** số **đọc từ màu của hình**, xấp xỉ; không thay số đo gốc.
- **Mã:** `lib/features/eic/` (`eic_data.dart`, `eic_player.dart`, `eic_view.dart`, `eic_commands.dart`); tích hợp trong `globe_page.dart` (`_eicRoute`, `_eicOpen`, `_closeEic`). Thiết kế âm thanh: `docs/MAY_HAT_TRAI_DAT.md`. Test: `test/eic_jukebox_test.dart`.

---

## 4. Danh mục dữ liệu

### 4.1. Dữ liệu đóng gói sẵn (`app/assets/`, chạy offline)

Mỗi file JSON chính có khối `data_card` (nguồn, đường dẫn, ngày lấy, độ phân giải, thời gian, đơn vị, giấy phép, giới hạn). Toàn bộ ghi công nằm trong `assets/data/credits.csv` (6 cột: `file,source,url,accessed,credit,audio_kind`).

| File | Nguồn | Nội dung | Dùng cho |
|---|---|---|---|
| `data/gistemp_global.json` | NASA GISS GISTEMP v4 | 146 năm dị thường nhiệt độ toàn cầu (1880–2025, kỳ chuẩn 1951–1980) | F1: ấm lên toàn cầu |
| `data/climate_history_nasa.json` | NASA POWER (MERRA-2), NASA FIRMS MODIS C6.1 | 29 địa điểm (1981–2025), ngày nắng nóng 3 ngưỡng (4 nơi), 2 sự kiện 15 ngày (Yagi 2024, lũ Huế 2020), điểm cháy theo tháng theo vùng | F1, RAG |
| `data/climate_34_provinces.json` | NASA POWER theo tháng | 34 tỉnh/thành, 1981–2025 | F1: lịch sử thời tiết offline |
| `data/vn_disasters_nasa.json` | NASA SEDAC GDIS | 282 sự kiện bão, lũ, sạt lở tại Việt Nam, định vị theo tỉnh, mức nặng 1–5 | F1: phát lại thiên tai |
| `data/touchgrid.json`, `series.json`, `frames/*.bin` | NASA POWER, NASA FIRMS, GADM 4.1 | Lưới 0,1° (2.849 ô đất liền), nhiệt và mưa 300 tháng (2001–2025), lượng tử uint8 | Bản đồ chạm–nghe, dòng thời gian |
| `touch/vn/` (`grid.json`, `elev/slope/water/pop.png`) | NASA SRTMGL30 v002, NASA SEDAC GPWv4 rev11 (Population Density 2020; Land and Water Area) | Lưới 152 × 306 ô, 0,05° (~5,5 km) toàn Việt Nam: độ cao, độ dốc, mặt nước, mật độ dân | F3: dự phòng offline, quét mặt cắt |
| `eic/` (5 thư mục + `index.json`) | NASA SVS 5475, 5011, 5436/5196, 3912, 4950 | Khung hình, số liệu từng khung, lưới rê tay, mô tả 508, lý do chọn âm | Máy hát Trái Đất |
| `data/dalat_scene.json` | NASA SRTM 30 m, MODIS MCD12Q1/MOD13Q1/MOD11A2, EC JRC, WWF HydroRIVERS | 144 ô (12 × 12, khoảng 20 × 20 km quanh Đà Lạt): độ cao, độ dốc, lớp phủ, NDVI, nhiệt bề mặt, mặt nước | F3 Đà Lạt |
| `world/elev_glob.bin` | NOAA ETOPO5 | Độ cao/độ sâu toàn cầu 0,5° | Quả địa cầu nổi khối |
| `data/planets_nasa.json` | NASA NSSDCA, NASA Space Place, NASA Science (số mặt trăng 8/2026) | 10 thiên thể, 135 sự thật thú vị | F2 |
| `data/qa_bank.json` | NASA Space Place, NASA Science, GISS, NSSDCA | 35 hỏi–đáp (12 câu đính chính hiểu lầm) | F2, RAG |
| `data/space_media.json` | NASA Chandra, Perseverance, Voyager, JWST, Hubble | 6 bản âm thanh và mô tả theo chuẩn Section 508 | F2 |
| `sounds/nasa/*.mp3`, `catalog.json` | NASA Historical Sounds | 10 bản ghi âm thật | F2: nghe và đố âm thanh |
| `data/hanoi_places.json` | Nhóm tự tổng hợp | 127 quán ăn và chỗ ở, 22 khu, 21 loại, 4 mức giá | Ăn, ở Hà Nội (đang tạm ẩn) |
| `data/vn_dvhc.json` | atlas34 (MIT) | 34 tỉnh, 3.321 xã/phường mới, 691 huyện cũ, 10.035 xã cũ, có toạ độ | Hiểu tên nơi |
| `asr/`, `voices/vi/` | sherpa-onnx (Zipformer), Silero VAD, Piper `vi_VN-vais1000` | Mô hình nghe và nói offline | Bản app |

### 4.2. Dữ liệu trực tuyến (khi có mạng)

| Dịch vụ | Cần khoá? | Bản web đi qua | Dùng cho |
|---|---|---|---|
| Open-Meteo (forecast, archive, air-quality, geocoding) | Không | Gọi thẳng | Thời tiết hôm nay, dự báo, bụi mịn, thời tiết một ngày trong quá khứ |
| ERA5 qua Open-Meteo Archive (1981 đến năm ngoái, theo ngày) | Không | Gọi thẳng | **Xu hướng xưa – nay** (nhiệt độ, mưa, ngày nắng nóng, năm nóng nhất), cả trong trợ lý AI |
| Google Weather API | Có (tuỳ chọn, Cài đặt) | Gọi thẳng | Nguồn thời tiết thay thế |
| NASA POWER (monthly point) | Không | `/api/nasa` (giữ bản sao 1 ngày) | Lịch sử khí hậu theo nơi |
| NASA EONET v3 | Không | `/api/eonet` (giữ 15 phút) | Thiên tai đang diễn ra và lưu trữ |
| NASA APOD | `NASA_API_KEY` (trên Vercel) | `/api/apod` (giữ 1 giờ) | Ảnh thiên văn hôm nay |
| NASA FIRMS | `FIRMS_MAP_KEY` (tuỳ chọn) | Gọi thẳng | Điểm cháy gần thời gian thực |
| USGS FDSN | Không | Gọi thẳng | Động đất quanh một nơi |
| Ô độ cao Terrarium (AWS) | Không | Gọi thẳng | Rê tay, độ cao khi phóng to |
| NASA GIBS – MODIS IGBP | Không | Gọi thẳng | Lớp phủ đất cho rê tay |
| OpenFreeMap (ô vector OpenStreetMap) | Không | Gọi thẳng | Sông, suối, hồ, rừng, đường cho rê tay |
| OpenStreetMap Overpass | Không | `/api/osm` (hỏi song song nhiều máy chủ, giữ 1 ngày) | Quanh đây có gì; dự phòng cho rê tay |
| Open Topo Data (SRTM 90 m) | Không | Gọi thẳng | Lưới độ cao dự phòng |
| Nominatim, Photon | Không | Gọi thẳng | Tìm tên nơi khi danh bạ offline không có |
| Google AI Studio (Gemma/Gemini) | `GEMINI_API_KEY` | `/api/gemini` | Trợ lý AI |
| Piper TTS trên máy chủ | Không | `/api/tts` (giữ bản đọc 1 năm) | Giọng Việt cho trình duyệt không có giọng Việt |
| Upstash Redis | `KV_REST_API_*` | `/api/stats` | Đếm lượt dùng ẩn danh (trang `/stats`) |

---

## 5. Dữ liệu được khai thác thế nào

### 5.1. Từ câu nói đến câu trả lời

```
Giọng nói ──> Nhận diện chữ ──> Sửa lỗi nghe nhầm ──> Lọc tiếng loa dội lại / tiếng ậm ừ
                                                                │
                      ┌─────────────────────────────────────────┘
                      ▼
   Lối thoát cố định ("về màn hình chính", "quay lại" khi đang rê tay) ──> thoát ngay
                      ▼
   Câu hỏi về dữ liệu NASA có sẵn (nguồn dữ liệu, bão Yagi, GISTEMP…) ──> trả lời từ file JSON
                      ▼
   Tách phần: THỜI TIẾT hay ĐỊA ĐIỂM (intent_domain) ──> ăn/ở Hà Nội ──> hanoi_places.json
                      ▼
   Hiểu lệnh (world_commands.parseWorld) ──> loại lệnh + nơi + thời gian
                      ▼
   Thực hiện: bay tới nơi · lấy số liệu (offline trước, online sau) · đọc + diễn tấu nhạc cụ
                      ▼
   Không lệnh nào khớp ──> hỏi Trợ lý AI kèm số liệu thật (RAG)
```

**Nguyên tắc:**

- **Dữ liệu có sẵn đi trước, mạng đi sau, AI đi cuối.** Nhờ vậy app trả lời nhanh, chạy được khi mất mạng và không bịa số.
- **Nói rõ nguồn và giới hạn.** Hỏi "nguồn dữ liệu" thì app đọc nguồn NASA đang dùng và tách bạch các nguồn ngoài NASA. Dữ liệu MERRA-2 thì nói rõ ô lưới khoảng 50 km.
- **Hiểu tiếng Việt tự nhiên.** App xử lý được:
  - câu ngập ngừng hoặc nói nối ("thời tiết… à Huế");
  - câu sửa lại ("không phải Huế mà là Đà Nẵng");
  - câu hỏi tiếp ("còn Đà Nẵng thì sao");
  - tên xã/phường cũ và mới;
  - các cặp dễ nhầm ("phở"/"phố", "Đà Nẵng"/"nắng", "Côn Đảo"/"còn").

### 5.2. Âm thanh hóa: số liệu nào thành âm nào

| Số liệu | Âm thanh / xúc giác |
|---|---|
| Nhiệt độ (NASA POWER T2M, GISTEMP) | **Đàn bầu**: càng nóng càng cao, ngũ cung |
| Lượng mưa (PRECTOTCORR) | **Đàn t'rưng**: mưa càng nhiều nốt càng dày, mưa rất to có sấm |
| Điểm cháy (FIRMS) | **Tiếng lửa khô** và trống |
| Thời tiết cực đoan, bão | Trống đồng, gió rít, rung màn hình |
| Ranh giới tỉnh/vùng | **Mõ** |
| Biển, mặt nước | **Sóng** |
| Hoàng Sa, Trường Sa | **Chiêng** ngân và câu đọc "(Việt Nam)" |
| Độ cao địa hình | **Sáo trúc**, liền hơi, càng cao càng vút |
| Độ dốc | **Rung**, càng dốc càng mạnh |
| Rừng / ruộng / dân cư / đường | T'rưng trầm (lá) / trống nhẹ / tiếng xe / lách tách |
| Hướng đông – tây | Âm lệch trái – phải (stereo) |
| Hành tinh | Mỗi hành tinh một giai điệu riêng |
| **Máy hát Trái Đất** | Giọng đàn liền hơi = giá trị chính của nhịp; tiếng gõ dày = diện tích; trái–phải = vùng mạnh nhất ở tây hay đông; sấm/gió/sóng = thay đổi mạnh; chiêng nhỏ = vùng Việt Nam đổi rõ |

Mã: `lib/audio/synth.dart` (tổng hợp nhạc cụ), `lib/audio/audio_engine.dart` (ánh xạ số liệu sang âm), `lib/features/globe/world_sound.dart`.

---

## 6. Kỹ thuật

### 6.1. Thư mục chính

```text
sense/
├── app/                      Ứng dụng Flutter (web, Android, iOS, Windows) — MÃ CHÍNH
│   ├── lib/
│   │   ├── main.dart, app_state.dart     Khung app, trạng thái chung, dịch vụ
│   │   ├── audio/                        Tổng hợp nhạc cụ, phát âm (flutter_soloud)
│   │   ├── core/                         Lưới, địa lý, rung, cache mạng, cử chỉ chữ Z
│   │   ├── data/                         Đọc dữ liệu NASA đóng gói (NasaNormalizedRepo)
│   │   ├── features/globe/               Màn chính: quả địa cầu, hiểu lệnh, rê tay, Hà Nội
│   │   ├── features/space/               Hệ Mặt Trời, hành tinh, trò chơi
│   │   ├── features/history/             Phát lại lịch sử thời tiết & thiên tai
│   │   ├── features/terrain_scan/        Quét mặt cắt, lưới chạm Việt Nam
│   │   ├── live/                         Dữ liệu trực tuyến, trợ lý AI, RAG, ô bản đồ địa hình
│   │   └── speech/                       Nghe (ASR) và nói (TTS) cho app và web
│   ├── api/                  Hàm Vercel cho bản web (gemini, tts, osm, nasa, eonet, apod, stats)
│   ├── assets/               Dữ liệu, âm thanh, mô hình giọng nói (mục 4.1)
│   ├── test/                 Kiểm thử tự động
│   ├── tool/                 Script build Vercel, tạo dữ liệu
│   └── vercel.json           Cấu hình web trên Vercel
├── pipeline/                 Python: tải, chuẩn hóa, kiểm chứng dữ liệu NASA (xem DATA_SOURCES.md)
├── data_nasa/                Kho dữ liệu gốc F1–F3 (nhập vào app bằng pipeline/import_data_nasa.py)
├── docs/                     Tài liệu (file này, DATA_SOURCES.md, báo cáo khả thi…)
└── web/                      Bản web HTML cũ (bản đồ chạm–nghe ban đầu), không phải bản đang chạy trên Vercel
```

### 6.2. Nghe và nói: app khác web thế nào

| | App (Android, iOS, Windows) | Web (trình duyệt) |
|---|---|---|
| Nghe | **sherpa-onnx** (Zipformer tiếng Việt, offline) và **Silero VAD** (nhận biết lúc ngừng nói). Tuỳ chọn ASR đám mây Groq/NVIDIA trong Cài đặt | **Web Speech API** của trình duyệt (Chrome, Edge). Máy tính để bàn nghe liên tục, có chờ khi người dùng ngập ngừng |
| Nói | **Piper** `vi_VN-vais1000` offline. Windows dự phòng bằng giọng hệ thống | Giọng Việt của trình duyệt (Edge HoaiMy/NamMinh, Safari Linh, Chrome Android). Không có thì dùng **Piper trên máy chủ** (`/api/tts`) |
| Mất mạng | Nghe, nói và dữ liệu đóng gói vẫn chạy | Cần mạng để tải trang. Dữ liệu đóng gói vẫn dùng được sau khi đã tải |

### 6.3. Khoá bí mật (bắt buộc đọc)

- **Không bao giờ đưa khoá vào mã nguồn hay git.**
  - Bản app đọc khoá từ `app/keys.json` hoặc `app/.env` (cả hai đã nằm trong `.gitignore`; mẫu ở `keys.example.json`, `.env.example`) hoặc từ Cài đặt.
  - Bản web chỉ dùng khoá đặt trong **Vercel → Project Settings → Environment Variables**: `GEMINI_API_KEY`, `NASA_API_KEY`, `KV_REST_API_URL`, `KV_REST_API_TOKEN`. Có thể đặt thêm `AI_PER_MIN` và `AI_MAX_INFLIGHT`.
- Trình duyệt không bao giờ thấy khoá: mọi lời gọi cần khoá đều đi qua `/api/*`.
- Thống kê `/api/stats` chỉ đếm số lượt, không lưu thông tin cá nhân.

---

## 7. Chạy, kiểm thử, triển khai

```bash
cd app
flutter pub get
flutter test                       # chạy toàn bộ kiểm thử
flutter run -d chrome              # chạy bản web trên máy
flutter run -d windows             # bản Windows (Lang.exe)
flutter run                        # điện thoại Android đang cắm (bật Gỡ lỗi USB)
flutter build web --release        # đóng gói web vào app/build/web
```

- **Web trên Vercel:** Vercel tự build từ GitHub (`ducvinh101101/sense`) bằng `tool/vercel_install.sh` (tải Flutter stable) và `tool/vercel_build.sh`, xuất ra `build/web`. Máy chủ ở Singapore (`sin1`).
- **Cập nhật dữ liệu NASA:** xem `docs/DATA_SOURCES.md`. Lệnh chính là `python -m pipeline.update`. Kho `data_nasa/` nhập vào app bằng `python pipeline/import_data_nasa.py`.
- **Kiểm thử quan trọng** (`app/test/`):
  - `control_commands_massive_test.dart`: hơn 3.300 câu lệnh mẫu.
  - `web_hard_cases_test.dart`, `vi_ambiguity_test.dart`: câu khó, câu dễ nhầm nghĩa tiếng Việt.
  - `hanoi_places_test.dart`, `intent_domain_test.dart`: dữ liệu và câu hỏi ăn, ở Hà Nội.
  - `game_choice_test.dart`: chọn trò chơi.
  - `exit_home_test.dart`, `z_gesture_test.dart`: lối thoát và cử chỉ chữ Z.
  - `terrain_patch_test.dart`, `vector_tiles_test.dart`: bản đồ địa hình thật, giải mã ô vector sông suối.

> Thêm câu lệnh mới hay sửa cách hiểu câu thì **thêm câu mẫu vào test** để lần sửa sau không làm hỏng câu cũ.

---

## 8. Giới hạn đã biết và việc còn mở

1. **Chưa thử với người khiếm thị thật.** Phiếu `docs/Khảo sát.docx` và sheet "Đánh giá chức năng" trong file Excel dùng cho việc này. Chưa có kết quả thì không đưa con số nào vào slide.
2. **TalkBack/VoiceOver giữ cử chỉ chạm**, nên khi bật trình đọc màn hình thì rê tay và vẽ chữ Z có thể không nhận. Cần thử.
3. **Độ phân giải:**
   - NASA POWER/MERRA-2 khoảng 50 km nên không thấy mưa cục bộ.
   - Lớp phủ MODIS khoảng 500 m nên chỉ phân biệt được vùng lớn. Tên sông, suối, phố cụ thể lấy từ OpenStreetMap.
4. **Rung trên web** chỉ có ở điện thoại Android; trình duyệt iPhone và máy tính không hỗ trợ.
5. **Phần quán ăn và chỗ ở Hà Nội đang tạm ẩn.** Dữ liệu do nhóm tự tổng hợp, chưa phải nguồn chính thức.
6. **Máy chủ bên ngoài có lúc bận** (Gemma 4 lỗi 500, Open-Meteo 503, Overpass quá tải). App đã có thử lại, model dự phòng và nguồn dự phòng.
7. **Danh bạ hành chính (`vn_dvhc.json`) không phải nguồn chính thức.** Việc quan trọng thì đối chiếu với nghị quyết sáp nhập.
8. **Chuỗi NASA POWER ở Việt Nam không đồng nhất theo thời gian** (mưa thập niên 1980 thấp, nhảy bậc quanh 2016). Xu hướng đã chuyển sang ERA5; F1 với khoảng dài vẫn cần sửa (mục 3.2).
9. **Số liệu Máy hát Trái Đất đọc từ màu của hình**, chỉ là xấp xỉ.
10. **Điểm cháy `fire_firms` đang viết tay**, chưa đếm từ FIRMS.

---

## 9. Ghi công nguồn

- NASA GISS GISTEMP v4 — <https://data.giss.nasa.gov/gistemp/>
- NASA POWER (MERRA-2) — <https://power.larc.nasa.gov/>
- NASA FIRMS (MODIS C6.1) — <https://firms.modaps.eosdis.nasa.gov/>
- NASA SEDAC GDIS (thiên tai định vị) — <https://doi.org/10.7910/DVN/7UW1YK>
- NASA SRTM, MODIS (MCD12Q1, MOD13Q1, MOD11A2) — <https://lpdaac.usgs.gov/>; NASA GIBS — <https://earthdata.nasa.gov/gibs>
- NASA SEDAC GPWv4 (dân số) — <https://sedac.ciesin.columbia.edu/>
- NASA NSSDCA Planetary Fact Sheet — <https://nssdc.gsfc.nasa.gov/planetary/factsheet/>; NASA Space Place — <https://spaceplace.nasa.gov/>
- NASA EONET — <https://eonet.gsfc.nasa.gov/>; NASA APOD — <https://apod.nasa.gov/>
- NASA Historical Sounds, Chandra, Perseverance, Voyager (âm thanh vũ trụ)
- NASA Scientific Visualization Studio: SVS 5475 / 5313 (Black Marble), 5011 (LIS trên ISS), 5436 / 5196 (GEOS DYAMOND CO₂), 3912 (ECCO2), 4950 (GEDI) — <https://svs.gsfc.nasa.gov/>
- NASA Science (số mặt trăng) — <https://science.nasa.gov/solar-system/>
- Nguồn ngoài NASA:
  - Open-Meteo — <https://open-meteo.com/>
  - ERA5, Copernicus Climate Change Service (C3S) / ECMWF (xu hướng xưa – nay)
  - Ô độ cao Terrarium (AWS Open Data) — <https://registry.opendata.aws/terrain-tiles/>
  - OpenStreetMap — <https://www.openstreetmap.org/copyright>; ô vector OpenFreeMap — <https://openfreemap.org/>
  - NOAA ETOPO5
  - EC JRC Global Surface Water
  - WWF HydroSHEDS
  - USGS
  - GADM 4.1
  - atlas34 (đơn vị hành chính Việt Nam)
- Phần mềm: Flutter, sherpa-onnx, Silero VAD, Piper TTS, flutter_soloud, Google Gemma 4 / Gemini.
- Khai báo AI: app dùng Gemma 4 / Gemini cho hỏi đáp tự nhiên. Quá trình phát triển có dùng trợ lý lập trình AI.
