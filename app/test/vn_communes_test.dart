// KIỂM TRA ĐỦ MỌI XÃ, PHƯỜNG: lấy đúng 3.321 xã, phường, đặc khu (sau 1/7/2025) + 10.035 xã cũ + 691 huyện cũ, ghép vào
// nhiều kiểu câu người khiếm thị hay nói, cho chạy qua bộ tách lệnh rồi tra danh bạ → phải ra ĐÚNG nơi đó.
// Gom hết lỗi, ghi build/vn_communes_report.txt.
import 'dart:convert';
import 'dart:io';

import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/live/live_weather.dart' show WeatherService;
import 'package:earthsense/live/vn_admin.dart';
import 'package:earthsense/live/vn_gazetteer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final gz = VnGazetteer.fromJson(jsonDecode(File('assets/data/vn_dvhc.json').readAsStringSync()) as Map<String, dynamic>);
  vnPlaceNameKnown = gz.knows;
  vnPlaceNameKnownExact = gz.knowsExact;
  final report = <String>[];
  tearDownAll(() {
    try {
      Directory('build').createSync(recursive: true);
      File('build/vn_communes_report.txt').writeAsStringSync(report.join('\n'));
    } catch (_) {}
  });

  String low(String t) => t[0].toLowerCase() + t.substring(1);

  test('dữ liệu đủ 34 tỉnh, 3.321 xã, phường', () {
    expect(gz.provinces.length, 34);
    expect(gz.wards.length, 3321);
    expect(gz.olds.length, greaterThan(10000));
    for (final w in gz.wards) {
      expect(w.$5, inInclusiveRange(8.0, 23.5), reason: w.$3);
      expect(w.$6, inInclusiveRange(102.0, 117.5), reason: w.$3);
    }
  });

  test('mọi xã, phường mới: hỏi thời tiết kèm tỉnh → đúng nơi', () {
    final fails = <String>[];
    var n = 0;
    for (final w in gz.wards) {
      final p = gz.provinces[w.$4].$2;
      final want = '${low(w.$2)} ${w.$3}, $p';
      for (final s in [
        'thời tiết ${low(w.$2)} ${w.$3}, $p',
        '${low(w.$2)} ${w.$3} $p có mưa không',
        'nhiệt độ ở ${low(w.$2)} ${w.$3} $p hôm nay',
        'ngày mai ${low(w.$2)} ${w.$3} $p thế nào',
      ]) {
        n++;
        final c = parseWorld(s);
        if (c.kind != WKind.weather) {
          fails.add('"$s" → $c');
          continue;
        }
        final hits = gz.find(c.target);
        if (hits.isEmpty || hits.first.label != want) {
          fails.add('"$s" → target "${c.target}" → ${hits.isEmpty ? 'KHÔNG THẤY' : hits.first.label}');
        }
      }
    }
    report
      ..add('=== XÃ MỚI + TỈNH: ${n - fails.length}/$n')
      ..addAll(fails);
    expect(fails, isEmpty, reason: fails.take(40).join('\n'));
  });

  test('mọi xã, phường mới: không nói tỉnh → vẫn có trong các nơi tìm được', () {
    final fails = <String>[];
    var n = 0;
    for (final w in gz.wards) {
      final p = gz.provinces[w.$4].$2;
      final want = '${low(w.$2)} ${w.$3}, $p';
      for (final s in ['thời tiết ${low(w.$2)} ${w.$3}', '${low(w.$2)} ${w.$3} có mưa không']) {
        n++;
        final c = parseWorld(s);
        final hits = gz.find(c.target);
        if (c.kind != WKind.weather || !hits.any((h) => h.label == want)) {
          fails.add('"$s" → $c → ${hits.map((h) => h.label).take(3).join(' | ')}');
        }
      }
    }
    report
      ..add('=== XÃ MỚI, KHÔNG TỈNH: ${n - fails.length}/$n')
      ..addAll(fails);
    expect(fails, isEmpty, reason: fails.take(40).join('\n'));
  });

  test('mọi xã, phường, thị trấn CŨ → nơi mới chứa nó', () {
    final fails = <String>[];
    var n = 0;
    final byCode = {for (final w in gz.wards) w.$1: w};
    for (final o in gz.olds) {
      final w = byCode[o.$3]!;
      final oldProv = gz.districts[o.$2].$2.replaceFirst(RegExp(r'^(Tỉnh|Thành phố)\s+'), '');
      final s = 'thời tiết ${low(o.$1)} $oldProv';
      n++;
      final c = parseWorld(s);
      final hits = gz.find(c.target);
      if (c.kind != WKind.weather || !hits.any((h) => (h.lat - w.$5).abs() < 1e-6 && (h.lon - w.$6).abs() < 1e-6)) {
        fails.add('"$s" → target "${c.target}" → ${hits.map((h) => h.label).take(2).join(' | ')} (mong: ${w.$2} ${w.$3})');
      }
    }
    report
      ..add('=== XÃ CŨ: ${n - fails.length}/$n')
      ..addAll(fails.take(300));
    // tên cũ trùng nhau trong cùng tỉnh cũ (vài chục trường hợp) → chấp nhận tối đa 2 %
    expect(fails.length, lessThan(n * 0.02), reason: fails.take(40).join('\n'));
  });

  test('mọi huyện, quận, thị xã CŨ → vùng đó', () {
    final fails = <String>[];
    var n = 0;
    for (final d in gz.districts) {
      final oldProv = d.$2.replaceFirst(RegExp(r'^(Tỉnh|Thành phố)\s+'), '');
      final s = 'thời tiết ${low(d.$1)} $oldProv';
      n++;
      final c = parseWorld(s);
      final hits = gz.find(c.target);
      if (c.kind != WKind.weather || hits.isEmpty || hits.first.kind != 'oldDistrict' && hits.first.kind != 'ward') {
        fails.add('"$s" → target "${c.target}" → ${hits.map((h) => h.label).take(2).join(' | ')}');
      }
    }
    report
      ..add('=== HUYỆN CŨ: ${n - fails.length}/$n')
      ..addAll(fails);
    expect(fails.length, lessThan(n * 0.03), reason: fails.take(40).join('\n'));
  });

  test('câu hay gặp, tên dễ nhầm', () {
    List<String> f(String s) => gz.find(parseWorld(s).target).map((h) => h.label).toList();
    expect(f('thời tiết xã Gia Lâm'), contains('xã Gia Lâm, Hà Nội'));
    expect(f('thời tiết huyện Gia Lâm').first, 'huyện Gia Lâm cũ, Hà Nội');
    expect(f('thời tiết xã Đặng Xá Hà Nội').first, contains('nay thuộc'));
    expect(f('thời tiết phường Hải Châu Đà Nẵng').first, 'phường Hải Châu, Đà Nẵng');
    expect(f('thời tiết xã Tân Lập, Tây Ninh').first, 'xã Tân Lập, Tây Ninh');
    expect(f('thời tiết xã Tân Lập').length, greaterThan(3)); // nhiều tỉnh có xã Tân Lập → app hỏi lại / chọn gần
    expect(f('thời tiết phường Lâm Viên - Đà Lạt').first, 'phường Lâm Viên - Đà Lạt, Lâm Đồng');
    expect(f('thời tiết phường Sa Pa').first, 'phường Sa Pa, Lào Cai');
    expect(f('thời tiết đặc khu Phú Quốc').first, 'đặc khu Phú Quốc, An Giang');
    expect(f('thời tiết quận Hoàn Kiếm').first, 'quận Hoàn Kiếm cũ, Hà Nội');
    expect(f('thời tiết xã Mường Hoa tỉnh Lào Cai'), isNotEmpty);
    expect(gz.find('salon tóc'), isEmpty);
    expect(gz.find('cảng nội địa'), isEmpty);
  });

  test('GPS → xã, phường gần nhất', () {
    final hn = gz.nearest(21.0285, 105.8542)!;
    expect(hn.$1.label, contains('Hà Nội'));
    expect(hn.$2, lessThan(3));
    expect(gz.nearest(10.7769, 106.7009)!.$1.label, contains('Hồ Chí Minh'));
    expect(gz.nearest(11.9404, 108.4583)!.$1.label, contains('Lâm Đồng'));
    expect(gz.nearest(22.3364, 103.8438)!.$1.label, contains('Lào Cai')); // Sa Pa
    expect(gz.nearest(1.0, 1.0), isNull); // ngoài Việt Nam
    expect(gz.nearest(35.68, 139.69), isNull); // Tô-ky-ô
    // mọi xã: đứng ngay trụ sở → ra đúng xã đó
    var wrong = 0;
    for (final w in gz.wards) {
      final r = gz.nearest(w.$5, w.$6)!;
      if (r.$1.short != w.$3) wrong++;
    }
    expect(wrong, lessThan(5)); // vài trụ sở dùng chung toà nhà
  });

  test('tên TỈNH: 34 tỉnh mới và 63 tỉnh cũ (đã sáp nhập) đều ra đúng tỉnh hiện nay', () {
    VnHit one(String s) {
      final h = gz.find(s);
      expect(h, isNotEmpty, reason: s);
      return h.first;
    }

    // tỉnh cũ → tỉnh mới (đây là lỗi thật: "thời tiết Đắk Nông" từng ra xã Đăk Nông ở Quảng Ngãi)
    expect(one('Đắk Nông').label, 'tỉnh Đắk Nông cũ, nay thuộc tỉnh Lâm Đồng');
    expect(one('đắk nông').province, 'Lâm Đồng');
    expect(one('tỉnh Hà Giang').province, 'Tuyên Quang');
    expect(one('Quảng Bình').province, 'Quảng Trị');
    expect(one('Bình Dương').province, 'Hồ Chí Minh');
    expect(one('Bà Rịa Vũng Tàu').province, 'Hồ Chí Minh');
    expect(one('Kon Tum').province, 'Quảng Ngãi');
    expect(one('Thừa Thiên Huế').province, 'Huế');
    expect(one('Sài Gòn').label, 'thành phố Hồ Chí Minh');
    // toạ độ tỉnh cũ nằm trong vùng tỉnh cũ (Đắk Nông: khoảng 11,7–12,9 độ bắc, 107,2–108,2 độ đông)
    final dn = one('Đắk Nông');
    expect(dn.lat, inInclusiveRange(11.7, 12.9));
    expect(dn.lon, inInclusiveRange(107.2, 108.2));
    // toạ độ = TỈNH LỴ (hỏi thời tiết "Lâm Đồng" là hỏi Đà Lạt; TP.HCM là trung tâm, không phải Bình Dương cũ)
    final hcm = one('thành phố Hồ Chí Minh');
    expect((hcm.lat - 10.777).abs() < 0.05 && (hcm.lon - 106.70).abs() < 0.05, isTrue, reason: '$hcm');
    final ld = one('Lâm Đồng');
    expect((ld.lat - 11.94).abs() < 0.05 && (ld.lon - 108.46).abs() < 0.05, isTrue, reason: '$ld');
    // đủ 34 tỉnh + 29 tỉnh cũ đều có tỉnh lỵ, và tỉnh lỵ nằm trong Việt Nam
    for (final p in gz.provinces) {
      final h = one(p.$2);
      expect(h.lat, inInclusiveRange(8.4, 23.4), reason: p.$2);
      expect(h.lon, inInclusiveRange(102.1, 109.5), reason: p.$2);
    }
    // tỉnh, thành hiện nay
    expect(one('Lâm Đồng').label, 'tỉnh Lâm Đồng');
    expect(one('thành phố Huế').label, 'thành phố Huế');
    expect(one('Hà Nội').kind, 'province');
    // đủ 63 tỉnh cũ
    var old = 0;
    for (final d in {for (final x in gz.districts) x.$2}) {
      final name = d.replaceFirst(RegExp(r'^(Tỉnh|Thành phố)\s+'), '');
      final h = gz.find(name);
      expect(h, isNotEmpty, reason: name);
      expect(h.first.kind, anyOf('province', 'oldProvince'), reason: name);
      old++;
    }
    expect(old, 63);
    // có "xã", "phường", "huyện" phía trước thì KHÔNG hiểu thành tỉnh
    expect(gz.find('phường Long An').first.label, 'phường Long An, Tây Ninh');
    expect(gz.find('thành phố Lào Cai').first.kind, isNot('province'));
    expect(gz.find('huyện Gia Lâm').first.kind, 'oldDistrict');
  });

  test('tìm địa điểm: KHÔNG nhận cửa hàng, salon, công ty, cảng hàng hoá', () {
    expect(WeatherService.poiAllowed('shop', 'hairdresser'), isFalse);
    expect(WeatherService.poiAllowed('shop', 'beauty'), isFalse);
    expect(WeatherService.poiAllowed('office', 'company'), isFalse);
    expect(WeatherService.poiAllowed('landuse', 'industrial'), isFalse);
    expect(WeatherService.poiAllowed('industrial', 'port'), isFalse);
    expect(WeatherService.poiAllowed('amenity', 'restaurant'), isFalse);
    expect(WeatherService.poiAllowed('amenity', 'cafe'), isFalse);
    expect(WeatherService.poiAllowed('craft', 'yes'), isFalse);
    expect(WeatherService.poiAllowed('natural', 'water'), isTrue);
    expect(WeatherService.poiAllowed('amenity', 'place_of_worship'), isTrue);
    expect(WeatherService.poiAllowed('tourism', 'attraction'), isTrue);
    expect(WeatherService.poiAllowed('leisure', 'park'), isTrue);
    expect(WeatherService.poiAllowed('historic', 'monument'), isTrue);
  });

  test('tách tỉnh khi tên xã trùng tên tỉnh cũ', () {
    expect(splitProvince('phường Long An').province, 'Tây Ninh'); // bản thân splitProvince coi là tỉnh…
    expect(gz.find('phường Long An').first.label, 'phường Long An, Tây Ninh'); // …nhưng danh bạ vẫn hiểu là phường Long An
  });
}
