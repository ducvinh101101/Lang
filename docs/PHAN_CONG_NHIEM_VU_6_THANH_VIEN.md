# LẮNG · PHÂN CÔNG 6 THÀNH VIÊN & CẨM NANG THI ĐẤU

> **NASA Space Apps Challenge 2026** — Thử thách **#14: *The Earth Information Jukebox*** · Đội **Lắng**
> **Dự án:** Lắng — quả địa cầu biết nói cho người khiếm thị, âm thanh hóa dữ liệu NASA bằng nhạc cụ dân tộc
> **Bản web:** <https://sense-app-two.vercel.app> · Cập nhật: 12/11/2026 (khớp với mã nguồn hiện tại)
> **Việc đầu tiên:** điền **họ tên thật** của 6 thành viên vào bảng mục 1. Slide nộp cho Space Apps bắt buộc có tên thành viên.

---

## 0. Ba nguyên tắc khi nói trước giám khảo

1. **Chỉ nói con số có trong mục 6 ("Số liệu được phép nói").** Mọi con số trong đó đã đối chiếu với dữ liệu và mã nguồn.
2. **Chưa thử với người dùng thật thì nói là chưa thử.** Đội chưa có kết quả thử nghiệm với người khiếm thị. Không nói "92% nhận diện", "100% người thử nghiệm…" hay "đã thử nghiệm trực tiếp" cho đến khi có phiếu khảo sát thật (mục 3, việc V1).
3. **Nói "giảm", "hạn chế", không nói "triệt tiêu 100%", "tuyệt đối".** Giám khảo chấm tiêu chí *Validity* (tính khả thi, có cơ sở). Một câu nói quá dễ làm mất điểm cả phần.

---

## 1. Bảng phân công

| # | Họ tên *(điền)* | Vai trò | Phụ trách | Mã nguồn chính |
|:-:|---|---|---|---|
| 1 | ……… *(Trưởng nhóm)* | Kiến trúc & Trợ năng | Khung app Flutter (web, Android, Windows), lối thoát giọng nói và chữ Z, CrashGuard, nộp bài | `main.dart`, `app_state.dart`, `core/z_gesture.dart`, `core/crash_guard.dart`, `features/help/` |
| 2 | ……… | Dữ liệu NASA & Pipeline | Pipeline Python, chuẩn hóa và kiểm chứng dữ liệu, ghi công nguồn | `pipeline/`, `assets/data/*.json`, `credits.csv`, `docs/DATA_SOURCES.md` |
| 3 | ……… | F1 Thời tiết, khí hậu & âm thanh | Thời tiết thật, phát lại lịch sử thời tiết và thiên tai, GISTEMP, nhạc cụ | `audio/`, `features/history/`, `live/live_weather.dart`, `live/weather_talk.dart`, `live/hazard_history.dart` |
| 4 | ……… | F3 Địa lý & bản đồ chạm | Rê tay khám phá, quét mặt cắt, quanh đây có gì | `features/globe/local_map.dart`, `live/terrain_*.dart`, `live/vector_tiles.dart`, `live/geo_around.dart`, `features/terrain_scan/` |
| 5 | ……… | F2 Vũ trụ & trò chơi | Hệ Mặt Trời, 10 thiên thể, âm thanh NASA, APOD, 4 trò chơi | `features/space/`, `live/apod.dart`, `live/nasa_sounds.dart` |
| 6 | ……… | Giọng nói & AI | Nghe/nói (app và web), hiểu câu tiếng Việt, trợ lý AI + RAG | `speech/`, `features/globe/world_commands.dart`, `live/gemini_assistant.dart`, `live/earth_rag.dart` |

---

## 2. Từng thành viên: đã làm gì, nói gì, trả lời gì

### Thành viên 1 — Kiến trúc & Trợ năng *(mở đầu và kết thúc phần trình bày)*

