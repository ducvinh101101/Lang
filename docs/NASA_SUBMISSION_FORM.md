# NASA Space Apps 2026 — Nội dung form nộp bài (Lắng)

> Hạn nộp chấm Hà Nội: **11:00 Chủ nhật 15/11/2026** (giờ Hà Nội). Hạn toàn cầu: 23:59 cùng ngày.
> Nộp tại **www.spaceappschallenge.org** → trang đội → tab **Project** → **Edit** → điền → tích 2 ô cam kết → **Submit**.
> Mọi ô trên form viết bằng **tiếng Anh**: chép nguyên phần trong khung. Chỗ có **[ … ]** là chỗ đội phải tự điền.
> **Submit bản đầu tiên ngay sáng 15/11**, sau đó sửa và Submit lại bao nhiêu lần cũng được trước 11:00.

---

## 1. Project Name

```
Lắng – Hear and Touch NASA Earth Data
```

(Nếu ô không nhận dấu tiếng Việt: `Lang – Hear and Touch NASA Earth Data`)

## 2. Challenge

```
The Earth Information Jukebox
```

## 3. High-Level Summary

```
Lắng (Vietnamese for "listen closely") is a talking globe that lets blind and low-vision people, older adults and children hear and touch NASA Earth data without seeing or reading. Its Earth Jukebox turns five NASA Scientific Visualization Studio visualizations (night lights, lightning seen from the ISS, CO₂, sea-surface temperature and GEDI forest height) back into numbers and plays them frame by frame on Vietnamese folk instruments, with spoken image descriptions and touch exploration. The same approach covers 146 years of GISTEMP warming, NASA POWER climate history and storm replays for 34 Vietnamese provinces, and SRTM terrain under the user's finger. It matters because NASA's Earth information is almost entirely visual, while about 2.5 million Vietnamese aged 50+ are blind or have serious vision loss and depend on others to read weather and disaster information to them.
```

## 4. Project Demo (link)

```
[Link Google Drive tới docs/Lang_SpaceApps_2026_Submission_EN.pdf — bản PDF 7 trang đã xuất sẵn]
```

- Tối đa **7 trang tính cả trang bìa**: `docs/Lang_SpaceApps_2026_Submission_EN.pdf` đúng 7 trang ✓ (bản sửa được: `.pptx` cùng tên).
- Hoặc video tối đa **30 giây** (nói tiếng Việt thì **bắt buộc phụ đề tiếng Anh**).
- Đặt quyền **"Bất kỳ ai có đường liên kết"**, mở thử bằng tab ẩn danh.

## 5. Final Project (link)

```
Source code: https://github.com/ducvinh101101/Lang
Web app (works in Chrome, Edge and Safari): https://sense-app-two.vercel.app
Android APK: [link bản phát hành APK trên GitHub Releases hoặc Google Drive]
```

- Repo GitHub phải để **Public** (hoặc ít nhất mở được khi không đăng nhập).
- README của repo phải bằng tiếng Anh (đã soạn sẵn `README.md` tiếng Anh, bản tiếng Việt chuyển sang `README.vi.md`).

## 6. Project Details

