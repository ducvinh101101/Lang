---
title: "Lắng · Sổ kỹ thuật"
subtitle: "NASA Space Apps Challenge 2026 · Thử thách #14 The Earth Information Jukebox"
---

# Cách đọc sổ

Sổ ghi lại quá trình làm Lắng theo **chức năng**, không theo mốc thời gian. Mỗi hạng mục có người phụ trách (theo bảng phân công), minh chứng trong mã nguồn hoặc lịch sử commit, và đánh giá.

**Thang đánh giá**

| Đánh giá | Nghĩa |
|---|---|
| **Đạt – Đủ** | Chạy được trên bản web, có kiểm thử tự động hoặc kiểm tra tay, đúng như mô tả |
| **Đạt – Thiếu** | Chạy được nhưng còn giới hạn đã biết (ghi ở cột "Còn thiếu") |
| **Chờ kiểm thử** | Đã viết mã, chưa chạy `flutter analyze` / `flutter test` hoặc chưa thử trên máy thật |
| **Chưa đạt** | Chưa làm hoặc chưa có kết quả |

**Thành viên và vai trò**

| Thành viên | Vai trò |
|---|---|
| Vinh | Trưởng nhóm, lập trình toàn bộ app và pipeline, nộp bài |
| Tuấn Minh | Thuyết trình chính, dẫn demo |
| Minh Sơn | Dữ liệu NASA: chọn nguồn, kiểm chứng, ghi công |
| Minh Phúc | Thiết kế âm thanh: nhạc cụ, cách ánh xạ số liệu thành âm |
| Xuân Phúc | Kiểm thử, liên hệ người dùng |
| Hoàng | Kiểm thử, liên hệ người dùng |

# 1. Nền tảng chung

| # | Hạng mục | Đã làm | Phụ trách | Minh chứng | Đánh giá | Còn thiếu |
|---|---|---|---|---|---|---|
| N1 | Khung app Flutter | Một mã nguồn chạy web (Vercel), Android, iOS, Windows | Vinh | `app/lib/main.dart`, `app_state.dart` | Đạt – Đủ | Bản iOS chỉ build qua CI, chưa thử nhiều trên iPhone thật |
| N2 | Lối thoát ở mọi màn | "quay lại", "về màn hình chính", vẽ chữ Z | Vinh | `core/z_gesture.dart` | Đạt – Đủ | Chưa thử khi bật TalkBack/VoiceOver |
| N3 | Vuốt hai ngón | Xuống = quay lại; trái/phải = chuyển phần (thời tiết → địa lý → vũ trụ → Jukebox) | Vinh | `core/two_finger_swipe.dart`, `test/two_finger_swipe_test.dart` | Chờ kiểm thử | Chạy `flutter test`, thử trên điện thoại |
| N4 | Giữ một ngón để nói | Giữ yên 350 ms thì app im, nghe lệnh; thả tay là chốt câu | Vinh | `globe_page.dart` (`_holdStart`, `_holdUp`) | Chờ kiểm thử | Thử trên máy demo |
| N5 | CrashGuard | App văng trong lúc gọi thư viện âm thanh/giọng đọc thì lần sau tự tắt phần đó và báo bằng lời | Vinh | `core/crash_guard.dart` | Đạt – Đủ | — |
| N6 | Tương phản màu | Vàng `#FFD54F` trên `#0A0D14`, ≈ 13,8:1 | Vinh | `ui/theme.dart` | Đạt – Đủ | Không phải chứng nhận WCAG toàn app |
| N7 | Build và CI | APK và IPA build tự động; kiểm thử chạy mỗi lần push | Vinh | `.github/workflows/android-apk.yml`, `ios-ipa.yml` | Đạt – Đủ | Repo Lang cần thêm lại secrets |

# 2. F1 · Nghe khí hậu

