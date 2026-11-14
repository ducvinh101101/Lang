# Lắng · Quả Địa Cầu Biết Nói & Âm Thanh Hóa Dữ Liệu Khoa Học NASA

> **NASA Space Apps Challenge 2026** — Thử thách **#14: *The Earth Information Jukebox***  
> **Định hướng:** Chuyển hóa kho dữ liệu khoa học mở của NASA (Khí hậu, Thiên tai, Vệ tinh Mặt đất & Vũ trụ) thành trải nghiệm **Âm thanh Nhạc cụ Dân tộc Việt Nam + Giọng nói Trợ năng + Xúc giác Haptic** dành cho người khiếm thị và cộng đồng.

---

## 1. Tổng Quan Dự Án (Project Overview)

Các biểu đồ khí hậu và ảnh vệ tinh từ **NASA Earth Information Center (EIC)** mang giá trị khoa học to lớn nhưng lại là rào cản đối với **người khiếm thị tại Việt Nam** (khảo sát RAAB 2015: khoảng 1,8% người từ 50 tuổi trở lên bị mù) và hàng trăm triệu người suy giảm thị lực trên thế giới.

**Lắng** giải quyết bài toán này bằng cách xây dựng một **"Earth Information Jukebox" đa giác quan**:
- **Nghe Trái Đất bằng Nhạc cụ Dân tộc Việt Nam (Cultural Data Sonification)**:
  - **Đàn Bầu** *(mô hình vật lý Karplus-Strong)*: Uốn cao độ theo nhiệt độ không khí `T2M` và chuỗi 146 năm ấm lên toàn cầu (`1880–2025`).
  - **Đàn T'rưng**: Gõ nhịp ống tre theo cường độ lượng mưa `PRECTOTCORR` và tái hiện chuỗi 15 ngày mưa lũ lịch sử.
  - **Tiếng Lửa Khô & Trống Đồng**: Biểu thị mật độ điểm nóng cháy rừng theo mùa từ vệ tinh NASA FIRMS (`MODIS C6.1 MCD14ML`) và cảnh báo thời tiết cực đoan.
  - **Mõ & Tiếng Sóng Biển**: Báo hiệu khi ngón tay vượt qua ranh giới tỉnh/vùng khí hậu, đường bờ biển, kèm **tiếng chiêng ngân khẳng định chủ quyền tại quần đảo Hoàng Sa và Trường Sa (Việt Nam)**.
