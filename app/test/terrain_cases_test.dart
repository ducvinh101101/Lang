// BỘ CÂU KHÓ cho phần ĐỊA HÌNH — những trường hợp dễ hiểu sai nhất:
//  • tên nơi chứa chữ trùng từ hỏi / từ thời tiết: Cao Bằng, Cao Lãnh, Nghệ An, Cửa Lò, Cô Tô, Đà Nẵng ("nang"), Gio Linh ("gio")…
//  • tên có chữ chỉ hướng: Nam Định, Bắc Ninh, Tây Ninh, Đông Hà (không được hiểu là "từ bắc xuống nam")
//  • câu thời tiết / đo khoảng cách / mực nước dễ bị cướp: "nhiệt độ cao nhất", "cầu dài bao nhiêu mét", "sóng biển cao bao nhiêu"
//  • lời đệm, gọi tên, hỏi vòng: "bạn ơi cho mình hỏi … nhỉ", "… nằm ở độ cao bao nhiêu", "… so với mực nước biển vậy bạn"
//  • ghép tự động: mọi tỉnh × nhiều mẫu câu (độ cao, tả địa hình, lát cắt, câu thời tiết không được thành địa hình)
//  • dữ liệu / tính toán: biên dải độ cao, số âm, qua kinh tuyến 180°, cực, ô Terrarium, mạng lỗi, PNG thật.
// Gom hết lỗi rồi báo một lần, ghi ra build/terrain_cases_report.txt.
import 'dart:io';
import 'dart:typed_data';

import 'package:earthsense/features/globe/terrain.dart';
import 'package:earthsense/features/globe/terrain_data.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:earthsense/live/vn_admin.dart' show foldVi, provincesNow;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Kết quả mong đợi: [kind] (null = KHÔNG được là địa hình), [aspect], [target] (so đúng từng chữ), [period].
class T {
  final WKind? kind;
  final String? aspect, target, period;
  const T(this.kind, {this.aspect, this.target, this.period});
}

const _t = WKind.terrain;
T h(String target) => T(_t, aspect: 'height', target: target);
T d(String target) => T(_t, aspect: 'describe', target: target);
T path(String a, String b) => T(_t, aspect: 'path', target: '$a|$b');
T prof(String target, String period) => T(_t, aspect: 'profile', target: target, period: period);
T peak(String target) => T(_t, aspect: 'peak', target: target);
const touch = T(_t, aspect: 'touch');
const off = T(_t, aspect: 'off');
const spine = T(_t, aspect: 'spine');
const deep = T(_t, aspect: 'deep');
const ovVn = T(_t, aspect: 'overview', target: 'vn');
const ovWorld = T(_t, aspect: 'overview', target: 'world');
const notTerrain = T(null);

