// Chọn kết quả nhận giọng: bỏ câu cloud (Whisper) "bịa" khi gặp lệnh ngắn / im lặng → dùng bộ nghe offline.
import 'package:flutter_test/flutter_test.dart';
import 'package:earthsense/speech/nvidia_asr.dart';

void main() {
  test('câu bịa quen thuộc của Whisper bị loại', () {
    expect(cloudSuspicious('Hãy subscribe cho kênh Ghiền Mì Gõ để không bỏ lỡ', 'thời tiết huế', 1.5), isNotNull);
    expect(cloudSuspicious('Cảm ơn các bạn đã theo dõi', '', 0.8), isNotNull);
    expect(cloudSuspicious('Thank you for watching!', 'weather in hue', 1.2), isNotNull);
  });
  test('quá nhiều chữ so với thời lượng tiếng', () {
    expect(cloudSuspicious('một hai ba bốn năm sáu bảy tám chín mười', '', 0.5), isNotNull);
  });
  test('dài hơn hẳn kết quả offline', () {
    expect(cloudSuspicious('nghe sét ở miền bắc việt nam vào mùa hè năm nay nhé bạn ơi', 'nghe sét', 4.0), isNotNull);
  });
  test('câu lệnh bình thường được giữ', () {
    expect(cloudSuspicious('Thời tiết Hà Nội', 'thời tiết hà nội', 1.4), isNull);
    expect(cloudSuspicious('Chiều nay có mưa không?', 'chiều nay có mưa không', 1.8), isNull);
    expect(cloudSuspicious('rê tay khám phá Đà Lạt', 'rê tay khám phá đà lạt', 2.0), isNull);
    expect(cloudSuspicious('listen to lightning', '', 1.0), isNull);
  });
}
