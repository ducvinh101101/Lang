// BỘ CÂU HỎI THỜI TIẾT người khiếm thị hay hỏi — kiểm tra app hiểu đúng ý (loại câu hỏi, nơi, ngày, buổi, khía cạnh).
// Mỗi dòng: câu nói → kết quả mong đợi (chỉ so các trường có ghi). Gom hết lỗi rồi báo một lần,
// đồng thời ghi ra build/weather_cases_report.txt để xem nhanh.
import 'dart:io';

import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:flutter_test/flutter_test.dart';

class E {
  final WKind kind;
  final String? target; // so khớp không dấu, chứa trong target
  final String? aspect;
  final int? day;
  final String? period;
  final bool noTarget; // target phải rỗng
  final bool anyAspect;
  const E(this.kind, {this.target, this.aspect, this.day, this.period, this.noTarget = false, this.anyAspect = false});
}

String _n(String s) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final k = from.indexOf(ch);
    b.write(k >= 0 ? to[k] : ch);
  }
  return b.toString().trim();
}

/// Số ngày từ hôm nay tới thứ [wd] (1 = thứ hai … 7 = chủ nhật) sắp tới; hôm nay đúng thứ đó → 0.
int _until(int wd) => (wd - DateTime.now().weekday + 7) % 7;

const W = WKind.weather;

