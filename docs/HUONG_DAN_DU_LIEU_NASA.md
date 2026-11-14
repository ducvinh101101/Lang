# HƯỚNG DẪN LẤY VÀ SỬ DỤNG DỮ LIỆU NASA

> **Dự án Lắng** · Đội Lắng · NASA Space Apps Challenge 2026 (#14)
> Cập nhật: 14/11/2026. Lần này bổ sung: **mục 3**, dữ liệu theo 3 chức năng chính (F1, F2, F3: phần nào dùng file nào); **mục 4**, bộ dữ liệu mới từ hình ảnh NASA SVS cho Máy hát Trái Đất (#14); **mục 5**, kiểm chứng bằng cách gọi thử thật từng nguồn và **kiểm tra số liệu thật đang đóng gói trong app** (mục 5.4: phát hiện chuỗi NASA POWER ở Việt Nam không đồng nhất theo thời gian, số mặt trăng đã cũ, cỡ lưới chạm F3 ghi sai; cả ba đã sửa). Tài liệu dành cho mọi thành viên: người tìm dữ liệu, người viết pipeline, người viết app, người làm slide.
> Tài liệu kỹ thuật chi tiết của pipeline: `docs/DATA_SOURCES.md`. Tài liệu chung về app: `docs/TECH_DATA_DOCUMENTATION`. Thiết kế âm thanh của Máy hát Trái Đất: `docs/MAY_HAT_TRAI_DAT.md`.

---

## 1. Nguyên tắc chung (đọc trước)

1. **Mỗi con số trong app phải truy được về nguồn.** Mỗi file JSON trong `app/assets/data/` có khối `data_card`. Mỗi file âm thanh hoặc dữ liệu có một dòng trong `credits.csv`.
2. **Không chép số tay vào code rồi gọi là "dữ liệu NASA".** Số phải được tải bằng script. Nếu bắt buộc chép tay (ví dụ bảng NSSDCA), ghi rõ trong `data_card.processing`.
3. **Không đưa khoá API lên GitHub.** Khoá để trong `.env`, `keys.json` (đã nằm trong `.gitignore`), biến môi trường, hoặc Vercel → Environment Variables.
4. **Luôn ghi rõ giới hạn.** Ví dụ: độ phân giải 50 km, năm cuối có số liệu, phần nào là ước lượng. App đọc giới hạn này cho người dùng nghe.
5. **Kiểm tra trước khi dùng:** đơn vị, giá trị thiếu (`-999`, `***`, `NaN`), năm chưa đủ 12 tháng. Xem mục 5 (kiểm chứng từng nguồn) và mục 11.

---

## 2. Bản đồ dữ liệu: dùng gì, ở đâu, lấy thế nào

| Dữ liệu NASA | Dùng cho | File trong app | Cách lấy | Khoá |
|---|---|---|---|---|
| **GISTEMP v4** (NASA GISS) | 146 năm nhiệt độ toàn cầu | `gistemp_global.json` | Tải file CSV | Không |
| **POWER** (NASA LaRC, MERRA-2) | Khí hậu từng tháng, từng ngày, bão Yagi, lũ Huế, lưới chạm. ⚠️ **Không dùng để nói xu hướng dài hạn ở Việt Nam** (mục 5.4) | `climate_history_nasa.json`, `climate_34_provinces.json`, `touchgrid.json`, `frames/` | API | Không |
| **FIRMS** (MODIS C6.1) | Điểm cháy | lưới `fire` trong `touchgrid.json` (chưa có, cần chạy với MAP_KEY); `fire_firms` trong `climate_history_nasa.json` | API | **MAP_KEY** (miễn phí) |
| **SEDAC GDIS** | 282 thiên tai Việt Nam | `vn_disasters_nasa.json` | Tải file trên SEDAC | Earthdata Login |
| **SEDAC GPWv4** (Population Density; Land and Water Area) | Mật độ dân số và mặt nước nội địa, lưới chạm toàn quốc | `assets/touch/vn/pop.png`, `water.png` | `data_nasa/crawl_f3.py` (earthaccess) | Earthdata Login |
| **SRTM** (SRTMGL30 v002) | Độ cao, độ dốc, lưới chạm toàn quốc | `assets/touch/vn/elev.png`, `slope.png` | `data_nasa/crawl_f3.py` (LP DAAC); lúc chạy dùng ô Terrarium (AWS) | Earthdata / Không |
| **MODIS MCD12Q1** (lớp phủ đất) | Rê tay khám phá | gọi trực tiếp lúc chạy | NASA GIBS (ô bản đồ) | Không |
| **NSSDCA Planetary Fact Sheet** | Thông số 10 thiên thể | `planets_nasa.json` | Đọc trang web | Không |
| **NASA Space Place** | 135 sự thật thú vị | `planets_nasa.json` → `fun_facts` | Kho `data_nasa/` | Không |
| **NASA Historical Sounds** | 10 bản ghi âm thật | `assets/sounds/nasa/` | Tải mp3 trên nasa.gov | Không |
| **APOD** | Ảnh thiên văn hôm nay | gọi trực tiếp lúc chạy | API api.nasa.gov | Khoá api.nasa.gov (có DEMO_KEY) |
| **EONET** | Thiên tai đang diễn ra | gọi trực tiếp lúc chạy | API | Không |
| **SVS 5475** Black Marble (VIIRS) | Máy hát: ánh đèn đêm 2012–2023 (có thể dùng cho F3, F1) | `assets/eic/nightlights/` | Tải video SVS → `build_eic.py` | Không |
| **SVS 5011** LIS trên ISS | Máy hát: sét 12 tháng (có thể dùng cho F1) | `assets/eic/lightning/` | Tải video SVS → `build_eic.py` | Không |
| **SVS 5436 / 5196** GEOS DYAMOND | Máy hát: CO₂ gần mặt đất 1–3/2020 | `assets/eic/co2/` | Tải 2 video SVS → `build_eic.py` | Không |
| **SVS 3912** ECCO2 | Máy hát: nhiệt độ mặt biển, Biển Đông theo tháng (có thể dùng cho F1, F3) | `assets/eic/ocean/` | Tải video SVS → `build_eic.py` | Không |
| **SVS 4950** GEDI | Máy hát: chiều cao tán rừng (có thể dùng cho F3) | `assets/eic/forest/` | Tải video SVS → `build_eic.py` | Không |

**Nguồn ngoài NASA đang dùng** (phải ghi công riêng):
- Open-Meteo: thời tiết hôm nay và dự báo.
- **ERA5** (Copernicus C3S / ECMWF, qua Open-Meteo Historical Weather API): **xu hướng xưa – nay** (nhiệt độ, mưa, ngày nắng nóng 1981 đến năm ngoái), vì chuỗi POWER ở Việt Nam không đồng nhất (mục 5.4).
- OpenStreetMap / OpenFreeMap: tên sông, đường.
- AWS Terrain Tiles: độ cao, có dùng dữ liệu SRTM.
- ETOPO (NOAA): độ cao toàn cầu 0,5° cho quả địa cầu (`assets/world/elev_glob.bin`).
- USGS: động đất trong F1.
- GADM: ranh giới.

---

## 3. Dữ liệu theo 3 chức năng chính: phần nào dùng dữ liệu nào

Mục này trả lời câu hỏi: **khi người dùng nói một câu, app lấy số từ đâu?** Mỗi chức năng được trình bày theo cùng một khuôn: (a) người dùng làm gì, (b) dữ liệu nào phục vụ từng bước, file nằm ở đâu, code nào đọc, (c) khi mất mạng thì sao, (d) muốn làm tốt hơn thì thêm dữ liệu gì.

Ký hiệu: 📦 = đóng gói sẵn trong app, chạy không cần mạng · 🌐 = app gọi qua mạng lúc chạy · ⚠️ = đang là ước lượng hoặc viết tay, chưa nên nói là "dữ liệu vệ tinh NASA".

### 3.1. F1: Lịch sử thời tiết và thiên tai

**Người dùng làm gì.** Nói *"lịch sử thời tiết Huế 3 năm qua"*, *"thiên tai ở Quảng Ninh từ 2015"*. App dựng các bản ghi: mỗi tháng một bản ghi nếu khoảng thời gian ≤ 3 năm, mỗi năm một bản ghi nếu dài hơn. Sau đó app phát lần lượt từng bản ghi: âm thanh nóng, lạnh, mưa, rồi các thiên tai xếp từ nhẹ đến nặng, kèm đồ hoạ và thanh timeline. Chạm màn hình thì app giải thích bản ghi đang phát.

**Dữ liệu cho từng bước:**

| Bước trong F1 | Dữ liệu | File / nguồn | Code đọc | Ghi chú |
|---|---|---|---|---|
| Nhiệt độ, lượng mưa từng tháng của **mọi điểm trên Trái Đất** | NASA POWER, `T2M` và `PRECTOTCORR`, theo tháng, 1981 đến năm ngoái | 🌐 `power.larc.nasa.gov/api/temporal/monthly/point`; bản web đi qua `/api/nasa` của Vercel để tránh lỗi CORS | `app/lib/live/nasa_power.dart` (`NasaPowerService`) | Ô lưới khoảng 50 km, không phải số đo trạm. Xem mục 7.1 và 8.1 |
| Như trên nhưng **không có mạng**, ở 34 tỉnh/thành | NASA POWER tháng 1981–2025, đã tải sẵn | 📦 `assets/data/climate_34_provinces.json` | `data/nasa_normalized_data.dart` (`parseClimate34`) | Nhập từ kho `data_nasa/f1/.../a_34/` bằng `import_data_nasa.py` |
| 29 điểm mẫu (14 Việt Nam + 15 thế giới), số ngày nắng nóng, bão Yagi 2024, lũ Huế 2020 | NASA POWER tháng và ngày (`T2M_MAX`, `PRECTOTCORR`, `WS10M`) | 📦 `assets/data/climate_history_nasa.json` | `nasa_normalized_data.dart` | Tạo bằng `pipeline/build_f1_climate.py`. Xem mục 8.1 và 8.2 |
| **Xu hướng xưa – nay** (ấm lên, ngày ≥ 35/37/39 °C, mưa cả năm, năm nóng nhất, âm thanh từng năm), cả trong câu trả lời của trợ lý AI | ERA5 (Copernicus/ECMWF, **ngoài NASA**), theo ngày, 1981 đến năm ngoái, một chuỗi liền mạch | 🌐 `archive-api.open-meteo.com/v1/archive` | `live/nasa_power.dart` (`extremes()` → `EraTrend`), `globe_page.dart`, `live/earth_rag.dart` | Không dùng POWER cho xu hướng vì chuỗi POWER ở Việt Nam không đồng nhất (mục 5.4). Mất mạng thì không nói xu hướng |
| Mức "nóng / lạnh / mưa" của một tháng **so với bình thường** | Trung bình cùng kỳ tính từ chính chuỗi POWER ở trên | (tính trong app) | `features/history/history_records.dart` | Đây là cách app suy ra *nắng nóng, rét đậm, mưa lớn bất thường, khô hạn* mà không cần nguồn thiên tai riêng |
| Thiên tai **đã ghi nhận** ở Việt Nam, 1971–2026 | NASA SEDAC GDIS + NASA GLC + EONET, kèm DMC, DesInventar | 📦 `assets/data/vn_disasters_nasa.json` (282 sự kiện, mức nặng 1–5) | `live/hazard_history.dart` | Định vị theo tâm tỉnh. Sự kiện chỉ có năm thì đọc "trong năm …, chưa rõ tháng" |
| Bão, lũ, cháy rừng, núi lửa, sạt lở quanh nơi đó (lưu trữ) | NASA EONET v3, `status=all`, khung ±3° | 🌐 `eonet.gsfc.nasa.gov/api/v3/events` | `live/hazard_history.dart`, `live/eonet.dart` | Không cần khoá |
| Động đất từ 4,5 độ trong bán kính 400 km | USGS FDSN (**ngoài NASA**) | 🌐 `earthquake.usgs.gov` | `live/hazard_history.dart` | Ghi công USGS riêng |
| Cháy rừng theo tháng, theo vùng | NASA FIRMS | ⚠️ `climate_history_nasa.json` → `fire_firms` đang **viết tay** | | Xem mục 8.6 để thay bằng số đếm thật |
| "Trái Đất nóng lên bao nhiêu từ 1880" | NASA GISTEMP v4 | 📦 `assets/data/gistemp_global.json` | `nasa_normalized_data.dart` | Độ lệch so với 1951–1980, không phải nhiệt độ tuyệt đối |
| Bản đồ chạm khí hậu toàn Việt Nam (lưới 0,1°) | NASA POWER regional (+ FIRMS khi có MAP_KEY) | 📦 `assets/data/touchgrid.json`, `series.json`, `frames/` | `data/asset_data.dart` | Tạo bằng `python -m pipeline.update` |
| **Bổ sung từ bộ mới (mục 4):** mùa giông sét, nhiệt độ Biển Đông theo mùa, CO₂ | NASA SVS 5011, 3912, 5436 | 📦 `assets/eic/lightning`, `ocean`, `co2` | `features/eic/` | Hiện dùng trong **Máy hát Trái Đất**. Mục 4.4 nói cách dùng lại cho F1 |

**Khi mất mạng:** F1 vẫn chạy được với 34 tỉnh/thành và 29 điểm mẫu, cùng danh mục thiên tai Việt Nam. Các nơi khác ngoài danh sách cần mạng để gọi POWER. Phần EONET và USGS lỗi thì app bỏ qua, không chặn việc phát lại thời tiết.

**Muốn F1 tốt hơn:**
1. Thay `fire_firms` viết tay bằng số đếm FIRMS thật (mục 8.6).
2. Lượng mưa trong các trận bão: dùng thêm GPM IMERG (mưa ô 10 km). Bỏ file vào `data/inbox/` theo mục 9.1.
3. Đèn đêm theo năm (SVS 5475) có thể làm lớp "mất điện sau bão". Xem mục 4.4.

### 3.2. F2: Khám phá vũ trụ

**Người dùng làm gì.** Nói *"kể về Sao Hỏa"*, *"sự thật thú vị về Sao Thổ"*, *"âm thanh thật của NASA"*, *"đố âm thanh NASA"*, *"Sao Kim nóng hơn Sao Thủy à?"*, *"ảnh thiên văn hôm nay"*.

| Phần trong F2 | Dữ liệu | File / nguồn | Code đọc | Ghi chú |
|---|---|---|---|---|
| Thông số 10 thiên thể (đường kính, khoảng cách, ngày, năm, nhiệt độ, số vệ tinh) | NSSDCA Planetary Fact Sheet (bản hệ mét) | 📦 `assets/data/planets_nasa.json` | `features/space/planet_facts.dart`, `data/planet_bodies.dart` | ⚠️ Chép tay vào `build_f2_space.py`; cần người thứ hai đối chiếu (mục 8.9) |
| "Sự thật thú vị về …": chọn **ngẫu nhiên** một câu | NASA Space Place (135 câu đã dịch) | 📦 `planets_nasa.json` → `fun_facts` | `globe_page.dart` (`_funFact`) | Nhập từ `data_nasa/assets/content/facts.json`; chỉ giữ câu ngắn, bỏ câu có đơn vị Mỹ |
| Hỏi – đáp có kiểm chứng, sửa nhận thức sai | Biên soạn từ trang NASA, mỗi mục kèm đường dẫn | 📦 `assets/data/qa_bank.json` (35+ cặp) | `globe_page.dart` (`_handleNasaNormalizedQuery`) | App tra kho này **trước khi** hỏi trợ lý AI |
| Âm thanh vũ trụ kèm mô tả kiểu Section 508 | Chandra *A Universe of Sound*, NASA Image and Video Library | 📦 `assets/data/space_media.json` | `globe_page.dart` | Mỗi mục có `audio_kind` để app nói rõ đó là bản ghi thật hay âm thanh chuyển từ dữ liệu |
| "Âm thanh thật của NASA" và trò "Đố âm thanh NASA" | NASA Historical Sounds (10 bản ghi mp3) | 📦 `assets/sounds/nasa/*.mp3`, `catalog.json` | `live/nasa_sounds.dart` | Tạo bằng `pipeline/nasa_sounds.py`; luôn là `audio_kind: "recording"` |
| Ảnh thiên văn hôm nay | APOD | 🌐 `api.nasa.gov/planetary/apod` (app và web đi qua `/api/apod` của Vercel) | `live/apod.dart` | Khoá nằm trên Vercel, không nằm trong APK |
| Trả lời câu hỏi mở về Trái Đất và vũ trụ | Kho kiến thức gom từ các file trên | 📦 (tính trong app) | `live/earth_rag.dart` | Trợ lý AI chỉ được trả lời dựa trên kho này. Mục 3.4 nói thêm |

**Khi mất mạng:** mọi phần trừ APOD và trợ lý AI đều chạy được.

**Muốn F2 tốt hơn:** thêm bản ghi trong Historical Sounds (mục 8.9). Thêm hình vũ trụ của SVS hoặc Chandra vào Máy hát theo đúng khuôn mục 4. Ví dụ "Caldwell 73" trong danh sách tài nguyên #14 là ảnh tĩnh: làm 1 khung, rê tay để nghe độ sáng từng vùng.

### 3.3. F3: Khám phá địa lý bằng tay

**Người dùng làm gì.** Nói *"chạm địa hình"* hoặc *"rê tay khám phá Đà Lạt"* rồi di ngón tay: máy rung theo độ dốc, sáo cao hơn khi đất cao hơn, nghe sóng khi qua mặt nước, nghe xe cộ khi qua khu dân cư. Hoặc nói *"quét mặt cắt địa hình"* để nghe hai lượt quét Bắc → Nam rồi Tây → Đông, mỗi lượt không quá 8 giây.

| Hiệu ứng trong F3 | Dữ liệu | File / nguồn | Code đọc | Ghi chú |
|---|---|---|---|---|
| **Sáo cao thấp theo độ cao** (trong Việt Nam) | NASA SRTMGL30 v002 (LP DAAC), lưới **152 × 306 ô, mỗi ô 0,05° (~5,5 km)** | 📦 `assets/touch/vn/elev.png` + `grid.json` | `features/terrain_scan/touch_grid.dart` | Tải bằng `data_nasa/crawl_f3.py` (thư viện `earthaccess`, cần Earthdata Login), xuất bằng `data_nasa/build_f3.py`. 1 byte/ô, 12,5 m mỗi bậc, 255 = biển. Mỗi ô là **độ cao trung bình** của ~5,5 km: ô có đỉnh Fansipan đọc 2.237 m, không phải 3.143 m (độ cao đỉnh chính xác lấy từ ô Terrarium khi có mạng) |
| **Rung theo độ dốc** | Tính từ SRTM ở độ phân giải gốc (30 giây cung, ~1 km) rồi lấy trung bình về ô 5,5 km | 📦 `assets/touch/vn/slope.png` | `touch_grid.dart`, `terrain_sense.dart` | 0,25° mỗi bậc; mức rung 0–4 |
| **Tiếng sóng khi qua mặt nước** | Tỉ lệ mặt nước nội địa, NASA SEDAC **GPWv4 Land and Water Area rev11** (2,5 phút cung) | 📦 `assets/touch/vn/water.png` | `touch_grid.dart` | Ô có ≥ 50 % mặt nước coi như đang trên sông, hồ. Biển nhận ra nhờ `elev` = 255. (Không phải JRC Global Surface Water như một số tài liệu cũ ghi) |
| **Tiếng xe khi qua khu dân cư** | Mật độ dân số NASA SEDAC **GPWv4 Population Density rev11**, năm 2020 (2,5 phút cung), cộng danh bạ phường đô thị | 📦 `assets/touch/vn/pop.png`, `assets/data/vn_dvhc.json` | `touch_grid.dart` (`trafficVolume`), `terrain_sense.dart` (`UrbanIndex`) | Thang log: 10^(b·0,025) − 1 người/km² |
| **Bản đồ rê tay chi tiết** quanh một điểm (độ cao từng ~18 m) | Ô Terrarium (AWS Open Data, dựng chủ yếu từ SRTM) | 🌐 `s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png` | `live/terrain_tiles.dart`, `live/terrain_patch.dart` | Độ cao = R·256 + G + B/256 − 32768 |
| Rừng, ruộng, đô thị, mặt nước dưới ngón tay | NASA MODIS MCD12Q1 (IGBP, 500 m) qua NASA GIBS | 🌐 GIBS WMTS, lớp `MODIS_Combined_L3_IGBP_Land_Cover_Type_Annual` | `live/terrain_tiles.dart`, `terrain_patch.dart` (17 lớp) | |
| Tên sông, hồ, đường, đỉnh núi | OpenStreetMap qua OpenFreeMap (**ngoài NASA**) | 🌐 ô vector OpenMapTiles | `live/vector_tiles.dart` | Ghi "© OpenStreetMap contributors" |
| **Quét mặt cắt địa hình** | Lấy lưới 26 × 26 ô quanh nơi đó từ chính các nguồn độ cao ở trên | 🌐 + 📦 | `terrain_scan_view.dart`, `globe/terrain.dart` | Tiếng sáo theo độ cao trung bình mỗi lát |
| Nổi khối và chạm trên **cả quả địa cầu** | ETOPO 20 phút (NOAA, **ngoài NASA**, phạm vi công cộng) | 📦 `assets/world/elev_glob.bin` (720 × 360) | `globe/terrain.dart` | Cũng dùng làm mặt nạ đất liền cho `build_eic.py` |
| Cảnh mẫu Đà Lạt 20 × 20 km khi mất mạng | Độ cao Open-Meteo; lớp phủ, NDVI, mặt nước | 📦 `assets/data/dalat_scene.json` | `nasa_normalized_data.dart` | ⚠️ Lớp phủ, NDVI, mặt nước đang **gán theo quy tắc** (mục 10) |
| **Bổ sung từ bộ mới (mục 4):** chiều cao tán rừng toàn cầu, ánh đèn đô thị | NASA SVS 4950 (GEDI), 5475 (Black Marble) | 📦 `assets/eic/forest`, `nightlights` | `features/eic/` | Hiện dùng trong Máy hát. Mục 4.4 nói cách dùng lại cho F3 |

**Khi mất mạng:** chạm địa hình trong Việt Nam vẫn có đủ độ cao, độ dốc, mặt nước và dân cư nhờ `assets/touch/vn/`. Bản đồ chi tiết, lớp phủ MODIS và tên sông đường cần mạng.

### 3.4. Phần dùng chung và Máy hát Trái Đất

| Phần | Dữ liệu dùng |
|---|---|
| Trợ lý AI (`live/earth_rag.dart`) | Chỉ trả lời dựa trên các file 📦 ở trên, kèm nguồn. Khoá AI nằm trên Vercel |
| Tin thời tiết hôm nay, dự báo | Open-Meteo (**ngoài NASA**). Không trộn với số POWER khi nói "theo NASA" |
| Thiên tai **đang diễn ra** | NASA EONET, `status=open` |
| **Máy hát Trái Đất** (thử thách #14) | 5 hình NASA SVS trong `assets/eic/`. Mục 4 trình bày chi tiết |

---

## 4. Bộ dữ liệu mới: hình ảnh NASA SVS cho Máy hát Trái Đất (thử thách #14)

Thử thách #14 cho sẵn danh sách hình ảnh của Earth Information Center (EIC). Đó là **video và hình**, không phải bảng số. Mục này hướng dẫn: lấy video nào, ở đâu, xử lý thế nào để ra số, kiểm tra ra sao, và từng bộ phục vụ chức năng nào. Tài liệu thiết kế âm thanh (vì sao chọn nhạc cụ nào) nằm ở `docs/MAY_HAT_TRAI_DAT.md`.

### 4.1. Năm bộ đang dùng

| Mã trong app | Hình NASA SVS | Dữ liệu gốc phía sau | Video cần tải (dung lượng) | Thời gian | Khung trong app |
|---|---|---|---|---|---|
| `nightlights` | [5475](https://svs.gsfc.nasa.gov/5475): Change in Night Lights (bản Science On a Sphere của EIC [5313](https://svs.gsfc.nasa.gov/5313)) | NASA Black Marble, VIIRS (VNP46A4), trung bình năm | `nightlights_2012-2024_KSC_04_plus2_2048x1024_30p_sos.mp4` (23,3 MB) | 2012–2023 | 12 năm |
| `lightning` | [5011](https://svs.gsfc.nasa.gov/5011): Lightning Events Detected from the ISS | Cảm biến LIS trên ISS, cửa sổ trượt 10 ngày | `iss_lightning_sos_yearly_07312023_2048p60.mp4` (350 MB) | 1/2017 – 7/2023 | 12 tháng (trung bình các năm) |
| `co2` | [5436](https://svs.gsfc.nasa.gov/5436): DYAMOND CO₂ (bản SOS của [5196](https://svs.gsfc.nasa.gov/5196)) | Mô hình GEOS của NASA GMAO, mô phỏng DYAMOND | `soscomp_1-29-2025a_1024p30.mp4` (27,2 MB) **và** video nền `dyamondPointCloud_1-29-2025a_dyamond_co2_sos_surface_8k_1024p30.mp4` (12,6 MB) | 14/1 – 3/3/2020, mỗi giờ 1 khung | 16 ngày, cách 3 ngày |
| `ocean` | [3912](https://svs.gsfc.nasa.gov/3912): Global Sea Surface Currents and Temperature | Mô hình ECCO2 (MIT / NASA JPL) | `flat_global_ecco2_2028x1024_comp_p30.mp4` (292 MB) | 25/3/2007 – 3/3/2008 | 12 tháng |
| `forest` | [4950](https://svs.gsfc.nasa.gov/4950): GEDI Forest Height | Laser GEDI trên ISS | `GEDI_global_w_colorbar_1080p60.mp4` (18,6 MB) **và** thang màu `GEDI_colorbar_0to50_01_print.jpg` | 4/2019 – 4/2020 | 12 dải kinh độ 30° |

Mỗi bộ trong app gồm `assets/eic/<mã>/meta.json` (mô tả Section 508, chú giải âm thanh, lý do chọn âm, nguồn, cách xử lý, số liệu từng khung) và `f00.jpg`… (khung hình 768 × 384, bản đồ phẳng). Cả 5 bộ khoảng 2,4 MB, chạy không cần mạng trên cả app lẫn web.

### 4.2. Cách lấy video

**Cách nhanh nhất:** chạy `data_nasa\svs\tai_svs.bat` (nhấp đúp). Script dùng `curl.exe` có sẵn trên Windows 10/11, **tự nối lại khi rớt mạng** (`-C -`), thử lại 5 lần, và ghi vào `data_nasa\svs\full\`. Hai video nhỏ (GEDI, video nền CO₂) và các thang màu tải tay từ trang SVS rồi đặt vào `data_nasa\svs\`.

**Tự tìm trên trang SVS:**
1. Mở `https://svs.gsfc.nasa.gov/<mã>`, kéo xuống phần *Download*. Hoặc gọi API `https://svs.gsfc.nasa.gov/api/<mã>`: trả JSON liệt kê mọi file, kèm kích thước.
2. Ưu tiên bản **bản đồ phẳng** (equirectangular, tỉ lệ 2:1, thường có chữ `sos` hoặc `flat` trong tên). Bản đồ phẳng đổi ra kinh độ, vĩ độ trực tiếp được. Bản quả cầu xoay (như GEDI) phải chiếu ngược (mục 4.3).
3. Chọn độ phân giải vừa đủ: 2048 × 1024 là đủ cho lưới 64 × 32. Bản 8K rất nặng mà không thêm thông tin cho âm thanh.
4. Tải **cả file mô tả thời gian** nếu có: `dyamond_timestamps.txt` (5436), `flat_ecco2_dates.txt` (3912). Đây là cách duy nhất biết khung nào ứng với ngày nào.
5. Tải **thang màu** (colorbar) nếu tách riêng: `dyamondCbar_6-27-2024a.png`, `GEDI_colorbar_0to50_01_print.jpg`, `nightlights_change_colorbar.png`.

**Kiểm tra video đã tải đủ chưa** (bắt buộc, vì trình duyệt hay để lại file dở):
```powershell
ffprobe -v error -show_entries stream=width,height,nb_frames -of compact "data_nasa\svs\full\<tên>.mp4"
```
Báo `moov atom not found` là file **tải dở**: xoá đi rồi tải lại. So dung lượng với cột "Video cần tải" ở bảng mục 4.1.

> **Không dùng thư mục frames của SVS cho trình duyệt.** Nhiều thư mục frames (như 3912) là ảnh **TIFF**: trình duyệt không mở được, và mỗi khung nặng vài MB. Dùng video mp4 với ffmpeg là nhanh nhất.

> **Không đưa video vào git.** Cả bộ video khoảng 720 MB. Thêm `svs/full/` và `*.mp4` vào `.gitignore` của `data_nasa/`. App chỉ cần `app/assets/eic/` (2,4 MB).

### 4.3. Xử lý: từ video ra số (`pipeline/build_eic.py`)

```powershell
pip install numpy pillow          # và cài ffmpeg (winget install Gyan.FFmpeg), có trong PATH
python pipeline/build_eic.py                  # cả 5 bộ, khoảng 3–4 phút
python pipeline/build_eic.py --only ocean     # chỉ một bộ
python pipeline/build_eic.py --svs D:\video   # video để chỗ khác
```

Script tìm video trong `data_nasa/svs/full/` trước, rồi `data_nasa/svs/`. Kết quả ghi vào `app/assets/eic/`, cùng `index.json` liệt kê các bộ đã làm được. Bộ nào thiếu video thì bị bỏ qua và in "bỏ qua: thiếu video …".

**Nguyên tắc chung cho mọi bộ.** Video chỉ có **màu**, nên phải đổi màu ra số rồi gom về một khuôn chung:
1. **Chọn khung:** theo ngày tháng thật (đọc file thời gian của SVS), không chia đều số khung một cách mù quáng.
2. **Đổi màu → số 0–1** theo cách riêng của từng bộ (bảng dưới).
3. **Bỏ chỗ không có số liệu:** đất liền với dữ liệu biển, biển với dữ liệu đất, vùng chữ và thang màu in trên hình. Mặt nạ đất liền lấy từ `app/assets/world/elev_glob.bin` (ETOPO 0,5°).
4. **Gộp về lưới:** 128 × 256 để tính, 64 × 32 ô để rê tay. Mỗi ô 1 byte, 0–254; 255 = không có số liệu.
5. **Tính số liệu từng khung** (hàm `summarize`):
   - `v` là trung bình toàn cầu, có **trọng số cos(vĩ độ)** vì ô ở gần cực nhỏ hơn ô ở xích đạo.
   - `area` là tỉ lệ diện tích vượt ngưỡng.
   - `cx` là vị trí Đông–Tây của 10 % ô mạnh nhất, tính bằng trung bình hướng trên vòng kinh độ để không bị lỗi ở kinh tuyến 180°.
   - `vn` là riêng vùng 6–24°B, 102–118°Đ (Việt Nam + Biển Đông).
   - `d` là mức đổi so với khung trước.
6. **Chuẩn hoá giữ tỉ lệ:** `v` được nhân để khung lớn nhất bằng 0,9, **không trừ đi giá trị nhỏ nhất**. Nhờ vậy câu "tăng 17 %" vẫn đúng. Việc trải giá trị ra cả thang âm cho dễ nghe do app làm lúc phát (`EicPlayer.pitchOf`), không làm sai số liệu.
7. **Ghi `meta.json`** gồm `method` (đã xử lý gì) và nguồn. App đọc được phần này khi người dùng nói "nguồn".

**Cách đổi màu ra số của từng bộ:**

| Bộ | Cách làm | Vì sao làm vậy |
|---|---|---|
| `nightlights` | Hình có mỗi năm 60 khung; lấy khung giữa của từng năm (khung 30, 90, …, 690). Lấy độ sáng trừ trung vị 15 × 15 điểm xung quanh, nên **chỉ giữ lại các đốm đèn**. Che 4 chỗ in chữ số năm. Chỉ tính trên đất liền. Chuẩn hoá theo bách phân vị 99,5 của cả 12 năm. Sau cùng lấy căn bậc hai | Nền bản đồ có màu đất, mây, băng. Trừ trung vị làm mất nền mịn nhưng giữ đốm nhỏ. Căn bậc hai để vùng đèn thưa (châu Phi) vẫn nghe được |
| `lightning` | Video **lặp từng năm, không in ngày tháng**. Bước 1: đếm chấm vàng ở mọi khung thứ 6. Bước 2: tính tỉ lệ sét ở Bắc bán cầu; mỗi lần tỉ lệ này vượt lên 50 % được coi là **giữa tháng 3**, mở đầu một năm (tìm được 7 lần, mỗi năm khoảng 726 khung). Bước 3: nội suy tháng cho các khung ở giữa, rồi **gộp khung cùng tháng của mọi năm** | Không có nhãn thời gian thì phải dùng chính quy luật vật lý: sét dịch lên Bắc bán cầu vào mùa hè phương Bắc. Lần đầu thử khớp một hình sin cho cả video thì ra sai pha. Cắt theo từng năm thì đúng |
| `co2` | Lấy **video tổng hợp trừ video nền cùng khung**: phần "cam" còn lại, (R − B), chính là lớp CO₂. Mỗi ngày lấy trung bình 6 khung cách 4 giờ; hình hiển thị là khung lúc 12 giờ. Ngày tháng theo `dyamond_timestamps.txt` (khung 3 = 15/1/2020, 24 khung mỗi ngày) | SVS có sẵn cả hai video nên tách lớp được chính xác. Lấy trung bình cả ngày để bỏ dao động ngày đêm của CO₂ sát mặt đất |
| `ocean` | **Tự tìm thang màu** 0–32 °C in ở góc dưới bên trái hình, gồm 274 màu. Mỗi điểm có màu đủ đậm được khớp với **màu gần nhất** trên thang để ra °C. Bỏ đất liền và vùng chữ. Khung chọn theo ngày 1 hằng tháng, dựa vào `flat_ecco2_dates.txt` | Có thang màu ngay trong hình nên đọc ra được °C thật, chứ không chỉ mức tương đối |
| `forest` | Video là **quả cầu xoay**. Bước 1: đo tâm và bán kính quả cầu từ vùng biển xanh (tâm 960, 540; bán kính 516 điểm ảnh). Bước 2: với mỗi khung, dò kinh độ và vĩ độ tâm sao cho **viền lục địa khớp nhất** với lưới ETOPO (khớp 75–94 %). Bước 3: chiếu ngược phép chiếu trực giao về lưới 2°. Bước 4: so màu với thang 0–50 m. Bước 5: lấy trung bình mọi lần một ô được nhìn thấy. Kết quả là một bản đồ phẳng; 12 "khung" là 12 dải kinh độ quét từ Tây sang Đông | Rừng gần như không đổi trong một năm, nên quét theo không gian thay cho thời gian. Chỉ lấy phần giữa quả cầu (bán kính ≤ 0,8) vì ở rìa ánh sáng làm tối màu |

### 4.4. Mỗi bộ hỗ trợ chức năng nào

Hiện cả 5 bộ dùng trong **Máy hát Trái Đất** (`features/eic/`). Vì số liệu nằm trong `meta.json` theo khuôn chung (lưới 64 × 32 có kinh độ, vĩ độ, kèm `vn` cho Việt Nam), các chức năng chính **dùng lại được** mà không phải xử lý video lần nữa:

| Bộ | Hỗ trợ chức năng | Cách dùng lại (đề xuất, chưa làm) | Kết quả đáng nói khi trình bày |
|---|---|---|---|
| `nightlights` | **F3**: khu dân cư. **F1**: thay đổi theo năm | F3: thêm độ sáng đèn đêm làm lớp thứ hai cạnh `pop.png`, tiếng xe dày hơn ở nơi sáng hơn. F1: đọc thêm câu "vùng này sáng hơn năm 2012 bao nhiêu" khi phát lịch sử theo năm | Toàn cầu sáng thêm khoảng 17 % từ 2012 đến 2023; vùng Việt Nam khoảng 44 % |
| `lightning` | **F1**: thiên tai | Khi phát lịch sử theo tháng, tháng nào trong top mùa giông của vùng đó thì thêm tiếng sấm nền và câu "đang mùa giông" | Toàn cầu nhiều sét nhất tháng 7; vùng Việt Nam nhiều nhất tháng 5 |
| `co2` | **F1**: bối cảnh khí hậu. **F2**: kiến thức | F2/qa_bank: câu hỏi "CO₂ ở đâu nhiều nhất" có số thật để trả lời. F1: câu bối cảnh khi nói về Trái Đất nóng lên, đặt cạnh GISTEMP | Mảng CO₂ lớn ở Đông Á, Ấn Độ, Trung Phi |
| `ocean` | **F1**: khí hậu Biển Đông. **F3**: rê tay trên biển | F3: hiện chạm biển chỉ có tiếng sóng; thêm nhiệt độ nước dưới ngón tay ("biển ấm, khoảng 29 độ"). F1: so mùa nóng của biển với mùa nóng trên đất liền | Biển Đông nóng nhất tháng 6–7, mát nhất tháng 1–3 (đọc từ hình, cao hơn thực tế khoảng 1–2 °C) |
| `forest` | **F3**: địa hình và lớp phủ | Thêm chiều cao tán rừng vào lời đọc khi rê tay qua lớp phủ MODIS loại "rừng" ("rừng cao khoảng 25 mét") | Rừng cao nhất ở Amazon, Congo, Đông Nam Á |

Muốn dùng lại trong code: đọc `EicLibrary.load()` rồi `byId('ocean')`. Đổi toạ độ ra ô: `x = (lon + 180) / 360`, `y = (90 − lat) / 180`, rồi gọi `set.at(khung, x, y)` để được giá trị 0–1, và `set.real(...)` để ra đơn vị thật (°C, mét).

### 4.5. Kiểm tra trước khi đưa vào app

| Kiểm tra | Cách làm | Kết quả hiện tại |
|---|---|---|
| Video đủ | `ffprobe` không báo `moov atom not found`; dung lượng khớp bảng 4.1 | 4 video tải bằng `tai_svs.bat`, đủ dung lượng |
| Khớp bản đồ | So vùng xám (đất liền) trong hình với mặt nạ ETOPO, thử dịch kinh độ ±30° | ECCO2 khớp 94,6 % ở độ dịch 0°, tức đúng −180…180° |
| Thời gian | So với hiểu biết đã biết | Sét Việt Nam đỉnh tháng 5, toàn cầu tháng 7; Biển Đông nóng nhất tháng 6–7; đèn đêm tăng đều, năm 2020 giảm nhẹ (COVID) |
| Không có NaN | `meta.json` không chứa `NaN`; mọi `v`, `area`, `d`, `vn` nằm trong 0–1 | Đạt, kiểm tra bằng `app/test/eic_jukebox_test.dart` |
| Nhìn lại ảnh | Mở vài `f*.jpg`, so với video gốc | |
| Nghe thử | Mở app, nói "máy hát Trái Đất", nghe hết một bộ, rê tay lên Việt Nam | |

**Giới hạn phải nói rõ** (đã ghi trong `meta.json` → `method`): đây là số **đọc từ hình**, đủ để nghe xu hướng và so nơi này với nơi khác, **không phải số đo gốc**.
- Nhiệt độ biển trung bình toàn cầu bị lệch lên, vì gần hai cực các sợi chỉ màu thưa.
- Rừng ở vĩ độ cao kém chính xác hơn, do bóng tối ở rìa quả cầu.
- Sét và đèn đêm là mức tương đối, không phải số chớp hay đơn vị nW/cm²/sr.

Muốn số gốc thì dùng VNP46A4 (Black Marble), LIS/ISS (GHRC DAAC), GEOS, ECCO2 (PO.DAAC), GEDI L3 (ORNL DAAC), tải qua Earthdata Search và đưa vào theo mục 9.1.

### 4.6. Thêm một hình SVS mới

1. Chọn bản bản đồ phẳng; tải video, file thời gian, thang màu (mục 4.2).
2. Trong `pipeline/build_eic.py`:
   - viết hàm `build_<mã>(svs, out)`, trả về danh sách ảnh, danh sách lưới số 0–1 (NaN = không có số liệu) và nhãn thời gian;
   - gọi `write_set(...)` để ghi;
   - thêm một mục `META["<mã>"]` gồm: tiêu đề, `describe_vi/en` (mô tả theo Section 508: hình là gì, phần tử dữ liệu trông thế nào, so với vật quen thuộc, chỗ nhiều và chỗ ít), `legend_vi/en` (nghe gì là gì), `why_vi/en` (vì sao chọn âm này), `sound` (`voice`, `pulse`, `bed`, có thể thêm `pitch: "vn"`), `sweep` (`time` / `season` / `space`), `low`, `high`, `unit`, `method`, `aliases`;
   - thêm tên vào `BUILDERS` và `ORDER`.
3. Chạy `python pipeline/build_eic.py --only <mã>`.
4. Khai báo thư mục `assets/eic/<mã>/` trong `app/pubspec.yaml`. Đây là bước **bắt buộc**: thiếu thì ảnh không hiện; khai báo mà thư mục không tồn tại thì build lỗi.
5. Thêm từ khoá nói vào `eicKeywords` trong `app/lib/features/eic/eic_commands.dart`.
6. Chạy `flutter test test/eic_jukebox_test.dart`.

**Các tài nguyên #14 khác chưa làm**, và cách xử lý gợi ý:
- **GEOS Aerosols / Air Quality:** giống `co2` (lớp màu phủ trên nền).
- **Perpetual Ocean 2:** giống `ocean`, nhưng không có thang màu, nên chỉ lấy mức chuyển động bằng hiệu giữa hai khung liên tiếp.
- **Atmospheric River 3D:** góc nhìn 3D, phải chiếu ngược như `forest`.
- **Caldwell 73:** ảnh tĩnh, 1 khung.
- **EIC Content Database:** dùng để tìm mã SVS của các hình khác.

---

## 5. Kiểm chứng: lấy đúng cách, đúng loại dữ liệu, xử lý đúng chưa

Mục này ghi lại việc **gọi thử thật** từng nguồn (ngày 14/11/2026) và đối chiếu với tài liệu chính thức. Mục tiêu là trả lời ba câu hỏi:

1. URL và tham số có đúng không?
2. Dữ liệu trả về **là loại gì** (đơn vị, định dạng, giá trị thiếu)?
3. Cách xử lý trong pipeline và app có khớp với loại dữ liệu đó không?

Ai sửa pipeline thì làm lại đúng các phép thử này.

### 5.1. Bảng kiểm chứng

| Nguồn | Cách lấy (đã thử) | Dữ liệu trả về thật sự là | Xử lý đúng phải là | Kết luận |
|---|---|---|---|---|
| **POWER tháng, điểm** | `.../api/temporal/monthly/point?parameters=T2M,PRECTOTCORR&community=AG&latitude=21.03&longitude=105.85&start=2024&end=2024&format=JSON` | JSON. `parameters.PRECTOTCORR.units` = **`mm/day`**, `T2M` = `C`. Khoá tháng `202401`…`202412`, thêm khoá **`202413` = trung bình năm**. `header.fill_value` = **−999**. Hà Nội 7/2024: 28,76 °C; mưa 12,71 mm/ngày | Mưa tháng = mm/ngày × **số ngày của tháng** (7/2024: 12,71 × 31 ≈ 394 mm). Bỏ khoá `…13`, bỏ −999. **Đọc đơn vị từ `parameters.*.units`**, đừng giả định | ✅ Đúng với `build_f1_climate.py`, `pipeline/sources/power.py` và `nasa_power.dart`. Thử nhanh: mưa năm 2024 = 5,55 mm/ngày × 366 ≈ 2.031 mm, nằm trong khoảng 1.200–3.000 mm |
| **POWER ngày, điểm** | `.../daily/point?...&start=20240906&end=20240908` (ngày dạng **YYYYMMDD**) | `T2M_MAX` (C), `PRECTOTCORR` (mm/day), `WS10M` (m/s). Hà Nội 7/9/2024 (bão Yagi): mưa **118,6 mm**, gió **11,81 m/s**, nhiệt độ cao nhất 27,62 °C | Mưa ngày dùng thẳng, không nhân. Gió là **trung bình cả ngày ở ô 50 km**, không phải gió giật, nên **không đổi ra "cấp bão"** | ✅ Ngày đỉnh bão hiện rõ trong số liệu |
| **POWER vùng** | `.../monthly/regional?latitude-min=20&latitude-max=22&longitude-min=105&longitude-max=107&parameters=T2M...` | GeoJSON `FeatureCollection`. Mỗi điểm lưới có `coordinates` = **[kinh độ, vĩ độ, độ cao]** | **Mỗi lần chỉ 1 tham số.** Thử 2 tham số thì máy chủ trả lỗi 422: *"A maximum of 1 parameters are can currently be requested"* | ✅ Pipeline đã gọi từng tham số |
| **FIRMS khu vực** | Đối chiếu trang API chính thức: `/api/area/csv/[MAP_KEY]/[SOURCE]/[W,S,E,N]/[DAY_RANGE]/[YYYY-MM-DD]` | CSV điểm cháy. `DAY_RANGE` chỉ từ **1 đến 10**. Nguồn: `MODIS_NRT`, `MODIS_SP`, `VIIRS_SNPP_NRT`, `VIIRS_SNPP_SP`, `VIIRS_NOAA20_NRT/SP`, `VIIRS_NOAA21_NRT` | Lịch sử dùng `_SP` (bản chuẩn, trễ vài tháng). Lặp từng đoạn 10 ngày. Đếm điểm có `confidence` ≥ 30. Thứ tự toạ độ là **Tây, Nam, Đông, Bắc** | ✅ Khớp `pipeline/sources/firms.py`. Chưa gọi thật vì cần MAP_KEY. Có thể dùng thêm VIIRS 375 m (`VIIRS_SNPP_SP`, từ 2012) cho chi tiết hơn |
| **EONET** | `https://eonet.gsfc.nasa.gov/api/v3/events?status=all&bbox=102,23.6,112,8.3&limit=5` | JSON sự kiện. `bbox` theo thứ tự **kinh độ nhỏ, vĩ độ lớn, kinh độ lớn, vĩ độ nhỏ** (góc trên trái rồi góc dưới phải). `status` = `open`, `closed`, `all`. Trả về 5 trận lũ ở Việt Nam, Campuchia, Trung Quốc 8–11/2026 | Đọc `geometry[].coordinates`. ⚠️ **Phát hiện khi thử:** một số sự kiện lũ ghi toạ độ **ngược [vĩ độ, kinh độ]**, ví dụ *Flood in Cambodia* = [13,54; 102,33] | 🔧 **Đã sửa app:** thêm `eonetLatLon()` trong `live/eonet.dart`, tự đổi lại khi số thứ hai vượt ±90°; dùng trong `eonet.dart` và `hazard_history.dart`; kèm `test/eonet_coords_test.dart`. Trước khi sửa, các trận lũ này bị đặt ở "vĩ độ 102" và bị F1 bỏ qua |
| **NASA SVS** | `https://svs.gsfc.nasa.gov/api/<mã>` liệt kê mọi file; gửi `HEAD` tới từng video | Video H.264. HEAD trả 200 với dung lượng 23.343.160 / 27.165.701 / 292.128.033 / 350.207.237 byte, khớp đúng file đã tải. Thư mục frames của 3912 là **TIFF**; frames của 5475 là PNG | Dùng `ffprobe` kiểm tra đủ file (mục 4.2). Đọc ngày từ file thời gian của SVS. Đổi màu ra số theo mục 4.3 | ✅ Kiểm tra lại: ECCO2 khớp mặt nạ đất 94,6 % ở độ dịch 0°; GEDI khớp viền lục địa 75–94 %; sét Việt Nam đỉnh tháng 5, toàn cầu tháng 7 |
| **SRTMGL30 + GPWv4** (F3) | `data_nasa/crawl_f3.py` dùng `earthaccess` tìm trên NASA CMR: `SRTMGL30` v002; GPWv4 *Population Density* rev11 (năm 2020); GPWv4 *Land and Water Area* rev11 | GeoTIFF / GTOPO DEM. GPWv4 có ô 2,5 phút cung (~4,6 km), **xấp xỉ** ô của lưới chạm (0,05° ≈ 5,5 km) | Dân số và mặt nước: lấy mẫu về lưới 0,05° (`block_sample`). Độ dốc tính ở độ phân giải gốc của SRTM rồi mới lấy trung bình | ✅ Đúng loại dữ liệu. ⚠️ `docs/DATA_SOURCES.md` ghi mặt nước là JRC; **đã sửa** thành GPWv4 Land and Water Area |
| **Terrarium, GIBS MODIS** (F3, lúc chạy) | `s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png`; GIBS `.../wmts/epsg3857/best/MODIS_Combined_L3_IGBP_Land_Cover_Type_Annual/default/default/GoogleMapsCompatible_Level8/{z}/{y}/{x}.png` | PNG mã hoá độ cao; PNG màu theo bảng IGBP (17 lớp) | Độ cao = R·256 + G + B/256 − 32768. Lớp phủ: **so màu với bảng màu IGBP** của GIBS (ảnh GIBS là ảnh màu, không phải mã lớp). Mức phóng to tối đa của lớp này là 8 | ✅ Đúng như code đang làm (`terrain_tiles.dart`, `terrain_patch.dart`). Đợt này chưa gọi thử lại |
| **GISTEMP** | `GLB.Ts+dSST.csv` | CSV: dòng đầu là tiêu đề phụ; `***` = chưa có số; cột `J-D` | Bỏ dòng đầu; `***` → thiếu, **không phải 0**. Là độ lệch so với 1951–1980 | ✅ Như mục 8.5 (đợt này chưa tải lại) |

### 5.2. Ba lỗi "đúng nguồn nhưng sai loại dữ liệu" hay gặp

1. **Đọc nhầm đơn vị tốc độ thành đơn vị tổng.** Mưa POWER theo tháng là **mm/ngày** (trung bình ngày trong tháng), không phải mm/tháng. Quên nhân thì mưa cả năm ra khoảng 60 mm thay vì 2.000 mm.
2. **Đọc nhầm số đọc từ hình thành số đo.** Số trong `assets/eic/` là **đọc từ màu của hình SVS**. Được nói "tăng khoảng 17 %" hay "nóng nhất tháng 6–7". Không được nói "nhiệt độ đo được là 30,1 °C".
3. **Đọc nhầm thứ tự toạ độ.** GeoJSON chuẩn là [kinh độ, vĩ độ]. POWER regional cũng vậy, kèm độ cao. EONET có lúc bị ngược. Bbox thì FIRMS là W,S,E,N, còn EONET là W,N,E,S. Luôn in vài điểm ra so với bản đồ trước khi tin.

### 5.3. Tự kiểm chứng lại (trình tự)

1. Gọi đúng URL trong bảng 5.1 cho **một điểm đã biết** (Hà Nội, tháng 7) và đọc **trường đơn vị** trong phản hồi.
2. So với hiểu biết thông thường (mục 11). Hà Nội tháng 7 khoảng 29 °C; mưa năm 1.200–3.000 mm; Fansipan khoảng 3.143 m.
3. Chạy script pipeline tương ứng và đọc **dòng kiểm tra** mà script in ra.
4. Chạy test: `python -m pytest tests/` và `cd app; flutter test`.
5. Ghi kết quả vào `data_card.processing` (hoặc `method` trong `meta.json` với dữ liệu SVS): đã kiểm chứng gì, ngày nào, ai làm.

### 5.4. Kiểm tra dữ liệu thật đang đóng gói trong app (14/11/2026)

Mở từng file trong `app/assets/`, đọc số bên trong và **so với nguồn gốc gọi trực tiếp** ngày 14/11/2026.

| File trong app | Có đúng chỗ, đúng khai báo? | So với nguồn thật | Kết luận |
|---|---|---|---|
| `data/climate_history_nasa.json` (29 nơi, 1981–2025) | ✅ | Hà Nội: nhiệt độ 1981–1990 = 24,46 °C, 2016–2025 = 23,49 °C; mưa 843,8 → 1.877,5 mm; năm 2025 = 2.222,8 mm. **Khớp đến từng số** với API POWER | ✅ Pipeline lấy đúng. ⚠️ Nhưng **chính số POWER sai xu hướng** (xem dưới) |
| `data/climate_34_provinces.json` (34 tỉnh, 540 tháng) | ✅ | An Giang 1981–1990 = 28,01 °C, khớp API POWER | ✅ Như trên |
| `data/hot_days_extremes` (trong file trên) | ✅ | POWER: Hà Nội 1985 có **88 ngày ≥ 35 °C, cao nhất 44,0 °C** (kỷ lục thật của Hà Nội khoảng 42–43 °C). ERA5 cùng điểm: 12 ngày/năm thập niên 1980, 23 ngày/năm gần đây | ❌ Số thập niên 1980 không dùng được. App đã chuyển sang ERA5 |
| `data/touchgrid.json`, `series.json`, `frames/` (lưới 0,1°, 2001–2025) | ✅ | Chỉ từ năm 2001, nên tránh được đoạn tệ nhất thập niên 1980. Danh sách `sources` có ghi FIRMS nhưng **chưa có lớp cháy** | ⚠️ Dùng được cho bản đồ từng năm; cẩn thận khi so 2001 với 2025 (bước nhảy mưa quanh 2016) |
| `data/gistemp_global.json` | ✅ | 146 năm (1880–2025); 2024 = 1,28 °C, năm nóng nhất, đúng như NASA công bố | ✅ |
| `data/vn_disasters_nasa.json` | ✅ | 282 sự kiện 1971–2026: sạt lở 116, bão 107, lũ 59; mỗi mục có nguồn (GDIS, GLC, EONET) và đường dẫn | ✅ |
| `data/planets_nasa.json`, `qa_bank.json` | ✅ | NASA Science (8/2026): **Sao Thổ 293** mặt trăng (app ghi 146), **Sao Mộc 115** (app ghi 95), **Sao Thiên Vương 29** (app ghi 28), Sao Hải Vương 16 (đúng). Đường kính, khoảng cách khớp NSSDCA | 🔧 **Đã sửa** số mặt trăng ở JSON, `build_f2_space.py`, `facts.json` của `data_nasa`, các câu trong code và test |
| `data/space_media.json`, `sounds/nasa/` (10 mp3 + `catalog.json`) | ✅ | Đủ 10 file khớp `catalog.json` | ✅ |
| `data/dalat_scene.json` | ✅ | `data_card` ghi SRTM/MODIS nhưng lớp phủ, NDVI, mặt nước **gán theo quy tắc** | ⚠️ Như mục 10, chỉ dùng làm dự phòng |
| `data/credits.csv` | ✅ | Thiếu dòng cho `assets/touch/vn/` và `assets/eic/` | 🔧 Đã thêm |
| `touch/vn/` (`elev`, `slope`, `water`, `pop`, `grid.json`) | ✅ | Lưới **152 × 306 ô, 0,05° (~5,5 km)**, không phải 850 × 1.250 như tài liệu cũ ghi. Kiểm tra: Hoàn Kiếm 12,5 m, 22.386 người/km²; Đà Lạt 1.487 m; hồ Dầu Tiếng 56 % mặt nước; ngoài khơi Nha Trang = không có số liệu (biển) | ✅ Số liệu hợp lý. 🔧 Đã sửa tài liệu |
| `eic/` (5 bộ SVS) | ✅ | Xem mục 4.5 | ✅ |
| `world/elev_glob.bin`, `countries.json` | ✅ | ETOPO 0,5° (NOAA), Natural Earth | ✅ (ngoài NASA, có ghi nguồn) |

**Phát hiện quan trọng: chuỗi NASA POWER ở Việt Nam không đồng nhất theo thời gian.** Gọi thẳng API POWER (`T2M`, `PRECTOTCORR`, theo tháng, 1981–2025) cho các điểm Việt Nam:

| Điểm | Mưa năm theo POWER | Thực tế / ERA5 | Nhiệt độ theo POWER |
|---|---|---|---|
| Hà Nội | 1987: **539 mm**; 1981–1990 trung bình 844 mm; 2016–2025: 1.878 mm | ERA5: 1.859 → 2.159 mm | **Giảm** 0,97 °C (24,46 → 23,49) trong khi ERA5 **tăng** 1,02 °C (23,16 → 24,18) |
| Đà Lạt | 1987: **97 mm**; 2001–2015 khoảng 1.000 mm; **từ 2016 nhảy lên** 1.800–2.400 mm | Đà Lạt thực tế khoảng 1.800 mm/năm | Giảm 1,1 °C |
| Gia Lai | 2001–2010: **502 mm**, 2016–2025: 2.217 mm (+342 %) | khoảng 2.000 mm/năm | Giảm 1,36 °C |
| Tokyo, Paris (đối chứng) | Ổn định, không nhảy bậc | | Tokyo ấm lên rõ |

Kết luận:
- Chuỗi POWER ở Việt Nam có **mưa thập niên 1980 thấp bất thường**, **nhiệt độ thập niên 1980 cao bất thường** và **một bước nhảy mưa quanh năm 2016**.
- Pipeline lấy số đúng, nhưng **nếu dùng số này để nói xu hướng thì sẽ nói sai**: "Hà Nội mát đi 1 độ, ngày nắng nóng giảm từ 86 xuống 14, mưa tăng gấp đôi".
- Trang phương pháp của POWER không nhắc đến bước nhảy này. Rất có thể do mô hình MERRA-2 có ít số liệu quan trắc ở khu vực này trong các giai đoạn đầu. Đây là **nhận định dựa trên kiểm tra**, chưa có xác nhận chính thức.

**Đã sửa trong app:**
- `NasaPowerService.extremes()` tải **một chuỗi ERA5 liền mạch 1981 đến năm ngoái** (Open-Meteo, lưu trữ tái phân tích) và trả về `EraTrend`.
- Câu "xưa và nay", câu "khí hậu ở …" (nhiệt độ, mưa, ngày ≥ 35/37/39 °C, năm nóng nhất, âm thanh từng năm) và công cụ khí hậu của trợ lý AI giờ đều lấy xu hướng từ ERA5, và **nói rõ nguồn**.
- Mất mạng thì app chỉ đọc mức gần đây của POWER, **không nói xu hướng**.
- POWER vẫn dùng cho giá trị từng tháng, từng năm và cho F1.

**Còn lại cho F1 (chưa sửa):** máy phát lịch sử F1 so mỗi tháng với "trung bình cùng kỳ" tính trên toàn chuỗi POWER. Với khoảng dài (nhiều năm, nhất là trước 2016), nó có thể gắn nhãn "khô hạn" sai cho những năm đầu. Khoảng ngắn gần đây (≤ 3 năm, từ 2016 trở đi) thì ổn. Cách sửa cần chọn: đổi chuỗi dài hạn của F1 sang ERA5, hoặc giới hạn F1 dùng POWER từ 2016.

---

## 6. Chuẩn bị một lần

### 6.1. Cài đặt

```powershell
# trong thư mục gốc repo (sense/)
pip install -r requirements.txt
# chỉ khi đọc file NetCDF / HDF5 / GeoTIFF:
pip install xarray netCDF4 h5netcdf h5py tifffile
```

### 6.2. Các tài khoản và khoá

| Khoá | Lấy ở đâu | Dùng cho | Đặt ở đâu |
|---|---|---|---|
| **FIRMS MAP_KEY** | <https://firms.modaps.eosdis.nasa.gov/api/map_key/> (nhập email, nhận ngay) | Pipeline điểm cháy | Biến môi trường `FIRMS_MAP_KEY` |
| **api.nasa.gov key** | <https://api.nasa.gov> (điền form, nhận qua email) | APOD trong app | `NASA_API_KEY` trong `.env` / Vercel |
| **Earthdata Login** | <https://urs.earthdata.nasa.gov> (đăng ký miễn phí) | Tải SEDAC, LP DAAC (SRTM, MODIS) bằng tay | Chỉ dùng trên trình duyệt, không cần cho app |

```powershell
# PowerShell, chỉ có hiệu lực trong cửa sổ đang mở
$env:FIRMS_MAP_KEY = "mã_của_bạn"
# bash
export FIRMS_MAP_KEY=mã_của_bạn
```

> `DEMO_KEY` của api.nasa.gov chỉ cho khoảng 30 lượt mỗi giờ trên mỗi địa chỉ IP. Đủ để thử, không đủ cho demo đông người.

---

## 7. Lấy từng loại dữ liệu

> Mục này cho biết **lấy ở đâu**. Cách **xử lý từng bước, có code mẫu** nằm ở mục 8.

### 7.1. NASA POWER — khí hậu theo điểm hoặc vùng (không cần khoá)

**Theo tháng, một điểm** (đây là cách `build_f1_climate.py` dùng):

```
https://power.larc.nasa.gov/api/temporal/monthly/point
  ?parameters=T2M,PRECTOTCORR,RH2M&community=AG
  &latitude=21.03&longitude=105.85&start=1981&end=2025&format=JSON
```

**Theo ngày** (cho bão, lũ, ngày nắng nóng): đổi `monthly` thành `daily`, và `start`, `end` viết dạng `YYYYMMDD`, ví dụ `start=20240901&end=20240915`.

**Theo vùng** (lưới chạm): `.../monthly/regional?latitude-min=..&latitude-max=..&longitude-min=..&longitude-max=..`. Mỗi lần gọi chỉ được **1 tham số**, nên chia vùng thành ô ≤ 5° (xem `pipeline/sources/power.py`).

| Tham số | Ý nghĩa | Đơn vị trả về | Lưu ý |
|---|---|---|---|
| `T2M` | Nhiệt độ không khí ở 2 m | °C | |
| `T2M_MAX` | Nhiệt độ cao nhất ngày | °C | Dùng đếm ngày ≥ 35/37/39 °C |
| `PRECTOTCORR` | Lượng mưa đã hiệu chỉnh | **mm/ngày** | Muốn tổng tháng: nhân với số ngày của tháng |
| `RH2M` | Độ ẩm tương đối | % | |
| `WS10M` | Gió ở 10 m | m/s | |

**Đọc kết quả:** `properties.parameter.<THAM_SỐ>` là bảng `{"YYYYMM": giá trị}`. Khoá `YYYY13` là trung bình năm, nhớ bỏ khi tính. Giá trị thiếu là `-999`.

> **Bẫy hay gặp:** vài tháng gần nhất có thể chưa đủ dữ liệu hoặc bị sai đơn vị. Pipeline đặt `end=2025` để chỉ lấy năm đã đủ. Khi tự lấy, hãy so tổng mưa năm với khoảng 1.200–3.000 mm.

### 7.2. NASA GISTEMP v4 — nhiệt độ toàn cầu (không cần khoá)

- File: <https://data.giss.nasa.gov/gistemp/tabledata_v4/GLB.Ts+dSST.csv>
- Dòng đầu là tiêu đề phụ, bỏ qua. Cột `J-D` là chênh lệch cả năm (°C) so với kỳ chuẩn **1951–1980**.
- Giá trị `***` nghĩa là chưa có số. Năm đang diễn ra thường là `***`.
- Script: `python pipeline/fetch_and_normalize_nasa.py` ghi ra `gistemp_global.json`.

### 7.3. NASA FIRMS — điểm cháy (cần MAP_KEY)

```
https://firms.modaps.eosdis.nasa.gov/api/area/csv/[MAP_KEY]/[SOURCE]/[W,S,E,N]/[SỐ_NGÀY]/[NGÀY_BẮT_ĐẦU]
ví dụ: .../api/area/csv/<MAP_KEY>/MODIS_SP/102,8.3,112,23.6/10/2024-03-01
```

- `SOURCE`: `MODIS_SP` (bản chuẩn, có từ 2000, dùng cho lịch sử), `MODIS_NRT` / `VIIRS_SNPP_NRT` (gần thời gian thực).
- Mỗi lần gọi tối đa **10 ngày**, nên phải lặp theo từng đoạn 10 ngày. Pipeline đã làm việc này và giữ cache trong `data/cache/`.
- Cột cần dùng: `latitude`, `longitude`, `acq_date`, `confidence`. Pipeline chỉ đếm điểm có độ tin cậy ≥ 30.
- Kiểm tra lượt còn lại: trang MAP_KEY → *Check status*.

### 7.4. SEDAC (GDIS, GPWv4) — tải bằng tay

1. Đăng nhập Earthdata Login, vào <https://sedac.ciesin.columbia.edu> (SEDAC hiện chuyển dần sang Earthdata).
2. **GDIS** (Geocoded Disasters): tải bảng CSV hoặc GeoPackage, lọc `country = Vietnam`.
3. **GPWv4**: chọn *Population Density* rev11, năm 2020, và *Land and Water Area* rev11, độ phân giải **2,5 phút cung (~4,6 km)**, dạng GeoTIFF. Đây là bản `crawl_f3.py` đang tải; bản 30 giây cung (~1 km) nặng hơn nhiều mà lưới chạm 0,05° không cần.
4. Bỏ file vào kho `data_nasa/`, rồi chạy `python pipeline/import_data_nasa.py`.

### 7.5. SRTM, MODIS — độ cao và lớp phủ đất

| Cách | Khi nào dùng | Cách làm |
|---|---|---|
| **Ô bản đồ (không khoá)** | Trong app, lúc chạy | Độ cao: `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png`, độ cao = (R×256 + G + B/256) − 32768 mét. Lớp phủ: NASA GIBS WMTS, lớp `MODIS_Combined_L3_IGBP_Land_Cover_Type_Annual` |
| **NASA Earthdata Search** | Cần file gốc cho pipeline | <https://search.earthdata.nasa.gov>, tìm `SRTMGL30` (bản app đang dùng cho lưới chạm), `SRTMGL1` (30 m, khi cần chi tiết) hoặc `MCD12Q1`, vẽ khung Việt Nam, tải về |
| **AppEEARS** | Cần cắt sẵn một vùng hoặc chuỗi thời gian (NDVI, nhiệt độ mặt đất) | <https://appeears.earthdatacloud.nasa.gov>, chọn vùng và sản phẩm (`MOD13Q1`, `MOD11A2`), nhận GeoTIFF/CSV qua email |

### 7.6. Vũ trụ: NSSDCA, Space Place, Historical Sounds

- **NSSDCA Planetary Fact Sheet** (bản hệ mét): <https://nssdc.gsfc.nasa.gov/planetary/factsheet/>. Số liệu đang **chép vào** `pipeline/build_f2_space.py`. Khi sửa, đối chiếu lại từng số với trang gốc.
- **NASA Space Place**: <https://spaceplace.nasa.gov>. Bản dịch nằm ở `data_nasa/assets/content/facts.json` và được nhập bằng `import_data_nasa.py`.
- **NASA Historical Sounds**: <https://www.nasa.gov/historical-sounds/>. Bỏ mp3 vào `data_nasa/assets/content/nasa/`, ghi một dòng trong `credits.csv`, rồi chạy `python pipeline/nasa_sounds.py`.

### 7.7. APOD và EONET (app gọi trực tiếp)

- **APOD:** `https://api.nasa.gov/planetary/apod?api_key=<KHOÁ>`. Trên web và trong APK build từ CI, app gọi qua `/api/apod` của Vercel, khoá nằm trên máy chủ.
- **EONET:** `https://eonet.gsfc.nasa.gov/api/v3/events?status=open&bbox=102,23.6,112,8.3`. Không cần khoá; trả về bão, cháy, núi lửa đang diễn ra.

---

## 8. Quy trình xử lý chi tiết từng nguồn (có code mẫu)

Mục này đi từng bước: **tải → đọc → làm sạch → tính → ghi JSON → kiểm tra → app dùng thế nào**. Code mẫu viết bằng Python thuần (thư viện chuẩn, thêm `numpy` và `Pillow` ở vài chỗ), chép ra chạy được ngay. Code mẫu bám đúng cách các script trong `pipeline/` đang làm, nhưng gọn hơn để dễ hiểu. Khi chạy thật cho app, **dùng script trong `pipeline/`**: script có thêm cache, thử lại khi lỗi và ghi `data_card`.

Dùng chung cho các ví dụ:

```python
import calendar, json, urllib.request

def lay_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Lang-SpaceApps"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))
```

### 8.1. NASA POWER theo tháng → khí hậu của một nơi

**Kết quả cần có:** nhiệt độ và tổng mưa từng tháng, từng năm của một nơi. App dùng phần này cho F1 và cho câu hỏi về một tháng, một năm cụ thể ("tháng 7 năm 2024 ở Hà Nội").

> ⚠️ **Không dùng kết quả này để tính "nóng lên bao nhiêu" ở Việt Nam.** Kiểm tra ngày 14/11/2026 (mục 5.4) cho thấy chuỗi POWER ở Việt Nam có mưa thập niên 1980 thấp bất thường, nhiệt độ thập niên 1980 cao bất thường và một bước nhảy mưa quanh năm 2016. Ví dụ: Hà Nội tính ra **mát đi 0,97 °C**, trong khi ERA5 cho **ấm lên 1,02 °C**. Các trường `warming_c`, `rain_1980s_mm`, `hottest_year` trong code mẫu dưới đây vẫn được tạo ra cho đủ khuôn, nhưng app **không đọc** chúng. Xu hướng lấy từ ERA5 (`NasaPowerService.extremes`).

**Bước 1 — Tải.** Một lần gọi lấy đủ 45 năm, 2 tham số, cho một điểm.

**Bước 2 — Đọc.** Kết quả nằm ở `properties.parameter.T2M`, dạng `{"198101": 16.4, "198102": 17.1, …, "198113": 23.9}`. Khoá có đuôi `13` là **trung bình năm** NASA tính sẵn: bỏ, tự tính lại cho chắc.

**Bước 3 — Làm sạch.**
- Giá trị `-999` là thiếu.
- Năm nào thiếu dù chỉ 1 tháng thì **bỏ cả năm**, không đoán bù. Năm thiếu tháng sẽ làm trung bình năm lệch.

**Bước 4 — Đổi đơn vị.** `PRECTOTCORR` là **mm/ngày**. Tổng mưa tháng = giá trị × số ngày của tháng đó (28, 29, 30 hoặc 31). Đừng nhân 30 cho mọi tháng.

**Bước 5 — Tính.**

```python
def khi_hau_mot_noi(lat, lon, y0=1981, y1=2025):
    url = ("https://power.larc.nasa.gov/api/temporal/monthly/point"
           "?parameters=T2M,PRECTOTCORR&community=AG"
           f"&latitude={lat}&longitude={lon}&start={y0}&end={y1}&format=JSON")
    par = lay_json(url)["properties"]["parameter"]
    t2m, mua = par["T2M"], par["PRECTOTCORR"]

    ok = lambda v: isinstance(v, (int, float)) and v > -900       # -999 = thiếu
    nam = []
    for y in range(y0, y1 + 1):
        t = [t2m.get(f"{y}{m:02d}") for m in range(1, 13)]          # không lấy khoá YYYY13
        r = [mua.get(f"{y}{m:02d}") for m in range(1, 13)]
        if not all(ok(v) for v in t + r):
            continue                                                # năm thiếu tháng: bỏ
        r_thang = [v * calendar.monthrange(y, m + 1)[1] for m, v in enumerate(r)]  # mm/ngày → mm/tháng
        nam.append({"year": y, "temp_c": round(sum(t) / 12, 2), "rain_mm": round(sum(r_thang), 1)})

    tb = lambda xs: round(sum(xs) / len(xs), 2)
    t80 = tb([n["temp_c"] for n in nam if 1981 <= n["year"] <= 1990])
    tgan = tb([n["temp_c"] for n in nam if 2016 <= n["year"] <= 2025])
    return {
        "start_year": nam[0]["year"], "end_year": nam[-1]["year"],
        "temp_1980s_c": t80, "temp_recent_c": tgan, "warming_c": round(tgan - t80, 2),
        "hottest_year": max(nam, key=lambda n: n["temp_c"])["year"],
        "yearly": nam,
    }

ha_noi = khi_hau_mot_noi(21.03, 105.85)
```

**Bước 6 — Kiểm tra.**
- `end_year` có đúng năm cuối đã đủ 12 tháng không?
- Hà Nội: nhiệt độ năm khoảng 23–25 °C, mưa năm khoảng 1.400–2.000 mm. Lệch xa là sai đơn vị hoặc sai toạ độ.
- Ô lưới POWER rộng khoảng 50 km, nên số liệu là của **cả vùng quanh điểm**, không phải của một trạm.

**Bước 7 — App dùng thế nào.** Bản tóm tắt nằm trong `climate_history_nasa.json` → `places`. App dùng giá trị **từng tháng, từng năm** của POWER (F1, "năm 2024 ở Huế"). ⚠️ **Không dùng `warming_c`, `rain_1980s_mm`, `hottest_year` của POWER để nói xu hướng**: chuỗi POWER ở Việt Nam không đồng nhất theo thời gian (mục 5.4). Câu "xưa và nay", "khí hậu ở …" và công cụ của trợ lý AI lấy xu hướng từ ERA5 (`NasaPowerService.extremes`).

### 8.2. NASA POWER theo ngày → đếm ngày nắng nóng, tái hiện một trận bão

**Đếm ngày nắng nóng.** Lấy `T2M_MAX` (nhiệt độ cao nhất mỗi ngày) cho cả một thập niên, đếm số ngày vượt ngưỡng, chia cho số năm.

> ⚠️ Ở Việt Nam, **không so thập niên 1980 với gần đây bằng POWER**. POWER cho Hà Nội năm 1985 tới 88 ngày ≥ 35 °C, cao nhất 44 °C, cao hơn mọi kỷ lục thật. App lấy số ngày nắng nóng xưa – nay từ ERA5. Code dưới đây vẫn đúng cách làm, chỉ cần đổi nguồn sang chuỗi đồng nhất (ERA5: `archive-api.open-meteo.com/v1/archive?daily=temperature_2m_max`). Dùng POWER theo ngày thì chỉ nên dùng cho **một sự kiện gần đây**, như bão Yagi 2024.

```python
def ngay_nang_nong(lat, lon, y0, y1):
    url = ("https://power.larc.nasa.gov/api/temporal/daily/point"
           "?parameters=T2M_MAX&community=AG"
           f"&latitude={lat}&longitude={lon}&start={y0}0101&end={y1}1231&format=JSON")
    tmax = lay_json(url)["properties"]["parameter"]["T2M_MAX"]     # {"19810101": 18.2, ...}
    hop_le = [v for v in tmax.values() if v > -900]
    so_nam = y1 - y0 + 1
    return {f"ge{n}_per_year": round(sum(v >= n for v in hop_le) / so_nam, 1) for n in (35, 37, 39)}

truoc = ngay_nang_nong(21.03, 105.85, 1981, 1990)
gan_day = ngay_nang_nong(21.03, 105.85, 2016, 2025)
```

**Tái hiện một sự kiện** (bão Yagi 1–15/9/2024, lũ Huế 6–20/10/2020): lấy từng ngày nhiệt độ, mưa, gió rồi tìm ngày mưa lớn nhất.

```python
def tai_hien_su_kien(lat, lon, tu, den):               # tu, den dạng "20240901"
    url = ("https://power.larc.nasa.gov/api/temporal/daily/point"
           "?parameters=T2M,PRECTOTCORR,WS10M&community=AG"
           f"&latitude={lat}&longitude={lon}&start={tu}&end={den}&format=JSON")
    p = lay_json(url)["properties"]["parameter"]
    ngay = []
    for k in sorted(p["T2M"]):
        if min(p["T2M"][k], p["PRECTOTCORR"][k], p["WS10M"][k]) <= -900:
            continue                                    # ngày thiếu: bỏ và ghi chú lại
        ngay.append({"date": f"{k[:4]}-{k[4:6]}-{k[6:]}", "temp_c": p["T2M"][k],
                     "rain_mm": p["PRECTOTCORR"][k],    # dữ liệu ngày: giữ nguyên mm/ngày
                     "wind_ms": p["WS10M"][k]})
    dinh = max(ngay, key=lambda d: d["rain_mm"])
    return {"days": ngay, "total_rain_mm": round(sum(d["rain_mm"] for d in ngay), 1),
            "peak_rain_date": dinh["date"], "peak_rain_mm": dinh["rain_mm"]}

yagi = tai_hien_su_kien(21.03, 105.85, "20240901", "20240915")
```

**Lưu ý khi nói về gió:** `WS10M` là **gió trung bình cả ngày** trên ô khoảng 50 km. Nó thấp hơn rất nhiều so với gió giật ở tâm bão, nên **không được quy ra cấp bão**. App đọc kèm câu lưu ý này.

**App dùng thế nào:** mỗi ngày là một nhịp. Đàn t'rưng chơi dày hay thưa theo `rain_mm`, mưa rất to thì thêm sấm, gió mạnh thì thêm gió rít. Giọng đọc nói ngày và số mm.

### 8.3. NASA POWER theo vùng → lưới chạm 0,1° toàn Việt Nam

Đây là phần dễ sai nhất, nên **dùng nguyên lệnh của pipeline**, đừng viết lại:

```powershell
python -m pipeline.update --only temp rain --years 2001-2025
```

Pipeline làm lần lượt các bước sau (đọc code ở `pipeline/sources/power.py`, `canonical.py`, `build.py`):

1. **Chia khung Việt Nam** (kinh độ 102–112, vĩ độ 8,3–23,6) thành các ô ≤ 5°, vì API vùng không nhận khung lớn.
2. **Gọi API vùng** cho từng ô, **mỗi lần một tham số**, gom nhiều năm một lần. Phản hồi được lưu cache ở `data/cache/`, chạy lại chỉ tải phần thiếu.
3. **Đổi đơn vị** theo đơn vị ghi trong phản hồi (`to_target_units`): mm/ngày × số ngày; mm/giờ × 24 × số ngày; kg/m²/s × 86.400 × số ngày.
4. **Đổi lưới:** POWER có ô 0,5° × 0,625°, thô hơn lưới đích 0,1°. Mỗi ô 0,1° lấy giá trị **điểm POWER gần nhất** (`resample_to_grid`). Nếu nguồn mịn hơn 0,1°, mỗi ô lấy **trung bình** các điểm rơi vào nó.
5. **Lưu định dạng chuẩn:** mỗi biến, mỗi tháng một file `data/raw/<biến>/<YYYY>-<MM>.npz` (lưới 153 hàng × 100 cột, kiểu float32). Từ bước này, mọi nguồn (POWER, FIRMS, file NASA gửi) đều giống nhau.
6. **In dòng kiểm tra** (`sanity`): trung bình, thấp nhất, cao nhất của 3 năm cuối, kèm khoảng hợp lý. Đọc dòng này trước khi đi tiếp.
7. **Build:** chỉ giữ ô đất liền (2.849 ô), tính chuẩn khí hậu 2001–2020 và độ lệch chuẩn của từng ô, từng tháng, rồi **lượng tử hoá** (mục 8.4). Ghi ra `touchgrid.json`, `series.json`, `frames/<biến>/<năm>.bin`.
8. **Kiểm chứng** (`validate`) rồi chép sang `app/assets/data/` và `web/data/`.

### 8.4. Lượng tử hoá: nén số thực về 1 byte, và cách đo sai số

Mỗi giá trị được đổi thành một số nguyên 0–254, còn 255 nghĩa là thiếu. Nhờ vậy 300 tháng × 2.849 ô chỉ còn khoảng 2 MB.

- **Thang tuyến tính** (nhiệt độ, 5–35 °C): `q = round((x − 5) / (35 − 5) × 254)`. Mỗi bước bằng 30/254 ≈ 0,118 °C, nên **sai số tối đa là nửa bước ≈ 0,059 °C**. Con số 0,058 °C mà `validate` đo được khớp với lý thuyết này.
- **Thang căn bậc hai** (mưa 0–1.200 mm, điểm cháy): lượng tử hoá trên √x. Giá trị nhỏ được giữ chi tiết hơn giá trị lớn, hợp với mưa vốn lệch mạnh về phía ít.

```python
import numpy as np

def luong_tu(x, vmin, vmax, thang="linear"):
    f = np.sqrt if thang == "sqrt" else (lambda v: v)
    t = (f(np.maximum(x, 0) if thang == "sqrt" else x) - f(vmin)) / (f(vmax) - f(vmin))
    q = np.clip(np.rint(t * 254), 0, 254)
    q[~np.isfinite(x)] = 255                            # 255 = thiếu
    return q.astype(np.uint8)

def giai_luong_tu(q, vmin, vmax, thang="linear"):
    f = np.sqrt if thang == "sqrt" else (lambda v: v)
    v = f(vmin) + q / 254 * (f(vmax) - f(vmin))
    v = v ** 2 if thang == "sqrt" else v
    return np.where(q == 255, np.nan, v)

x = np.array([5.0, 17.33, 29.87, 35.0, np.nan])
print(np.nanmax(np.abs(giai_luong_tu(luong_tu(x, 5, 35), 5, 35) - x)))   # luôn ≤ 0,059
```

**Khi đổi khoảng `min`/`max` của một biến** trong `config.py`, sai số đổi theo. Nhớ chạy lại `validate` và cập nhật con số trong slide.

### 8.5. NASA GISTEMP → 146 năm ấm lên toàn cầu

1. **Tải** file CSV (khoảng 30 KB).
2. **Bỏ dòng tiêu đề phụ:** dòng đầu là "Land-Ocean: Global Means". Bảng thật bắt đầu từ dòng có chữ `Year,`.
3. **Lấy cột `J-D`** (trung bình tháng 1–12). Bỏ năm có `***`, thường là năm đang diễn ra.
4. **Hiểu đúng con số:** đây là **chênh lệch so với trung bình 1951–1980**, không phải nhiệt độ thật. Nói "năm 2024 nóng hơn mức trung bình 1951–1980 là 1,28 °C", không nói "nhiệt độ năm 2024 là 1,28 °C".

```python
import csv, io

def gistemp():
    url = "https://data.giss.nasa.gov/gistemp/tabledata_v4/GLB.Ts+dSST.csv"
    text = urllib.request.urlopen(url, timeout=60).read().decode("utf-8")
    dong = [d for d in text.splitlines() if d.strip()]
    dau = next(i for i, d in enumerate(dong) if d.startswith("Year,"))   # bỏ tiêu đề phụ
    nam = []
    for row in csv.DictReader(io.StringIO("\n".join(dong[dau:]))):
        jd = (row.get("J-D") or "").strip()
        if row["Year"].isdigit() and jd and "*" not in jd:              # "***" = chưa đủ số
            nam.append({"year": int(row["Year"]), "anomaly_c": round(float(jd), 2)})
    nong_nhat = max(nam, key=lambda n: n["anomaly_c"])
    return {"baseline_period": "1951-1980", "unit": "°C", "series": nam,
            "hottest_year": nong_nhat["year"], "hottest_anomaly_c": nong_nhat["anomaly_c"]}
```

**Kiểm tra:** năm đầu 1880, năm nóng nhất hiện là 2024 (+1,28 °C).

**App dùng thế nào:** đàn bầu lướt qua 146 năm, mỗi năm một nốt, chênh lệch càng lớn nốt càng cao. Giọng đọc nói năm nóng nhất.

### 8.6. NASA FIRMS → điểm cháy theo tháng, theo vùng

Đây là cách **thay số đang viết tay** trong `fire_firms` (mục 10).

1. **Lấy MAP_KEY** và đặt `FIRMS_MAP_KEY` (mục 6.2).
2. **Chọn sản phẩm:** `MODIS_SP` (bản chuẩn, có từ năm 2000). Dữ liệu chuẩn có **độ trễ vài tháng**, nên tháng quá gần sẽ trả về rỗng. Rỗng ở đây **không có nghĩa là không có cháy**. Pipeline bỏ qua 4 tháng gần nhất vì lý do này.
3. **Chia tháng thành các cửa sổ ≤ 10 ngày** (giới hạn của API). Một tháng cần 4 lần gọi; 25 năm cần khoảng 1.200 lần, nên phải có cache.
4. **Lọc:**
   - chỉ giữ điểm có `acq_date` đúng tháng đang xét;
   - với MODIS, chỉ giữ điểm có `confidence` ≥ 30 (thang 0–100); với VIIRS, bỏ điểm loại `l`;
   - bỏ điểm trùng (cùng toạ độ, ngày, giờ).
5. **Đếm:** theo ô 0,1° (cho lưới chạm) hoặc theo vùng (cho bản tin).
6. **Lấy trung bình** từng tháng qua các năm, ra 12 số cho mỗi vùng.

```python
import csv, datetime as dt, io, os, time
from collections import defaultdict

KEY = os.environ.get("FIRMS_MAP_KEY", "")
VN = "102,8.3,112,23.6"                                  # Tây, Nam, Đông, Bắc
# Khung GẦN ĐÚNG của từng vùng (lon_min, lat_min, lon_max, lat_max). Muốn chính xác: dùng ranh giới tỉnh.
VUNG = {"tay_nguyen": (107.2, 11.0, 109.0, 15.5), "tay_bac": (102.1, 20.4, 105.0, 22.9)}

def tai_cua_so(ngay_bat_dau, so_ngay=10, nguon="MODIS_SP"):
    url = (f"https://firms.modaps.eosdis.nasa.gov/api/area/csv/{KEY}/{nguon}/{VN}/"
           f"{so_ngay}/{ngay_bat_dau.isoformat()}")
    text = urllib.request.urlopen(url, timeout=120).read().decode("utf-8")
    if not text.startswith("latitude"):                  # sai khoá / hết lượt: FIRMS trả chữ, không phải CSV
        raise RuntimeError(text[:120])
    return list(csv.DictReader(io.StringIO(text)))

def diem_chay_mot_thang(y, m, tin_cay_toi_thieu=30):
    dau = dt.date(y, m, 1)
    cuoi = dt.date(y + m // 12, m % 12 + 1, 1) - dt.timedelta(days=1)
    da_thay, diem, d = set(), [], dau
    while d <= cuoi:                                     # mỗi lần tối đa 10 ngày
        so_ngay = min(10, (cuoi - d).days + 1)
        for r in tai_cua_so(d, so_ngay):
            if not r["acq_date"].startswith(f"{y:04d}-{m:02d}"):
                continue                                 # chỉ giữ điểm đúng tháng
            if int(r["confidence"]) < tin_cay_toi_thieu:
                continue
            k = (r["latitude"], r["longitude"], r["acq_date"], r["acq_time"])
            if k not in da_thay:                         # bỏ điểm trùng giữa các cửa sổ
                da_thay.add(k)
                diem.append((float(r["latitude"]), float(r["longitude"])))
        d += dt.timedelta(days=so_ngay)
        time.sleep(0.3)                                  # nhẹ tay với giới hạn của MAP_KEY
    return diem

def dem_theo_vung(diem):
    dem = defaultdict(int)
    for lat, lon in diem:
        for ten, (x0, y0, x1, y1) in VUNG.items():
            if x0 <= lon <= x1 and y0 <= lat <= y1:
                dem[ten] += 1
    return dem

def trung_binh_thang(nam_tu=2001, nam_den=2025):
    """→ {vùng: [TB tháng 1, …, TB tháng 12]}"""
    tong = {v: [0] * 12 for v in VUNG}
    for y in range(nam_tu, nam_den + 1):
        for m in range(1, 13):
            for v, n in dem_theo_vung(diem_chay_mot_thang(y, m)).items():
                tong[v][m - 1] += n
    so_nam = nam_den - nam_tu + 1
    return {v: [round(x / so_nam) for x in t] for v, t in tong.items()}
```

> Chạy thật thì nên dùng lại `pipeline/sources/firms.py`. Script này đã có cache từng cửa sổ, tự thử lại 3 lần, và đếm sẵn theo ô 0,1°. Từ lưới ô đó, cộng các ô thuộc từng vùng là ra số theo vùng, không phải tải lại.

**Kiểm tra:**
- Tây Nguyên phải cao điểm vào mùa khô (tháng 2–4), Tây Bắc vào tháng 3–4.
- Tháng nào cũng 0 thì kiểm tra lại khoá, thứ tự toạ độ, độ trễ của dữ liệu.
- Điểm cháy MODIS là **điểm nóng bất thường** trong ô khoảng 1 km. Nó gồm cả đốt nương rẫy và đốt rơm, không chỉ cháy rừng. App phải nói rõ điều này.

**App dùng thế nào:** tiếng lửa lách tách, số "hạt nổ" tăng theo căn bậc hai số điểm cháy, để vùng cháy nhiều không át hết các vùng khác.

### 8.7. NASA SEDAC GDIS → danh mục thiên tai có vị trí

1. **Tải:** đăng nhập Earthdata, tải bộ *Geocoded Disasters (GDIS) Dataset* dạng CSV.
2. **Lọc** `country == "Vietnam"`. GDIS phủ giai đoạn 1960–2018; các năm sau bổ sung từ nguồn khác trong kho `data_nasa/` (GLC, EONET, DMC, DesInventar).
3. **Gộp theo `disasterno`:** một trận thiên tai có nhiều dòng, mỗi dòng là một tỉnh bị ảnh hưởng.
4. **Định vị:** mỗi tỉnh được đổi thành **tâm tỉnh cũ**, lấy từ danh bạ hành chính của app.
   - Tên tỉnh được so khớp mờ: bỏ dấu, bỏ khoảng trắng và ký tự lạ, độ giống ≥ 0,86. Nhờ vậy vẫn khớp được khi gặp lỗi mã hoá kiểu "Qu?ng Nam".
   - Kết quả hiện tại: định vị được 282/301 sự kiện. 19 sự kiện còn lại không khớp tỉnh nào nên bị bỏ, không đoán.
5. **Chuẩn hoá mức nặng** từ thang 1–10 về 1–5 (chia 2, kẹp trong khoảng 1–5). Sự kiện chỉ có năm, không có tháng, thì ghi "trong năm …, chưa rõ tháng".

```python
import csv
with open("pend-gdis-1960-2018-disasterlocations.csv", encoding="utf-8", errors="replace") as f:
    vn = [r for r in csv.DictReader(f) if r.get("country") == "Vietnam"]
# Tên cột có thể khác giữa các phiên bản: in vn[0].keys() ra xem trước khi viết tiếp
```

Toàn bộ các bước đã viết sẵn trong `pipeline/import_data_nasa.py` (hàm `build_f1`).

**App dùng thế nào:** khi hỏi "lịch sử thiên tai Quảng Ngãi", app lọc các sự kiện có tâm tỉnh nằm gần nơi hỏi, rồi phát lại theo thời gian. Bão, lũ, sạt lở mỗi loại một âm.

### 8.8. Độ cao và lớp phủ đất từ ô bản đồ (Terrarium, NASA GIBS)

Cách này không cần khoá và không cần tải file lớn. App dùng chính cách này khi rê tay khám phá.

**Bước 1 — Đổi toạ độ ra số hiệu ô bản đồ** ở mức phóng `z`. Mức 13 ứng với khoảng 18 m mỗi điểm ảnh ở Việt Nam.

**Bước 2 — Tải ô PNG 256 × 256 rồi đọc màu điểm ảnh.**
- **Terrarium:** độ cao = R × 256 + G + B / 256 − 32768 (mét). Dữ liệu gốc gồm SRTM của NASA.
- **GIBS MODIS MCD12Q1:** mỗi màu là một loại phủ đất theo bảng IGBP (17 loại). Chọn màu gần nhất trong bảng; điểm ảnh trong suốt nghĩa là không có dữ liệu. Mức chi tiết nhất của lớp này là mức 8 (ô khoảng 500 m).

```python
import io, math
from PIL import Image

def o_chua(lat, lon, z):                              # toạ độ → số hiệu ô (x, y) ở mức z
    n = 2 ** z
    x = int((lon + 180) / 360 * n)
    y = int((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n)
    return x, y

def diem_anh(lat, lon, z, x, y):                      # vị trí điểm ảnh trong ô 256×256
    n = 2 ** z
    px = int(((lon + 180) / 360 * n - x) * 256)
    py = int(((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n - y) * 256)
    return px, py

def tai_anh(url):
    return Image.open(io.BytesIO(urllib.request.urlopen(url, timeout=60).read())).convert("RGBA")

def do_cao(lat, lon, z=13):
    x, y = o_chua(lat, lon, z)
    anh = tai_anh(f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png")
    r, g, b, _ = anh.getpixel(diem_anh(lat, lon, z, x, y))
    return r * 256 + g + b / 256 - 32768             # mét

# Bảng màu IGBP của lớp GIBS (đủ 17 loại trong app/lib/live/terrain_patch.dart)
IGBP = {2: ((49, 204, 49), "Rừng lá rộng thường xanh"), 12: ((250, 239, 115), "Đồng ruộng"),
        13: ((255, 0, 0), "Đô thị"), 17: ((134, 202, 227), "Mặt nước")}

def lop_phu(lat, lon, z=8):
    x, y = o_chua(lat, lon, z)
    url = ("https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/"
           "MODIS_Combined_L3_IGBP_Land_Cover_Type_Annual/default/default/"
           f"GoogleMapsCompatible_Level8/{z}/{y}/{x}.png")       # chú ý: {y} đứng trước {x}
    r, g, b, a = tai_anh(url).getpixel(diem_anh(lat, lon, z, x, y))
    if a < 128:
        return None                                   # trong suốt = không có dữ liệu
    ma, (mau, ten) = min(IGBP.items(),
                         key=lambda kv: sum((c - d) ** 2 for c, d in zip(kv[1][0], (r, g, b))))
    return ma, ten

print(do_cao(11.942, 108.442), lop_phu(11.942, 108.442))   # Hồ Xuân Hương, Đà Lạt
```

**Bước 3 — Tính độ dốc** từ chênh độ cao giữa các điểm cạnh nhau: độ dốc (độ) = atan(√(dz/dx² + dz/dy²)).

**Bước 4 — Làm mượt.** Ô MODIS 500 m to hơn nhiều so với điểm ảnh độ cao (18 m). Tô thẳng sẽ thành từng khối vuông, nên app làm mượt và tính **tỉ lệ** từng loại phủ quanh mỗi điểm (`terrain_patch.dart`).

**Kiểm tra:** Đà Lạt khoảng 1.500 m (đọc ra 1.492 m), Hồ Gươm khoảng 10 m. Fansipan đọc ra khoảng 3.108 m, thấp hơn đỉnh thật 3.143 m vì mỗi điểm ảnh là trung bình một ô.

**Cần file gốc** (để làm số liệu trong pipeline, hoặc lấy NDVI, nhiệt độ mặt đất cho cảnh Đà Lạt): dùng **AppEEARS**.
1. Đăng nhập, chọn *Extract → Area*.
2. Vẽ hoặc tải lên vùng cần lấy.
3. Chọn sản phẩm `MCD12Q1.061` (lớp `LC_Type1`), `MOD13Q1.061` (`NDVI`), `MOD11A2.061` (`LST_Day_1km`), và khoảng ngày.
4. Chọn đầu ra GeoTIFF, phép chiếu Geographic.
5. Khi nhận email, tải file về `data/inbox/<tên>/`.
6. Chú ý **hệ số scale** của từng lớp: NDVI × 0,0001; LST × 0,02 ra Kelvin, trừ 273,15 ra °C.

### 8.9. Dữ liệu vũ trụ: NSSDCA, Space Place, âm thanh NASA

**NSSDCA (thông số hành tinh).** Trang này không có API, nên số liệu được chép tay. Quy trình:
1. Mở bản **hệ mét** của từng thiên thể, ví dụ `marsfact.html`.
2. Chép vào `build_f2_space.py` **đúng đơn vị của trang**: khối lượng 10²⁴ kg, đường kính km, nhiệt độ trung bình °C, chu kỳ ngày.
3. **Người thứ hai đối chiếu lại** từng số, rồi ghi tên người đối chiếu và ngày vào `data_card.processing`.
4. Số mặt trăng thay đổi theo thời gian: ghi "theo NASA, tính đến năm 2026".

**NASA Space Place (sự thật thú vị).**
1. Chép câu gốc tiếng Anh và đường dẫn trang vào `data_nasa/assets/content/facts.json`, rồi dịch sang tiếng Việt.
2. `import_data_nasa.py` tự lọc: chỉ giữ câu ngắn dạng gạch đầu dòng; bỏ câu dùng đơn vị Mỹ (độ F, dặm, pound) và câu hỏi.

**NASA Historical Sounds.**
1. Tải mp3 từ trang nasa.gov.
2. Bỏ vào `data_nasa/assets/content/nasa/`, thêm một dòng trong `credits.csv` (tên file, tên bản ghi, đường dẫn, ngày tải).
3. Chạy `python pipeline/nasa_sounds.py`. Script chép file vào app, đo thời lượng, và ghi `catalog.json` gồm lời giới thiệu song ngữ và câu đố. Lời giới thiệu viết trong chính script, theo thông tin NASA đã công bố về bản ghi.
4. Bản ghi loại này luôn có `audio_kind: "recording"`: app nói đây là **âm thanh thu thật**.

### 8.10. Đóng gói ra JSON cho app

Mọi file đầu ra đều theo khuôn: **`data_card` + phần dữ liệu**. Ví dụ:

```python
import datetime as dt
from pathlib import Path

ket_qua = {
    "data_card": {
        "dataset": "NASA POWER Agroclimatology — Monthly Point",
        "provider": "NASA Langley Research Center (LaRC)",
        "url": "https://power.larc.nasa.gov/api/temporal/monthly/point",
        "accessed": dt.date.today().isoformat(),
        "spatial": "Điểm 21,03°B 105,85°Đ (ô lưới khoảng 50 km)",
        "temporal": f"{ha_noi['start_year']}–{ha_noi['end_year']}, theo tháng",
        "processing": "Bỏ -999; bỏ năm thiếu tháng; mưa mm/ngày × số ngày của tháng; TB 1981–1990 và 2016–2025.",
        "limitation_vi": "Số liệu trung bình trên ô lưới khoảng 50 km, không phải số đo của một trạm.",
        "citation": "NASA LaRC POWER Project, Agroclimatology Archive v2.0.",
        "audio_kind": "app_sonification",
    },
    "places": [ha_noi],
}
Path("app/assets/data/vi_du.json").write_text(json.dumps(ket_qua, ensure_ascii=False, indent=2), encoding="utf-8")
```

- Ghi `ensure_ascii=False` để giữ chữ tiếng Việt.
- File đặt trong `app/assets/data/` thì app đọc được ngay, vì thư mục này đã khai báo trong `app/pubspec.yaml`. Đặt ở thư mục con mới thì phải khai báo thêm thư mục đó.

### 8.11. Từ số liệu ra âm thanh: app ánh xạ thế nào

Phần này cho người làm dữ liệu biết **chọn khoảng `min`/`max` thế nào** để âm thanh nghe rõ.

| Dữ liệu | Nhạc cụ | Cách ánh xạ (`app/lib/audio/`) |
|---|---|---|
| Nhiệt độ (`danbau`) | Đàn bầu | Giá trị đưa về 0–1 theo `min`/`max`, rồi chọn nốt trên **thang ngũ cung 3 quãng tám** bắt đầu từ C3 (130,81 Hz). Càng nóng càng cao, đàn bầu luyến giữa các nốt |
| Lượng mưa (`trung`) | Đàn t'rưng | Số nốt mỗi nhịp tăng theo **căn bậc hai** lượng mưa; nốt chọn ngẫu nhiên trong ngũ cung quãng C5. Mưa rất to thêm sấm |
| Điểm cháy (`fire`) | Tiếng lửa + trống | Số tiếng nổ lách tách tăng theo căn bậc hai số điểm cháy |
| Độ cao (rê tay, quét địa hình) | Sáo trúc | Như đàn bầu: càng cao nốt càng cao |
| Độ dốc | Rung máy | Càng dốc rung càng mạnh |

**Quy tắc chọn khoảng:**
- `min`/`max` phải phủ được gần hết giá trị thật. Nếu quá rộng, mọi nơi nghe cùng một nốt. Nếu quá hẹp, nhiều giá trị bị kẹt ở nốt cao nhất hoặc thấp nhất.
- Dữ liệu lệch mạnh (mưa, cháy, dân số) dùng `scale: "sqrt"`.
- Đổi khoảng rồi thì nghe thử ở 3 nơi khác nhau (ví dụ Hà Nội, Đà Lạt, Cà Mau) và chạy lại `validate`.

---

## 9. Đưa dữ liệu vào app

Tất cả lệnh chạy ở **thư mục gốc repo** (`sense/`). Kết quả ghi vào `app/assets/data/`.

| Lệnh | Tạo ra | Cần mạng / khoá |
|---|---|---|
| `python -m pipeline.update` | Lưới chạm 0,1°: `touchgrid.json`, `series.json`, `frames/` (cả `app/assets/data/` và `web/data/`) | POWER; FIRMS cần `FIRMS_MAP_KEY` |
| `python -m pipeline.update --only temp rain` | Như trên, bỏ điểm cháy (khi chưa có MAP_KEY) | POWER |
| `python -m pipeline.update --years 2018-2025` | Thử nhanh ít năm | POWER |
| `python -m pipeline.update --skip-fetch` | Chỉ build lại từ `data/raw/` đã có | Không |
| `python pipeline/fetch_and_normalize_nasa.py` | `gistemp_global.json` | GISTEMP |
| `python pipeline/build_f1_climate.py` | `climate_history_nasa.json` (29 nơi, ngày nắng nóng, Yagi, lũ Huế) | POWER |
| `python pipeline/build_f2_space.py` | `planets_nasa.json`, `qa_bank.json`, `space_media.json` | Không bắt buộc |
| `python pipeline/build_f3_terrain.py` | `dalat_scene.json`, `credits.csv`, chạy kiểm định 7 điểm | Open-Meteo |
| `python pipeline/import_data_nasa.py` | `vn_disasters_nasa.json`, `climate_34_provinces.json`, thêm `fun_facts` | Không (đọc `data_nasa/`) |
| `python pipeline/nasa_sounds.py` | `assets/sounds/nasa/*.mp3` + `catalog.json` | Không |
| `data_nasa\svs\tai_svs.bat` | Tải đủ 4 video NASA SVS vào `data_nasa/svs/full/` (tự nối lại khi rớt mạng) | svs.gsfc.nasa.gov |
| `python pipeline/build_eic.py` | `assets/eic/` (5 hình SVS cho Máy hát Trái Đất), cần ffmpeg | Không (đọc video đã tải) |
| `python -m pipeline.validate --raw data/raw --out web/data --samples 6` | In sai số lớn nhất và 3 điểm kiểm tra ngẫu nhiên | Không |

Sau khi chạy: mở app (`chay_ban_nhanh.bat` hoặc `flutter run`), hỏi thử một câu dùng dữ liệu đó, rồi commit cả file dữ liệu và script.

### 9.1. Khi có file NASA mới (NetCDF, HDF5, GeoTIFF, CSV)

Không cần viết code:

1. Tạo `data/inbox/<tên>/`, bỏ file vào.
2. Viết `source.json` mô tả file. Có ví dụ cho IMERG, MERRA-2, NEO, CSV điểm trong `docs/DATA_SOURCES.md` mục 2.
3. Chạy `python -m pipeline.update --only <biến> --inbox <tên>`.

Thêm một biến hoàn toàn mới (ví dụ độ ẩm đất `GWETROOT` của POWER): thêm một mục vào `VARS` trong `pipeline/config.py`. App tự hiện biến mới và tự chọn nhạc cụ. Xem `docs/DATA_SOURCES.md` mục 3.

### 9.2. Khối `data_card` bắt buộc cho mọi file

```json
"data_card": {
  "dataset": "Tên bộ dữ liệu và phiên bản",
  "provider": "Đơn vị cung cấp (NASA LaRC, NASA GISS…)",
  "url": "Đường dẫn nguồn",
  "accessed": "Ngày tải (YYYY-MM-DD)",
  "spatial": "Phạm vi và độ phân giải",
  "temporal": "Khoảng thời gian",
  "processing": "Đã xử lý gì: đổi đơn vị, lọc, lấy trung bình…",
  "limitation_vi": "Giới hạn — app sẽ đọc câu này cho người dùng",
  "citation": "Câu trích dẫn theo yêu cầu của nguồn",
  "audio_kind": "recording | nasa_sonification | app_sonification"
}
```

`audio_kind` cho biết âm thanh là **bản ghi thật** (`recording`), **NASA chuyển từ dữ liệu** (`nasa_sonification`) hay **app tự chuyển** (`app_sonification`). App luôn nói rõ loại này cho người nghe.

---

## 10. Trạng thái hiện tại của từng bộ dữ liệu (cần biết trước khi trình bày)

| File | Trạng thái | Việc cần làm |
|---|---|---|
| `gistemp_global.json` | ✅ Tải thật từ GISTEMP | — |
| `climate_history_nasa.json` → `places`, `hot_days_extremes`, `historical_events` | ✅ Khớp đúng API POWER (kiểm 14/11/2026). ⚠️ Nhưng **chuỗi POWER ở Việt Nam không đồng nhất**: `warming_c`, `rain_1980s_mm`, `hot_days_extremes` thập niên 1980 sai lệch lớn (mục 5.4) | App đã chuyển phần xu hướng sang ERA5. Khi trình bày: POWER cho giá trị tháng/năm gần đây; không trích "Hà Nội mát đi 1 độ" |
| `climate_34_provinces.json`, `vn_disasters_nasa.json` | ✅ Nhập từ kho `data_nasa/` | Ghi rõ người và ngày tải vào kho |
| `touchgrid.json`, `frames/` | ✅ Nhiệt độ và mưa POWER thật, đã kiểm chứng sai số (≤ 0,058 °C). **Chưa có lớp điểm cháy**, dù danh sách `sources` có ghi FIRMS | Chạy lại `pipeline.update` với `FIRMS_MAP_KEY` để có lớp điểm cháy |
| `climate_history_nasa.json` → **`fire_firms`** | ⚠️ **Số trung bình tháng theo 6 vùng đang được viết tay** trong `build_f1_climate.py` (hàm `build_firms_fire_summary`), không tính từ API | Viết lại để đếm từ FIRMS `MODIS_SP` 2001–2025 (dùng lại `pipeline/sources/firms.py`) |
| `dalat_scene.json` | ⚠️ **Độ cao lấy từ Open-Meteo Elevation** (mô hình Copernicus DEM), không phải SRTM như `data_card` ghi. **Lớp phủ, NDVI, nhiệt độ mặt đất, mặt nước** đang được **gán theo quy tắc** (khoảng cách tới hồ, độ cao), không đọc từ MODIS/JRC | Lấy thật qua AppEEARS (MCD12Q1, MOD13Q1, MOD11A2) hoặc sửa `data_card` cho đúng là "ước lượng". App vẫn dùng file này làm dự phòng khi mất mạng và cho trợ lý AI |
| `planets_nasa.json` (thông số) | ⚠️ Chép tay từ NSSDCA. **Số mặt trăng đã cũ** → đã sửa theo NASA Science (8/2026): Sao Thổ 293, Sao Mộc 115, Sao Thiên Vương 29, Sao Hải Vương 16 | Đối chiếu lại các số còn lại với trang NSSDCA |
| Rê tay khám phá (lúc chạy) | ✅ Ô Terrarium (SRTM), MODIS MCD12Q1 qua GIBS, OSM thật | — |
| `assets/touch/vn/` | ✅ SRTMGL30, GPWv4 thật, tải bằng `crawl_f3.py` | — |
| `assets/eic/` (5 bộ SVS) | ✅ Đọc từ video SVS thật; ⚠️ là **số đọc từ màu của hình**, không phải số đo gốc | Khi trình bày, nói "đọc từ hình ảnh NASA SVS" (mục 4.5) |
| EONET trong F1 | ✅ Đã sửa lỗi toạ độ bị ghi ngược ở một số sự kiện lũ (mục 5.1) | — |

> Trước khi sửa xong các dòng ⚠️, **không nói** trước giám khảo rằng điểm cháy theo vùng hay lớp phủ đất ở Đà Lạt "lấy từ vệ tinh NASA".

---

## 11. Kiểm tra dữ liệu trước khi đưa vào app

| Kiểm tra | Cách làm |
|---|---|
| Đơn vị | Mưa POWER là mm/ngày. Tổng năm ở Việt Nam thường 1.200–3.000 mm. Ra 50 mm hay 50.000 mm là sai đơn vị |
| Giá trị thiếu | Bỏ `-999` (POWER), `***` (GISTEMP), `NaN`. Không coi chúng là số 0 |
| Năm chưa đủ | Năm cuối có đủ 12 tháng chưa? Nếu chưa, chốt năm cuối hoặc ghi rõ trong `temporal` |
| Toạ độ | Kinh độ trước hay vĩ độ trước? Kinh độ dạng 0–360 hay −180–180? |
| So với thực tế | Hà Nội tháng 7 khoảng 29–30 °C; Đà Lạt khoảng 1.500 m; năm nóng nhất GISTEMP là 2024 |
| **Đồng nhất theo thời gian** | Trước khi nói xu hướng, in chuỗi từng năm ra xem có bước nhảy không (mưa tăng gấp đôi trong 1 năm, thập niên 1980 khô bất thường). So với một nguồn khác ở cùng điểm (ERA5). Xem mục 5.4 |
| **Số liệu thay đổi theo thời gian** | Số mặt trăng, kỷ lục, năm nóng nhất… phải tra lại trang NASA trước mỗi lần nộp hoặc trình bày (ví dụ Sao Thổ: 146 → 293 mặt trăng trong 2025–2026) |
| Sai số sau nén | `python -m pipeline.validate …` phải in sai số nhỏ hơn nửa bước lượng tử |
| Kiểm thử | `python -m pytest tests/` (pipeline) và `flutter test` trong `app/` |

---

## 12. Ghi nguồn và quy định sử dụng

- **Dữ liệu NASA** nói chung dùng tự do. Nhưng **không dùng logo NASA**, và không viết như thể NASA bảo trợ dự án. Ghi "Dữ liệu: NASA POWER…", không ghi "Ứng dụng của NASA".
- **Mỗi bộ dữ liệu có câu trích dẫn riêng** (`citation` trong `data_card`). Đưa đủ vào mục **References** trên trang nộp bài Space Apps.
- **Nguồn ngoài NASA:**
  - OpenStreetMap: ghi "© OpenStreetMap contributors" (giấy phép ODbL);
  - Open-Meteo: CC BY 4.0;
  - ERA5 (xu hướng xưa – nay): ghi "Copernicus Climate Change Service (C3S) ERA5" kèm Open-Meteo;
  - JRC Global Surface Water, HydroRIVERS, GADM: theo điều khoản của từng nguồn.
- **Space Apps** yêu cầu liệt kê mọi nguồn dữ liệu và khai báo việc dùng AI. Danh sách nguồn có sẵn trong `app/assets/data/credits.csv` và trong app (nói "nguồn dữ liệu").

---

## 13. Sự cố thường gặp

| Hiện tượng | Nguyên nhân và cách xử lý |
|---|---|
| POWER trả lỗi 429 hoặc chậm | Gọi quá nhiều cùng lúc. Giảm số luồng, chạy lại (pipeline có cache nên chỉ tải phần thiếu) |
| POWER vùng báo lỗi kích thước | Khung quá lớn hoặc nhiều tham số. Chia ô ≤ 5°, mỗi lần 1 tham số |
| FIRMS trả về trống | Sai thứ tự toạ độ (phải là Tây, Nam, Đông, Bắc), quá 10 ngày một lần, hoặc hết lượt của MAP_KEY |
| Mưa ra số quá nhỏ hoặc quá lớn | Quên đổi mm/ngày sang mm/tháng, hoặc đổi hai lần |
| Năm cuối toàn `-999` hoặc `***` | NASA chưa công bố. Chốt năm cuối là năm trước |
| Tải SEDAC hoặc LP DAAC bị đòi đăng nhập | Cần Earthdata Login (miễn phí) |
| APOD báo hết lượt | Đang dùng `DEMO_KEY`. Đặt `NASA_API_KEY` trên Vercel |
| `ffprobe` báo `moov atom not found` | Video SVS tải dở (thường do chuyển file khi trình duyệt chưa tải xong). Xoá đi, tải lại bằng `tai_svs.bat` |
| Trình duyệt không mở được thư mục frames của SVS | Frames là TIFF hoặc quá nặng. Dùng video mp4 + ffmpeg |
| `build_eic.py` in "bỏ qua: thiếu video" | Video chưa nằm trong `data_nasa/svs/full/` hoặc `data_nasa/svs/`, hoặc tên file khác. Giữ đúng tên gốc của SVS |
| Sự kiện EONET nằm "ngoài Trái Đất" (vĩ độ > 90) | Toạ độ bị ghi ngược [vĩ độ, kinh độ]. Dùng `eonetLatLon()` (mục 5.1) |
| POWER vùng trả lỗi 422 | Đang xin hơn 1 tham số. Mỗi lần chỉ được 1 tham số |
| App nói một nơi ở Việt Nam "mát đi", hoặc mưa "tăng gấp đôi" | Đang lấy xu hướng từ POWER. Chuỗi POWER ở Việt Nam không đồng nhất; dùng ERA5 (`NasaPowerService.extremes`), mục 5.4 |
| Số mặt trăng, số liệu thiên thể lệch với trang NASA | Số liệu đã cũ. Sửa trong `pipeline/build_f2_space.py` rồi chạy lại, và sửa cả câu dự phòng trong `app/lib/features/space/` |

---

## 14. Đường dẫn tham khảo

- NASA POWER API: <https://power.larc.nasa.gov/docs/services/api/>
- NASA GISTEMP: <https://data.giss.nasa.gov/gistemp/>
- NASA FIRMS API: <https://firms.modaps.eosdis.nasa.gov/api/>
- NASA Earthdata Search: <https://search.earthdata.nasa.gov> · AppEEARS: <https://appeears.earthdatacloud.nasa.gov>
- NASA GIBS: <https://nasa-gibs.github.io/gibs-api-docs/>
- NASA SEDAC: <https://sedac.ciesin.columbia.edu>
- NSSDCA Planetary Fact Sheet: <https://nssdc.gsfc.nasa.gov/planetary/factsheet/>
- api.nasa.gov (APOD): <https://api.nasa.gov> · EONET: <https://eonet.gsfc.nasa.gov/docs/v3>
- NASA Historical Sounds: <https://www.nasa.gov/historical-sounds/>
- NASA SVS (hình cho Máy hát Trái Đất): <https://svs.gsfc.nasa.gov/5475> · <https://svs.gsfc.nasa.gov/5011> · <https://svs.gsfc.nasa.gov/5436> · <https://svs.gsfc.nasa.gov/3912> · <https://svs.gsfc.nasa.gov/4950> · API: `https://svs.gsfc.nasa.gov/api/<mã>`
- Danh sách tài nguyên thử thách #14: <https://www.spaceappschallenge.org/2026/challenges/the-earth-information-jukebox/?tab=resources>
- FIRMS Area API: <https://firms.modaps.eosdis.nasa.gov/api/area/> · EONET v3: <https://eonet.gsfc.nasa.gov/docs/v3>
- SRTMGL30: <https://www.earthdata.nasa.gov/data/catalog/lpcloud-srtmgl30-002> · GPWv4 Land and Water Area: <https://www.earthdata.nasa.gov/data/catalog/esdis-ciesin-sedac-gpwv4-landh2oarea-r11-4.11>
- Quy định nộp bài Space Apps: <https://www.spaceappschallenge.org/resources/project-submission-guide/>
