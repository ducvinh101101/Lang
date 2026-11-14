// Đọc một gói dữ liệu THẬT do pipeline Python tạo (test/fixtures/data, sinh bằng:
//   python -m pipeline.synthetic --out data/raw --years 2020
//   python -m pipeline.build --raw data/raw --out app/test/fixtures/data --years 2020 --clim-years 2020)
// để chắc phần Dart đọc đúng định dạng mà Python ghi (base64, lượng tử hoá sqrt, frames phẳng).
import 'dart:io';
import 'dart:typed_data';

import 'package:earthsense/core/geo.dart';
import 'package:earthsense/data/asset_data.dart';
import 'package:earthsense/data/loader.dart';
import 'package:flutter_test/flutter_test.dart';

class _DirLoader implements DataLoader {
  final String dir;
  _DirLoader(this.dir);
  @override
  Future<String> text(String path) => File('$dir/$path').readAsString();
  @override
  Future<Uint8List> bytes(String path) => File('$dir/$path').readAsBytes();
  @override
  String describe() => dir;
}

void main() {
  test('đọc gói dữ liệu pipeline', () async {
    final d = (await AssetData.tryLoad(_DirLoader('test/fixtures/data')))!;
    expect(d.years, [2020]);
    expect(d.vars.keys.toSet(), {'temp', 'rain', 'fire'});
    expect(d.vars['rain']!.instrument, 'trung');
    expect(d.vars['rain']!.sqrtScale, isTrue);
    expect(d.vars['fire']!.instrument, 'fire');
    expect(d.geo.type.where((t) => t == cellVn).length, 2849);
    const hue = 7155;
    expect(d.geo.type[hue], cellVn);
    expect(d.geo.region[hue], 2);
    await d.ensureYear('rain', 2020);
    // Giá trị Python dequantize cho cùng ô: 820.2616…
    expect(d.values('rain', 2020, 9)[hue], closeTo(820.26, 0.05));
    expect(d.values('rain', 2020, 9)[0].isNaN, isTrue); // ô không phải đất liền
    expect(d.series(2, 'rain').length, 12);
    expect(d.version, isNotEmpty);
    expect(d.credits, isNotEmpty);
  });

  test('thiếu touchgrid.json → null (không làm app sập)', () async {
    expect(await AssetData.tryLoad(_DirLoader('test/khong-co')), isNull);
  });
}
