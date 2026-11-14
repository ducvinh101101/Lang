// ĐỊA LÝ QUANH TA: độ cao địa hình (SRTM qua OpenTopoData; dự phòng Copernicus DEM qua Open-Meteo) và các đối tượng
// bản đồ quanh một điểm (OpenStreetMap qua Overpass API): sông hồ, rừng, công viên, khu dân cư, đồng ruộng, bãi biển,
// đỉnh núi, đường lớn. Mô tả theo hướng: "Phía đông khoảng 500 mét là sông Hàn."
// Cùng dữ liệu được dùng cho chế độ "khám phá bằng chạm" (local_map.dart).
// Đều miễn phí, không cần khoá; dữ liệu © OpenStreetMap contributors.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'eonet.dart' show bearingVi;
import 'vector_tiles.dart' show loadVectorFeatures;

/// Một đối tượng bản đồ, toạ độ đã đổi sang MÉT quanh tâm (x: đông, y: bắc).
class OsmFeature {
  final String kind; // water river forest park residential farmland beach peak place road coast
  final String name;
  final List<Float32List> parts; // mỗi phần: x0,y0,x1,y1… (mét)
  final bool area;
  final double? ele; // độ cao (đỉnh núi)
  /// vùng có lỗ (đảo giữa hồ, khoảng trống giữa rừng): các vòng tính theo chẵn–lẻ thay vì "nằm trong vòng nào cũng được"
  final bool evenOdd;
  /// bề rộng ước chừng (mét) của đối tượng dạng đường: sông lớn ~40, suối ~15, phố nhỏ ~10
  final double? width;
  const OsmFeature(this.kind, this.name, this.parts, this.area, {this.ele, this.evenOdd = false, this.width});

  /// (x, y) mét có nằm trong vùng này không.
  bool contains(double x, double y) {
    if (!area) return false;
    var inside = false;
    for (final p in parts) {
      if (_inPoly(p, x, y)) {
        if (!evenOdd) return true;
        inside = !inside;
      }
    }
    return inside;
  }
}

/// Tên chung khi đối tượng không có tên.
String kindVi(String k) => switch (k) {
      'water' => 'hồ nước',
      'river' => 'sông',
      'forest' => 'rừng cây',
      'park' => 'công viên',
      'residential' => 'khu dân cư',
      'farmland' => 'đồng ruộng',
      'beach' => 'bãi biển',
      'peak' => 'đỉnh núi',
      'place' => 'khu dân cư',
      'road' => 'đường lớn',
      'coast' => 'bờ biển',
      'high' => 'vùng cao',
      _ => 'đất trống',
    };

class AroundData {
  final double lat, lon;
  final double radius; // mét
  final List<OsmFeature> features;
  final double? elevCenter;
  final List<double> elevRing; // 8 hướng (bắc, đông bắc… tây bắc) cách 1 km; NaN nếu thiếu
  final Float32List? elevGrid; // lưới n×n trong khung ±radius (hàng 0 = phía bắc)
  final int gridN;
  AroundData(this.lat, this.lon, this.radius, this.features, this.elevCenter, this.elevRing, this.elevGrid, this.gridN);

  /// Mét → độ (để tính hướng).
  (double, double) toLatLon(double x, double y) =>
      (lat + y / 110540.0, lon + x / (111320.0 * math.cos(lat * math.pi / 180)));

  /// Độ cao tại (x, y) mét — nội suy từ lưới.
  double? elevAt(double x, double y) {
    final g = elevGrid;
    if (g == null) return elevCenter;
    final n = gridN;
    final fx = ((x + radius) / (2 * radius) * (n - 1)).clamp(0.0, n - 1.0);
    final fy = ((radius - y) / (2 * radius) * (n - 1)).clamp(0.0, n - 1.0);
    final x0 = fx.floor(), y0 = fy.floor();
    final x1 = math.min(n - 1, x0 + 1), y1 = math.min(n - 1, y0 + 1);
    final tx = fx - x0, ty = fy - y0;
    double v(int r, int c) => g[r * n + c];
    final a = v(y0, x0) * (1 - tx) + v(y0, x1) * tx;
    final b = v(y1, x0) * (1 - tx) + v(y1, x1) * tx;
    final e = a * (1 - ty) + b * ty;
    return e.isNaN ? null : e;
  }