final viCases = <String, T>{
  // ---------- bật / tắt chạm địa hình ----------
  'chạm địa hình': touch,
  'bật chạm địa hình': touch,
  'mở chế độ địa hình': touch,
  'bật chế độ địa hình nổi': touch,
  'địa hình nổi': touch,
  'cho tôi sờ địa hình': touch,
  'cảm nhận địa hình': touch,
  'chạm vào quả địa cầu': touch,
  'chạm lên quả cầu': touch,
  'rê tay trên quả địa cầu': touch,
  'địa hình 3D': touch,
  'địa hình ba chiều': touch,
  'bản đồ nổi': touch,
  'hướng dẫn chạm địa hình': touch,
  'Trái Đất ơi chạm địa hình': touch,
  'ờ chạm địa hình đi': touch,
  'tắt chạm địa hình': off,
  'tắt địa hình': off,
  'tắt địa hình nổi': off,
  'thoát chạm địa hình': off,
  'dừng chế độ địa hình': off,
  'bỏ chạm địa hình': off,
  'thoát': const T(WKind.exitLocal),

  // ---------- độ cao một nơi ----------
  'Đà Lạt cao bao nhiêu mét': h('Đà Lạt'),
  'Đà Lạt cao bao nhiêu': h('Đà Lạt'),
  'Đà Lạt cao mấy mét': h('Đà Lạt'),
  'Đà Lạt nằm ở độ cao bao nhiêu': h('Đà Lạt'),
  'Đà Lạt nằm ở độ cao bao nhiêu mét': h('Đà Lạt'),
  'Đà Lạt ở độ cao bao nhiêu mét': h('Đà Lạt'),
  'độ cao Đà Lạt là bao nhiêu': h('Đà Lạt'),
  'độ cao của Sa Pa': h('Sa Pa'),
  'độ cao ở Mộc Châu': h('Mộc Châu'),
  'cho tôi biết độ cao của Hà Giang': h('Hà Giang'),
  'bạn ơi cho mình hỏi Sa Pa cao bao nhiêu mét nhỉ': h('Sa Pa'),
  'Sa Pa cao bao nhiêu mét so với mực nước biển vậy bạn': h('Sa Pa'),
  'Hà Nội cao bao nhiêu so với mực nước biển': h('Hà Nội'),
  'Hà Nội cao hơn mặt biển bao nhiêu': h('Hà Nội'),
  'Trái Đất ơi Huế cao bao nhiêu mét': h('Huế'),
  'Cao Bằng cao bao nhiêu mét': h('Cao Bằng'),
  'Cao Lãnh cao bao nhiêu': h('Cao Lãnh'),
  'Nghệ An cao bao nhiêu': h('Nghệ An'),
  'Hà Tĩnh cao bao nhiêu': h('Hà Tĩnh'),
  'Vũng Tàu cao bao nhiêu mét vậy': h('Vũng Tàu'),
  'Cửa Lò cao bao nhiêu': h('Cửa Lò'),
  'Cô Tô cao bao nhiêu': h('Cô Tô'),
  'Mũi Né cao bao nhiêu': h('Mũi Né'),
  'Tây Ninh cao bao nhiêu': h('Tây Ninh'),
  'Nam Định cao bao nhiêu': h('Nam Định'),
  'Bắc Ninh cao bao nhiêu mét': h('Bắc Ninh'),
  'Đông Hà cao bao nhiêu': h('Đông Hà'),
  'Gio Linh cao bao nhiêu': h('Gio Linh'),
  'Mường Nhé cao bao nhiêu': h('Mường Nhé'),
  'Tam Đảo cao bao nhiêu': h('Tam Đảo'),
  'Bà Nà cao bao nhiêu': h('Bà Nà'),
  'Sơn La cao bao nhiêu mét': h('Sơn La'),
  'Đà Nẵng cao bao nhiêu': h('Đà Nẵng'),
  'xã Mường Hoa cao bao nhiêu': h('xã Mường Hoa'),
  'phường Hải Châu Đà Nẵng cao bao nhiêu mét': h('phường Hải Châu Đà Nẵng'),
  'độ cao ở đây': h(''),
  'chỗ này cao bao nhiêu': h(''),
  'ở đây cao bao nhiêu mét': h(''),
  'nơi này cao bao nhiêu': h(''),
  'tôi đang ở độ cao bao nhiêu': h(''),
  'Phan Xi Păng cao bao nhiêu': h('đỉnh Phan Xi Păng'),
  'Fansipan cao bao nhiêu mét': h('đỉnh Phan Xi Păng'),
  'đỉnh Phan-xi-păng cao bao nhiêu': h('đỉnh Phan Xi Păng'),
  'núi Phan Xi Păng có cao không': h('đỉnh Phan Xi Păng'),
  'Lang Biang cao bao nhiêu': h('đỉnh Lang Biang'),
  'núi Bà Đen cao bao nhiêu': h('núi Bà Đen'),
  'núi Everest cao bao nhiêu mét': h('núi Everest'),
  'núi Ê vơ rét cao bao nhiêu': h('núi Everest'),
  'núi Phú Sĩ cao bao nhiêu': h('núi Phú Sĩ'),
  'cao nguyên Lâm Viên cao bao nhiêu': h('cao nguyên Lâm Viên'),

  // ---------- tả địa hình, tổng quan ----------
  'địa hình ở Huế thế nào': d('Huế'),
  'địa hình Đà Lạt ra sao': d('Đà Lạt'),
  'địa hình Sa Pa như thế nào': d('Sa Pa'),
  'mô tả địa hình Hà Giang': d('Hà Giang'),
  'địa hình vùng Tây Bắc': d('Tây Bắc'),
  'địa hình Tây Nguyên thế nào': d('Tây Nguyên'),
  'địa hình của Nghệ An': d('Nghệ An'),
  'địa hình Cao Bằng': d('Cao Bằng'),
  'địa hình Đà Nẵng có gì': d('Đà Nẵng'),
  'địa hình Gio Linh': d('Gio Linh'),
  'địa hình Cao Lãnh': d('Cao Lãnh'),
  'địa hình quanh đây': d(''),
  'địa hình chỗ này': d(''),
  'địa hình là gì': d(''),
  'địa hình Việt Nam': ovVn,
  'địa hình nước ta': ovVn,
  'giới thiệu địa hình Việt Nam': ovVn,
  'địa hình Việt Nam như thế nào': ovVn,
  'kể về địa hình Việt Nam': ovVn,
  'địa hình thế giới': ovWorld,
  'địa hình Trái Đất': ovWorld,
  'địa hình toàn cầu': ovWorld,

  // ---------- đi dọc, từ … đến …, lát cắt ----------
  'đi dọc Việt Nam': spine,
  'dọc Việt Nam': spine,
  'đi dọc đất nước': spine,
  'dọc chiều dài đất nước': spine,
  'nghe địa hình từ bắc vào nam': spine,
  'địa hình Việt Nam từ bắc vào nam': spine,
  'địa hình từ Hà Nội đến Sa Pa': path('Hà Nội', 'Sa Pa'),
  'lát cắt từ Đà Lạt xuống Nha Trang': path('Đà Lạt', 'Nha Trang'),
  'địa hình từ Huế ra Đà Nẵng thế nào': path('Huế', 'Đà Nẵng'),
  'độ cao từ Hà Nội tới Hải Phòng': path('Hà Nội', 'Hải Phòng'),
  'nghe địa hình từ Bắc Ninh đến Nam Định': path('Bắc Ninh', 'Nam Định'),
  'địa hình từ Tây Ninh sang Đồng Nai': path('Tây Ninh', 'Đồng Nai'),
  'địa hình từ Hà Nội đến Cao Bằng': path('Hà Nội', 'Cao Bằng'),
  'nghe địa hình từ Huế đến Đà Nẵng': path('Huế', 'Đà Nẵng'),
  'lát cắt địa hình Đà Lạt': prof('Đà Lạt', 'ew'),
  'lát cắt địa hình Nam Định': prof('Nam Định', 'ew'),
  'lát cắt địa hình Bắc Ninh': prof('Bắc Ninh', 'ew'),
  'mặt cắt địa hình Huế theo chiều bắc nam': prof('Huế', 'ns'),
  'cắt ngang Đà Lạt từ tây sang đông': prof('Đà Lạt', 'ew'),
  'lát cắt địa hình qua Đà Lạt từ bắc xuống nam': prof('Đà Lạt', 'ns'),
  'lát cắt ở đây': prof('', 'ew'),

  // ---------- núi cao nhất, nơi sâu nhất ----------
  'núi cao nhất Việt Nam': peak('vn'),
  'núi nào cao nhất Việt Nam': peak('vn'),
  'đâu là đỉnh cao nhất Việt Nam': peak('vn'),
  'đỉnh núi cao nhất thế giới là gì': peak('world'),
  'ngọn núi cao nhất thế giới': peak('world'),
  'nóc nhà Đông Dương': peak('vn'),
  'nóc nhà thế giới': peak('world'),
  'núi cao nhất châu Phi': peak('Kilimanjaro'),
  'núi cao nhất châu Âu': peak('Mount Elbrus'),
  'núi cao nhất Nhật Bản': peak('Mount Fuji'),
  'núi cao nhất Đông Nam Á': peak('Hkakabo Razi'),
  'núi cao nhất châu Á': peak('world'),
  'núi cao nhất Nam Mỹ': peak('Aconcagua'),
  'núi cao nhất': peak(''),
  'nơi sâu nhất trên trái đất': deep,
  'chỗ sâu nhất đại dương': deep,
  'rãnh Mariana': deep,
  'vực Challenger': deep,

  // ---------- KHÔNG được thành địa hình ----------
  'nhiệt độ cao nhất hôm nay': const T(WKind.weather),
  'nhiệt độ cao nhất ở Sa Pa': const T(WKind.weather),
  'Sa Pa có mưa không': const T(WKind.weather),
  'thời tiết Cao Bằng': const T(WKind.weather),
  'thời tiết Đà Lạt ngày mai': const T(WKind.weather),
  'Đà Nẵng hôm nay nắng không': const T(WKind.weather),
  'so sánh nhiệt độ Hà Nội và Đà Nẵng': const T(WKind.weather),
  'Đà Lạt có lạnh không': notTerrain,
  'đỉnh Phan Xi Păng có tuyết không': notTerrain,
  'mực nước sông Hồng cao bao nhiêu': notTerrain,
  'sóng biển cao bao nhiêu': notTerrain,
  'cầu Long Biên dài bao nhiêu mét': notTerrain,
  'Hồ Tây rộng bao nhiêu mét': notTerrain,
  'Hà Nội cách Huế bao xa': notTerrain,
  'hồ nào sâu nhất Việt Nam': notTerrain,
  'tòa nhà cao nhất Việt Nam': notTerrain,
  'nghe nhạc từ sáng đến chiều': notTerrain,
  'dự báo từ thứ hai đến chủ nhật': notTerrain,
  'bay từ Hà Nội đến Huế': notTerrain,
  'khám phá địa hình Hồ Hoàn Kiếm': const T(WKind.explore),
  'nghe địa hình': const T(WKind.explore),
  'khám phá bằng tay Đà Lạt': const T(WKind.explore),
  'quanh đây có gì': const T(WKind.around),
  'xung quanh Đà Lạt có núi không': const T(WKind.around),
  'tôi đang ở đâu': const T(WKind.around),
  'núi cao nhất trên Sao Hỏa': const T(WKind.planet),
  'trợ giúp': const T(WKind.help),
  'hướng dẫn địa lý': const T(WKind.help),
  'kể về Vịnh Hạ Long': const T(WKind.landmark),
};