```
WHAT IT DOES
Lắng is a voice-first globe for people who cannot see a chart. Users simply speak (Vietnamese or English); a short tone confirms the command and a voice answers. Nothing on screen must be seen.

1. Earth Jukebox (the core of Challenge 14). Five NASA SVS / Earth Information Center visualizations are played as sound: Black Marble night lights 2012–2023 (SVS 5475), lightning from the LIS sensor on the ISS by month (SVS 5011), GEOS CO₂ (SVS 5436/5196), ECCO2 sea-surface temperature and currents (SVS 3912) and GEDI forest canopy height (SVS 4950). Each visualization starts with a spoken description of the image (following Section 508 image-description practice) and a legend of the sounds. During playback the main instrument's pitch follows the value, the density of percussion follows the area affected, left/right stereo follows west/east, and a small gong marks a noticeable change over Vietnam and the East Sea. Users can say "month 5" or "year 2020" to jump, "explain" to hear why an instrument was chosen, or slide a finger over the image to hear each region. Results you can hear: Vietnam's night lights grew about 44% from 2012 to 2023 (17% globally); lightning over Vietnam peaks in May, two months before the global peak.

2. Hear the climate. Temperature plays on the đàn bầu (one-string zither) and rain on the t'rưng (bamboo xylophone): NASA GISTEMP v4 (146 years of global warming, 2024 = +1.28 °C vs 1951–1980), NASA POWER monthly climate 1981–2025 for 34 provinces, and 15-day day-by-day replays of Typhoon Yagi (2024) and the 2020 Central Vietnam floods. NASA SEDAC GDIS adds 282 geocoded disasters in Vietnam.

3. Touch the land. On a real terrain map, a bamboo flute rises with SRTM elevation and the phone vibrates with slope; MODIS land cover adds water, forest and town sounds; place names, elevation and slope are read aloud.

4. Explore space. NSSDCA planetary facts, NASA Space Place fun facts, ten real NASA historical recordings and four voice-only games.

HOW IT WORKS
- Data pipeline (Python): download from NASA APIs and archives, convert units, validate, compress and write a data card for every file (source, date, resolution, licence, limits). For the Earth Jukebox, pipeline/build_eic.py converts each video frame to numbers with a method suited to that visualization: brightness above the dark background (night lights), composite minus base-map video (CO₂), colour-bar matching (sea temperature), seasonal phase detection (lightning) and inverse projection of a rotating globe fitted to coastlines (GEDI). Each frame becomes a 64 × 32 grid plus summary values.
- App: Flutter for Android, iOS, Windows and the web. Offline speech recognition with sherpa-onnx (Vietnamese Zipformer, NVIDIA Parakeet for English, Silero voice activity detection), offline Vietnamese voice with Piper, and folk instruments synthesised on the device (flutter_soloud). Values are mapped to a five-note pentatonic scale over three octaves, and the exact number is always read aloud after the music.
- Accessibility: voice control with no screen needed, interrupt with "stop", go back with "go back", a Z gesture or a two-finger swipe down, hold one finger to talk, high-contrast interface, works offline on Android.
- Open questions go to an AI assistant (Gemma 4 / Gemini) that is always given the relevant NASA data first (retrieval-augmented), so it answers from the data instead of inventing numbers.

HOW WE CHECKED IT
After compressing 300 months of NASA POWER data the largest error is 0.058 °C (temperature) and 1.485 mm/month (rain); our 2024 GISTEMP value matches NASA's; Đà Lạt reads 1,492 m against about 1,500 m in reality; about 3,900 automated tests run in CI on every push, including more than 3,300 voice-command sentences. While validating, we found that NASA POWER's long series for Vietnam has jumps over time (Hà Nội showed −0.97 °C cooling vs +1.02 °C warming in ERA5), so long-term trends use the ERA5 reanalysis and the app names that source aloud.

LIMITS WE STATE OPENLY
NASA POWER cells are about 50 km; Earth Jukebox values are read from image colours and are approximate (sea temperature may read 1–2 °C high); the fire-season figures are still illustrative; we have not yet tested with blind users.

BENEFITS AND GOALS
A blind person can check this afternoon's rain, hear how bad past floods were and feel the land around them without asking anyone. Children can learn climate and space by ear. Next: test with a Vietnamese blind association, add an easy-listening mode, fix gesture conflicts with screen readers, and add live storm alerts from NASA EONET.

Team: Vinh (team lead, developer), Tuấn Minh (lead presenter), Minh Sơn (NASA data), Minh Phúc (sound design), Xuân Phúc and Hoàng (testing and outreach).
```

## 7. Use of AI

