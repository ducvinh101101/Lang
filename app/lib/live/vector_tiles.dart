// BẢN ĐỒ SÔNG SUỐI, HỒ, RỪNG, CÔNG VIÊN, ĐƯỜNG PHỐ, ĐỈNH NÚI quanh một điểm — từ Ô BẢN ĐỒ VECTOR OpenStreetMap
// (OpenFreeMap, lược đồ OpenMapTiles). Nhanh và ổn định hơn hỏi máy chủ Overpass công cộng (hay quá tải, có lúc
// không trả lời): ô bản đồ nằm trên CDN, mức 14 ≈ 2,3 km mỗi ô → khung rê tay 2,4 km chỉ cần 1–4 ô, mỗi ô ~50–300 KB.
// Miễn phí, không cần khoá, trình duyệt gọi thẳng được (CORS). Dữ liệu © OpenStreetMap contributors.
//
// Giải mã định dạng Mapbox Vector Tile (protobuf) viết tay ở đây (không cần thư viện), rồi đổi sang OsmFeature
// (toạ độ MÉT quanh tâm) để bản đồ rê tay vẽ và đọc tên đúng chỗ ngón tay.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'geo_around.dart' show OsmFeature;

// ============================ giải mã Mapbox Vector Tile ============================

class MvtFeature {
  final int type; // 1 điểm, 2 đường, 3 vùng
  final Map<String, Object?> tags;
  final List<List<(int, int)>> rings; // toạ độ trong ô (0..extent)
  MvtFeature(this.type, this.tags, this.rings);
}

class MvtLayer {
  final String name;
  final int extent;
  final List<MvtFeature> features;
  MvtLayer(this.name, this.extent, this.features);
}

class _Pb {
  final Uint8List b;
  int p;
  final int end;
  _Pb(this.b, [this.p = 0, int? end]) : end = end ?? b.length;
  bool get eof => p >= end;
  int varint() {
    var r = 0, mul = 1;
    while (true) {
      final c = b[p++];
      r += (c & 0x7f) * mul;
      if (c < 0x80) return r;
      mul *= 128;
    }
  }

  _Pb sub() {
    final n = varint();
    final s = _Pb(b, p, p + n);
    p += n;
    return s;
  }

  String str() {
    final n = varint();
    final s = utf8.decode(Uint8List.sublistView(b, p, p + n), allowMalformed: true);
    p += n;
    return s;
  }

  void skip(int wire) {
    switch (wire) {
      case 0:
        varint();
      case 1:
        p += 8;
      case 2:
        p += varint();
      case 5:
        p += 4;
      default:
        throw FormatException('wire $wire');
    }
  }
}

int _zz(int n) => (n & 1) == 1 ? -((n + 1) >> 1) : n >> 1;

/// Giải mã một ô vector (chỉ giữ các lớp trong [wanted], null = tất cả).
List<MvtLayer> decodeMvt(Uint8List bytes, {Set<String>? wanted}) {
  final out = <MvtLayer>[];
  final r = _Pb(bytes);
  while (!r.eof) {
    final key = r.varint();
    if (key >> 3 == 3 && key & 7 == 2) {
      final l = _layer(r.sub(), wanted);
      if (l != null) out.add(l);
    } else {
      r.skip(key & 7);
    }
  }
  return out;
}

MvtLayer? _layer(_Pb r, Set<String>? wanted) {
  var name = '';
  var extent = 4096;
  final keys = <String>[];
  final vals = <Object?>[];
  final raw = <_Pb>[];
  while (!r.eof) {
    final key = r.varint(), f = key >> 3, w = key & 7;
    if (f == 1 && w == 2) {
      name = r.str();
      if (wanted != null && !wanted.contains(name)) return null;
    } else if (f == 2 && w == 2) {
      raw.add(r.sub());
    } else if (f == 3 && w == 2) {
      keys.add(r.str());
    } else if (f == 4 && w == 2) {
      vals.add(_value(r.sub()));
    } else if (f == 5 && w == 0) {
      extent = r.varint();
    } else {
      r.skip(w);
    }
  }
  return MvtLayer(name, extent, [for (final fr in raw) _feature(fr, keys, vals)]);
}