final enCases = <String, T>{
  'touch terrain': touch,
  'terrain mode': touch,
  'feel the terrain': touch,
  '3d terrain': touch,
  'turn off terrain': off,
  'disable terrain': off,
  'stop terrain touch': off,
  'how high is Da Lat': h('Da Lat'),
  'how high is Da Lat above sea level': h('Da Lat'),
  'what is the elevation of Sa Pa': h('Sa Pa'),
  'elevation of Hanoi': h('Hanoi'),
  "what's the elevation here": h(''),
  'altitude of Lhasa': h('Lhasa'),
  'how tall is Mount Fuji': h('núi Phú Sĩ'),
  'how high is Fansipan': h('đỉnh Phan Xi Păng'),
  'how high is Everest in meters': h('núi Everest'),
  'terrain of Hue': d('Hue'),
  'describe the terrain around Sa Pa': d('Sa Pa'),
  'terrain here': d(''),
  'terrain of Viet Nam': ovVn,
  'terrain of Vietnam': ovVn,
  'terrain of the world': ovWorld,
  'along Viet Nam': spine,
  'along Vietnam': spine,
  'terrain from north to south': spine,
  'terrain from Hanoi to Sa Pa': path('Hanoi', 'Sa Pa'),
  'terrain from Hanoi to Sa Pa please': path('Hanoi', 'Sa Pa'),
  'elevation profile from Hue to Da Nang': path('Hue', 'Da Nang'),
  'terrain profile of Da Lat': prof('Da Lat', 'ew'),
  'cross section of Hue': prof('Hue', 'ew'),
  'highest mountain in the world': peak('world'),
  'highest mountain in Viet Nam': peak('vn'),
  'highest mountain in Africa': peak('Kilimanjaro'),
  'tallest mountain in Japan': peak('Mount Fuji'),
  'highest peak in Europe': peak('Mount Elbrus'),
  'deepest point on earth': deep,
  'how deep is the ocean': deep,
  'mariana trench': deep,
  'weather in Hanoi': notTerrain,
  'how high is the temperature in Hanoi': notTerrain,
  'how high will the water level get': notTerrain,
  'how high are the waves in Da Nang': notTerrain,
  'will it snow in Sa Pa': notTerrain,
};

