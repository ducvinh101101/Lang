# Lắng · bản Flutter

Tên file chạy trên Windows: `Lang.exe`.

Bản Flutter (Android/iOS) của `web/index.html`. Dùng chung lưới 0,1°, 6 vùng và định dạng dữ liệu với pipeline Python,
nên khi F1 xong dữ liệu NASA thật, chỉ cần chép output vào `assets/data/` rồi bật một công tắc trong Cài đặt.

## Chạy lần đầu

```bash
cd app
flutter create --org vn.earthsense --project-name danbau_trai_dat --platforms android,ios .
flutter pub get
flutter test          # test logic: so khớp số với bản web
flutter run
```

`flutter create .` chỉ sinh thư mục `android/`, `ios/` còn thiếu, không ghi đè `lib/` hay `test/`.

**Chưa có điện thoại/giả lập?** Chạy thử trên Windows:

```bash
flutter create --platforms windows .
flutter run -d windows
```

Cần Visual Studio 2022 với workload "Desktop development with C++" (`flutter doctor` sẽ báo nếu thiếu). Giọng đọc tiếng Việt trên
Windows: Cài đặt → Thời gian và ngôn ngữ → Giọng nói → thêm giọng tiếng Việt (Microsoft An). Không có giọng thì app hiện phụ đề.
Hoặc cắm điện thoại Android (bật Gỡ lỗi USB), hay tạo máy ảo trong Android Studio → Device Manager.

**Android 11 trở lên** cần cho phép app tìm dịch vụ đọc chữ. Thêm vào `android/app/src/main/AndroidManifest.xml`,
ngay trong thẻ `<manifest>`:

```xml
<queries>
  <intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>
</queries>
```

Máy cần có giọng tiếng Việt (Cài đặt → Chuyển văn bản thành giọng nói → Google → Cài đặt dữ liệu giọng nói → Tiếng Việt).
Nếu máy không có giọng tiếng Việt, app vẫn hiện phụ đề.

## Thiết kế chuyên biệt cho người khiếm thị

App được thiết kế **100% bằng âm thanh và tương tác chạm** cho người khiếm thị và nhìn kém:
- **Quả địa cầu biết nói & nghe lệnh**: Tương tác hoàn toàn bằng giọng nói và chạm ngón tay. Rê tay trên quả cầu để nghe nhạc cụ dân tộc tương ứng theo thời tiết, độ cao và ranh giới địa lý.
- **Lắng nghe liên tục (Hands-free)**: Nói lệnh bất cứ lúc nào (ví dụ: *"thời tiết Hà Nội"*, *"quanh đây có gì"*, *"nơi mưa nhiều nhất"*, *"kể về Sao Hỏa"*...).
- **Cắt lời thông minh (Barge-in)**: Có thể nói *"dừng lại"*, *"thôi"*, *"im lặng"* bất cứ lúc nào ngay cả khi app đang nói.
- **Trợ lý AI thời tiết**: Tự động trả lời câu hỏi tự do, đưa ra lời khuyên đi lại an toàn (đường trơn, dông sét, nắng nóng, chỉ số UV, ô nhiễm không khí).
- **Hỗ trợ đầy đủ phím tắt & TalkBack/VoiceOver**: Có thể dùng bàn phím máy tính hoặc cử chỉ trình đọc màn hình để duyệt thuận tiện.

## Cấu trúc

```
lib/
  main.dart                 Khung app chính (MaterialApp, theme tối sơn mài cho người khiếm thị)
  app_state.dart            Trạng thái toàn app + quản lý dịch vụ (ChangeNotifier)
  core/geo.dart             Lưới 100×153, đường viền, 6 vùng, địa danh
  data/climate_data.dart    Interface ClimateData: values / clim / sd / series
  data/asset_data.dart      Nguồn NASA: đọc touchgrid.json, frames/*.bin, series.json
  audio/synth.dart          Tổng hợp đàn bầu, T'rưng, mõ, trống, chiêng, lửa, sóng → WAV
  audio/audio_engine.dart   Ánh xạ dữ liệu → âm (ngũ cung, mật độ nốt, pan đông–tây)
  speech/speaker.dart       TTS, giọng Piper offline tiếng Việt đóng gói, nhường TalkBack/VoiceOver
  speech/voice_listener_io.dart Nhận diện giọng nói tiếng Việt offline (Sherpa-onnx + Silero VAD)
  live/weather_talk.dart    Hỏi đáp thời tiết bằng câu ngắn, trực quan, lời khuyên đi lại
  live/gemini_assistant.dart Trợ lý Gemini AI hỗ trợ câu hỏi tự nhiên bằng giọng nói
  features/globe/           Quả địa cầu 3D tương tác chạm và âm thanh
  features/settings/        Cài đặt ngôn ngữ, tốc độ đọc, giọng đọc, âm lượng
```

## Giọng đọc

