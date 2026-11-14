import 'dart:io';
import 'dart:typed_data';

import 'package:earthsense/features/globe/terrain.dart';
import 'package:earthsense/features/globe/terrain_data.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('lệnh địa hình (tiếng Việt)', () {
    void ok(String s, String aspect, [String? target, String? period]) {
      final c = parseWorld(s);
      expect(c.kind, WKind.terrain, reason: '$s → $c');
      expect(c.aspect, aspect, reason: '$s → $c');
      if (target != null) expect(c.target, target, reason: '$s → $c');
      if (period != null) expect(c.period, period, reason: '$s → $c');
    }

    test('chạm địa hình / tắt', () {
      ok('chạm địa hình', 'touch');
      ok('bật chế độ địa hình nổi', 'touch');
      ok('cho tôi sờ địa hình', 'touch');
      ok('tắt chạm địa hình', 'off');
    });
    test('độ cao một nơi', () {
      ok('Đà Lạt cao bao nhiêu mét', 'height', 'Đà Lạt');
      ok('độ cao của Sa Pa', 'height', 'Sa Pa');
      ok('Hà Nội cao bao nhiêu so với mực nước biển', 'height', 'Hà Nội');
      ok('Cao Bằng cao bao nhiêu mét', 'height', 'Cao Bằng');
      ok('Nghệ An cao bao nhiêu', 'height', 'Nghệ An');
      ok('Vũng Tàu cao bao nhiêu mét vậy', 'height', 'Vũng Tàu');
      ok('xã Mường Hoa cao bao nhiêu', 'height', 'xã Mường Hoa');
      ok('độ cao ở đây', 'height', '');
      ok('Phan Xi Păng cao bao nhiêu', 'height', 'đỉnh Phan Xi Păng');
      ok('núi Everest cao bao nhiêu mét', 'height', 'núi Everest');
    });
    test('tả địa hình, tổng quan', () {
      ok('địa hình ở Huế thế nào', 'describe', 'Huế');
      ok('địa hình Đà Lạt ra sao', 'describe', 'Đà Lạt');
      ok('địa hình Việt Nam', 'overview', 'vn');
      ok('giới thiệu địa hình Việt Nam', 'overview', 'vn');
      ok('địa hình thế giới', 'overview', 'world');
    });
    test('lát cắt, đi dọc, từ … đến …', () {
      ok('đi dọc Việt Nam', 'spine');
      ok('nghe địa hình từ bắc vào nam', 'spine');
      ok('địa hình từ Hà Nội đến Sa Pa', 'path', 'Hà Nội|Sa Pa');
      ok('nghe địa hình từ Huế đến Đà Nẵng', 'path', 'Huế|Đà Nẵng');
      ok('lát cắt địa hình Đà Lạt', 'profile', 'Đà Lạt', 'ew');
      ok('lát cắt địa hình qua Đà Lạt từ bắc xuống nam', 'profile', 'Đà Lạt', 'ns');
    });
    test('núi cao nhất, nơi sâu nhất', () {
      ok('núi cao nhất Việt Nam', 'peak', 'vn');
      ok('đỉnh núi cao nhất thế giới là gì', 'peak', 'world');
      ok('nóc nhà Đông Dương', 'peak', 'vn');
      ok('nơi sâu nhất trên trái đất', 'deep');
    });
    test('không cướp câu thời tiết, khám phá', () {
      expect(parseWorld('nhiệt độ cao nhất hôm nay').kind, isNot(WKind.terrain));
      expect(parseWorld('thời tiết Đà Lạt').kind, isNot(WKind.terrain));
      expect(parseWorld('Sa Pa có mưa không').kind, isNot(WKind.terrain));
      expect(parseWorld('khám phá địa hình Hồ Hoàn Kiếm').kind, WKind.explore);
      expect(parseWorld('quanh đây có gì').kind, WKind.around);
      expect(parseWorld('so sánh nhiệt độ Hà Nội và Đà Nẵng').kind, WKind.weather);
    });
  });

  group('terrain commands (English)', () {
    void ok(String s, String aspect, [String? target]) {
      final c = parseWorldEn(s);
      expect(c.kind, WKind.terrain, reason: '$s → $c');
      expect(c.aspect, aspect, reason: '$s → $c');
      if (target != null) expect(c.target, target, reason: '$s → $c');
    }

    test('basic', () {
      ok('touch terrain', 'touch');
      ok('how high is Da Lat', 'height', 'Da Lat');
      ok('elevation of Mount Everest', 'height', 'núi Everest');
      ok('terrain of Viet Nam', 'overview', 'vn');
      ok('terrain of Hue', 'describe', 'Hue');
      ok('highest mountain in the world', 'peak', 'world');
      ok('terrain from Hanoi to Sa Pa', 'path', 'Hanoi|Sa Pa');
      ok('along Viet Nam', 'spine');
      ok('turn off terrain', 'off');
      expect(parseWorldEn('weather in Hanoi').kind, isNot(WKind.terrain));
    });
  });

  group('dữ liệu địa hình', () {
    test('số, dải độ cao, dạng địa hình', () {
      expect(groupNum(3143), '3.143');
      expect(groupNum(8849, en: true), '8,849');
      expect(groupNum(-10935), '-10.935');
      expect(roundElev(1523), 1520);
      expect(roundElev(47.4), 47);
      expect(bandOf(-8000), 0);
      expect(bandOf(-50), 2);
      expect(bandOf(10), 3);
      expect(bandOf(1500), 7);
      expect(bandOf(8800), 10);
      expect(landformAt(22.3, 103.77)!.vi, 'dãy Hoàng Liên Sơn');
      expect(landformAt(11.94, 108.44)!.vi, 'cao nguyên Lâm Viên, Đà Lạt');
      expect(landformAt(10.0, 105.8)!.vi, 'đồng bằng sông Cửu Long');
      expect(landformAt(21.0, 105.85)!.vi, 'đồng bằng sông Hồng');
      expect(landformAt(28.0, 86.9)!.vi, 'dãy Himalaya');
      expect(landformAt(18.67, 105.68, e: 5)!.vi, 'dải đồng bằng ven biển miền Trung'); // Vinh: thấp, không phải dãy núi
      expect(landformAt(18.3, 105.2, e: 900)!.vi, 'dãy Trường Sơn Bắc');
      expect(peakIn('Phan Xi Păng cao bao nhiêu')!.h, 3143);
      expect(peakIn('thời tiết Hà Nội'), isNull);
    });
    test('câu trả lời', () {
      final p = peakIn('fansipan')!;
      expect(heightAnswer(p.vi, p.en, p.lat, p.lon, 0, peak: p).$1, contains('3.143 mét'));
      final a = heightAnswer('Đà Lạt', 'Da Lat', 11.94, 108.44, 1512);
      expect(a.$1, contains('1.510 mét'));
      expect(a.$1, contains('Lâm Viên'));
      expect(elevPhrase(-3200).$1, contains('dưới mặt biển'));
      final flat = reliefAnswer('Cần Thơ', 'Can Tho', 10.03, 105.78, 2, List.filled(8, 3.0), 20);
      expect(flat.$1, contains('bằng phẳng'));
      final steep = reliefAnswer('Sa Pa', 'Sa Pa', 22.33, 103.84, 1500, [2800, 2000, 900, 700, 1200, 1800, 2400, 2600], 10);
      expect(steep.$1, contains('hiểm trở'));
      expect(steep.$1, contains('phía bắc'));
      final sea = reliefAnswer('Đà Nẵng', 'Da Nang', 16.05, 108.2, 10, [20, -30, -40, -20, 15, 300, 600, 200], 20);
      expect(sea.$1, contains('Biển ở phía'));
      final pr = profileSummary([5, 10, 400, 1500, 900, 30, -20, -50], 300);
      expect(pr.$1, contains('1.500'));
      expect(pr.$1, contains('biển'));
    });
    test('toạ độ, đường đi', () {
      final (la, lo) = offsetKm(21.0, 105.8, 100, 90);
      expect(distKm(21.0, 105.8, la, lo), closeTo(100, 0.5));
      final s = samplePath([(10.0, 100.0), (10.0, 102.0), (12.0, 102.0)], 5);
      expect(s.length, 5);
      expect(s.first.$2, closeTo(100, 1e-9));
      expect(s.last.$1, closeTo(12, 1e-9));
      expect(vnSpine.first.$3, greaterThan(vnSpine.last.$3));
    });
    test('giải mã Terrarium', () {
      // 0 m: R=128 G=0 B=0 · 3.143 m: 32768 + 3143 = 35911 = 140·256 + 71
      final px = Uint8List.fromList([128, 0, 0, 255, 140, 71, 0, 255, 127, 0, 0, 255]);
      expect(Terrain.terrariumToElev(px), [0, 3143, -256]);
      final (z, x, y) = Terrain.tileOf(21.03, 105.85, 7);
      expect((z, x, y), (7, 101, 56));
      expect(Terrain.key(12, 4095, 4095), isNot(Terrain.key(12, 4095, 4094)));
    });
    test('lưới độ cao toàn cầu đóng gói trong app', () {
      final f = File('assets/world/elev_glob.bin');
      expect(f.lengthSync(), Terrain.gw * Terrain.gh * 2);
      final bytes = f.readAsBytesSync();
      final t = Terrain(http.Client())..setGlobal(bytes.buffer.asInt16List(bytes.offsetInBytes, bytes.length ~/ 2));
      expect(t.ready, isTrue);
      expect(t.globalAt(27.99, 86.93), greaterThan(3500)); // Himalaya (trung bình ô 0,5°)
      expect(t.globalAt(32, 88), greaterThan(4000)); // Tây Tạng
      expect(t.globalAt(21.03, 105.85), lessThan(200)); // Hà Nội
      expect(t.globalAt(10.0, 105.8), lessThan(60)); // Cửu Long
      expect(t.globalAt(12.7, 108.05), greaterThan(300)); // Tây Nguyên
      expect(t.globalAt(11.35, 142.2), lessThan(-5000)); // Mariana
      expect(t.globalAt(-80, 0), greaterThan(1500)); // Nam Cực
      expect(t.at(21.03, 105.85), t.globalAt(21.03, 105.85)); // chưa có ô chi tiết → dùng lưới
      expect(t.globalAt(0, 179.9).isNaN, isFalse); // qua kinh tuyến 180
    });
  });
}