final viCases = <String, E>{
  // ---- bây giờ / tổng quát ----
  'thời tiết hôm nay thế nào': const E(W, day: 0, noTarget: true),
  'bây giờ trời thế nào': const E(W, noTarget: true),
  'ngoài trời đang thế nào': const E(W, noTarget: true),
  'hôm nay trời ra sao': const E(W, day: 0, noTarget: true),
  'thời tiết ở đây': const E(W, noTarget: true),
  'thời tiết chỗ tôi': const E(W, noTarget: true),
  'thời tiết ở nhà tôi': const E(W, noTarget: true),
  'thời tiết quanh đây': const E(W, noTarget: true),
  'thời tiết Hà Nội': const E(W, target: 'ha noi'),
  'Hà Nội bây giờ thế nào': const E(W, target: 'ha noi'),
  'Đà Nẵng hôm nay ra sao': const E(W, target: 'da nang', day: 0),
  'thời tiết thành phố Hồ Chí Minh': const E(W, target: 'ho chi minh'),
  'thời tiết sài gòn': const E(W, target: 'sai gon'),
  'cho tôi hỏi thời tiết Đà Nẵng với': const E(W, target: 'da nang'),
  'ơ thời tiết Huế thế nào nhỉ': const E(W, target: 'hue'),
  'bạn ơi hôm nay có mưa không': const E(W, aspect: 'rain', day: 0, noTarget: true),
  'Trái Đất ơi thời tiết Hà Nội': const E(W, target: 'ha noi'),
  'thoi tiet ha noi': const E(W, target: 'ha noi'),
  'thời tiết hà lội': const E(W, target: 'ha loi'),
  'thời tiết Paris': const E(W, target: 'paris'),
  'Tokyo có mưa không': const E(W, target: 'tokyo', aspect: 'rain'),
  'thời tiết Sa Pa': const E(W, target: 'sa pa'),
  'thời tiết Vịnh Hạ Long': const E(W, target: 'ha long'),
  'thời tiết xã Tân Lập': const E(W, target: 'xa tan lap'),
  'phường Bến Nghé có mưa không': const E(W, target: 'ben nghe', aspect: 'rain'),
  'thời tiết huyện Mù Cang Chải': const E(W, target: 'mu cang chai'),
  // ---- trời nắng / mây ----
  'trời có nắng không': const E(W, aspect: 'sky', noTarget: true),
  'hôm nay trời nhiều mây không': const E(W, aspect: 'sky', day: 0),
  'trời có âm u không': const E(W, aspect: 'sky'),
  'ngoài trời có nắng không': const E(W, aspect: 'sky'),
  'trời có đẹp không': const E(W, aspect: 'outing'),
  // ---- nhiệt độ ----
  'bây giờ bao nhiêu độ': const E(W, aspect: 'temp', noTarget: true),
  'Huế mấy độ': const E(W, aspect: 'temp', target: 'hue'),
  'nhiệt độ ngoài trời': const E(W, aspect: 'temp', noTarget: true),
  'hôm nay có nóng không': const E(W, aspect: 'temp', day: 0),
  'ngày mai Hà Nội có lạnh không': const E(W, aspect: 'temp', target: 'ha noi', day: 1),
  'tối nay có rét không': const E(W, aspect: 'temp', day: 0, period: 'toi'),
  'chiều nay bao nhiêu độ': const E(W, aspect: 'temp', period: 'chieu'),
  'nhiệt độ cao nhất hôm nay': const E(W, aspect: 'temp', day: 0),
  'đêm nay lạnh nhất bao nhiêu độ': const E(W, aspect: 'temp', period: 'dem'),
  'nhiệt độ ở Đà Lạt bây giờ': const E(W, aspect: 'temp', target: 'da lat'),
  'cảm giác ngoài trời nóng không': const E(W, aspect: 'temp'),
  'hôm nay nóng hơn hôm qua không': const E(W, aspect: 'temp', day: 0),
  // ---- mưa ----
  'có mưa không': const E(W, aspect: 'rain', noTarget: true),
  'hôm nay có mưa không': const E(W, aspect: 'rain', day: 0),
  'chiều nay có mưa không': const E(W, aspect: 'rain', period: 'chieu'),
  'tối nay ở Huế có mưa không': const E(W, aspect: 'rain', target: 'hue', period: 'toi'),
  'mai có mưa không': const E(W, aspect: 'rain', day: 1),
  'sáng mai đi học có cần mang ô không': const E(W, aspect: 'rain', day: 1, period: 'sang'),
  'có cần mang áo mưa không': const E(W, aspect: 'rain'),
  'mấy giờ thì mưa': const E(W, aspect: 'rain'),
  'bao giờ tạnh mưa': const E(W, aspect: 'rain'),
  'đang mưa à': const E(W, aspect: 'rain'),
  'mưa to không': const E(W, aspect: 'rain'),
  'lượng mưa hôm nay bao nhiêu': const E(W, aspect: 'rain', day: 0),
  'có dông không': const E(W, aspect: 'rain'),
  'có sấm sét không': const E(W, aspect: 'rain'),
  'ngày kia Đà Lạt có mưa không': const E(W, aspect: 'rain', target: 'da lat', day: 2),
  'trưa nay mưa không': const E(W, aspect: 'rain', period: 'trua'),
  'đêm nay có mưa không': const E(W, aspect: 'rain', period: 'dem'),
  // ---- gió ----
  'gió có mạnh không': const E(W, aspect: 'wind'),
  'gió hướng nào': const E(W, aspect: 'wind'),
  'ngoài biển gió to không': const E(W, aspect: 'wind'),
  'hôm nay gió bao nhiêu': const E(W, aspect: 'wind', day: 0),
  // ---- độ ẩm / không khí / UV ----
  'độ ẩm bao nhiêu': const E(W, aspect: 'humid'),
  'trời có nồm không': const E(W, aspect: 'humid'),
  'có oi bức không': const E(W, aspect: 'humid'),
  'không khí hôm nay thế nào': const E(W, aspect: 'air'),
  'có ô nhiễm không': const E(W, aspect: 'air'),
  'có nên đeo khẩu trang không': const E(W, aspect: 'air'),
  'bụi mịn có cao không': const E(W, aspect: 'air'),
  'nắng có gắt không': const E(W, aspect: 'uv'),
  'chỉ số tia cực tím': const E(W, aspect: 'uv'),
  'có cần bôi kem chống nắng không': const E(W, aspect: 'uv'),
  // ---- mặt trời mọc / lặn ----
  'mấy giờ mặt trời mọc': const E(W, aspect: 'sun'),
  'mặt trời lặn lúc mấy giờ': const E(W, aspect: 'sun'),
  'mấy giờ trời tối': const E(W, aspect: 'sun'),
  'ngày mai mặt trời mọc lúc mấy giờ': const E(W, aspect: 'sun', day: 1),
  // ---- lời khuyên / đi lại ----
  'hôm nay nên mặc gì': const E(W, aspect: 'advice', day: 0),
  'ra ngoài cần mang gì': const E(W, aspect: 'advice'),
  'đường có trơn không': const E(W, aspect: 'advice'),
  'đi bộ ra ngoài có an toàn không': const E(W, aspect: 'advice'),
  'hôm nay phơi đồ được không': const E(W, aspect: 'dry', day: 0),
  'mai đi chơi được không': const E(W, aspect: 'outing', day: 1),
  'chiều nay đi tập thể dục được không': const E(W, aspect: 'outing', period: 'chieu'),
  // ---- ngày trong tuần ----
  'thứ bảy này có mưa không': E(W, aspect: 'rain', day: _until(6)),
  'chủ nhật trời thế nào': E(W, day: _until(7)),
  'thứ hai tuần sau nóng không': E(W, aspect: 'temp', day: _until(1) == 0 ? 7 : _until(1)),
  // ---- dự báo nhiều ngày ----
  'dự báo thời tiết': const E(WKind.forecast),
  'dự báo mấy ngày tới': const E(WKind.forecast),
  '3 ngày tới': const E(WKind.forecast, day: 3),
  'tuần này thời tiết thế nào': const E(WKind.forecast, day: 7),
  'cuối tuần thời tiết thế nào': const E(WKind.forecast, aspect: 'weekend'),
  'cuối tuần có mưa không': const E(WKind.forecast, aspect: 'weekend'),
  'dự báo 10 ngày ở Sa Pa': const E(WKind.forecast, day: 10, target: 'sa pa'),
  // ---- theo giờ / ngày cụ thể ----
  'thời tiết theo giờ': const E(WKind.hours),
  '24 giờ tới': const E(WKind.hours),
  'ngày 30 tháng 10 thời tiết thế nào': const E(WKind.day),
  'hôm qua Hà Nội có mưa không': const E(WKind.day, target: 'ha noi'),
  // ---- thiên tai ----
  'có bão không': const E(WKind.disasters),
  // ---- xã / phường / thôn (sau sáp nhập 2025, có cả tên tỉnh, tỉnh cũ) ----
  'thời tiết xã Tân Lập tỉnh Tây Ninh': const E(W, target: 'xa tan lap tinh tay ninh'),
  'xã Tân Lập ở Tây Ninh có mưa không': const E(W, aspect: 'rain', target: 'xa tan lap o tay ninh'),
  'phường Hải Châu Đà Nẵng hôm nay mấy độ': const E(W, aspect: 'temp', day: 0, target: 'phuong hai chau da nang'),
  'thời tiết phường Hoàn Kiếm': const E(W, target: 'phuong hoan kiem'),
  'xã Bát Tràng có mưa không': const E(W, aspect: 'rain', target: 'xa bat trang'),
  'ngày mai ở xã Mường Hoa tỉnh Yên Bái có lạnh không': const E(W, aspect: 'temp', day: 1, target: 'xa muong hoa tinh yen bai'),
  'thời tiết thị trấn Sa Pa': const E(W, target: 'thi tran sa pa'),
  'quận 1 có mưa không': const E(W, aspect: 'rain', target: 'quan 1'),
  'thời tiết thôn Đông Anh': const E(W, target: 'thon dong anh'),
  'thời tiết ấp Tân Lập': const E(W, target: 'ap tan lap'),
  'thời tiết đặc khu Phú Quốc': const E(W, target: 'dac khu phu quoc'),
  'xã Mai Lâm có nắng không': const E(W, aspect: 'sky', target: 'xa mai lam'),
  'thời tiết Tân Lập Tây Ninh': const E(W, target: 'tan lap tay ninh'),
  'có nên phơi quần áo không': const E(W, aspect: 'dry', noTarget: true),
  // ---- cách nói khác ----
  'hôm nay ra ngoài có cần mang ô không': const E(W, aspect: 'rain', day: 0),
  'trời sắp mưa chưa': const E(W, aspect: 'rain'),
  'bao giờ thì hết mưa': const E(W, aspect: 'rain'),
  'mưa đến mấy giờ': const E(W, aspect: 'rain'),
  'hôm nay có mưa phùn không': const E(W, aspect: 'rain', day: 0),
  'hôm nay có giông bão không': const E(W, aspect: 'rain', day: 0),
  'nhiệt độ thấp nhất đêm nay': const E(W, aspect: 'temp', period: 'dem'),
  'ngày mai trời có lạnh hơn không': const E(W, aspect: 'temp', day: 1),
  'sáng nay có sương mù không': const E(W, aspect: 'sky', period: 'sang'),
  'cho tôi biết nhiệt độ': const E(W, aspect: 'temp', noTarget: true),
  'hôm nay mấy độ vậy': const E(W, aspect: 'temp', day: 0),
  'trời nóng quá nhỉ': const E(W, aspect: 'temp'),
  'ngoài trời lạnh không': const E(W, aspect: 'temp'),
  'có cần mặc áo ấm không': const E(W, aspect: 'advice'),
  'độ ẩm không khí bao nhiêu': const E(W, aspect: 'humid'),
  'chất lượng không khí ở Hà Nội': const E(W, aspect: 'air', target: 'ha noi'),
  'gió mùa đông bắc về chưa': const E(W, aspect: 'wind'),
  'tuần sau thời tiết thế nào': const E(WKind.forecast, day: 7),
  'mấy ngày tới có mưa không': const E(WKind.forecast),
  'ngày 1 tháng 11 có mưa không': const E(WKind.day),
  'thời tiết ở Bắc Kinh': const E(W, target: 'bac kinh'),
  'thời tiết New York': const E(W, target: 'new york'),
  'thời tiết Côn Đảo': const E(W, target: 'con dao'),
  'Mũi Né có gió không': const E(W, aspect: 'wind', target: 'mui ne'),
  'Đà Lạt có lạnh không': const E(W, aspect: 'temp', target: 'da lat'),
  'ở Hội An mai có mưa không': const E(W, aspect: 'rain', day: 1, target: 'hoi an'),
  'mặt trời mọc ở Sa Pa lúc mấy giờ': const E(W, aspect: 'sun', target: 'sa pa'),
  'thời tiết Hà Nội ngày mai': const E(W, day: 1, target: 'ha noi'),
  'thời tiết ngày mai ở Đà Nẵng thế nào': const E(W, day: 1, target: 'da nang'),
  'mai Sài Gòn mưa không': const E(W, aspect: 'rain', day: 1, target: 'sai gon'),
  // ---- so sánh hai nơi ----
  'Hà Nội và Đà Nẵng nơi nào nóng hơn': const E(W, aspect: 'compare', target: 'ha noi|da nang'),
  'so sánh thời tiết Huế với Đà Nẵng': const E(W, aspect: 'compare', target: 'hue|da nang'),
};