- **Máy hát Trái Đất — nghe hình ảnh dữ liệu NASA (đúng đề #14)**: 5 hình của NASA Scientific Visualization Studio / Earth Information Center (ánh đèn ban đêm Black Marble, sét từ ISS, CO₂ DYAMOND, nhiệt độ mặt biển ECCO2, chiều cao rừng GEDI) được đổi từ màu ra số (`pipeline/build_eic.py`) rồi phát thành âm thanh, kèm mô tả hình Section 508, lý do chọn âm, rê tay trên hình. Xem [`docs/MAY_HAT_TRAI_DAT.md`](docs/MAY_HAT_TRAI_DAT.md).
- **Tương tác Giọng nói Rảnh tay 100% & Trợ lý AI Khoa học**:
  - Nhận diện giọng nói tiếng Việt ngoại tuyến (**Sherpa-ONNX Zipformer + Silero VAD**) và giọng đọc Neural TTS offline (**Piper `vi_VN-vais1000`**).
  - Tích hợp mô hình **Google Gemma 4 MoE (`gemma-4-26b-a4b-it`)** kết hợp **Local Earth RAG** trích xuất trực tiếp từ 6 bộ dữ liệu chuẩn hóa của NASA, để AI diễn đạt lại số liệu thật thay vì tự bịa (hạn chế ảo giác số liệu).
- **Trợ năng (độ tương phản màu ≈ 13,8:1, vượt ngưỡng AAA của WCAG; mô tả ảnh theo hướng dẫn Section 508)**:
  - Giao diện Sơn Mài tương phản cực cao (`#0A0D14` / `#FFD54F`), tương thích TalkBack / VoiceOver, mô tả ảnh thiên văn theo 4 quy tắc Section 508 và phản hồi rung xúc giác **Haptic** theo địa hình.

---

## 2. Hệ Sinh Thái Dữ Liệu NASA Đã Chuẩn Hóa & Tích Hợp (`app/assets/data/`)

Toàn bộ dữ liệu NASA trong **Lắng** được chuẩn hóa theo 3 nhóm chức năng (**F1 – F2 – F3**), đính kèm khối siêu dữ liệu chuẩn **`data_card` (12 trường)**, bảng ghi công **[`credits.csv`](app/assets/data/credits.csv) (6 cột)**, và vượt qua **7 cổng kiểm định chất lượng tự động (7-Point Quality Gate)**:

| Nhóm | Tệp Dữ Liệu Chuẩn Hóa | Nguồn Dữ Liệu NASA Gốc | Nội Dung & Ứng Dụng Trong Web/App |
|---|---|---|---|
| **F1** | **[`gistemp_global.json`](app/assets/data/gistemp_global.json)** | **NASA GISS Surface Temperature Analysis (GISTEMP v4)** (`1880–2025`, kỳ chuẩn `1951–1980`) | Chuỗi 146 năm dị thường nhiệt độ toàn cầu (`+1,28 °C` năm 2024; `+1,18 °C` năm 2025); phát chuỗi âm thanh Đàn Bầu `gistempYears`. |
| **F1** | **[`climate_history_nasa.json`](app/assets/data/climate_history_nasa.json)** | **NASA POWER Monthly & Daily (MERRA-2)** (`1981–2025`, chốt `end <= 20251231`) & **NASA FIRMS (`MODIS C6.1 MCD14ML`)** | • Chuỗi 45 năm nhiệt độ (`T2M`) & mưa (`PRECTOTCORR`) cho **29 địa điểm** (14 tỉnh/thành đại diện 7 vùng khí hậu VN + 15 TP thế giới).<br>• Số liệu từng tháng, từng năm cho F1. ⚠️ **Xu hướng xưa – nay** (ấm lên, ngày nắng nóng 3 ngưỡng KTTV `≥ 35/37/39 °C`, mưa cả năm) **lấy từ ERA5**, không từ POWER: kiểm tra 14/11/2026 cho thấy chuỗi POWER ở Việt Nam không đồng nhất theo thời gian (Hà Nội tính ra "mát đi 0,97 °C" trong khi ERA5 cho "ấm lên 1,02 °C"). Xem [`docs/HUONG_DAN_DU_LIEU_NASA.md`](docs/HUONG_DAN_DU_LIEU_NASA.md) mục 5.4.<br>• Chuỗi 15 ngày **Siêu bão Yagi (01–15/09/2024 tại Hà Nội & Quảng Ninh)** và **Mưa lũ miền Trung (06–20/10/2020 tại Huế)** kèm thuyết minh rõ độ phân giải ô lưới tái phân tích `~50 km`.<br>• Phân bố 12 tháng điểm cháy rừng cho 6 vùng khí hậu Việt Nam (`fire_firms`) — ⚠️ hiện là số viết tay, đang thay bằng số đếm từ API FIRMS. |
| **F1** | **[`vn_disasters_nasa.json`](app/assets/data/vn_disasters_nasa.json) & [`climate_34_provinces.json`](app/assets/data/climate_34_provinces.json)** | **NASA SEDAC GDIS & NASA POWER Monthly (`1981–2025`)** | • **282 sự kiện thiên tai lịch sử tại Việt Nam** (107 bão, 59 lũ, 116 sạt lở) định vị theo tỉnh/thành.<br>• Dữ liệu khí hậu tháng `1981–2025` cho **34 tỉnh/thành Việt Nam**, tra cứu lịch sử thời tiết và thiên tai hoàn toàn offline. |
| **F1** | **[`touchgrid.json`](app/assets/data/touchgrid.json), [`series.json`](app/assets/data/series.json) & `frames/*.bin`** | **NASA POWER + NASA FIRMS + GADM 4.1** | Lưới không gian `0,1°` (`100 × 153` ô, `2.849` ô đất liền Việt Nam) lượng tử hóa `uint8` siêu nhẹ qua 300 tháng (`2001–2025`). |
| **F2** | **[`planets_nasa.json`](app/assets/data/planets_nasa.json)** | **NASA NSSDCA Planetary Fact Sheet (Metric)**, NASA Solar System Exploration & **NASA Space Place** | Thông số chuẩn cho Mặt Trời, 8 hành tinh và Mặt Trăng (số mặt trăng theo NASA Science 8/2026: Sao Thổ 293, Sao Mộc 115, Sao Thiên Vương 29, Sao Hải Vương 16) kèm **135 sự thật thú vị (`fun_facts`)** đã đổi sang hệ mét từ NASA Space Place. |
| **F2** | **[`space_media.json`](app/assets/data/space_media.json) & [`assets/sounds/nasa/catalog.json`](app/assets/sounds/nasa/catalog.json)** | **NASA Chandra X-ray, NASA Perseverance Mars Mic, NASA Voyager PWS, JWST, Hubble & NASA Historical Sounds** | • 6 bản âm thanh & mô tả vũ trụ chuẩn **Mục 508 (Section 508)**; phân biệt minh bạch 3 nhãn `recording`, `nasa_sonification` và `app_sonification`.<br>• **10 bản ghi âm lịch sử thật của NASA (`*.mp3`)** (Apollo 11, Apollo 13, Sputnik 1, Voyager, Perseverance, Ingenuity, Kepler,LCROSS...) dùng để nghe trực tiếp và chơi trò **"Đố âm thanh NASA"**. |
| **F2** | **[`qa_bank.json`](app/assets/data/qa_bank.json)** | **NASA Space Place, NASA Science, NASA GISS, NSSDCA** | **35 cặp câu hỏi – trả lời kiểm chứng** trực tiếp từ NASA (bao gồm **12 câu đính chính nhận thức sai phổ biến** về Trái Đất và Vũ trụ). |
| **F3** | **[`dalat_scene.json`](app/assets/data/dalat_scene.json) & [`assets/touch/vn/grid.json`](app/assets/touch/vn/grid.json)** | **NASA SRTMGL30 v002**, **NASA SEDAC GPWv4 rev11** (mật độ dân số 2020; diện tích mặt nước), **NASA MODIS (`MCD12Q1`)** qua GIBS lúc chạy; cảnh Đà Lạt: SRTM, MODIS & EC JRC Water | • Lưới chạm địa hình toàn Việt Nam `152 × 306` ô, mỗi ô `0,05°` (~5,5 km) (`elev.png`, `slope.png`, `water.png`, `pop.png`) và lưới đa lớp `12 × 12` quanh Đà Lạt (lớp phủ đang gán theo quy tắc, chỉ làm dự phòng); phát tiếng sáo theo độ cao, tiếng sóng/lá/xe cộ theo bề mặt, rung Haptic mạnh theo độ dốc và quét mặt cắt địa hình (mỗi lượt quét ≤ 8 giây). |
| **#14** | **[`assets/eic/`](app/assets/eic/)** (5 bộ: `nightlights`, `lightning`, `co2`, `ocean`, `forest`) | **NASA SVS** 5475/5313 (Black Marble VIIRS), 5011 (LIS trên ISS), 5436/5196 (GEOS DYAMOND), 3912 (ECCO2), 4950 (GEDI) | **Máy hát Trái Đất**: khung hình 768 × 384, số liệu từng khung (toàn cầu, diện tích, vị trí đông–tây, vùng Việt Nam), lưới rê tay 64 × 32, mô tả Section 508, lý do chọn âm. Số đọc từ màu của hình (xấp xỉ). |

> **Minh bạch nguồn dữ liệu bằng giọng nói:** Bất kỳ lúc nào người dùng nói khẩu lệnh **"Nguồn dữ liệu"** (*"Data source"*), ứng dụng sẽ đọc to nguyên văn tuyên bố ghi công các nguồn NASA và tách bạch rõ các nguồn bổ trợ ngoài NASA (Open-Meteo, EC JRC, WWF HydroSHEDS).

---

## 3. Cấu Trúc Thư Mục (Repository Structure)

```text
├── app/                          Ứng dụng đa nền tảng Flutter (Web, Android, iOS, Windows)
│   ├── assets/data/              Kho dữ liệu NASA chuẩn hóa (6 bộ JSON + touchgrid.json + frames/*.bin + credits.csv)
│   ├── lib/
│   │   ├── audio/                Bộ tổng hợp âm thanh C++ SoLoud & nhạc cụ dân tộc (synth.dart, audio_engine.dart)
│   │   ├── data/                 NasaNormalizedRepo (nasa_normalized_data.dart) & AssetData (asset_data.dart)
│   │   ├── features/globe/       Quả địa cầu 3D Sơn Mài, Bản đồ địa hình đa lớp (local_map.dart), Âm thanh (world_sound.dart)
│   │   ├── features/space/       Hệ Mặt Trời, thông số hành tinh NASA 2026 & trò chơi vũ trụ (planet_facts.dart, planet_games.dart)
│   │   ├── features/touch/       Bản đồ Chạm–Nghe Việt Nam & Dòng thời gian 300 tháng (touch_page.dart)
│   │   ├── live/                 NASA POWER/FIRMS/EONET/APOD Live, EarthRag, Google Gemma 4 Assistant
│   │   └── speech/               Sherpa-ONNX Offline ASR, Silero VAD & Piper Neural TTS tiếng Việt
│   └── test/                     Bộ kiểm thử tự động (nasa_normalized_data_test.dart, planet_facts_test.dart...)
├── pipeline/                     Pipeline Python tải, chuẩn hóa, lượng tử hóa & kiểm chứng dữ liệu NASA
│   ├── config.py                 Khai báo biến, đơn vị, thang lượng tử hóa và nguồn NASA (power | firms | neo | inbox)
│   ├── update.py                 Một lệnh đồng bộ: tải → chuẩn hóa → build → validate → xuất sang app & web
│   ├── build.py                  Đổi lưới 0,1°, mặt nạ đất/biển, khoảng cách bờ biển, lượng tử hóa uint8
│   └── validate.py               Đối chiếu sai số giữa file nhị phân xuất ra với dữ liệu gốc NASA (tiêu chí Validity)
├── web/                          Ứng dụng Web độc lập (index.html + web/data/)
├── docs/                         Tài liệu Kiến trúc Công nghệ & Khai thác Dữ liệu NASA
│   ├── TECH_DATA_DOCUMENTATION.md
│   ├── TECH_DATA_DOCUMENTATION.docx
│   └── DATA_SOURCES.md
└── tests/                        Bộ kiểm thử pytest cho pipeline Python
```

---

## 4. Bằng Chứng Kiểm Định Độ Chính Xác Dữ Liệu (Validity Evidence)

### 4.1. Kiểm định Pipeline Lượng tử hóa Lưới 0,1° — 300 Tháng Dữ liệu NASA POWER Thật (`pipeline/validate.py`)
Chạy lệnh kiểm chứng đối chiếu trực tiếp giữa mảng lượng tử hóa `uint8` trong `touchgrid.json` / `frames/*.bin` (300 tháng, `2001–2025`, `1.488` điểm lưới gốc nội suy sang `2.849` ô đất liền `0,1°`) và dữ liệu gốc NASA POWER:

```text
[kiểm tra] temp: trung bình tháng 25.7 °C, thấp nhất 20.6, cao nhất 29.3 (Việt Nam thường 15–30 °C)
[kiểm tra] rain: trung bình tháng 158.8 mm/tháng, thấp nhất 9.8, cao nhất 373.9 → tổng năm ≈ 1905 mm (Việt Nam thường 1.200–3.000 mm)
[build] temp: 300 tháng, thiếu 0
[build] rain: 300 tháng, thiếu 0
[build] touchgrid.json: 280 KB | series.json: 41 KB | 2849 ô đất liền
[validate] temp 2005-10: 2849 ô, sai số lớn nhất 0.058 °C, vượt ngưỡng 0
           điểm 22.25°N 104.75°E: gốc 23.89, web 23.90
           điểm 20.35°N 106.55°E: gốc 24.82, web 24.84
           điểm 21.75°N 105.35°E: gốc 23.63, web 23.66
[validate] rain 2013-04: 2849 ô, sai số lớn nhất 1.485 mm/tháng, vượt ngưỡng 0
           điểm 21.95°N 104.15°E: gốc 133.20, web 134.39
           điểm 12.75°N 108.95°E: gốc 23.10, web 22.79
           điểm 22.55°N 103.85°E: gốc 135.60, web 134.39
[validate] ĐẠT
```

### 4.2. Kiểm định 7 Cổng Chất lượng Dữ liệu Chuẩn hóa (`app/test/nasa_normalized_data_test.dart`)
```bash
cd app
flutter test
# 00:03 +15: All tests passed! (Đạt 7/7 cổng Quality Gate trên toàn bộ 6 bộ JSON NASA & credits.csv)
```

---

## 5. Hướng Dẫn Cài Đặt & Chạy Nhanh (Quick Start)

### A. Chạy Ứng dụng Đa nền tảng (Flutter — Web / Android / Windows / iOS)
```bash
cd app
flutter pub get
flutter test                      # Kiểm tra toàn bộ 15 unit tests & 7-Point Quality Gate
flutter run -d chrome             # Chạy trên trình duyệt Web
flutter run -d windows            # Chạy bản Windows Desktop (Lang.exe)
flutter build web --release       # Đóng gói bản Web sản phẩm vào app/build/web
```

### B. Chạy Pipeline Cập nhật Dữ liệu NASA (`Python 3.11+`)
```bash
pip install -r requirements.txt
python -m pytest -q                                     # Kiểm thử pipeline Python
python -m pipeline.update --only temp rain              # Tải dữ liệu thật NASA POWER (2001–2025) & build tự động
```
Xem hướng dẫn chi tiết cách nạp thêm tệp NetCDF / HDF5 / GeoTIFF từ hộp thư `data/inbox/` tại **[docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)** và kiến trúc toàn hệ thống tại **[docs/TECH_DATA_DOCUMENTATION.md](docs/TECH_DATA_DOCUMENTATION.md)**.

---

## 6. Ghi Công Nguồn Dữ Liệu & Công Cụ (References & Credits)

1. **NASA GISS Surface Temperature Analysis (GISTEMP v4)** — Goddard Institute for Space Studies: https://data.giss.nasa.gov/gistemp/
2. **NASA POWER Project (Prediction Of Worldwide Energy Resources — MERRA-2)** — NASA Langley Research Center: https://power.larc.nasa.gov/
3. **NASA FIRMS (Fire Information for Resource Management System — MODIS Collection 6.1 `MCD14ML`)** — NASA LANCE / EOSDIS: https://firms.modaps.eosdis.nasa.gov/
4. **NASA SRTM GL1 v003 (Shuttle Radar Topography Mission 30m)** & **NASA MODIS (`MCD12Q1`, `MOD13Q1`, `MOD11A2`)** — NASA LP DAAC: https://lpdaac.usgs.gov/
5. **NASA NSSDCA Planetary Fact Sheet (Metric)** — NASA Goddard Space Flight Center: https://nssdc.gsfc.nasa.gov/planetary/factsheet/
6. **NASA Chandra X-ray Observatory, NASA Perseverance Mars Microphone & NASA Voyager PWS** (Audio & Sonifications): https://www.nasa.gov/mission_pages/chandra/news/black-hole-sonification-remix.html
7. **NASA Earth Observatory (NEO), NASA EONET & NASA APOD**: https://neo.gsfc.nasa.gov/ | https://eonet.gsfc.nasa.gov/
8. **NASA Scientific Visualization Studio** (Máy hát Trái Đất): SVS 5475 / 5313, 5011, 5436 / 5196, 3912, 4950 — https://svs.gsfc.nasa.gov/
9. **NASA SRTMGL30 v002** (LP DAAC) & **NASA SEDAC GPWv4 rev11** (mật độ dân số, diện tích mặt nước) — lưới chạm F3: https://www.earthdata.nasa.gov/
10. **NASA Science** (số mặt trăng cập nhật): https://science.nasa.gov/solar-system/
11. **Nguồn bổ trợ ngoài NASA (được tách bạch minh bạch)**:
   - **Open-Meteo API** (Dự báo thời tiết thời gian thực): https://open-meteo.com/
   - **ERA5 — Copernicus Climate Change Service / ECMWF** (qua Open-Meteo Archive): xu hướng khí hậu xưa – nay.
   - **USGS** (động đất trong lịch sử thiên tai).
   - **EC JRC Global Surface Water** & **WWF HydroSHEDS / HydroRIVERS** (Lớp thủy văn bổ trợ trong `dalat_scene.json`).
   - **GADM v4.1** & dữ liệu hành chính Việt Nam (bao gồm quần đảo **Hoàng Sa** và **Trường Sa**).
12. **Khai báo sử dụng công cụ AI**:
   - Trong ứng dụng: Sử dụng **Google Gemma 4 (`gemma-4-26b-a4b-it`)** kết hợp **Local Earth RAG** cho tính năng hỏi đáp giọng nói tự nhiên, nhận diện giọng nói offline **Sherpa-ONNX**, và giọng đọc **Piper Neural TTS**.
   - Trong quá trình phát triển: Có sự hỗ trợ của trợ lý lập trình AI (Antigravity / Claude) trong việc chuẩn hóa pipeline kiểm thử và tài liệu hóa.