```
AI used while building:
- Claude (Anthropic) – coding assistant (Flutter/Dart and Python), checking data sources and numbers against NASA pages, drafting documentation, slides and demo scripts. All code and claims were reviewed and tested by the team.
- Antigravity (Google) – coding assistant for the test pipeline and documentation.
- [Thêm công cụ AI khác đội đã dùng và dùng vào việc gì, ví dụ: ChatGPT / Codex / Gemini / Copilot …]

AI inside the app:
- Google Gemma 4 (gemma-4-26b-a4b-it) / Gemini API – answers open questions; it is always given the relevant NASA data first (retrieval-augmented) and built-in commands, not AI, provide the official numbers.
- Groq Whisper large-v3 (optional cloud speech recognition when online), with a filter that discards known Whisper hallucinations.
- On-device models (not generative): sherpa-onnx Zipformer Vietnamese ASR, NVIDIA Parakeet TDT-CTC 110M English ASR, Silero VAD, Piper vi_VN-vais1000 text-to-speech.

No AI-generated images, music or data are used: screenshots are real, images in the Earth Jukebox are original NASA SVS frames, and all sounds are synthesised from the data or are real NASA recordings.
```

## 8. NASA Data / Partner Data

```
NASA data:
- NASA Scientific Visualization Studio / Earth Information Center: SVS 5475 & 5313 (Black Marble VIIRS night lights), SVS 5011 (Lightning Imaging Sensor on the ISS), SVS 5436 & 5196 (GEOS DYAMOND CO₂), SVS 3912 (ECCO2 sea-surface temperature and currents), SVS 4950 (GEDI forest canopy height) – https://svs.gsfc.nasa.gov/
- NASA GISS Surface Temperature Analysis (GISTEMP v4) – https://data.giss.nasa.gov/gistemp/
- NASA POWER (MERRA-2) monthly and daily data – https://power.larc.nasa.gov/
- NASA SEDAC Geocoded Disasters (GDIS) and GPWv4 rev11 population density and water area (CIESIN) – doi:10.7927/H49C6VHW
- NASA SRTMGL30 v002 and SRTM GL1 elevation (LP DAAC) – https://www.earthdata.nasa.gov/data/catalog/lpcloud-srtmgl30-002 – doi:10.5067/MEaSUREs/SRTM/SRTMGL30.002
- NASA MODIS MCD12Q1 land cover (LP DAAC, served via NASA GIBS) – https://lpdaac.usgs.gov/
- NASA FIRMS MODIS C6.1 active fire data – https://firms.modaps.eosdis.nasa.gov/
- NASA EONET natural events – https://eonet.gsfc.nasa.gov/
- NASA Global Landslide Catalog
- NASA NSSDCA Planetary Fact Sheet – https://nssdc.gsfc.nasa.gov/planetary/factsheet/
- NASA Science Solar System and NASA Space Place – https://science.nasa.gov/solar-system/ , https://spaceplace.nasa.gov/
- NASA Historical Sounds – https://www.nasa.gov/historical-sounds/
- NASA Astronomy Picture of the Day (APOD) API – https://api.nasa.gov/

Partner space agency data: none.
```

## 9. References

```
Non-NASA data:
- ERA5 reanalysis, Copernicus Climate Change Service / ECMWF (Hersbach et al., 2020), via the Open-Meteo Historical Weather API (CC BY 4.0) – https://open-meteo.com/
- Open-Meteo forecast API (live weather) – https://open-meteo.com/
- OpenStreetMap contributors (ODbL) – place, river and street names
- Natural Earth 1:50m country boundaries (public domain)
- EC JRC Global Surface Water (Pekel et al., 2016); WWF HydroRIVERS v1.0 (Lehner & Grill, 2013)
- USGS earthquake feed
- Vietnam administrative units: General Statistics Office of Vietnam; GADM 4.1
- RAAB Vietnam 2015 survey (IAPB); GSO mid-term census 2024 (population statistics in the slides)

Open-source software and models:
- Flutter and Dart (BSD-3-Clause)
- sherpa-onnx, k2-fsa (Apache-2.0); Zipformer Vietnamese ASR model sherpa-onnx-zipformer-vi-int8-2025-04-20
- NVIDIA Parakeet TDT-CTC 110M English ASR (CC-BY-4.0)
- Silero VAD (MIT)
- Piper TTS voice vi_VN-vais1000-medium; VAIS-1000 corpus (CC BY 4.0); espeak-ng data (GPL-3.0)
- flutter_soloud / SoLoud (MIT / zlib), flutter_tts, record, geolocator, path_provider, http, shared_preferences
- Python: numpy, Pillow, ffmpeg
- Fonts: Be Vietnam Pro and Baloo 2 (SIL Open Font License)

Research:
- Arcand, K. et al. (2024), a study of NASA's data sonifications with 3,184 participants including blind and low-vision listeners
- Ginns, P. (2005), meta-analysis of the modality effect (narration with visuals)
- Section 508 image-description guidelines (NASA image descriptions)

AI tools: see "Use of AI".
```

