import 'package:earthsense/features/voice/commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bỏ dấu', () {
    expect(normVi('Thời tiết Huế!'), 'thoi tiet hue');
    expect(normVi('ĐÀ NẴNG'), 'da nang');
  });

  test('lệnh địa danh, vùng, tỉnh', () {
    final a = parseCommand('Huế');
    expect(a.kind, CmdKind.goPlace);
    expect(a.place!.name, 'Huế');
    expect(parseCommand('phóng to Đà Nẵng').place!.name, 'Đà Nẵng');
    expect(parseCommand('Sài Gòn').place!.name, 'TP. Hồ Chí Minh');
    expect(parseCommand('Quảng Ninh').place!.name, 'Hạ Long');
    expect(parseCommand('Hoàng Sa').place!.name, 'quần đảo Hoàng Sa');
    expect(parseCommand('quần đảo Trường Sa').place!.name, 'quần đảo Trường Sa');
    final r = parseCommand('Tây Nguyên');
    expect(r.kind, CmdKind.goRegion);
    expect(r.region, 4);
  });

  test('cao nhất / thấp nhất', () {
    final a = parseCommand('nơi mưa nhiều nhất');
    expect(a.kind, CmdKind.extreme);
    expect(a.max, isTrue);
    expect(a.layer, 'rain');
    final b = parseCommand('chỗ nào lạnh nhất');
    expect(b.kind, CmdKind.extreme);
    expect(b.max, isFalse);
    expect(b.layer, 'temp');
    final c = parseCommand('nóng nhất ở Tây Nguyên');
    expect(c.region, 4);
    expect(c.layer, 'temp');
  });

  test('thời gian', () {
    final a = parseCommand('tháng 10 năm 2020');
    expect(a.kind, CmdKind.time);
    expect(a.month, 9);
    expect(a.year, 2020);
    expect(parseCommand('tháng mười hai').month, 11);
    expect(parseCommand('năm 2016').year, 2016);
    final b = parseCommand('mưa tháng 9 ở Huế');
    expect(b.month, 8);
    expect(b.place!.name, 'Huế');
    expect(b.layer, 'rain');
  });

  test('điều khiển', () {
    expect(parseCommand('dừng').kind, CmdKind.stop);
    expect(parseCommand('trợ giúp').kind, CmdKind.help);
    expect(parseCommand('đọc lại').kind, CmdKind.repeat);
    expect(parseCommand('đọc chậm hơn').kind, CmdKind.slower);
    expect(parseCommand('to hơn').kind, CmdKind.louder);
    expect(parseCommand('thu nhỏ').kind, CmdKind.zoomOut);
    expect(parseCommand('tóm tắt').kind, CmdKind.summary);
    expect(parseCommand('nhiệt độ').kind, CmdKind.layer);
    expect(parseCommand('mưa').layer, 'rain');
    expect(parseCommand('đây là đâu').kind, CmdKind.readHere);
    expect(parseCommand('abc xyz').kind, CmdKind.unknown);
    expect(parseCommand('thời tiết').kind, CmdKind.live);
    expect(parseCommand('thời tiết ở đây').here, isTrue);
    expect(parseCommand('nhiệt độ chỗ này').layer, 'temp');
    expect(parseCommand('nhiệt độ chỗ này').kind, CmdKind.readHere);
  });

  test('tháng sau / trước (phân biệt với tháng sáu)', () {
    expect(parseCommand('tháng sau').kind, CmdKind.shift);
    expect(parseCommand('tháng sau').month, 1);
    expect(parseCommand('tháng trước').month, -1);
    expect(parseCommand('năm sau').month, 12);
    expect(parseCommand('năm ngoái').month, -12);
    expect(parseCommand('tháng sáu').kind, CmdKind.time);
    expect(parseCommand('tháng sáu').month, 5);
  });

  test('khớp gần đúng câu nhận giọng', () {
    expect(snapCommand('thức nào'), ('thu nhỏ', true));
    expect(snapCommand('cun ma thuội'), ('Buôn Ma Thuột', true));
    expect(snapCommand('hoang sạc').$1, 'Hoàng Sa');
    expect(snapCommand('kháng sâu'), ('tháng sau', true));
    expect(snapCommand('thời tiết huế').$2, false); // đã hiểu: giữ nguyên
    expect(snapCommand('mình đi chơi nhé').$2, false); // không giống lệnh nào: không đoán bừa
    expect(snapCommand('xương này').$2, false);
  });

  test('từ khoá ưu tiên viết hoa, không dấu câu', () {
    final h = hotwordPhrases();
    expect(h, contains('THỜI TIẾT'));
    expect(h, contains('HỒ CHÍ MINH'));
    expect(h.every((t) => !t.contains('.')), isTrue);
  });

  test('thời tiết thật: bây giờ, dự báo, có mưa không, nên làm gì', () {
    final a = parseCommand('thời tiết Huế');
    expect(a.kind, CmdKind.live);
    expect(a.place!.name, 'Huế');
    expect(a.liveDay, isNull);
    expect(parseCommand('bây giờ ở Đà Nẵng thế nào').kind, CmdKind.live);
    final b = parseCommand('ngày mai Hà Nội có mưa không');
    expect(b.kind, CmdKind.live);
    expect(b.liveDay, 1);
    expect(b.liveAspect, 'rain');
    expect(b.place!.name, 'Hà Nội');
    expect(parseCommand('hôm nay nên làm gì').liveAspect, 'advice');
    expect(parseCommand('hôm nay nên làm gì').liveDay, 0);
    expect(parseCommand('dự báo cuối tuần').liveDay, 7);
    expect(parseCommand('có nên ra ngoài không').liveAspect, 'advice');
    // dữ liệu NASA theo tháng/năm vẫn là lệnh thời gian, không phải thời tiết thật
    expect(parseCommand('thời tiết tháng 10 năm 2020 ở Huế').kind, CmdKind.time);
    expect(parseCommand('nơi mưa nhiều nhất').kind, CmdKind.extreme);
  });

  test('đặt nơi của tôi', () {
    final c = parseCommand('tôi ở Huế');
    expect(c.kind, CmdKind.setHome);
    expect(c.place!.name, 'Huế');
    expect(parseCommand('tôi ở đây').kind, isNot(CmdKind.setHome));
  });

  test('đổi kiểu bản đồ: hôm nay / NASA', () {
    expect(parseCommand('bản đồ hôm nay').kind, CmdKind.mapToday);
    expect(parseCommand('cập nhật bản đồ').kind, CmdKind.mapToday);
    expect(parseCommand('dữ liệu NASA').kind, CmdKind.mapHistory);
    expect(parseCommand('xem các năm trước').kind, CmdKind.mapHistory);
    expect(parseCommand('năm trước').kind, CmdKind.shift); // vẫn là lùi một năm
    expect(parseCommand('hôm nay nên làm gì').kind, CmdKind.live);
  });

  test('ngày cụ thể', () {
    final now = DateTime(2026, 10, 20);
    expect(dateOf('bản đồ ngày 15 tháng 10 năm 2024', now: now), DateTime(2024, 10, 15));
    expect(dateOf('ngày 2 tháng chín', now: now), DateTime(2026, 9, 2));
    expect(dateOf('thời tiết 2/9/2025 ở Huế', now: now), DateTime(2025, 9, 2));
    expect(dateOf('hôm qua', now: now), DateTime(2026, 10, 19));
    expect(dateOf('tháng 11/2020', now: now), isNull); // tháng/năm của dữ liệu NASA, không phải ngày
    expect(dateOf('ngày 31 tháng 2', now: now), isNull);
    expect(dateOf('ngày mai có mưa không', now: now), isNull); // dự báo nói, không phải bản đồ ngày
    final c = parseCommand('thời tiết ngày 15 tháng 10 năm 2024 ở Huế');
    expect(c.kind, CmdKind.dayMap);
    expect(c.place!.name, 'Huế');
    expect(parseCommand('tháng 10 năm 2020').kind, CmdKind.time); // vẫn là dữ liệu NASA theo tháng
  });
}