Object? _value(_Pb r) {
  Object? v;
  while (!r.eof) {
    final key = r.varint(), f = key >> 3, w = key & 7;
    switch (f) {
      case 1:
        v = r.str();
      case 2:
        v = ByteData.sublistView(r.b, r.p, r.p + 4).getFloat32(0, Endian.little);
        r.p += 4;
      case 3:
        v = ByteData.sublistView(r.b, r.p, r.p + 8).getFloat64(0, Endian.little);
        r.p += 8;
      case 4 || 5:
        v = r.varint();
      case 6:
        v = _zz(r.varint());
      case 7:
        v = r.varint() != 0;
      default:
        r.skip(w);
    }
  }
  return v;
}

MvtFeature _feature(_Pb r, List<String> keys, List<Object?> vals) {
  var type = 0;
  final tags = <String, Object?>{};
  final geom = <int>[];
  while (!r.eof) {
    final key = r.varint(), f = key >> 3, w = key & 7;
    if (f == 2 && w == 2) {
      final s = r.sub();
      while (!s.eof) {
        final k = s.varint();
        final v = s.eof ? 0 : s.varint();
        if (k < keys.length && v < vals.length) tags[keys[k]] = vals[v];
      }
    } else if (f == 3 && w == 0) {
      type = r.varint();
    } else if (f == 4 && w == 2) {
      final s = r.sub();
      while (!s.eof) {
        geom.add(s.varint());
      }
    } else {
      r.skip(w);
    }
  }
  // lệnh hình học: MoveTo(1) / LineTo(2) / ClosePath(7), toạ độ cộng dồn dạng zigzag
  final rings = <List<(int, int)>>[];
  var x = 0, y = 0, i = 0;
  List<(int, int)>? cur;
  while (i < geom.length) {
    final c = geom[i++];
    final id = c & 7, n = c >> 3;
    if (id == 1 || id == 2) {
      for (var k = 0; k < n; k++) {
        if (i + 1 >= geom.length) break;
        x += _zz(geom[i++]);
        y += _zz(geom[i++]);
        if (id == 1) {
          cur = [(x, y)];
          rings.add(cur);
        } else {
          cur?.add((x, y));
        }
      }
    } else if (id == 7) {
      if (cur != null && cur.isNotEmpty) cur.add(cur.first);
    } else {
      break;
    }
  }
  return MvtFeature(type, tags, rings);
}

/// Diện tích có dấu của vòng (toạ độ ô, y hướng xuống): > 0 là vòng NGOÀI theo chuẩn MVT.
double ringArea(List<(int, int)> r) {
  var a = 0.0;
  for (var i = 0; i + 1 < r.length; i++) {
    a += r[i].$1 * r[i + 1].$2 - r[i + 1].$1 * r[i].$2;
  }
  return a / 2;
}

// ============================ tải ô + đổi sang đối tượng bản đồ ============================

const _tileJson = 'https://tiles.openfreemap.org/planet';
const _fallbackTemplate = 'https://tiles.openfreemap.org/planet/20261101_080013_pt/{z}/{x}/{y}.pbf';
String? _template;
final _tileCache = <String, Uint8List>{};

Future<String> _tileTemplate(http.Client c) async {
  final t = _template;
  if (t != null) return t;
  try {
    final r = await c.get(Uri.parse(_tileJson)).timeout(const Duration(seconds: 6));
    if (r.statusCode == 200) {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final tiles = j is Map ? j['tiles'] : null;
      if (tiles is List && tiles.isNotEmpty && tiles.first is String) return _template = tiles.first as String;
    }
  } catch (_) {}
  return _fallbackTemplate;
}

const _layers = {
  'water', 'waterway', 'water_name', 'landcover', 'landuse', 'park', 'transportation', 'transportation_name',
  'mountain_peak', 'place',
};