  /// Loại địa hình tại (x, y) mét và đối tượng tương ứng (null = đất thường).
  (String, OsmFeature?) classify(double x, double y) {
    const order = ['river', 'water', 'coast', 'beach', 'forest', 'park', 'farmland', 'residential', 'road'];
    for (final k in order) {
      for (final f in features) {
        if (f.kind != k) continue;
        if (f.area) {
          if (f.contains(x, y)) return (k, f);
        } else {
          final w = f.width;
          // nửa bề rộng + ~12 m cho ngón tay (ngón tay trên màn hình to hơn một con suối nhỏ)
          final tol = w != null ? w / 2 + 12 : (k == 'river' ? 35.0 : (k == 'road' ? 15.0 : 25.0));
          for (final p in f.parts) {
            if (_distToLine(p, x, y) <= tol) return (k, f);
          }
        }
      }
    }
    final e = elevAt(x, y), c = elevCenter;
    if (e != null && c != null && e - c > 60) return ('high', null);
    return ('land', null);
  }
}

bool _inPoly(Float32List p, double x, double y) {
  var inside = false;
  final n = p.length ~/ 2;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = p[i * 2], yi = p[i * 2 + 1], xj = p[j * 2], yj = p[j * 2 + 1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

double _distToLine(Float32List p, double x, double y) {
  var best = double.infinity;
  final n = p.length ~/ 2;
  if (n == 1) return math.sqrt(math.pow(p[0] - x, 2) + math.pow(p[1] - y, 2));
  for (var i = 0; i + 1 < n; i++) {
    final ax = p[i * 2], ay = p[i * 2 + 1], bx = p[i * 2 + 2], by = p[i * 2 + 3];
    final dx = bx - ax, dy = by - ay;
    final l2 = dx * dx + dy * dy;
    final t = l2 == 0 ? 0.0 : (((x - ax) * dx + (y - ay) * dy) / l2).clamp(0.0, 1.0);
    final px = ax + t * dx, py = ay + t * dy;
    final d = math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
    if (d < best) best = d;
  }
  return best;
}

/// Điểm gần nhất của đối tượng tới tâm: (khoảng cách mét, x, y).
(double, double, double) _nearest(OsmFeature f) {
  var best = (double.infinity, 0.0, 0.0);
  for (final p in f.parts) {
    if (f.area && _inPoly(p, 0, 0)) return (0, 0, 0);
    for (var i = 0; i < p.length; i += 2) {
      final d = math.sqrt(p[i] * p[i] + p[i + 1] * p[i + 1]);
      if (d < best.$1) best = (d, p[i].toDouble(), p[i + 1].toDouble());
    }
  }
  return best;
}

class GeoAroundService {
  final http.Client client;
  void Function(String)? log;
  GeoAroundService(this.client, {this.log});

  final _cache = <String, AroundData>{};

  /// Kết quả không rỗng đến sớm nhất; tất cả đều hỏng → null.
  static Future<Map<String, dynamic>?> _firstOk(List<Future<Map<String, dynamic>>> fs) {
    final done = Completer<Map<String, dynamic>?>();
    var left = fs.length;
    for (final f in fs) {
      f.then((m) {
        left--;
        if (done.isCompleted) return;
        if (m.isNotEmpty) {
          done.complete(m);
        } else if (left == 0) {
          done.complete(null);
        }
      });
    }
    return done.future;
  }

  Future<Map<String, dynamic>> _json(Uri u, {String? body, Duration wait = const Duration(seconds: 25)}) async {
    final h = <String, String>{
      'Accept': 'application/json',
      if (!kIsWeb) 'User-Agent': 'SenseApp/1.0 (contact@sense.app; NASA Space Apps for visually impaired)',
    };
    final r = body == null
        ? await client.get(u, headers: h).timeout(wait)
        : await client.post(u, headers: h, body: {'data': body}).timeout(wait);
    if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Độ cao nhiều điểm (tối đa 100): SRTM 90 m (OpenTopoData), dự phòng Copernicus DEM (Open-Meteo).
  Future<List<double>> elevations(List<(double, double)> pts) async {
    // bản web: OpenTopoData không cho trình duyệt gọi thẳng (CORS) → dùng luôn Open-Meteo, đỡ chờ một lần lỗi
    if (!kIsWeb) {
      try {
        final loc = pts.map((p) => '${p.$1.toStringAsFixed(5)},${p.$2.toStringAsFixed(5)}').join('|');
        final j = await _json(Uri.https('api.opentopodata.org', '/v1/srtm90m', {'locations': loc}));
        final res = (j['results'] as List?) ?? const [];
        if (res.length == pts.length) {
          return [
            for (final r in res) r is Map && r['elevation'] is num ? (r['elevation'] as num).toDouble() : double.nan
          ];
        }
      } catch (e) {
        log?.call('[độ cao SRTM] $e → dùng Open-Meteo');
      }
    }
    final j = await _json(Uri.https('api.open-meteo.com', '/v1/elevation', {
      'latitude': pts.map((p) => p.$1.toStringAsFixed(5)).join(','),
      'longitude': pts.map((p) => p.$2.toStringAsFixed(5)).join(','),
    }));
    return [for (final e in (j['elevation'] as List?) ?? const []) e is num ? e.toDouble() : double.nan];
  }

  /// Tải dữ liệu quanh (lat, lon) trong bán kính [radius] mét. [grid]: có lấy lưới độ cao 10×10 (cho chế độ chạm).
  /// [osmWait]: chờ máy chủ OpenStreetMap tối đa bao lâu (máy chủ Overpass công cộng hay quá tải; bản đồ rê tay
  /// mở ngay rồi thêm lớp OSM khi về, nên ở đó chờ lâu được).
  Future<AroundData> load(double lat, double lon,
      {double radius = 1200, bool grid = false, Duration osmWait = const Duration(seconds: 10)}) async {
    final key = '${lat.toStringAsFixed(4)}|${lon.toStringAsFixed(4)}|$radius|$grid';
    final hit = _cache[key];
    if (hit != null) return hit;
    final kx = 111320.0 * math.cos(lat * math.pi / 180), ky = 110540.0;
    // 1) độ cao: tâm + 8 hướng cách 1 km
    final ring = <(double, double)>[(lat, lon)];
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4; // 0 = bắc, theo chiều kim đồng hồ
      ring.add((lat + 1000 * math.cos(a) / ky, lon + 1000 * math.sin(a) / kx));
    }
    final elevF = elevations(ring).catchError((Object e) {
      log?.call('[độ cao] $e');
      return <double>[];
    });
    // 2) OpenStreetMap — ưu tiên Ô BẢN ĐỒ VECTOR (CDN, nhanh, ổn định: sông suối, hồ, rừng, công viên, đường, đỉnh núi);
    //    chỉ khi không tải được mới hỏi máy chủ Overpass (hay quá tải)
    final vecF = loadVectorFeatures(lat, lon, radius, client: client, log: log).catchError((Object e) {
      log?.call('[ô bản đồ vector] $e');
      return null;
    });
    final dLat = radius / ky, dLon = radius / kx;
    final bbox = '${(lat - dLat).toStringAsFixed(5)},${(lon - dLon).toStringAsFixed(5)},'
        '${(lat + dLat).toStringAsFixed(5)},${(lon + dLon).toStringAsFixed(5)}';
    final a = 'around:${radius.round()},${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    final q = '[out:json][timeout:10];('
        'way["natural"="water"]($a);relation["natural"="water"]($a);way["landuse"="reservoir"]($a);'
        'way["waterway"~"^(river|canal|stream)\$"]($a);'
        'way["landuse"~"^(forest|residential|farmland|meadow|orchard)\$"]($a);'
        'relation["landuse"="forest"]($a);'
        'way["natural"~"^(wood|beach|coastline)\$"]($a);relation["natural"="wood"]($a);'
        'way["leisure"~"^(park|garden)\$"]($a);'
        'node["natural"="peak"]($a);'
        'node["place"~"^(suburb|quarter|neighbourhood|village|town|hamlet|city)\$"]($a);'
        'way["highway"~"^(motorway|trunk|primary|secondary)\$"]["name"]($a);'
        ');out geom($bbox) qt 500;';
    // hỏi song song nhiều máy chủ Overpass, lấy câu trả lời đầu tiên (máy chủ chính hay quá tải hoặc chậm)
    final vec = await vecF;
    final osm = (vec != null && vec.isNotEmpty) ? null : await _firstOk([
      // bản web: đi qua máy chủ của app trước (/api/osm — không bị chặn CORS, CDN nhớ sẵn), vẫn hỏi thẳng song song
      if (kIsWeb)
        _json(Uri.base.resolve('/api/osm').replace(queryParameters: {'data': q}), wait: osmWait)
            .catchError((Object e) {
          log?.call('[Overpass qua máy chủ app] $e');
          return <String, dynamic>{};
        }),
      // (11/2026: overpass-api.de, nchc, lz4 hay từ chối; maps.mail.ru chậm nhưng thường vẫn trả lời)
      for (final (host, path) in const [
        ('overpass.nchc.org.tw', '/api/interpreter'),
        ('lz4.overpass-api.de', '/api/interpreter'),
        ('overpass-api.de', '/api/interpreter'),
        ('overpass.kumi.systems', '/api/interpreter'),
        ('overpass.private.coffee', '/api/interpreter'),
        ('maps.mail.ru', '/osm/tools/overpass/api/interpreter'),
      ])
        // GET ?data=… (câu hỏi ngắn) như trình duyệt/curl: ít bị chặn hơn POST qua proxy, và được máy chủ cache
        _json(Uri.https(host, path, {'data': q}), wait: osmWait).catchError((Object e) {
          log?.call('[Overpass $host] $e');
          return <String, dynamic>{};
        }),
    ]);
    final feats = (vec != null && vec.isNotEmpty) ? vec : (osm == null ? <OsmFeature>[] : _parse(osm, lat, lon, kx, ky));
    final elev = await elevF;
    Float32List? g;
    const n = 10;
    if (grid) {
      final pts = <(double, double)>[
        for (var r = 0; r < n; r++)
          for (var c = 0; c < n; c++) (lat + dLat - 2 * dLat * r / (n - 1), lon - dLon + 2 * dLon * c / (n - 1))
      ];
      try {
        // OpenTopoData: tối đa 1 lần/giây
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        final e = await elevations(pts);
        if (e.length == n * n) g = Float32List.fromList(e);
      } catch (e) {
        log?.call('[lưới độ cao] $e');
      }
    }
    final data = AroundData(lat, lon, radius, feats, elev.isNotEmpty && !elev.first.isNaN ? elev.first : null,
        elev.length == 9 ? elev.sublist(1) : List.filled(8, double.nan), g, n);
    if (osm == null && (vec == null || vec.isEmpty) && elev.isEmpty) {
      log?.call('[Overpass] Không kết nối được máy chủ bản đồ mở; sử dụng dữ liệu địa danh và địa hình offline.');
    }
    if (_cache.length > 10) _cache.clear();
    _cache[key] = data;
    return data;
  }

  static List<OsmFeature> _parse(Map<String, dynamic> j, double lat, double lon, double kx, double ky) {
    final out = <OsmFeature>[];
    Float32List conv(List geom) {
      final f = Float32List(geom.length * 2);
      for (var i = 0; i < geom.length; i++) {
        final p = geom[i];
        if (p is! Map) continue;
        f[i * 2] = (((p['lon'] as num).toDouble() - lon) * kx);
        f[i * 2 + 1] = (((p['lat'] as num).toDouble() - lat) * ky);
      }
      return f;
    }

    for (final e in (j['elements'] as List?) ?? const []) {
      if (e is! Map) continue;
      final tags = e['tags'] is Map ? e['tags'] as Map : const {};
      final kind = _kindOf(tags);
      if (kind == null) continue;
      final name = '${tags['name:vi'] ?? tags['name'] ?? ''}';
      final type = e['type'];
      if (type == 'node') {
        final la = e['lat'], lo = e['lon'];
        if (la is! num || lo is! num) continue;
        final ele = double.tryParse('${tags['ele'] ?? ''}');
        out.add(OsmFeature(kind, name, [Float32List.fromList([(lo - lon) * kx, (la - lat) * ky])], false, ele: ele));
      } else if (type == 'way' && e['geometry'] is List) {
        final area = !(kind == 'river' || kind == 'road' || kind == 'coast');
        out.add(OsmFeature(kind, name, [conv(e['geometry'] as List)], area));
      } else if (type == 'relation' && e['members'] is List) {
        final parts = <Float32List>[];
        for (final m in e['members'] as List) {
          if (m is Map && m['role'] == 'outer' && m['geometry'] is List) parts.add(conv(m['geometry'] as List));
        }
        if (parts.isNotEmpty) out.add(OsmFeature(kind, name, parts, true));
      }
    }
    return out;
  }

  static String? _kindOf(Map tags) {
    final ww = tags['waterway'], lu = tags['landuse'], nat = tags['natural'], lei = tags['leisure'];
    if (ww == 'river' || ww == 'canal' || ww == 'stream') return 'river';
    if (nat == 'water' || lu == 'reservoir') return 'water';
    if (nat == 'coastline') return 'coast';
    if (nat == 'beach') return 'beach';
    if (lu == 'forest' || nat == 'wood') return 'forest';
    if (lei == 'park' || lei == 'garden') return 'park';
    if (lu == 'farmland' || lu == 'meadow' || lu == 'orchard') return 'farmland';
    if (lu == 'residential') return 'residential';
    if (nat == 'peak') return 'peak';
    if (tags['place'] != null) return 'place';
    if (tags['highway'] != null) return 'road';
    return null;
  }
}

String _roundDist(double m) {
  if (m < 60) return 'ngay cạnh';
  if (m < 1000) return 'khoảng ${(m / 50).round() * 50} mét';
  return 'khoảng ${(m / 100).round() / 10} ki-lô-mét'.replaceAll('.', ',');
}

/// Mô tả địa lý quanh điểm cho người khiếm thị (tiếng Việt).
String describeAround(AroundData d, String placeVi) {
  final b = StringBuffer();
  // --- địa hình
  final e = d.elevCenter;
  if (e != null) {
    final terrain = e < 30
        ? 'vùng đồng bằng thấp'
        : e < 200
            ? 'vùng đồng bằng hoặc trung du'
            : e < 500
                ? 'vùng đồi'
                : e < 1500
                    ? 'vùng cao nguyên, đồi núi'
                    : 'vùng núi cao';
    b.write('$placeVi cao khoảng ${e.round()} mét so với mực nước biển, thuộc $terrain. ');
    final ring = d.elevRing;
    final valid = [for (var k = 0; k < 8; k++) if (!ring[k].isNaN) k];
    if (valid.isNotEmpty) {
      const dirs = ['bắc', 'đông bắc', 'đông', 'đông nam', 'nam', 'tây nam', 'tây', 'tây bắc'];
      var hi = valid.first, lo = valid.first;
      for (final k in valid) {
        if (ring[k] > ring[hi]) hi = k;
        if (ring[k] < ring[lo]) lo = k;
      }
      final relief = ring[hi] - ring[lo];
      if (relief < 15) {
        b.write('Mặt đất quanh đây khá bằng phẳng. ');
      } else {
        if (ring[hi] - e >= 15) {
          b.write('Phía ${dirs[hi]} cao hơn khoảng ${(ring[hi] - e).round()} mét'
              '${ring[hi] - e > 150 ? ', là đồi núi' : (ring[hi] - e > 40 ? ', là khu đồi' : '')}. ');
        }
        if (e - ring[lo] >= 15) b.write('Đất thấp dần về phía ${dirs[lo]}, thấp hơn khoảng ${(e - ring[lo]).round()} mét. ');
      }
    }
  }
  // --- đối tượng bản đồ: mỗi loại lấy cái gần nhất (ưu tiên có tên)
  final picks = <String, (OsmFeature, double, double, double)>{};
  for (final f in d.features) {
    final (dist, x, y) = _nearest(f);
    if (dist.isInfinite || dist > d.radius * 1.2) continue;
    final key = f.kind == 'place' || f.kind == 'road' ? '${f.kind}${f.name}' : f.kind;
    final cur = picks[key];
    final better = cur == null ||
        (f.name.isNotEmpty && cur.$1.name.isEmpty) ||
        ((f.name.isNotEmpty) == (cur.$1.name.isNotEmpty) && dist < cur.$2);
    if (better) picks[key] = (f, dist, x, y);
  }
  final list = picks.values.toList()..sort((a, b) => a.$2.compareTo(b.$2));
  final inside = <String>[];
  final around = <String>[];
  var roads = 0, places = 0;
  for (final (f, dist, x, y) in list) {
    if (f.kind == 'road' && ++roads > 2) continue;
    if (f.kind == 'place' && ++places > 2) continue;
    final name = f.name.isNotEmpty
        ? (f.kind == 'river' && !f.name.toLowerCase().startsWith(RegExp(r'(sông|kênh|suối|rạch)')) ? 'sông ${f.name}' : f.name)
        : kindVi(f.kind);
    final what = f.kind == 'peak' && f.ele != null ? '$name, cao ${f.ele!.round()} mét' : name;
    if (dist < 1) {
      inside.add(what);
      continue;
    }
    final (la, lo) = d.toLatLon(x, y);
    final dir = bearingVi(d.lat, d.lon, la, lo);
    around.add(dist < 60 ? 'Ngay cạnh, $dir là $what.' : '${dir[0].toUpperCase()}${dir.substring(1)} ${_roundDist(dist)} là $what.');
    if (around.length >= 7) break;
  }
  if (inside.isNotEmpty) b.write('Bạn đang ở trong ${inside.take(2).join(' và ')}. ');
  if (around.isEmpty && inside.isEmpty) {
    b.write('Bản đồ OpenStreetMap chưa có nhiều thông tin quanh điểm này.');
  } else {
    b.write(around.join(' '));
  }
  return b.toString().trim();
}

/// English names of terrain kinds.
String kindEn(String k) => switch (k) {
      'water' => 'a lake',
      'river' => 'a river',
      'forest' => 'woods',
      'park' => 'a park',
      'residential' => 'a residential area',
      'farmland' => 'farmland',
      'beach' => 'a beach',
      'peak' => 'a peak',
      'place' => 'a neighbourhood',
      'road' => 'a main road',
      'coast' => 'the coast',
      'high' => 'high ground',
      _ => 'open ground',
    };

String _dirEn(double lat1, double lon1, double lat2, double lon2) {
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180, dl = (lon2 - lon1) * math.pi / 180;
  final deg = (math.atan2(math.sin(dl) * math.cos(p2), math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)) *
              180 /
              math.pi +
          360) %
      360;
  const names = ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'];
  return names[((deg + 22.5) ~/ 45) % 8];
}

/// English description of the area around a point.
String describeAroundEn(AroundData d, String place) {
  final b = StringBuffer();
  const dirs = ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'];
  final e = d.elevCenter;
  if (e != null) {
    final terrain = e < 30
        ? 'low plains'
        : e < 200
            ? 'plains or midlands'
            : e < 500
                ? 'hills'
                : e < 1500
                    ? 'highlands'
                    : 'high mountains';
    b.write('$place is about ${e.round()} metres above sea level, in $terrain. ');
    final ring = d.elevRing;
    final valid = [for (var k = 0; k < 8; k++) if (!ring[k].isNaN) k];
    if (valid.isNotEmpty) {
      var hi = valid.first, lo = valid.first;
      for (final k in valid) {
        if (ring[k] > ring[hi]) hi = k;
        if (ring[k] < ring[lo]) lo = k;
      }
      if (ring[hi] - ring[lo] < 15) {
        b.write('The ground around here is quite flat. ');
      } else {
        if (ring[hi] - e >= 15) b.write('To the ${dirs[hi]} the land rises about ${(ring[hi] - e).round()} metres. ');
        if (e - ring[lo] >= 15) b.write('It slopes down to the ${dirs[lo]}, about ${(e - ring[lo]).round()} metres lower. ');
      }
    }
  }
  final picks = <String, (OsmFeature, double, double, double)>{};
  for (final f in d.features) {
    final (dist, x, y) = _nearest(f);
    if (dist.isInfinite || dist > d.radius * 1.2) continue;
    final key = f.kind == 'place' || f.kind == 'road' ? '${f.kind}${f.name}' : f.kind;
    final cur = picks[key];
    if (cur == null || (f.name.isNotEmpty && cur.$1.name.isEmpty) || ((f.name.isNotEmpty) == (cur.$1.name.isNotEmpty) && dist < cur.$2)) {
      picks[key] = (f, dist, x, y);
    }
  }
  final list = picks.values.toList()..sort((a, b) => a.$2.compareTo(b.$2));
  final inside = <String>[], around = <String>[];
  var roads = 0, places = 0;
  for (final (f, dist, x, y) in list) {
    if (f.kind == 'road' && ++roads > 2) continue;
    if (f.kind == 'place' && ++places > 2) continue;
    final what = f.name.isNotEmpty ? f.name : kindEn(f.kind);
    if (dist < 1) {
      inside.add(what);
      continue;
    }
    final (la, lo) = d.toLatLon(x, y);
    final dir = _dirEn(d.lat, d.lon, la, lo);
    final dd = dist < 60 ? 'right next to you' : (dist < 1000 ? 'about ${(dist / 50).round() * 50} metres' : 'about ${(dist / 100).round() / 10} kilometres');
    around.add(dist < 60 ? 'Right next to you, to the $dir, is $what.' : '$dd to the $dir is $what.');
    if (around.length >= 7) break;
  }
  if (inside.isNotEmpty) b.write('You are inside ${inside.take(2).join(' and ')}. ');
  b.write(around.isEmpty && inside.isEmpty ? 'The open map has little information around this point.' : around.join(' '));
  final s = b.toString().trim();
  return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