**Đã có trong app:**
- Một mã nguồn Flutter chạy web (Vercel), Android, Windows. Hai bản chỉ khác ở phần nghe/nói.
- Dùng hoàn toàn bằng giọng nói: app tự bật mic, nghe liên tục; nói "dừng lại" để ngắt lời app bất cứ lúc nào.
- **Luôn có đường thoát:** "quay lại", "thoát", "về màn hình chính" ở mọi màn; **vẽ chữ Z** (một ngón, dưới 1 giây) để về màn hình chính của nhánh đang dùng.
- **CrashGuard:** nếu lần trước app văng trong lúc gọi thư viện giọng đọc hoặc âm thanh, lần mở sau app tự tắt phần đó (chế độ an toàn), báo bằng lời và ghi nhật ký lỗi.
- Màu vàng `#FFD54F` trên nền `#0A0D14`: độ tương phản ≈ 13,8:1, vượt ngưỡng AAA (7:1) của WCAG cho chữ. *Đây là tương phản màu, không phải chứng nhận WCAG AAA toàn app.*

**Kịch bản (45–60 giây):**
> "Biểu đồ khí hậu và ảnh vệ tinh của NASA là dữ liệu để nhìn. Người khiếm thị gần như không dùng được. Lắng chuyển dữ liệu đó sang tai và tay: giọng đọc tiếng Việt, nhạc cụ dân tộc, và bản đồ để rê ngón tay. Toàn bộ app điều khiển bằng giọng nói, không cần nhìn, không cần bấm. Ở bất kỳ đâu, nói 'về màn hình chính' hoặc vẽ chữ Z là về chỗ quen thuộc, nên người dùng không bao giờ bị kẹt."

**Hỏi – đáp:**
- *Làm sao người khiếm thị không bị lạc trong app?* → Mỗi lệnh có tiếng "ding" báo đã nhận. Mỗi màn có câu giới thiệu ngắn nói được làm gì. Lối thoát giống nhau ở mọi màn (giọng nói hoặc chữ Z).
- *Đã thử với người khiếm thị chưa?* → **Nói thật:** chưa có đợt thử chính thức. Đội đã chuẩn bị phiếu khảo sát và kế hoạch thử (mục 3). Rủi ro đã biết: khi bật TalkBack/VoiceOver, trình đọc màn hình giữ cử chỉ chạm nên rê tay và chữ Z có thể không nhận; cần thử để chọn cách xử lý.

### Thành viên 2 — Dữ liệu NASA & Pipeline

**Đã có:**
- Pipeline Python tải, chuẩn hóa và kiểm chứng dữ liệu (`python -m pipeline.update`). Mỗi file JSON có khối `data_card` (nguồn, ngày lấy, độ phân giải, đơn vị, giấy phép, giới hạn); ghi công trong `credits.csv`.
- Lưới 0,1° cho Việt Nam: 2.849 ô đất liền, nhiệt độ và mưa 300 tháng (2001–2025), lượng tử hóa `uint8`. File lưới `touchgrid.json` khoảng 280 KB; cả phần khung hình theo tháng (`frames/`) thêm khoảng 1,7 MB.
- `validate.py` so từng ô với dữ liệu gốc: sai số lớn nhất **0,058 °C** (nhiệt, tháng 10/2005) và **1,485 mm/tháng** (mưa, tháng 4/2013).

**Kịch bản:**
> "Thách thức là đưa dữ liệu vệ tinh rất lớn vào một app chạy được cả khi mất mạng. Em cắt lưới 0,1 độ cho Việt Nam, nén 300 tháng nhiệt độ và lượng mưa NASA POWER xuống khoảng 2 MB. Script kiểm chứng so từng ô với dữ liệu gốc: sai số lớn nhất 0,058 độ C với nhiệt độ. Mỗi file đều ghi rõ nguồn, ngày lấy và giới hạn."