final enCases = <String, E>{
  'what is the weather like': const E(W, noTarget: true),
  'weather in London': const E(W, target: 'london'),
  'is it going to rain today': const E(W, aspect: 'rain', day: 0),
  'will it rain tomorrow in Hanoi': const E(W, aspect: 'rain', day: 1, target: 'hanoi'),
  'how hot is it': const E(W, aspect: 'temp'),
  'what is the temperature in Tokyo': const E(W, aspect: 'temp', target: 'tokyo'),
  'is it windy': const E(W, aspect: 'wind'),
  'what time is sunset': const E(W, aspect: 'sun'),
  'is it sunny': const E(W, aspect: 'sky'),
  'what should i wear today': const E(W, aspect: 'advice', day: 0),
  'can i dry my laundry today': const E(W, aspect: 'dry', day: 0),
  'next 3 days': const E(WKind.forecast, day: 3),
  'weather this weekend': const E(WKind.forecast, aspect: 'weekend'),
  'will it rain on saturday': E(W, aspect: 'rain', day: _until(6)),
  'do i need an umbrella': const E(W, aspect: 'rain'),
  'is it cold outside': const E(W, aspect: 'temp'),
  'what is the humidity': const E(W, aspect: 'humid'),
  'how is the air quality in hanoi': const E(W, aspect: 'air', target: 'hanoi'),
  'when does the sun rise tomorrow': const E(W, aspect: 'sun', day: 1),
};