| # | Hạng mục | Đã làm | Phụ trách | Minh chứng | Đánh giá | Còn thiếu |
|---|---|---|---|---|---|---|
| F1.1 | Dữ liệu khí hậu 34 tỉnh | NASA POWER (MERRA-2) theo tháng 1981–2025 | Minh Sơn | `climate_34_provinces.json` | Đạt – Đủ | Ô lưới ≈ 50 km, không chi tiết tới huyện |
| F1.2 | Lưới chạm toàn Việt Nam | 0,1°, 2.849 ô, 300 tháng, nén `uint8` | Minh Sơn, Vinh | `touchgrid.json`, `pipeline/validate.py` | Đạt – Đủ | — |
| F1.3 | Kiểm chứng nén | Sai số lớn nhất 0,058 °C và 1,485 mm/tháng | Minh Sơn | `pipeline/validate.py` | Đạt – Đủ | — |
| F1.4 | Âm thanh khí hậu | Đàn bầu = nhiệt độ, t'rưng = mưa, sấm, gió, trống, rung khi bão | Minh Phúc, Vinh | `audio/`, `docs/CHUYEN_DU_LIEU_THANH_AM_THANH.md` | Đạt – Đủ | — |
| F1.5 | Thời tiết hiện tại | Bây giờ, 48 giờ, 10 ngày, bụi mịn, lời khuyên | Vinh | `live/live_weather.dart`, `weather_talk.dart` | Đạt – Đủ | Nguồn là Open-Meteo, không phải NASA (đã nói rõ) |
| F1.6 | Tái hiện bão | 15 ngày bão Yagi, mưa lũ Huế 10/2020 | Vinh, Minh Phúc | `features/history/` | Đạt – Đủ | — |
| F1.7 | Thiên tai | 282 sự kiện (107 bão, 59 lũ, 116 sạt lở) | Minh Sơn | `vn_disasters_nasa.json` (SEDAC GDIS) | Đạt – Đủ | — |
| F1.8 | Ấm lên toàn cầu | 146 năm GISTEMP; 2024 = +1,28 °C | Minh Sơn | `gistemp_global.json` | Đạt – Đủ | — |
| F1.9 | Mùa cháy | Điểm cháy FIRMS theo tháng | Minh Sơn | `assets/data/` | Đạt – Thiếu | Số liệu mùa cháy còn mang tính minh họa |
| F1.10 | Kiểm thử F1 | Câu lệnh thời tiết, lịch sử, thiên tai | Xuân Phúc | `app/test/` | Đạt – Đủ | — |

# 3. F2 · Khám phá vũ trụ

| # | Hạng mục | Đã làm | Phụ trách | Minh chứng | Đánh giá | Còn thiếu |
|---|---|---|---|---|---|---|
| F2.1 | Hệ Mặt Trời | Mặt Trời và 8 hành tinh, mỗi thiên thể một âm | Vinh, Minh Phúc | `features/space/` | Đạt – Đủ | Bản đồ 2D, không phải mô hình 3D |
| F2.2 | Thông số thiên thể | 10 thiên thể (NASA NSSDCA) | Minh Sơn | `planets_nasa.json` | Đạt – Đủ | — |
| F2.3 | Nội dung | 135 sự thật thú vị, 35 hỏi–đáp (12 câu đính chính) | Minh Sơn | `qa_bank.json` | Đạt – Đủ | — |
| F2.4 | Âm thanh NASA | 10 bản ghi âm thật | Minh Phúc | `assets/sounds/nasa/` | Đạt – Đủ | — |
| F2.5 | Ảnh thiên văn hôm nay | Đọc lời giải thích APOD | Vinh | `live/apod.dart` | Đạt – Đủ | Cần mạng |
| F2.6 | Trò chơi | 4 trò chơi bằng giọng nói, có gợi ý, nhắc lại, bỏ qua | Vinh | `features/space/planet_games.dart` | Đạt – Đủ | — |
| F2.7 | Kiểm thử F2 | Câu hỏi hành tinh tiếng Việt và tiếng Anh | Hoàng | `test/planet_facts_test.dart` | Đạt – Đủ | — |

# 4. F3 · Chạm vào địa hình