**Hỏi – đáp:**
- *Lượng tử hóa có làm sai số liệu không?* → Có sai số nhỏ và đã đo: tối đa 0,058 °C và 1,485 mm/tháng. Nhỏ hơn nhiều so với sai số vốn có của dữ liệu tái phân tích MERRA-2 (ô lưới khoảng 50 km). *Không nói "nằm trong ngưỡng của Tổ chức Khí tượng Thế giới"* vì đội chưa có nguồn cho câu đó.
- *NASA ra dữ liệu mới thì sao?* → Chạy `python -m pipeline.update`: tải lại, chuẩn hóa, kiểm chứng, xuất sang app.

### Thành viên 3 — F1 Thời tiết, khí hậu & âm thanh

**Đã có:**
- Thời tiết thật (Open-Meteo, không cần khoá): bây giờ, 48 giờ, 10 ngày, bụi mịn, kèm lời khuyên đi lại. Máy chủ bận thì app tự thử lại một lần.
- **Âm thanh hóa:** đàn bầu (nhiệt độ, càng nóng càng cao, thang ngũ cung), đàn t'rưng (mưa càng nhiều nốt càng dày, mưa rất to có sấm), tiếng lửa khô (điểm cháy FIRMS), trống, gió rít, rung khi bão.
- **Phát lại lịch sử** thời tiết và thiên tai theo tháng hoặc năm cho 34 tỉnh (NASA POWER 1981–2025) và 282 sự kiện thiên tai (NASA SEDAC GDIS). App nói rõ số liệu NASA mới có đến năm nào.
- **Tái hiện 15 ngày:** bão Yagi (9/2024, miền Bắc) và mưa lũ Huế (10/2020).
- **146 năm GISTEMP:** năm nóng nhất 2024, +1,28 °C so với kỳ chuẩn 1951–1980.
- Đếm ngày nắng nóng 3 ngưỡng 35/37/39 °C cho 4 nơi, so 1981–1990 với 2016–2025.

**Kịch bản:**
> "Em biến số liệu khí hậu thành tiếng nhạc cụ Việt. Nhiệt độ là đàn bầu: càng nóng tiếng càng cao. Mưa là đàn t'rưng: mưa càng to nốt càng dày. Nói 'bão Yagi', app phát lại 15 ngày của cơn bão theo số liệu NASA POWER, ngày nào mưa lớn nghe là biết. Nói 'Trái Đất nóng lên bao nhiêu', đàn bầu lướt qua 146 năm GISTEMP."

**Hỏi – đáp:**
- *Vì sao dùng nhạc cụ dân tộc?* → Gần gũi với người nghe Việt Nam. Đàn bầu uốn cao độ liên tục nên hợp với số liệu biến đổi liên tục như nhiệt độ. Mỗi loại số liệu một nhạc cụ nên không lẫn.
- *Làm sao phân biệt mưa thường và bão?* → Mưa tăng thì nốt t'rưng dày dần; mưa rất to thêm sấm; bão thêm gió rít, trống và rung. Giọng đọc luôn nói kèm con số.
- *Dữ liệu có chi tiết tới quận/huyện không?* → Không. NASA POWER có ô lưới khoảng 50 km, app nói rõ giới hạn này.

### Thành viên 4 — F3 Địa lý & bản đồ chạm

**Đã có:**
- **Rê tay khám phá:** bản đồ địa hình thật khoảng 2,4 × 2,4 km quanh nơi được hỏi (hoặc vị trí GPS), phía bắc ở trên.
  - Độ cao: ô Terrarium (AWS Open Data, dựng từ NASA SRTM), khoảng 18 m mỗi điểm.
  - Lớp phủ đất: NASA GIBS – MODIS MCD12Q1 (IGBP), khoảng 500 m.
  - Sông, suối, hồ, rừng, đường có tên: OpenStreetMap qua ô vector (OpenFreeMap). Kiểm chứng được: Suối Cam Ly, Hồ Xuân Hương, Đồi Cù ở Đà Lạt; Hồ Hoàn Kiếm, sông Hồng ở Hà Nội.
