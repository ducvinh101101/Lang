// F3 — đọc dữ liệu địa lý THẬT do data_nasa/build_f3.py xuất ra (assets/touch/vn/): lưới cả nước, mỗi lớp là một ảnh
// PNG xám 1 byte/ô (255 = không có số liệu):
//   elev  — độ cao NASA SRTMGL30 (12,5 m/bậc; 255 = biển)
//   slope — độ dốc tính ở độ phân giải gốc ~1 km rồi lấy trung bình ô (0,25°/bậc)
//   water — tỉ lệ mặt nước nội địa NASA SEDAC GPWv4 (0,004/bậc)
//   pop   — mật độ dân số NASA SEDAC GPWv4 2020 (thang log: 10^(b·0,025) − 1 người/km²)
// Có dữ liệu này thì chạm địa hình trong Việt Nam dùng số liệu thật (độ dốc, sông hồ, mật độ dân số → số xe);
// chưa có (chưa chạy crawl_f3.py / build_f3.py) thì app dùng cách ước lượng cũ — không lỗi.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class TouchLayerData {
  final String name;
  final Uint8List bytes; // 1 byte/ô, hàng trên cùng (bắc) trước
  final double scale, offset;
  final bool log;
  final double? onThreshold;
  const TouchLayerData(this.name, this.bytes, this.scale, this.offset, {this.log = false, this.onThreshold});

  /// Giá trị thật của ô thứ [i]; null = không có số liệu (với lớp độ cao: biển).
  double? value(int i) {
    if (i < 0 || i >= bytes.length) return null;
    final b = bytes[i];
    if (b == 255) return null;
    final v = b * scale + offset;
    return log ? math.pow(10, v).toDouble() - 1 : v;
  }
}

/// Số liệu thật dưới ngón tay.
class TouchSample {
  final double? elev, slope, water, pop;
  final bool sea;
  const TouchSample({this.elev, this.slope, this.water, this.pop, this.sea = false});
}

class TouchGrid {
  final double lon0, latTop, step;
  final int cols, rows;
  final Map<String, TouchLayerData> layers;
  final Map<String, dynamic> dataCards;
  TouchGrid(this.lon0, this.latTop, this.step, this.cols, this.rows, this.layers, {this.dataCards = const {}});

  /// Đã nạp (null = chưa có dữ liệu thật trong app).
  static TouchGrid? loaded;

  double get latBottom => latTop - rows * step;
  double get lon1 => lon0 + cols * step;

  bool contains(double lat, double lon) => lat <= latTop && lat > latBottom && lon >= lon0 && lon < lon1;

  /// Số liệu ở (lat, lon); null nếu ngoài khung lưới.
  TouchSample? sample(double lat, double lon) {
    if (!contains(lat, lon)) return null;
    final c = ((lon - lon0) / step).floor().clamp(0, cols - 1);
    final r = ((latTop - lat) / step).floor().clamp(0, rows - 1);
    final i = r * cols + c;
    final elevL = layers['elev'];
    final e = elevL?.value(i);
    final sea = elevL != null && e == null;
    return TouchSample(
      elev: e,
      slope: sea ? null : layers['slope']?.value(i),
      water: layers['water']?.value(i),
      pop: sea ? null : layers['pop']?.value(i),
      sea: sea,
    );
  }

  double get waterThreshold => layers['water']?.onThreshold ?? 0.5;

  /// Dựng từ grid.json + bộ đọc byte của từng lớp (đã giải mã thành 1 byte/ô).
  static TouchGrid fromMeta(Map<String, dynamic> meta, Map<String, Uint8List> layerBytes) {
    final g = meta['grid'] as Map<String, dynamic>;
    final cols = (g['cols'] as num).toInt(), rows = (g['rows'] as num).toInt();
    final layers = <String, TouchLayerData>{};
    for (final l in (meta['layers'] as List? ?? const [])) {
      final name = '${l['name']}';
      final b = layerBytes[name];
      if (b == null || b.length != cols * rows) continue;
      layers[name] = TouchLayerData(name, b, (l['scale'] as num).toDouble(), ((l['offset'] ?? 0) as num).toDouble(),
          log: l['log'] == true, onThreshold: (l['on_threshold'] as num?)?.toDouble());
    }
    return TouchGrid((g['lon0'] as num).toDouble(), (g['lat_top'] as num).toDouble(), (g['step'] as num).toDouble(), cols, rows,
        layers,
        dataCards: (meta['data_cards'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  /// Nạp thư mục [dir] (vd 'assets/touch/vn'). [text] / [bytes] đọc file (rootBundle trong app, File trong test).
  /// Không có dữ liệu → null.
  static Future<TouchGrid?> load(
      String dir, Future<String> Function(String path) text, Future<Uint8List> Function(String path) bytes) async {
    try {
      final meta = jsonDecode(await text('$dir/grid.json')) as Map<String, dynamic>;
      final out = <String, Uint8List>{};
      for (final l in (meta['layers'] as List? ?? const [])) {
        out['${l['name']}'] = await decodeGrayPng(await bytes('$dir/${l['file']}'));
      }
      return fromMeta(meta, out);
    } catch (_) {
      return null;
    }
  }
}

/// PNG → 1 byte/điểm (kênh đỏ; ảnh xám thì R = G = B), theo thứ tự hàng.
Future<Uint8List> decodeGrayPng(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final im = frame.image;
  final data = await im.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  final w = im.width, h = im.height;
  im.dispose();
  if (data == null) throw StateError('không giải mã được PNG');
  final rgba = data.buffer.asUint8List();
  final out = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    out[i] = rgba[i * 4];
  }
  return out;
}

// ---------- luật đổi số liệu → âm thanh (theo data_nasa/flutter/lib/touch/touch_rules.dart) ----------

/// Mật độ dân số (người/km²) → âm lượng tiếng xe 0 (dưới 50 người/km²) … 0,8 (từ 10.000 người/km²), thang log.
double trafficVolume(double? density) {
  if (density == null || density < 50) return 0;
  final t = ((math.log(density) / math.ln10 - 1.7) / 2.3).clamp(0.0, 1.0);
  return 0.25 + 0.55 * t;
}

/// Mật độ dân số → số xe chạy qua trong mỗi 2 giây (0..6).
int carsPerWindow(double? density) {
  if (density == null || density < 50) return 0;
  return (1.5 * (math.log(density / 50) / math.ln10 + 1)).round().clamp(1, 6);
}