| # | Hạng mục | Đã làm | Phụ trách | Minh chứng | Đánh giá | Còn thiếu |
|---|---|---|---|---|---|---|
| F3.1 | Bản đồ chạm | Địa hình thật ≈ 2,4 × 2,4 km, bắc ở trên | Vinh | `features/globe/local_map.dart` | Đạt – Đủ | — |
| F3.2 | Dữ liệu địa hình | SRTM (≈ 18 m/điểm), MODIS MCD12Q1 (≈ 500 m), GPWv4, tên sông hồ OSM | Minh Sơn | `live/terrain_*.dart`, `vector_tiles.dart` | Đạt – Đủ | — |
| F3.3 | Âm thanh và rung | Sáo theo độ cao, rung theo độ dốc, sóng nước, lá rừng, tiếng xe | Minh Phúc, Vinh | `audio/`, `core/haptics.dart` | Đạt – Thiếu | Rung chỉ có trên Android |
| F3.4 | Quét mặt cắt | Vùng ≈ 100 km, Bắc → Nam rồi Tây → Đông, ≤ 8 giây/lượt | Vinh | `features/terrain_scan/` | Đạt – Đủ | — |
| F3.5 | Chạy khi mất mạng | Lưới độ cao thô ≈ 1 km có sẵn | Minh Sơn | `assets/data/` | Đạt – Thiếu | Không có tên sông, đường khi mất mạng |
| F3.6 | Kiểm chứng | Đà Lạt đọc 1.492 m (thực tế ≈ 1.500 m) | Xuân Phúc, Hoàng | kiểm tra tay | Đạt – Đủ | — |

# 5. Earth Jukebox (lõi của thử thách #14)

| # | Hạng mục | Đã làm | Phụ trách | Minh chứng | Đánh giá | Còn thiếu |
|---|---|---|---|---|---|---|
| J1 | Chọn hình NASA | 5 visualization SVS: Black Marble, sét LIS, CO₂ GEOS, ECCO2, GEDI | Minh Sơn | `data_nasa/svs/` | Đạt – Đủ | — |
| J2 | Đọc màu thành số | Lưới 64 × 32 và giá trị tóm tắt cho từng khung hình | Vinh, Minh Sơn | `pipeline/build_eic.py` | Đạt – Thiếu | Số đọc từ màu ảnh là gần đúng |
| J3 | Ánh xạ âm thanh | Cao độ = giá trị, mật độ nhịp = diện tích, trái/phải = tây/đông, chiêng khi Việt Nam đổi mức | Minh Phúc | `docs/CHUYEN_DU_LIEU_THANH_AM_THANH.md` | Đạt – Đủ | — |
| J4 | Mô tả ảnh bằng lời | Mô tả, chú giải, rê tay nghe từng vùng, "giải thích" | Vinh | `features/eic/` | Đạt – Đủ | — |
| J5 | Kết quả nghe được | Đèn đêm Việt Nam tăng ≈ 44% (2012–2023); sét ở Việt Nam đỉnh tháng 5 | Minh Sơn | dữ liệu khung hình | Đạt – Đủ | — |

# 6. Giọng nói và AI

| # | Hạng mục | Đã làm | Phụ trách | Minh chứng | Đánh giá | Còn thiếu |
|---|---|---|---|---|---|---|
| G1 | Nghe offline tiếng Việt | sherpa-onnx Zipformer + Silero VAD, có từ khoá ưu tiên | Vinh | `speech/voice_listener_io.dart` | Đạt – Đủ | — |
| G2 | Nghe offline tiếng Anh | NVIDIA Parakeet đóng gói sẵn trong app, không phải tải | Vinh | `assets/asr/en_parakeet/` | Chờ kiểm thử | Thử build và dung lượng APK |
| G3 | Lọc nhận nhầm từ máy chủ | Bỏ kết quả Whisper khi ra câu "rác" hoặc dài bất thường, quay về kết quả offline | Vinh | `speech/nvidia_asr.dart`, `test/asr_cloud_choice_test.dart` | Chờ kiểm thử | Chạy `flutter test` |
| G4 | Giọng đọc | Piper `vi_VN-vais1000` offline; web dùng giọng trình duyệt hoặc Piper qua `/api/tts` | Vinh | `speech/speaker.dart` | Đạt – Đủ | — |
| G5 | Giọng đọc trên Safari/iPad | Mở khoá giọng đọc ở lần chạm đầu; iPhone, iPad, Firefox dùng giọng máy chủ | Vinh | `speech/web_speech_web.dart` | Chờ kiểm thử | Thử trên iPad sau khi deploy |
| G6 | Hiểu câu tự nhiên | Câu ngập ngừng, câu sửa, câu hỏi tiếp, tên xã/phường cũ và mới | Vinh | `features/globe/world_commands.dart`; hơn 3.300 câu mẫu | Đạt – Đủ | — |
| G7 | Trợ lý AI có dữ liệu | Gemma 4 / Gemini, gửi kèm số liệu NASA liên quan (RAG); khoá API trên máy chủ | Vinh | `live/gemini_assistant.dart`, `earth_rag.dart` | Đạt – Đủ | Không bảo đảm 100% AI không bịa số |