- **Rê ngón tay:** tiếng sáo cao thấp theo độ cao; rung mạnh dần theo độ dốc (bản web chỉ rung được trên điện thoại Android; trình duyệt iPhone và máy tính không hỗ trợ rung); sóng ở mặt nước; lá xào xạc ở rừng; tiếng xe ở khu dân cư. Sang chỗ mới thì đọc tên, độ cao, độ dốc.
- **Quét mặt cắt:** vùng khoảng 100 km quanh nơi được hỏi (ví dụ Đà Lạt ≈ 107 km mỗi chiều), quét Bắc → Nam rồi Tây → Đông, mỗi lượt ≤ 8 giây.
- Hoàng Sa, Trường Sa: tiếng **chiêng** và câu đọc "(Việt Nam)".

**Kịch bản:**
> "Em biến màn hình phẳng thành bản đồ để sờ. Nói 'rê tay khám phá Đà Lạt', app mở bản đồ địa hình thật. Ngón tay đi lên đồi thì tiếng sáo cao dần, máy rung theo độ dốc. Chạm vào Hồ Xuân Hương nghe tiếng sóng và tên hồ, chạm vào rừng nghe lá xào xạc. Độ cao lấy từ dữ liệu SRTM của NASA, lớp phủ đất từ MODIS, tên sông suối từ OpenStreetMap."

**Hỏi – đáp:**
- *Màn hình phẳng, sao biết tay đang ở đâu?* → Sang chỗ mới app đọc tên, độ cao, độ dốc; âm lệch trái/phải theo hướng đông/tây; rung theo độ dốc.
- *Có giật không?* → Ảnh địa hình dựng một lần khi mở. Rê tay chỉ tra bảng độ cao đã có sẵn trong bộ nhớ nên không cần tải thêm. *(Không nói "dưới 16 ms, 60 khung hình/giây" vì chưa đo.)*
- *Mất mạng thì sao?* → Dùng lưới độ cao thô có sẵn trong app (khoảng 1 km). Vẫn rê tay được nhưng ít chi tiết, không có tên sông, đường.

### Thành viên 5 — F2 Vũ trụ & trò chơi

**Đã có:**
- Màn Hệ Mặt Trời (vẽ 2D): Mặt Trời và 8 hành tinh trên quỹ đạo, mỗi thiên thể một âm riêng.
- Thông số 10 thiên thể (NASA NSSDCA, hệ mét); số mặt trăng ghi "theo NASA, tính đến năm 2026".
- **135 sự thật thú vị** (NASA Space Place); **35 hỏi–đáp** có nguồn, trong đó 12 câu đính chính hiểu lầm (Trái Đất phẳng, vì sao có mùa…).
- **10 bản ghi âm thật của NASA:** Sputnik, Apollo 11, Apollo 13, sóng radio Sao Thổ, Enceladus, sét Sao Mộc, plasma liên sao, Juno, Kepler, Stardust.
- Ảnh thiên văn hôm nay (NASA APOD): app đọc lời giải thích.
- **4 trò chơi bằng giọng nói:** Đố vui, "Tôi là ai", Nghe tiếng đoán hành tinh, Đố âm thanh NASA. Có "gợi ý", "nhắc lại", "bỏ qua", "dừng"; kỷ lục lưu trên máy.

**Kịch bản:**
> "Em mở cánh cửa vũ trụ bằng âm thanh. Nói 'kể về Sao Hỏa', app đọc thông số NASA và một sự thật thú vị: năm 2021 trực thăng Ingenuity bay trên Sao Hỏa. Nói 'âm thanh thật của NASA' để nghe bản ghi Apollo 11. Bốn trò chơi đều chơi bằng giọng nói, sai thì có gợi ý, không bị phạt."

