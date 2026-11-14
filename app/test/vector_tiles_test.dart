// Bản đồ sông suối, hồ, rừng, đường cho RÊ TAY: giải mã ô vector (Mapbox Vector Tile) và đổi sang đối tượng bản đồ.
// Ô thử được MÃ HOÁ ngay trong test (đúng chuẩn MVT 2.1) để kiểm tra bộ giải mã viết tay.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:earthsense/live/geo_around.dart';
import 'package:earthsense/live/vector_tiles.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------- bộ mã hoá protobuf / MVT tối giản cho test ----------
List<int> _var(int v) {
  final o = <int>[];
  while (v >= 0x80) {
    o.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  o.add(v);
  return o;
}

List<int> _key(int f, int w) => _var((f << 3) | w);
List<int> _bytes(int f, List<int> b) => [..._key(f, 2), ..._var(b.length), ...b];
List<int> _str(int f, String s) => _bytes(f, utf8.encode(s));
int _zz(int n) => n >= 0 ? n * 2 : -n * 2 - 1;

/// Hình học: danh sách vòng/đường; vùng thì tự đóng (ClosePath).
List<int> _geom(List<List<(int, int)>> rings, {bool close = false, bool point = false}) {
  final g = <int>[];
  var cx = 0, cy = 0;
  for (final r in rings) {
    g.add((1 << 3) | 1); // MoveTo 1
    g
      ..add(_zz(r[0].$1 - cx))
      ..add(_zz(r[0].$2 - cy));
    cx = r[0].$1;
    cy = r[0].$2;
    if (point) continue;
    final rest = close ? r.sublist(1) : r.sublist(1);
    g.add((rest.length << 3) | 2); // LineTo n
    for (final p in rest) {
      g
        ..add(_zz(p.$1 - cx))
        ..add(_zz(p.$2 - cy));
      cx = p.$1;
      cy = p.$2;
    }
    if (close) g.add((1 << 3) | 7);
  }
  return g;
}

class _L {
  final String name;
  final keys = <String>[];
  final vals = <Object>[];
  final feats = <List<int>>[];
  _L(this.name);
  int _k(String k) => keys.contains(k) ? keys.indexOf(k) : (keys..add(k)).length - 1;
  int _v(Object v) => vals.contains(v) ? vals.indexOf(v) : (vals..add(v)).length - 1;
  void add(int type, Map<String, Object> tags, List<int> geom) {
    final t = <int>[];
    tags.forEach((k, v) => t
      ..add(_k(k))
      ..add(_v(v)));
    final packedTags = [for (final x in t) ..._var(x)];
    final packedGeom = [for (final x in geom) ..._var(x)];
    feats.add([..._bytes(2, packedTags), ..._key(3, 0), ..._var(type), ..._bytes(4, packedGeom)]);
  }

  List<int> encode() {
    final b = <int>[..._key(15, 0), ..._var(2), ..._str(1, name)];
    for (final f in feats) {
      b.addAll(_bytes(2, f));
    }
    for (final k in keys) {
      b.addAll(_str(3, k));
    }
    for (final v in vals) {
      final vb = v is String ? _str(1, v) : [..._key(5, 0), ..._var(v as int)];
      b.addAll(_bytes(4, vb));
    }
    b.addAll([..._key(5, 0), ..._var(4096)]);
    return b;
  }
}

Uint8List _tile(List<_L> layers) => Uint8List.fromList([for (final l in layers) ..._bytes(3, l.encode())]);

void main() {
  // ô thử: z14, ô chứa tâm (lat, lon); dùng toạ độ ô để đặt đối tượng
  const z = 14;
  const lat = 11.942, lon = 108.442; // Hồ Xuân Hương, Đà Lạt
  final n = 1 << z;
  final tx = ((lon + 180) / 360 * n).floor();
  final s = math.sin(lat * math.pi / 180);
  final wy = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * n;
  final ty = wy.floor();
  final cx = (((lon + 180) / 360 * n) - tx) * 4096, cy = (wy - ty) * 4096;
  (int, int) at(double dxM, double dyM) {
    // mét → toạ độ ô (1 đơn vị ô ≈ chu vi·cos(lat) / 2^z / 4096 mét)
    final mPerUnit = 40075016.686 * math.cos(lat * math.pi / 180) / n / 4096;
    return ((cx + dxM / mPerUnit).round(), (cy - dyM / mPerUnit).round());
  }

  final water = _L('water')
    // hồ vuông 400 m quanh tâm, có đảo 100 m ở giữa (vòng trong ngược chiều)
    ..add(3, {'class': 'lake'}, _geom([
      [at(-200, 200), at(200, 200), at(200, -200), at(-200, -200)],
      [at(-50, 50), at(-50, -50), at(50, -50), at(50, 50)],
    ], close: true))
    ..add(3, {'class': 'swimming_pool'}, _geom([
      [at(500, 500), at(520, 500), at(520, 480), at(500, 480)]
    ], close: true));
  final waterName = _L('water_name')..add(1, {'class': 'lake', 'name': 'Hồ Xuân Hương'}, _geom([[at(120, 120)]], point: true));
  final waterway = _L('waterway')
    ..add(2, {'class': 'stream', 'name': 'Suối Cam Ly'}, _geom([[at(-1000, 600), at(-300, 600), at(-300, 1000)]]))
    ..add(2, {'class': 'stream'}, _geom([[at(600, -900), at(900, -900)]]))
    ..add(2, {'class': 'ditch'}, _geom([[at(0, -700), at(100, -700)]]));
  final landcover = _L('landcover')
    ..add(3, {'class': 'wood', 'subclass': 'forest'}, _geom([
      [at(400, -200), at(900, -200), at(900, -600), at(400, -600)]
    ], close: true));
  final transportName = _L('transportation_name')
    ..add(2, {'class': 'secondary', 'name': 'Trần Quốc Toản'}, _geom([[at(-600, -300), at(600, -300)]]));
  final peak = _L('mountain_peak')..add(1, {'class': 'peak', 'name': 'Đồi Cù', 'ele': 1520}, _geom([[at(-700, -800)]], point: true));
  final far = _L('park')
    ..add(3, {'class': 'park', 'name': 'Rất xa'}, _geom([
      [at(5000, 5000), at(5200, 5000), at(5200, 4800)]
    ], close: true));
  final bytes = _tile([water, waterName, waterway, landcover, transportName, peak, far]);

  test('giải mã đúng lớp, thẻ, số đối tượng', () {
    final ls = decodeMvt(bytes);
    expect(ls.map((l) => l.name), containsAll(['water', 'waterway', 'landcover', 'mountain_peak']));
    final ww = ls.firstWhere((l) => l.name == 'waterway');
    expect(ww.extent, 4096);
    expect(ww.features.length, 3);
    expect(ww.features.first.tags['name'], 'Suối Cam Ly');
    expect(ww.features.first.rings.first.length, 3);
    final pk = ls.firstWhere((l) => l.name == 'mountain_peak').features.first;
    expect(pk.type, 1);
    expect(pk.tags['ele'], 1520);
    final lake = ls.firstWhere((l) => l.name == 'water').features.first;
    expect(lake.rings.length, 2); // vòng ngoài + đảo
    expect(lake.rings.first.first, lake.rings.first.last); // ClosePath
    expect(ringArea(lake.rings[0]) > 0, isNot(ringArea(lake.rings[1]) > 0));
    expect(decodeMvt(bytes, wanted: {'water'}).map((l) => l.name).toList(), ['water']);
  });

  final feats = featuresFromTile(decodeMvt(bytes), z, tx, ty, lat, lon, 1200);
  AroundData data() => AroundData(lat, lon, 1200, feats, 1500, List.filled(8, double.nan), null, 10);

  test('đổi sang đối tượng bản đồ: đúng loại, tên, toạ độ mét', () {
    final lake = feats.firstWhere((f) => f.kind == 'water');
    expect(lake.name, 'Hồ Xuân Hương'); // tên lấy từ lớp water_name
    expect(lake.evenOdd, isTrue);
    expect(feats.where((f) => f.name == 'Rất xa'), isEmpty); // ngoài khung
    expect(feats.where((f) => f.kind == 'water').length, 1); // bể bơi bị bỏ
    final camly = feats.firstWhere((f) => f.name == 'Suối Cam Ly');
    expect(camly.kind, 'river');
    expect(camly.area, isFalse);
    expect(camly.parts.first[0], closeTo(-1000, 6));
    expect(camly.parts.first[1], closeTo(600, 6));
    expect(feats.where((f) => f.kind == 'river' && f.name == 'suối').length, 1); // suối không tên
    expect(feats.where((f) => f.kind == 'river').length, 2); // mương (ditch) bị bỏ
    final pk = feats.firstWhere((f) => f.kind == 'peak');
    expect(pk.name, 'Đồi Cù');
    expect(pk.ele, 1520);
    expect(feats.firstWhere((f) => f.kind == 'forest').name, 'rừng cây');
    expect(feats.firstWhere((f) => f.kind == 'road').name, 'Trần Quốc Toản');
  });

  test('chạm đúng chỗ → đúng đối tượng (kể cả đảo giữa hồ, suối mảnh)', () {
    final d = data();
    expect(d.classify(150, 150).$2?.name, 'Hồ Xuân Hương');
    expect(d.classify(0, 0).$1, isNot('water')); // đảo giữa hồ
    expect(d.classify(-600, 605).$2?.name, 'Suối Cam Ly'); // sát suối
    expect(d.classify(-600, 660).$1, isNot('river')); // cách suối 60 m: không còn là suối
    expect(d.classify(650, -400).$1, 'forest');
    expect(d.classify(0, -302).$2?.name, 'Trần Quốc Toản');
    expect(d.classify(-900, -100).$1, 'land');
  });
}