## 10. Hai ô cam kết (bắt buộc tích)

- ☐ Đã đọc hướng dẫn nộp bài và đồng ý với điều khoản của cuộc thi.
- ☐ Bài là sản phẩm của đội; mọi tài nguyên bên ngoài đã ghi ở mục References.

## 11. Giấy phép mã nguồn

Bài nộp sẽ công khai. Không chọn giấy phép thì NASA mặc định **Apache 2.0**. Đề xuất: code của đội theo **Apache-2.0**, ghi rõ trong README là các thành phần bên thứ ba giữ giấy phép riêng (espeak-ng data GPL-3.0, Parakeet CC-BY-4.0, giọng Piper/VAIS-1000 CC BY 4.0, font OFL).

---

## Danh sách kiểm tra trước 11:00

| Việc | Ai | Xong |
|---|---|---|
| Tất cả thành viên đã đăng ký điểm thi **Hanoi, Vietnam** và có tên ở tab **Members** (sau khi cổng đóng thì không thêm được) | Trưởng nhóm | ☐ |
| Đã chọn đúng thử thách **The Earth Information Jukebox** | Trưởng nhóm | ☐ |
| Repo `github.com/ducvinh101101/Lang` để **Public**, README tiếng Anh | Vinh | ☐ |
| Link slide (PDF 7 trang) và link APK đặt **"Bất kỳ ai có đường liên kết"**, đã mở thử bằng tab ẩn danh | Vinh | ☐ |
| Web app mở được trên điện thoại khác mạng | Cả đội | ☐ |
| Đã thêm các công cụ AI khác vào **Use of AI** | Cả đội | ☐ |
| Không có thông tin cá nhân trong bài và repo: ngày sinh, địa chỉ, số điện thoại, ảnh thành viên dưới 18 tuổi | Cả đội | ☐ |
| **Submit** bản đầu tiên sáng 15/11, kiểm tra trạng thái "đã nộp" | Trưởng nhóm | ☐ |
| Đến phòng chấm / vào Zoom (ID 940 8456 9142) **trước giờ chấm 10 phút** | Cả đội | ☐ |

## Phần trình bày trước giám khảo (15 phút)

BTC khuyên **trình bày 5–7 phút** để dành thời gian hỏi đáp. Kế hoạch:

| Phần | Thời lượng | Tài liệu |
|---|---|---|
| Thuyết trình 7 slide | ~4 phút 30 | `Kich_ban_phan_vai_Lang_rut_gon.docx` |
| Demo trực tiếp | ~2 phút 30 | `Kich_ban_demo_EN_5phut.docx` / `Kich_ban_demo_VI_1nguoi_5phut.docx`, phần "Bản thi 2 phút 30" |
| Hỏi đáp | ~8 phút | `Lang_Hoi_dap_theo_phan_cong.docx` |

## Tiêu chí chấm và chỗ bài trả lời

| Tiêu chí | Bài trả lời ở đâu |
|---|---|
| Impact | Slide 2 (2,5 triệu người, bão Yagi), slide 7 (ai được giúp, bước tiếp) |
| Creativity | Nhạc cụ dân tộc, rê tay trên địa hình và trên hình NASA, giữ để nói |
| Validity | Slide 6: 0,058 °C, GISTEMP khớp NASA, 1.492 m, ~3.900 test; phát hiện POWER nhảy bậc → ERA5; nói rõ giới hạn |
| Relevance | Earth Jukebox: 5 hình NASA SVS/EIC phát thành âm theo từng khung, đúng đề #14 |
| Presentation | 7 slide, demo trực tiếp, câu chuyện "nghe thay cho nhìn" |