**Hỏi – đáp:**
- *Mô tả ảnh vũ trụ theo chuẩn nào?* → Theo hướng dẫn mô tả ảnh của Section 508: câu ngắn, so với vật quen thuộc, và luôn nói rõ đó là âm **thu thật** hay âm **chuyển từ dữ liệu**.
- *Câu đố lấy từ đâu?* → Từ NASA Space Place và NSSDCA, có ghi nguồn trong file dữ liệu.

### Thành viên 6 — Giọng nói & AI

**Đã có:**
- **App:** nghe offline bằng sherpa-onnx (Zipformer tiếng Việt) và Silero VAD (biết lúc người dùng ngừng nói); đọc offline bằng Piper `vi_VN-vais1000`.
- **Web:** nghe bằng Web Speech API của trình duyệt; đọc bằng giọng Việt của trình duyệt, không có thì dùng Piper trên máy chủ (`/api/tts`).
- **Hiểu tiếng Việt tự nhiên:** câu ngập ngừng, câu sửa ("không phải Huế mà là Đà Nẵng"), câu hỏi tiếp ("còn Đà Nẵng thì sao"), tên xã/phường cũ và mới (34 tỉnh sau sáp nhập). Kiểm thử tự động với hơn 3.300 câu lệnh mẫu.
- **Chống loa dội vào mic:** câu nghe được mà trùng lời app vừa đọc thì bỏ qua (so khớp chữ), cộng thêm khử vọng của trình duyệt trên web.
- **Trợ lý AI** Gemma 4 26B, chỉ dùng khi dữ liệu có sẵn không trả lời được. Trước khi hỏi, app đưa số liệu thật liên quan vào câu hỏi (RAG). Lỗi thì thử lại, rồi chuyển sang model dự phòng Gemini Flash-Lite. Khoá API nằm trên máy chủ Vercel, trình duyệt không thấy.

**Kịch bản:**
> "Em phụ trách tai và giọng của Lắng. Bản app nghe và nói hoàn toàn offline. App hiểu cách nói tự nhiên của người Việt, kể cả khi nói nhầm rồi sửa. Câu nào không có sẵn đáp án thì mới hỏi AI, và trước khi hỏi, app gửi kèm số liệu NASA thật để AI diễn đạt lại thay vì tự bịa."

**Hỏi – đáp:**
- *Làm sao chắc AI không bịa số?* → Không thể bảo đảm 100% với mô hình ngôn ngữ. Đội giảm rủi ro bằng 3 lớp: (1) câu hỏi có đáp án trong dữ liệu thì trả lời thẳng từ file, không qua AI; (2) khi gọi AI, gửi kèm số liệu thật và yêu cầu chỉ dùng số liệu đó; (3) không có dữ liệu thì yêu cầu AI nói là chưa có.
- *Loa đang đọc, sao mic nghe được "dừng lại"?* → Lệnh dừng được nhận cả khi app đang nói. Phần nghe lại lời của chính app thì bị lọc vì trùng chữ với câu vừa đọc.

---

## 3. Việc còn lại trước khi nộp bài