- **Bản web** dùng giọng của trình duyệt: Edge có *Microsoft HoaiMy/NamMinh Online (Natural)*, Chrome có *Google Tiếng Việt* —
  giọng trực tuyến, chỉ có trong trình duyệt.
- **App trên Windows** dùng giọng cài trong Windows, qua một bộ đọc riêng chạy ngoài app (PowerShell + Windows.Media.SpeechSynthesis):
  chọn giọng theo tên, ưu tiên tiếng Việt, dừng được ngay, lỗi không kéo app chết theo (thay plugin flutter_tts trên Windows).
- **Máy chưa có giọng tiếng Việt** (chỉ có David/Zira/Mark) thì tiếng Việt bị đọc bằng giọng Anh. App báo và chỉ cách cài:
  Cài đặt → Thời gian và ngôn ngữ → Giọng nói (Speech) → Thêm giọng (Add voices) → **Tiếng Việt** (giọng *Microsoft An*),
  rồi trong app bấm **Kiểm tra lại** (Cài đặt, hoặc Menu ở chế độ khiếm thị). Máy dùng thử cần cài trước buổi thử.
- Giống bản web: tên vùng khi rê tay đọc nhanh hơn 12%; số liệu chờ câu đang đọc xong mới đọc, không cắt ngang.
- Cài đặt có ô **Giọng đọc** để chọn giọng (chọn là đọc thử).

## Hoàng Sa và Trường Sa

Bản đồ vẽ quần đảo **Hoàng Sa** (các chấm đảo phía đông Đà Nẵng) và **Trường Sa** (khung thu nhỏ góc dưới bên phải, vì phần lớn
quần đảo nằm ngoài khung lưới 102–112°Đ), ghi rõ "(Việt Nam)" như bản web. Rê tay vào: tiếng chiêng nhỏ + đọc
"Quần đảo Hoàng Sa, Việt Nam"; chạm đúp đọc thêm thuộc Đà Nẵng / Khánh Hòa. Lệnh nói: "Hoàng Sa", "Trường Sa".

## Chống văng (chế độ an toàn)

App ghi dấu vết trước mỗi lệnh gọi vào thư viện gốc (giọng đọc, âm thanh). Nếu app bị tắt đột ngột NGAY trong lệnh đó,
lần mở sau app **tự tắt phần gây lỗi** và báo cho người dùng:
- lỗi ở giọng đọc → dùng **giọng dự phòng chạy ngoài app** (PowerShell + System.Speech trên Windows) — có lỗi cũng không kéo app chết theo;
- lỗi ở nhạc cụ → tạm tắt nhạc cụ, giọng đọc vẫn chạy.

Bật lại trong Cài đặt → Khắc phục sự cố (hoặc Menu ở chế độ khiếm thị). Nhật ký lỗi: đường dẫn hiện trong Cài đặt
(thường là `%TEMP%\danbau_trai_dat\nhat-ky-loi.txt`) — gửi file này cho nhóm khi báo lỗi.
Chạy thử để khoanh vùng: `--dart-define=NO_TTS=true`, `--dart-define=NO_AUDIO=true`.

## Đã có / chưa có so với bản web

| Phần | Flutter |
|---|---|
| Chạm–nghe: đàn bầu liên tục, T'rưng, lửa + trống, mõ qua vùng, sóng ở biển, đọc tên vùng, đọc số khi dừng | Có |
| Điều khiển khi bật TalkBack/VoiceOver (nút mũi tên, thao tác tuỳ chỉnh), phím mũi tên | Có (web không có) |
| Dòng thời gian, danh sách tháng bất thường | Có |
| Hướng dẫn âm thanh | Có (bản gọn) |
| VI/EN, cài đặt lưu lại | Có |
| Bản tin sáng, Thí nghiệm thanh điệu, Tour 60 giây | Chưa: khung trống, ghi chú việc cần làm |
| Lệnh giọng nói, trợ lý AI | Chưa: web dùng `window.claude`, sang app cần backend riêng |
| Gợn sóng hình ảnh, chế độ tương phản cao, chữ lớn | Chưa |

## Giới hạn cần biết

- **TalkBack/VoiceOver giữ cử chỉ chạm**, nên "rê ngón tay để nghe" chỉ chạy khi tắt trình đọc màn hình. Khi bật thì dùng
  nút mũi tên hoặc thao tác tuỳ chỉnh. Cần thử với người dùng khiếm thị thật để chọn cách tốt nhất.
- Âm phát một lần được hẹn giờ bằng Timer của Dart (lệch vài ms), không chính xác tới từng mẫu như Web Audio.
  Với Chạm–nghe và Dòng thời gian thì đủ dùng.
- Bản này được viết khi chưa có Flutter SDK để biên dịch: đã kiểm tra cú pháp, chưa chạy `flutter analyze`.
  Nếu API của `flutter_soloud` lệch phiên bản, chỉ sửa `lib/audio/soloud_backend.dart`.