String? _check(String q, WCmd c, E e) {
  final errs = <String>[];
  if (c.kind != e.kind) errs.add('kind=${c.kind.name} (cần ${e.kind.name})');
  final tn = _n(c.target);
  if (e.noTarget && tn.isNotEmpty) errs.add('target="${c.target}" (cần rỗng)');
  if (e.target != null && !e.target!.split('|').every((p) => tn.contains(p))) errs.add('target="${c.target}" (cần chứa ${e.target})');
  if (!e.anyAspect) {
    if (e.aspect != null && c.aspect != e.aspect) {
      errs.add('aspect=${c.aspect} (cần ${e.aspect})');
    } else if (e.aspect == null && e.kind == W && c.aspect != null) {
      errs.add('aspect=${c.aspect} (cần không có)');
    }
  }
  if (e.day != null && c.liveDay != e.day) errs.add('day=${c.liveDay} (cần ${e.day})');
  if (e.period != null && c.period != e.period) errs.add('period=${c.period} (cần ${e.period})');
  return errs.isEmpty ? null : '"$q" → ${errs.join(', ')}';
}

void main() {
  test('các câu hỏi thời tiết (tiếng Việt + tiếng Anh)', () {
    final fails = <String>[];
    viCases.forEach((q, e) {
      final r = _check(q, parseWorld(q), e);
      if (r != null) fails.add('[vi] $r');
    });
    enCases.forEach((q, e) {
      final r = _check(q, parseWorldEn(q), e);
      if (r != null) fails.add('[en] $r');
    });
    final total = viCases.length + enCases.length;
    final report = 'Đạt ${total - fails.length}/$total\n${fails.join('\n')}\n';
    try {
      Directory('build').createSync(recursive: true);
      File('build/weather_cases_report.txt').writeAsStringSync(report);
    } catch (_) {}
    // ignore: avoid_print
    print(report);
    expect(fails, isEmpty, reason: report);
  });
}