| # | Việc | Người làm | Ưu tiên | Kết quả cần có |
|:-:|---|:-:|:-:|---|
| V1 | **Thử với 3–5 người khiếm thị** (hoặc người bịt mắt, nếu chưa liên hệ được). Dùng `Khảo sát.docx` và sheet "Đánh giá chức năng" | TV1 + TV4 | Cao | Phiếu đã điền, ghi âm/ghi chú, 3 kết quả chính để đưa vào slide |
| V2 | Điền họ tên thật 6 thành viên vào slide và tài liệu này | TV1 | Cao | Slide 1 và slide 7 bản tiếng Anh có tên |
| V3 | Chốt **deck tiếng Anh ≤ 7 slide** (`Lang_SpaceApps_2026_Submission_EN.pptx`, bản PDF `Lang_SpaceApps_2026_Submission_EN.pdf`) và đặt ở link công khai | TV1 | Cao | Link mở được khi chưa đăng nhập |
| V4 | Quay **video demo ≤ 30 giây**, phụ đề tiếng Anh, quay màn hình thật (không dùng ảnh AI) | TV5 | Cao | File mp4 + link công khai |
| V5 | Ghi rõ **khai báo dùng AI** (Gemma/Gemini trong app, trợ lý lập trình AI khi phát triển) và **danh sách nguồn** trên trang nộp bài | TV2 | Cao | Mục "Use of AI" và "References" trên trang dự án |
| V6 | Push mã mới nhất lên GitHub, kiểm tra Vercel build xong, thử lại 5 câu lệnh demo trên web | TV6 | Cao | Web chạy đúng bản mới |
| V7 | Tập demo theo mục 4, mỗi người nói đúng thời lượng | Cả đội | Trung bình | 2 lần tập trọn vẹn |
| V8 | Thử rê tay và chữ Z khi bật TalkBack trên Android | TV4 | Trung bình | Ghi kết quả, quyết định cách xử lý |

> **Quy định Space Apps (bản Global):** demo là deck tối đa 7 slide (tính cả slide tiêu đề, bằng tiếng Anh) **hoặc** video tối đa 30 giây có phụ đề tiếng Anh, đặt ở link công khai. Slide phải có tên đội, tên thành viên, thử thách, một hình ảnh dự án, trải nghiệm người dùng và dữ liệu cơ quan vũ trụ đã dùng. Ảnh/video do AI tạo phải có dấu "AI-generated" nhìn thấy được. Nguồn: <https://www.spaceappschallenge.org/resources/project-submission-guide/>
> **Tiêu chí chấm (5 tiêu chí của NASA, mỗi tiêu chí 1–10 điểm):** Impact (tác động), Creativity (sáng tạo), Validity (khả thi, có cơ sở), Relevance (đúng thử thách), Presentation (trình bày). Nguồn: <https://www.spaceappschallenge.org/resources/judging-awards-guide/>

---

## 4. Trình bày trước giám khảo (15 phút: trình bày ~7 phút + hỏi đáp)

BTC Hà Nội: mỗi đội 15 phút, gồm trình bày và hỏi đáp; nên trình bày **5–7 phút**. Có mặt tại phòng chấm (hoặc vào Zoom, Meeting ID 940 8456 9142) **trước giờ chấm 10 phút**.

| Thời gian | Phần | Người | Tài liệu |
|---|---|---|---|
| 0:00–4:30 | Thuyết trình 7 slide | Tuấn Minh, Minh Sơn, Minh Phúc, Xuân Phúc / Hoàng | `Kich_ban_phan_vai_Lang_rut_gon.docx` |
| 4:30–7:00 | Demo trực tiếp, **bản thi 2 phút 30** | Vinh thao tác, Tuấn Minh dẫn | `Kich_ban_demo_EN_5phut.docx` (A/B) hoặc `Kich_ban_demo_VI_1nguoi_5phut.docx` |
| 7:00–15:00 | Hỏi đáp | Theo phân công | `Lang_Hoi_dap_theo_phan_cong.docx` |

Bản thi 2 phút 30: **"weather in Hue"** → **"listen to lightning"** → **"month 5"** → vẽ chữ **Z** → **"how many moons does Saturn have"**. Cử chỉ mới (vuốt hai ngón, giữ để nói) chỉ dùng nếu đã thử ổn trên đúng máy demo.

**Chuẩn bị:** máy có mic tốt, loa ngoài; Chrome hoặc Edge; mạng ổn định. Mở sẵn web, cho phép mic, mở "nghe sét" một lần cho hình tải sẵn. Có máy dự phòng mở cùng màn hình.

---

## 5. Câu KHÔNG được nói (và câu thay thế)