# 7. Kiểm thử với người dùng và hồ sơ nộp

| # | Hạng mục | Đã làm | Phụ trách | Minh chứng | Đánh giá | Còn thiếu |
|---|---|---|---|---|---|---|
| K1 | Thử với người khiếm thị | Đã có phiếu khảo sát và kế hoạch thử | Xuân Phúc, Hoàng | `docs/Khảo sát.docx` | Chưa đạt | Chưa có đợt thử chính thức |
| K2 | Góp ý từ người thử | Bảng lỗi: Safari/iPad, giao diện co giãn, chạm sai nước, âm chồng nhau, đề xuất cử chỉ | Xuân Phúc, Hoàng | `Bang_Danh_Gia_Va_Feedback_Lang_NASA.xlsx` | Đạt – Thiếu | Lỗi giao diện co giãn cần ảnh chụp để sửa tiếp |
| K3 | Deck nộp bài | 7 trang tiếng Anh | Tuấn Minh, Vinh | `docs/Lang_SpaceApps_2026_Submission_EN.pdf` | Đạt – Thiếu | Ô "Results" ở slide 6 còn để trống |
| K4 | Kịch bản thuyết trình và demo | Phân vai 4:30, demo 2:30, hỏi đáp | Tuấn Minh | `docs/Kich_ban_*.docx` | Đạt – Đủ | Tập trọn vẹn 2 lần |
| K5 | Form nộp bài | Nội dung tiếng Anh cho mọi trường | Vinh | `docs/NASA_SUBMISSION_FORM.md` | Đạt – Thiếu | Điền thêm công cụ AI khác (nếu có) |
| K6 | Repo và link công khai | — | Vinh | GitHub, Google Drive | Chưa đạt | Mở công khai, kiểm tra link khi chưa đăng nhập |

# 8. Vấn đề gặp phải và cách giải quyết