/// Đối tượng bản đồ quanh (lat, lon) trong khung ±[radius] mét. null nếu không tải được ô nào.
Future<List<OsmFeature>?> loadVectorFeatures(double lat, double lon, double radius,
    {http.Client? client, int zoom = 14, void Function(String)? log}) async {
  final c = client ?? http.Client();
  try {
    final tpl = await _tileTemplate(c);
    final kx = 111320.0 * math.cos(lat * math.pi / 180), ky = 110540.0;
    final dLat = radius / ky, dLon = radius / kx;
    final n = 1 << zoom;
    int tx(double lo) => ((lo + 180) / 360 * n).floor();
    int ty(double la) {
      final s = math.sin(la * math.pi / 180);
      return ((0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * n).floor();
    }

    final x0 = tx(lon - dLon), x1 = tx(lon + dLon), y0 = ty(lat + dLat), y1 = ty(lat - dLat);
    final jobs = <Future<(int, int, Uint8List?)>>[];
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        final url = tpl.replaceAll('{z}', '$zoom').replaceAll('{x}', '$x').replaceAll('{y}', '$y');
        jobs.add(() async {
          final hit = _tileCache[url];
          if (hit != null) return (x, y, hit);
          try {
            final r = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
            if (r.statusCode != 200) return (x, y, null);
            if (_tileCache.length > 24) _tileCache.remove(_tileCache.keys.first);
            return (x, y, _tileCache[url] = r.bodyBytes);
          } catch (e) {
            log?.call('[ô bản đồ vector] $e');
            return (x, y, null);
          }
        }());
      }
    }
    final tiles = await Future.wait(jobs);
    if (tiles.every((t) => t.$3 == null)) return null;
    final out = <OsmFeature>[];
    for (final (x, y, bytes) in tiles) {
      if (bytes == null) continue;
      try {
        out.addAll(featuresFromTile(decodeMvt(bytes, wanted: _layers), zoom, x, y, lat, lon, radius));
      } catch (e) {
        log?.call('[giải mã ô $x/$y] $e');
      }
    }
    return out;
  } finally {
    if (client == null) c.close();
  }
}