| Không nói | Nói thay |
|---|---|
| "1,2 triệu người khiếm thị Việt Nam" (chưa có nguồn) | "Khảo sát RAAB 2015: khoảng 1,8% người Việt từ 50 tuổi trở lên bị mù" |
| "Chuẩn WCAG AAA" | "Độ tương phản màu ≈ 13,8:1, vượt ngưỡng AAA cho chữ" |
| "Triệt tiêu 100% ảo giác AI" | "Giảm rủi ro AI bịa số bằng dữ liệu thật đưa kèm câu hỏi" |
| "92% nhận diện", "100% người thử nghiệm…" | Kết quả thật từ việc V1, hoặc "đang thử nghiệm" |
| "TRL 6–7", "15/15 test" | "Bản chạy thật trên web; hơn 30 file kiểm thử, hơn 3.300 câu lệnh mẫu" |
| "Nén toàn bộ dữ liệu còn 280 KB" | "Lưới chạm 280 KB, cả 300 tháng khoảng 2 MB" |
| "Quét mặt cắt 8 km" | "Quét vùng khoảng 100 km, mỗi lượt dưới 8 giây" |
| "Tiếng chuông chùa ở Hoàng Sa" | "Tiếng chiêng ở Hoàng Sa, Trường Sa" |
| "Mô hình 3D Hệ Mặt Trời" | "Bản đồ Hệ Mặt Trời có âm thanh" |
| "Flash-Lite chạy khi mất mạng" | "Flash-Lite là model dự phòng khi Gemma lỗi; khi mất mạng thì app dùng dữ liệu có sẵn" |
| "Thiên tai từ EM-DAT/GDACS" | "282 sự kiện từ NASA SEDAC GDIS" |

---

## 6. Số liệu được phép nói (đã kiểm chứng)

| Mục | Số liệu | Nguồn trong dự án |
|---|---|---|
| Ấm lên toàn cầu | 146 năm (1880–2025); 2024 nóng nhất, +1,28 °C so với 1951–1980 | `gistemp_global.json` (NASA GISTEMP v4) |
| Khí hậu tỉnh | 34 tỉnh/thành, theo tháng 1981–2025 | `climate_34_provinces.json` (NASA POWER) |
| So sánh khí hậu | 29 địa điểm (14 trong nước, 15 thế giới), 1981–1990 so với 2016–2025 | `climate_history_nasa.json` |
| Thiên tai | 282 sự kiện: 107 bão, 59 lũ, 116 sạt lở | `vn_disasters_nasa.json` (NASA SEDAC GDIS) |
| Lưới chạm | 0,1°, 2.849 ô đất liền, 300 tháng (2001–2025) | `touchgrid.json`, `frames/` |
| Kiểm chứng | Sai số tối đa 0,058 °C (nhiệt) và 1,485 mm/tháng (mưa) | `pipeline/validate.py` |
| Vũ trụ | 10 thiên thể, 135 sự thật thú vị, 35 hỏi–đáp (12 câu đính chính) | `planets_nasa.json`, `qa_bank.json` |
| Âm thanh NASA | 10 bản ghi âm thật | `assets/sounds/nasa/` |
| Trò chơi | 4 trò, chơi bằng giọng nói | `features/space/planet_games.dart` |
| Rê tay | Khung ≈ 2,4 × 2,4 km; độ cao ≈ 18 m/điểm; lớp phủ ≈ 500 m | `local_map.dart`, `terrain_patch.dart` |
| Kiểm thử | Hơn 30 file kiểm thử, hơn 3.300 câu lệnh mẫu | `app/test/` |
| Tương phản | ≈ 13,8:1 (`#FFD54F` trên `#0A0D14`) | `ui/theme.dart` |
| Người khiếm thị VN | RAAB 2015: ≈ 1,8% người từ 50 tuổi trở lên bị mù | Khảo sát RAAB Việt Nam 2015 |