String? _check(String s, WCmd c, T e) {
  if (e.kind == null) return c.kind == WKind.terrain ? '"$s" KHÔNG được là địa hình nhưng ra $c' : null;
  final bad = <String>[];
  if (c.kind != e.kind) bad.add('kind ${c.kind} ≠ ${e.kind}');
  if (e.aspect != null && c.aspect != e.aspect) bad.add('aspect ${c.aspect} ≠ ${e.aspect}');
  if (e.target != null && c.target != e.target) bad.add('target "${c.target}" ≠ "${e.target}"');
  if (e.period != null && c.period != e.period) bad.add('period ${c.period} ≠ ${e.period}');
  return bad.isEmpty ? null : '"$s" → ${bad.join(', ')}';
}

final _report = <String>[];
void _write() {
  try {
    Directory('build').createSync(recursive: true);
    File('build/terrain_cases_report.txt').writeAsStringSync(_report.join('\n'));
  } catch (_) {}
}

/// Câu hỏi đã tách tên nơi: không còn sót từ hỏi.
const _leftovers = ['bao nhieu', 'the nao', 'ra sao', 'dia hinh', 'do cao', 'la gi', 'so voi', 'muc nuoc', 'cao may', 'cho toi', 'cho minh'];

// ---- ảnh PNG Terrarium thật (256 × 256, một màu) để thử đường tải + giải mã ----
final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});
int _crc(List<int> b) {
  var c = 0xFFFFFFFF;
  for (final x in b) {
    c = _crcTable[(c ^ x) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

List<int> _chunk(String type, List<int> data) {
  final t = type.codeUnits;
  final len = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc([...t, ...data]));
  return [...len.buffer.asUint8List(), ...t, ...data, ...crc.buffer.asUint8List()];
}

Uint8List terrariumPng(double elevMeters) {
  final v = elevMeters + 32768;
  final r = v ~/ 256, g = (v % 256).floor(), b = ((v - v.floor()) * 256).floor();
  final ihdr = ByteData(13)
    ..setUint32(0, 256)
    ..setUint32(4, 256)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  final raw = BytesBuilder();
  for (var y = 0; y < 256; y++) {
    raw.addByte(0);
    for (var x = 0; x < 256; x++) {
      raw.add([r, g, b, 255]);
    }
  }
  return Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10,
    ..._chunk('IHDR', ihdr.buffer.asUint8List()),
    ..._chunk('IDAT', ZLibCodec().encode(raw.toBytes())),
    ..._chunk('IEND', const []),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(_write);

  group('câu khó (tiếng Việt)', () {
    test('${viCases.length} câu', () {
      final fails = <String>[];
      viCases.forEach((s, e) {
        final f = _check(s, parseWorld(s), e);
        if (f != null) fails.add(f);
      });
      _report
        ..add('=== TIẾNG VIỆT: ${viCases.length - fails.length}/${viCases.length} đúng')
        ..addAll(fails);
      expect(fails, isEmpty, reason: fails.join('\n'));
    });
  });

  group('hard cases (English)', () {
    test('${enCases.length} sentences', () {
      final fails = <String>[];
      enCases.forEach((s, e) {
        final f = _check(s, parseWorldEn(s), e);
        if (f != null) fails.add(f);
      });
      _report
        ..add('=== ENGLISH: ${enCases.length - fails.length}/${enCases.length}')
        ..addAll(fails);
      expect(fails, isEmpty, reason: fails.join('\n'));
    });
  });

  group('ghép tự động: mọi tỉnh × nhiều mẫu câu', () {
    final places = [
      ...provincesNow,
      'Sa Pa', 'Đà Lạt', 'Mộc Châu', 'Cao Lãnh', 'Cửa Lò', 'Cô Tô', 'Mũi Né', 'Vũng Tàu', 'Gio Linh', 'Tam Đảo', 'Hà Giang',
      'Bắc Kạn', 'Nam Định', 'Đông Hà', 'Phú Quốc', 'Côn Đảo', 'Hội An', 'Nha Trang', 'Buôn Ma Thuột', 'Pleiku', 'Mù Cang Chải',
      'Đồng Văn', 'Mèo Vạc', 'Tam Cốc', 'Hạ Long', 'Bà Nà', 'Kon Tum', 'Bảo Lộc', 'Tà Xùa', 'Y Tý',
    ];
    const prefixes = ['', 'cho tôi hỏi ', 'bạn ơi ', 'Trái Đất ơi ', 'ờ '];
    const heightTpl = [
      '{} cao bao nhiêu',
      '{} cao bao nhiêu mét',
      '{} cao mấy mét',
      '{} nằm ở độ cao bao nhiêu',
      '{} cao bao nhiêu so với mực nước biển',
      '{} cao bao nhiêu mét vậy',
      '{} cao bao nhiêu nhỉ',
      'độ cao của {}',
      'độ cao ở {} là bao nhiêu',
      'cho tôi biết độ cao {}',
    ];
    const describeTpl = ['địa hình {}', 'địa hình ở {} thế nào', 'địa hình {} ra sao', 'mô tả địa hình {}', 'địa hình của {} như thế nào'];
    const weatherTpl = [
      'thời tiết {}',
      '{} có mưa không',
      'nhiệt độ {}',
      '{} nóng không',
      'nhiệt độ cao nhất ở {}',
      '{} ngày mai thế nào',
      'dự báo {} ba ngày tới',
      'độ ẩm ở {}',
      '{} có bão không',
    ];

    test('độ cao: tên nơi tách đúng', () {
      final fails = <String>[];
      var n = 0;
      for (final p in places) {
        for (final pre in prefixes) {
          for (final tpl in heightTpl) {
            final s = '$pre${tpl.replaceAll('{}', p)}';
            n++;
            final f = _check(s, parseWorld(s), h(p));
            if (f != null) fails.add(f);
          }
        }
      }
      _report
        ..add('=== GHÉP ĐỘ CAO: ${n - fails.length}/$n')
        ..addAll(fails);
      expect(fails, isEmpty, reason: fails.take(60).join('\n'));
    });

    test('tả địa hình: tên nơi tách đúng', () {
      final fails = <String>[];
      var n = 0;
      for (final p in places) {
        for (final tpl in describeTpl) {
          final s = tpl.replaceAll('{}', p);
          n++;
          final f = _check(s, parseWorld(s), d(p));
          if (f != null) fails.add(f);
        }
      }
      _report
        ..add('=== GHÉP TẢ ĐỊA HÌNH: ${n - fails.length}/$n')
        ..addAll(fails);
      expect(fails, isEmpty, reason: fails.take(60).join('\n'));
    });

    test('từ … đến …: hai nơi tách đúng', () {
      final fails = <String>[];
      var n = 0;
      for (var k = 0; k < places.length; k++) {
        final a = places[k], b = places[(k * 7 + 3) % places.length];
        if (a == b) continue;
        for (final tpl in ['địa hình từ {a} đến {b}', 'lát cắt địa hình từ {a} tới {b}', 'độ cao từ {a} đến {b} thế nào']) {
          final s = tpl.replaceAll('{a}', a).replaceAll('{b}', b);
          n++;
          final f = _check(s, parseWorld(s), path(a, b));
          if (f != null) fails.add(f);
        }
      }
      _report
        ..add('=== GHÉP TỪ … ĐẾN …: ${n - fails.length}/$n')
        ..addAll(fails);
      expect(fails, isEmpty, reason: fails.take(60).join('\n'));
    });

    test('câu thời tiết KHÔNG bị hiểu thành địa hình', () {
      final fails = <String>[];
      var n = 0;
      for (final p in places) {
        for (final tpl in weatherTpl) {
          final s = tpl.replaceAll('{}', p);
          n++;
          final c = parseWorld(s);
          if (c.kind == WKind.terrain) fails.add('"$s" → $c');
        }
      }
      _report
        ..add('=== THỜI TIẾT KHÔNG THÀNH ĐỊA HÌNH: ${n - fails.length}/$n')
        ..addAll(fails);
      expect(fails, isEmpty, reason: fails.take(60).join('\n'));
    });

    test('tên nơi trả về không sót từ hỏi', () {
      final fails = <String>[];
      for (final s in [...viCases.keys]) {
        final c = parseWorld(s);
        if (c.kind != WKind.terrain) continue;
        final nt = foldVi(c.target);
        for (final w in _leftovers) {
          if (' $nt '.contains(' $w ')) fails.add('"$s" → target "${c.target}" còn "$w"');
        }
      }
      _report.addAll(fails);
      expect(fails, isEmpty, reason: fails.join('\n'));
    });
  });

  group('dữ liệu địa hình: biên và số lạ', () {
    test('dải độ cao đúng ở biên', () {
      expect(bandOf(-6000), 1);
      expect(bandOf(-6000.1), 0);
      expect(bandOf(-200), 2);
      expect(bandOf(-0.1), 2);
      expect(bandOf(0), 3);
      expect(bandOf(49.9), 3);
      expect(bandOf(50), 4);
      expect(bandOf(5000), 10);
      expect(bandOf(double.infinity), 10);
      expect(bandOf(-12000), 0);
      for (var b = 0; b <= 10; b++) {
        expect(bandName(b).$1, isNotEmpty);
        expect(bandName(b).$2, isNotEmpty);
      }
    });
    test('số và làm tròn', () {
      expect(groupNum(0), '0');
      expect(groupNum(999), '999');
      expect(groupNum(1000), '1.000');
      expect(groupNum(1000000), '1.000.000');
      expect(groupNum(-1000, en: true), '-1,000');
      expect(roundElev(-1523), -1520);
      expect(roundElev(999), 1000);
      expect(roundElev(-0.4), 0);
      expect(elevPhrase(0).$1, contains('ngang mực nước biển'));
      expect(elevPhrase(2.4).$1, contains('ngang mực nước biển'));
      expect(elevPhrase(-0.4).$1, contains('ngang mực nước biển'));
      expect(elevPhrase(3).$1, contains('3 mét'));
      expect(elevPhrase(-50).$1, contains('sâu khoảng 50 mét'));
      expect(elevPhrase(8849).$2, contains('8,850'));
    });
    test('âm đàn theo độ cao', () {
      expect(elevTone(-5), 0);
      expect(elevTone(0), 0);
      expect(elevTone(8000), 1);
      expect(elevTone(20000), 1);
      expect(elevTone(2000), greaterThan(elevTone(1000)));
      expect(elevTone(10), greaterThan(0));
    });
    test('dạng địa hình: biên khung, biển, cực', () {
      expect(landformAt(-89, 0, e: 2800)!.vi, 'châu Nam Cực');
      expect(landformAt(0, -30), isNull); // giữa Đại Tây Dương
      expect(landformAt(11.35, 142.2, e: -8000)!.vi, 'rãnh Ma-ri-a-na');
      expect(landformAt(11.35, 142.2, e: 100), isNull);
      expect(landformAt(21.4, 103.3)!.vi, 'dãy Hoàng Liên Sơn'); // đúng góc khung
      expect(landformAt(21.0, 105.85, e: 1500), isNot(predicate<Landform?>((f) => f?.vi == 'đồng bằng sông Hồng')));
      expect(landformAt(16.05, 108.2, e: 8)!.vi, 'dải đồng bằng ven biển miền Trung'); // Đà Nẵng thấp, không phải Bạch Mã
      expect(landformAt(16.19, 107.86, e: 1200)!.vi, 'dãy Bạch Mã và đèo Hải Vân');
      expect(landformAt(12.67, 108.04, e: 500)!.vi, 'Tây Nguyên');
      expect(landformAt(10.78, 106.7, e: 5), isNot(predicate<Landform?>((f) => f?.kind == 1)));
      expect(landformAt(30, 90, e: double.nan)!.vi, 'cao nguyên Tây Tạng');
    });
    test('hướng 8 phía quay vòng', () {
      expect(dir8(0).$1, 'bắc');
      expect(dir8(8).$1, 'bắc');
      expect(dir8(-1).$1, 'tây bắc');
      expect(dir8(4).$2, 'south');
    });
    test('tả quanh một điểm: thiếu số, toàn biển, giữa biển', () {
      final none = reliefAnswer('A', 'A', 21, 105, 10, List.filled(8, double.nan), 10);
      expect(none.$1, isNot(contains('Cách')));
      final sea = reliefAnswer('B', 'B', 15, 115, -3000, List.filled(8, -3100.0), 20);
      expect(sea.$1, contains('dưới mặt biển'));
      expect(sea.$1, isNot(contains('Biển ở phía')));
      final some = reliefAnswer('C', 'C', 21, 105, 20, [double.nan, 30, 40, double.nan, 25, 20, 10, 15], 10);
      expect(some.$1, contains('phía đông'));
    });
    test('tóm tắt lát cắt: rỗng, NaN, đếm lần lên núi', () {
      expect(profileSummary([double.nan, double.nan], 100).$1, 'Chưa có số liệu độ cao.');
      expect(profileSummary([], 100).$1, 'Chưa có số liệu độ cao.');
      final p = profileSummary([double.nan, 100, 900, 50, 800, 20], 200);
      expect(p.$1, contains('Có 2 lần lên núi lớn'));
      expect(p.$1, contains('Cao nhất 900 mét'));
      expect(profileSummary([5, 6, 7, 6, 5], 50).$1, contains('Đường khá bằng'));
      expect(profileSummary([-100, -200, -300, 10], 80).$1, contains('Phần lớn đường đi qua biển'));
      expect(profileSummary([42], 0).$1, contains('42 mét'));
    });
    test('câu trả lời độ cao: số âm, đỉnh núi', () {
      expect(heightAnswer('Biển Chết', 'Dead Sea', 31.5, 35.5, -430).$1, contains('dưới mặt biển'));
      for (final p in peaks) {
        final a = heightAnswer(p.vi, p.en, p.lat, p.lon, 0, peak: p);
        expect(a.$1, contains(groupNum(p.h)), reason: p.vi);
        expect(a.$2, contains(groupNum(p.h, en: true)), reason: p.en);
      }
    });
    test('đỉnh núi: tên gọi, không bắt nhầm', () {
      expect(peakIn('Phăng Xi Păng')!.en, 'Fansipan');
      expect(peakIn('FANSIPAN')!.en, 'Fansipan');
      expect(peakIn('đỉnh everest')!.en, 'Mount Everest');
      expect(peakIn('cả hai nơi cao bao nhiêu'), isNull);
      expect(peakIn('cao nguyên Lâm Viên'), isNull);
      expect(peakIn('bà đen'), isNotNull);
      expect(peakIn('Bạch Mã')!.h, 1450);
      expect(peakIn(''), isNull);
      // mọi đỉnh tìm được bằng chính tên tiếng Việt / tiếng Anh của nó
      for (final p in peaks) {
        expect(peakIn(p.vi)?.en, p.en, reason: p.vi);
      }
      // tên tiếng Anh trong lệnh "núi cao nhất châu …" phải có trong danh sách
      for (final en in ['Kilimanjaro', 'Mount Elbrus', 'Mont Blanc', 'Denali', 'Aconcagua', 'Hkakabo Razi', 'Mount Fuji', 'Mount Kinabalu']) {
        expect(peaks.any((p) => p.en == en), isTrue, reason: en);
      }
    });
    test('toạ độ: qua kinh tuyến 180°, cực, điểm trùng', () {
      final s = samplePath([(0.0, 179.0), (0.0, -179.0)], 3);
      expect(s[1].$2.abs(), closeTo(180, 1e-6)); // đi qua 180°, không vòng qua 0°
      expect(samplePath([], 5), isEmpty);
      expect(samplePath([(1.0, 1.0)], 5), [(1.0, 1.0)]);
      expect(samplePath([(1.0, 1.0), (2.0, 2.0)], 0), isEmpty);
      final same = samplePath([(10.0, 10.0), (10.0, 10.0), (10.0, 10.0)], 4);
      expect(same.length, 4);
      expect(same.every((p) => !p.$1.isNaN && !p.$2.isNaN), isTrue);
      final two = samplePath([(10.0, 100.0), (12.0, 104.0)], 2);
      expect(two.first, (10.0, 100.0));
      expect(two.last.$1, closeTo(12, 1e-9));
      expect(two.last.$2, closeTo(104, 1e-9));
      final (la, lo) = offsetKm(10, 100, 111.195, 0);
      expect(la, closeTo(11, 0.01));
      expect(lo, closeTo(100, 1e-6));
      final (la2, lo2) = offsetKm(0, 179.9, 50, 90);
      expect(lo2, lessThan(-179)); // qua 180° thành kinh độ âm
      expect(la2, closeTo(0, 0.01));
      expect(distKm(0, 0, 0, 180), closeTo(20015, 5));
      expect(distKm(21, 105.8, 10.8, 106.7), closeTo(distKm(10.8, 106.7, 21, 105.8), 1e-9));
      expect(distKm(5, 5, 5, 5), 0);
      for (var i = 1; i < vnSpine.length; i++) {
        expect(distKm(vnSpine[i - 1].$3, vnSpine[i - 1].$4, vnSpine[i].$3, vnSpine[i].$4), lessThan(400), reason: vnSpine[i].$1);
      }
    });
  });

  group('lưới độ cao + ô chi tiết', () {
    late Terrain t;
    setUp(() {
      final bytes = File('assets/world/elev_glob.bin').readAsBytesSync();
      t = Terrain(MockClient((r) async => http.Response('', 404)))
        ..setGlobal(bytes.buffer.asInt16List(bytes.offsetInBytes, bytes.length ~/ 2));
    });

    test('mép bản đồ không văng lỗi, không NaN', () {
      for (final (la, lo) in [(90.0, 0.0), (-90.0, 0.0), (95.0, 10.0), (0.0, -180.0), (0.0, 180.0), (0.0, 540.0), (45.0, -720.0)]) {
        final e = t.globalAt(la, lo);
        expect(e.isNaN, isFalse, reason: '($la, $lo)');
      }
      expect((t.globalAt(0, -180) - t.globalAt(0, 180)).abs(), lessThan(1));
    });
    test('lưới sai cỡ bị bỏ qua', () {
      final x = Terrain(http.Client())..setGlobal(Int16List(10));
      expect(x.ready, isFalse);
      expect(x.globalAt(0, 0).isNaN, isTrue);
    });
    test('nhiều điểm quen thuộc hợp lý', () {
      expect(t.globalAt(30.0, 90.0), greaterThan(4000)); // Tây Tạng
      expect(t.globalAt(-15, -70), greaterThan(3000)); // Andes / Altiplano
      expect(t.globalAt(23, 10), greaterThan(200)); // Sahara
      expect(t.globalAt(-3, -60), lessThan(200)); // Amazon
      expect(t.globalAt(72, -40), greaterThan(2000)); // băng Greenland
      expect(t.globalAt(0, -150), lessThan(-3000)); // giữa Thái Bình Dương
      expect(t.globalAt(15, 113), lessThan(-1000)); // Biển Đông sâu
      expect(t.globalAt(22.3, 103.8), greaterThan(t.globalAt(21.0, 105.85))); // Hoàng Liên Sơn > Hà Nội
      expect(t.globalAt(11.94, 108.44), greaterThan(t.globalAt(10.78, 106.7))); // Đà Lạt > TP HCM
    });
    test('ô Terrarium: giải mã, kẹp số, khoá ô', () {
      expect(Terrain.terrariumToElev(Uint8List.fromList([255, 255, 255, 255])), [9000]);
      expect(Terrain.terrariumToElev(Uint8List.fromList([0, 0, 0, 255])), [-12000]);
      expect(Terrain.terrariumToElev(Uint8List.fromList([128, 0, 128, 255])), [1]); // 0,5 m làm tròn lên
      expect(Terrain.terrariumToElev(Uint8List(0)), isEmpty);
      expect(Terrain.tileOf(89.9, 0, 5).$3, 0); // vĩ độ quá 85° kẹp lại
      expect(Terrain.tileOf(-89.9, 0, 5).$3, 31);
      expect(Terrain.tileOf(0, 180, 4).$2, 0); // kinh độ 180° quay về ô 0
      expect(Terrain.tileOf(0, -180, 4).$2, 0);
      expect(Terrain.tileOf(0, 179.99, 4).$2, 15);
      final keys = <int>{};
      for (var z = 0; z <= 12; z++) {
        for (final x in [0, 1, (1 << z) - 1]) {
          for (final y in [0, 1, (1 << z) - 1]) {
            final k = Terrain.key(z, x, y);
            keys.add(k);
            expect(Terrain.keyZ(k), z);
          }
        }
      }
      expect(keys.length, greaterThan(100)); // không trùng khoá
    });
    test('mạng lỗi → vẫn trả độ cao từ lưới, không treo', () async {
      final sw = Stopwatch()..start();
      final e = await t.precise(21.03, 105.85);
      expect(e, closeTo(t.globalAt(21.03, 105.85), 1e-9));
      final ring = await t.ring(12, 108, 10);
      expect(ring.length, 8);
      expect(ring.every((x) => !x.isNaN), isTrue);
      final line = await t.line([(23.3, 105.3), (8.6, 104.7)], 20, z: 6);
      expect(line.length, 20);
      expect(sw.elapsed.inSeconds, lessThan(8));
      expect(await t.precise(88, 0), t.globalAt(88, 0)); // gần cực: không tải ô
    });
    test('tải ô PNG thật → độ cao chính xác ở mọi điểm trong ô', () async {
      var calls = 0;
      final png = terrariumPng(3143);
      final tt = Terrain(MockClient((r) async {
        calls++;
        return http.Response.bytes(png, 200);
      }))
        ..setGlobal(Int16List(Terrain.gw * Terrain.gh));
      final e = await tt.precise(22.3033, 103.7750, z: 11);
      expect(e, closeTo(3143, 1));
      expect(tt.at(22.3033, 103.7750), closeTo(3143, 1));
      // điểm khác trong cùng ô: không tải lại
      final before = calls;
      final (z, x, y) = Terrain.tileOf(22.3033, 103.7750, 11);
      expect(tt.hasTile(z, x, y), isTrue);
      await tt.precise(22.3033, 103.7750, z: 11);
      expect(calls, before);
      // điểm ngoài ô (chưa tải, mạng trả ô khác) vẫn có số
      expect(tt.at(0, 0).isNaN, isFalse);
    });
    test('ô lỗi một lần thì 60 giây sau mới thử lại (không dội máy chủ)', () async {
      var calls = 0;
      final tt = Terrain(MockClient((r) async {
        calls++;
        return http.Response('', 500);
      }))
        ..setGlobal(Int16List(Terrain.gw * Terrain.gh));
      await tt.precise(10, 106);
      final c1 = calls;
      await tt.precise(10, 106);
      await tt.precise(10, 106);
      expect(calls, c1);
    });
  });
}