/// Đổi các lớp của một ô (z, x, y) sang đối tượng bản đồ, toạ độ mét quanh (lat, lon); bỏ những gì ngoài khung.
List<OsmFeature> featuresFromTile(List<MvtLayer> layers, int z, int tx, int ty, double lat, double lon, double radius) {
  final kx = 111320.0 * math.cos(lat * math.pi / 180), ky = 110540.0;
  final n = (1 << z).toDouble();
  final lim = radius * 1.4;
  Float32List? conv(List<(int, int)> ring, int extent, {bool clip = false}) {
    final pts = <double>[];
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    double? lx, ly;
    for (final (rx, ry) in ring) {
      // vùng: cắt về đúng khung ô (ô vector có viền đệm chồng sang ô bên cạnh → tô 2 lần thành vệt sáng ở mép ô)
      final px = clip ? rx.clamp(0, extent) : rx, py = clip ? ry.clamp(0, extent) : ry;
      final wx = (tx + px / extent) / n, wy = (ty + py / extent) / n;
      final lo = wx * 360 - 180;
      final la = math.atan(_sinh(math.pi * (1 - 2 * wy))) * 180 / math.pi;
      final mx = (lo - lon) * kx, my = (la - lat) * ky;
      if (lx != null && (mx - lx).abs() < 2 && (my - ly!).abs() < 2) continue; // bỏ điểm sát nhau (< 2 m)
      pts
        ..add(mx)
        ..add(my);
      lx = mx;
      ly = my;
      minX = math.min(minX, mx);
      maxX = math.max(maxX, mx);
      minY = math.min(minY, my);
      maxY = math.max(maxY, my);
    }
    if (pts.isEmpty || maxX < -lim || minX > lim || maxY < -lim || minY > lim) return null;
    return Float32List.fromList(pts);
  }

  String nameOf(Map<String, Object?> t) => '${t['name:vi'] ?? t['name'] ?? ''}'.trim();
  final out = <OsmFeature>[];
  final waterNames = <(double, double, String)>[];

  void addArea(String kind, MvtFeature f, int extent, {String? name, double? width}) {
    final parts = <Float32List>[];
    for (final r in f.rings) {
      final p = conv(r, extent, clip: true);
      if (p != null && p.length >= 6) parts.add(p);
    }
    if (parts.isNotEmpty) out.add(OsmFeature(kind, name ?? nameOf(f.tags), parts, true, evenOdd: true));
  }

  void addLine(String kind, MvtFeature f, int extent, {String? name, double? width}) {
    final parts = <Float32List>[];
    for (final r in f.rings) {
      final p = conv(r, extent);
      if (p != null && p.length >= 4) parts.add(p);
    }
    if (parts.isNotEmpty) out.add(OsmFeature(kind, name ?? nameOf(f.tags), parts, false, width: width));
  }

  for (final l in layers) {
    for (final f in l.features) {
      final cls = '${f.tags['class'] ?? ''}', sub = '${f.tags['subclass'] ?? ''}';
      switch (l.name) {
        case 'water':
          if (f.type != 3 || cls == 'swimming_pool') break;
          addArea(cls == 'river' ? 'river' : 'water', f, l.extent,
              name: nameOf(f.tags).isNotEmpty ? null : (cls == 'ocean' ? 'Biển' : ''));
        case 'water_name':
          if (f.type == 1 && f.rings.isNotEmpty && f.rings.first.isNotEmpty) {
            final p = conv([f.rings.first.first], l.extent);
            final nm = nameOf(f.tags);
            if (p != null && nm.isNotEmpty) waterNames.add((p[0], p[1], nm));
          }
        case 'waterway':
          if (f.type != 2) break;
          if (cls == 'river' || cls == 'canal') {
            addLine('river', f, l.extent, width: cls == 'river' ? 40 : 20);
          } else if (cls == 'stream') {
            addLine('river', f, l.extent, name: nameOf(f.tags).isEmpty ? 'suối' : null, width: 15);
          }
        case 'landcover':
          if (f.type != 3) break;
          final k = switch (cls) {
            'wood' => 'forest',
            'farmland' => 'farmland',
            'sand' => 'beach',
            'wetland' => 'water',
            'grass' => 'park',
            _ => null,
          };
          if (k == null) break;
          addArea(k, f, l.extent,
              name: nameOf(f.tags).isNotEmpty
                  ? null
                  : switch (cls) {
                      'wood' => 'rừng cây',
                      'wetland' => 'vùng đất ngập nước',
                      'grass' => (sub == 'park' || sub == 'garden') ? 'công viên' : 'bãi cỏ',
                      'farmland' => 'đồng ruộng',
                      'sand' => 'bãi cát',
                      _ => '',
                    });
        case 'landuse':
          if (f.type != 3) break;
          if (const {'residential', 'suburb', 'neighbourhood', 'quarter'}.contains(cls)) {
            addArea('residential', f, l.extent);
          } else if (const {'commercial', 'retail', 'industrial'}.contains(cls)) {
            addArea('residential', f, l.extent, name: cls == 'industrial' ? 'khu công nghiệp' : 'khu thương mại');
          } else if (cls == 'farmland' || cls == 'orchard') {
            addArea('farmland', f, l.extent);
          }
        case 'park':
          if (f.type == 3) addArea('park', f, l.extent);
        case 'transportation':
          if (f.type == 2 && const {'motorway', 'trunk', 'primary', 'secondary'}.contains(cls)) {
            addLine('road', f, l.extent, name: '', width: 15);
          }
        case 'transportation_name':
          if (f.type == 2 && const {'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'minor'}.contains(cls)) {
            addLine('road', f, l.extent, width: cls == 'minor' || cls == 'tertiary' ? 10 : 15);
          }
        case 'mountain_peak':
          if (f.type == 1 && f.rings.isNotEmpty && f.rings.first.isNotEmpty) {
            final p = conv([f.rings.first.first], l.extent);
            final ele = f.tags['ele'];
            if (p != null) out.add(OsmFeature('peak', nameOf(f.tags), [p], false, ele: ele is num ? ele.toDouble() : null));
          }
        case 'place':
          if (f.type == 1 &&
              f.rings.isNotEmpty &&
              f.rings.first.isNotEmpty &&
              const {'suburb', 'quarter', 'neighbourhood', 'village', 'hamlet', 'town', 'city'}.contains(cls)) {
            final p = conv([f.rings.first.first], l.extent);
            final nm = nameOf(f.tags);
            if (p != null && nm.isNotEmpty) out.add(OsmFeature('place', nm, [p], false));
          }
      }
    }
  }
  // tên hồ nằm ở lớp riêng (điểm): gắn cho mặt nước chứa điểm đó
  for (final (x, y, nm) in waterNames) {
    for (var i = 0; i < out.length; i++) {
      final f = out[i];
      if (!f.area || (f.kind != 'water' && f.kind != 'river') || f.name.isNotEmpty) continue;
      if (f.contains(x, y)) {
        out[i] = OsmFeature(f.kind, nm, f.parts, true, evenOdd: f.evenOdd);
        break;
      }
    }
  }
  // mặt sông (vùng) chưa có tên: lấy tên dòng sông (đường) chạy qua
  for (var i = 0; i < out.length; i++) {
    final f = out[i];
    if (!f.area || f.kind != 'river' || f.name.isNotEmpty) continue;
    String? nm;
    for (final g in out) {
      if (g.area || g.kind != 'river' || g.name.isEmpty || g.name == 'suối') continue;
      for (final p in g.parts) {
        for (var k = 0; k + 1 < p.length && nm == null; k += 2) {
          if (f.contains(p[k], p[k + 1])) nm = g.name;
        }
      }
      if (nm != null) break;
    }
    if (nm != null) out[i] = OsmFeature(f.kind, nm, f.parts, true, evenOdd: f.evenOdd);
  }
  return out;
}

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