| # | Vấn đề | Thuộc | Nguyên nhân | Cách giải quyết | Kết quả |
|---|---|---|---|---|---|
| V1 | App đọc hai lần một câu, tiếng chồng nhau | Giọng nói | Nhiều phần cùng gọi giọng đọc | Gom về một hàng đợi đọc; câu mới ngắt câu cũ | Đã sửa |
| V2 | Mic nghe lại chính lời app vừa đọc | Giọng nói | Loa dội vào mic | Bỏ câu trùng chữ với lời vừa đọc; bật khử vọng trên web | Đã sửa |
| V3 | Người dùng chưa nói xong đã bị cắt | Giọng nói | Ngưỡng im lặng VAD quá ngắn | Nới ngưỡng im lặng lên 650 ms, giữ thêm âm trước lúc nói | Đã sửa |
| V4 | Lời chào khởi động to và nhanh | Giọng nói | Âm lượng và tốc độ mặc định | Chỉnh lại lời chào lúc mở app | Đã sửa |
| V5 | Lệnh ngắn bị nhận thành câu lạ | Giọng nói | Whisper trên máy chủ "bịa" câu khi đoạn âm quá ngắn | Gửi kèm gợi ý từ vựng; lọc câu rác và câu dài bất thường; quay về kết quả offline | Chờ kiểm thử |
| V6 | Bản tiếng Anh phải tải model lúc đầu | Giọng nói | Model Parakeet không có sẵn | Đóng gói model vào app | Chờ kiểm thử |
| V7 | Safari/iPad không có tiếng | Web | Safari chỉ cho phát giọng đọc sau một lần chạm | Mở khoá ở lần chạm đầu; chuyển sang giọng máy chủ nếu trình duyệt im | Chờ kiểm thử |
| V8 | Chạm vào Mexico lại nghe "Thái Bình Dương" | Quả địa cầu | Quả địa cầu tự quay trong lúc chờ phân biệt chạm một/hai lần; nhãn tên nằm trên biển | Lưu góc nhìn lúc chạm; chạm gần nhãn (≤ 28 px) thì chọn nước đó | Chờ kiểm thử |
| V9 | Âm thanh chồng nhau khi thao tác liên tục | Âm thanh | Âm cũ chưa dừng khi kéo hoặc ra lệnh mới | Dừng âm khi kéo quả địa cầu; chống trộn lệnh khi bấm nhanh | Đã sửa |
| V10 | Người dùng cần cách điều khiển nhanh hơn giọng nói | Trợ năng | Góp ý từ người thử | Thêm vuốt hai ngón và giữ để nói | Chờ kiểm thử |
| V11 | Lệnh gõ hoặc chip bị bỏ qua; thẻ thời tiết sai nơi | Giao diện | Lỗi xử lý lệnh trong màn quả địa cầu | Sửa luồng lệnh gõ và vị trí thẻ | Đã sửa |
| V12 | Chú thích đè lên chip, giao diện vỡ trên màn nhỏ | Giao diện | Bố cục cố định | Sửa bố cục co giãn | Đạt – Thiếu: còn lỗi người thử báo, cần ảnh |
| V13 | Build Android không chạy | Build | JAVA_HOME sai, Gradle cũ | Nâng Gradle 9.5.1, AGP 9.1.1; chỉ JAVA_HOME tới JDK có sẵn | Đã sửa |
| V14 | CI báo lỗi kiểm thử | Build | Test gọi mạng trên CI; khác phiên bản Flutter; test hành tinh tiếng Anh sai câu so sánh | Ghim Flutter 3.44.8 + JDK 21; bỏ test gọi mạng trên CI; sửa câu so sánh | Đã sửa |
| V15 | Bản web Vercel thiếu dữ liệu | Build | Thư mục `app/lib/data` không được đưa lên git | Đưa thư mục vào git | Đã sửa |
| V16 | Build lỗi vì `AppState.kid` không tồn tại | Build | Gọi thuộc tính đã bỏ | Xoá lời gọi | Đã sửa |
| V17 | AI trả lỗi 500 | AI | Cấu hình "thinking" của Gemini | Tự tắt cấu hình đó, chờ lâu hơn trước khi thử lại, chuyển sang model dự phòng | Đã sửa |
| V18 | Chuỗi dài hạn NASA POWER ở Việt Nam có bước nhảy | Dữ liệu | Hà Nội: −0,97 °C theo POWER so với +1,02 °C theo ERA5 | Xu hướng dài hạn dùng ERA5, app đọc tên nguồn | Đã xử lý |
| V19 | Dữ liệu quá lớn để chạy offline | Dữ liệu | 300 tháng × 2.849 ô | Nén `uint8`, kiểm chứng sai số bằng `validate.py` | Đã xử lý |
| V20 | Tài liệu có số liệu không có nguồn | Hồ sơ | "1,2 triệu người", "WCAG AAA" | Thay bằng số RAAB và "tương phản ≈ 13,8:1" | Đã sửa |
| V21 | Rê tay và chữ Z có thể không nhận khi bật TalkBack | Trợ năng | Trình đọc màn hình giữ cử chỉ chạm | Cần thử để chọn cách xử lý | Chưa giải quyết |

# 9. Tóm tắt đánh giá

| Phần | Đạt – Đủ | Đạt – Thiếu | Chờ kiểm thử | Chưa đạt |
|---|---|---|---|---|
| Nền tảng chung | 5 | 0 | 2 | 0 |
| F1 · Nghe khí hậu | 9 | 1 | 0 | 0 |
| F2 · Khám phá vũ trụ | 7 | 0 | 0 | 0 |
| F3 · Chạm vào địa hình | 4 | 2 | 0 | 0 |
| Earth Jukebox | 4 | 1 | 0 | 0 |
| Giọng nói và AI | 4 | 0 | 3 | 0 |
| Kiểm thử và hồ sơ | 1 | 3 | 0 | 2 |

**Việc cần làm tiếp:** chạy `flutter analyze` và `flutter test` cho các mục "Chờ kiểm thử"; thử với người khiếm thị (K1); thử TalkBack (V21); điền ô "Results" ở slide 6; mở công khai repo và link.
