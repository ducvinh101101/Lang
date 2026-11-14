// touch_map.dart — đọc dữ liệu F3 (grid.json + các ảnh PNG) và tra giá trị theo ô.
// Đã chạy `flutter analyze` (Flutter 3.44) — xem flutter/README.md.
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

class TouchLayer {
  TouchLayer(this.name, this.labelVi, this.unit, this.im, this.scale, this.offset, this.log, {this.onThreshold});
  final String name, labelVi, unit;
  final img.Image im;
  final double scale, offset;
  final bool log;
  final double? onThreshold; // lớp mặt nước: ngưỡng coi là "đang ở trên sông, hồ"

  /// Giá trị thật của ô (c, r); null = biển (lớp độ cao) hoặc không có số liệu.
  double? valueAt(int c, int r) {
    final b = im.getPixel(c, r).r.toInt();
    if (b == 255) return null;
    final v = b * scale + offset;
    return log ? math.pow(10, v).toDouble() - 1 : v;
  }
}

class Island {
  Island(this.nameVi, this.unitVi, this.latTop, this.latBottom);
  final String nameVi, unitVi;
  final double latTop, latBottom;
}

class Region {
  Region(this.id, this.nameVi, this.intro, this.level2, this.elevMean, this.elevMax);
  final int id;
  final String nameVi, intro;
  final String? level2;          // thư mục cấp 2, ví dụ 'p05' (chỉ có ở cấp 1)
  final int? elevMean, elevMax;
}

class TouchMap {
  TouchMap(this.dir);
  final String dir;               // ví dụ 'assets/touch/vn' hoặc 'assets/touch/p05'
  late final String level;
  late final double lon0, latTop, step;
  late final int cols, rows;
  late final img.Image ids;
  final layers = <String, TouchLayer>{};
  final regions = <int, Region>{};
  final islands = <Island>[];
  late final String basemapAsset;
  late final Map<String, dynamic> dataCards;

  static Future<TouchMap> load(String dir) async {
    final m = TouchMap(dir);
    final meta = jsonDecode(await rootBundle.loadString('$dir/grid.json')) as Map<String, dynamic>;
    final g = meta['grid'] as Map<String, dynamic>;
    m.level = meta['level'] as String;
    m.lon0 = (g['lon0'] as num).toDouble();
    m.latTop = (g['lat_top'] as num).toDouble();
    m.step = (g['step'] as num).toDouble();
    m.cols = g['cols'] as int;
    m.rows = g['rows'] as int;
    m.dataCards = (meta['data_cards'] as Map).cast<String, dynamic>();
    m.basemapAsset = '$dir/${meta['basemap']['file']}';

    Future<img.Image> png(String f) async =>
        img.decodePng((await rootBundle.load('$dir/$f')).buffer.asUint8List())!;
    m.ids = await png(meta['ids']['file'] as String);
    for (final l in meta['layers'] as List) {
      m.layers[l['name'] as String] = TouchLayer(
          l['name'] as String, l['label_vi'] as String, l['unit'] as String,
          await png(l['file'] as String),
          (l['scale'] as num).toDouble(), (l['offset'] as num).toDouble(), l['log'] == true,
          onThreshold: (l['on_threshold'] as num?)?.toDouble());
    }
    final namesFile = meta['ids']['names'] as String;
    for (final r in jsonDecode(await rootBundle.loadString('$dir/$namesFile')) as List) {
      m.regions[r['id'] as int] = Region(r['id'] as int, (r['name_vi'] ?? '') as String,
          (r['intro_vi'] ?? '') as String, r['level2'] as String?,
          r['elev_mean_m'] as int?, r['elev_max_m'] as int?);
    }
    for (final i in (meta['islands'] ?? []) as List) {
      m.islands.add(Island(i['name_vi'] as String, i['unit_vi'] as String,
          (i['lat_top'] as num).toDouble(), (i['lat_bottom'] as num).toDouble()));
    }
    return m;
  }

  double get aspect => cols / rows;   // khung bản đồ trên màn hình PHẢI giữ đúng tỉ lệ này

  /// Vị trí ngón tay (x, y) trong khung rộng w, cao h -> ô lưới.
  (int, int)? cellAt(double x, double y, double w, double h) {
    final c = (x / w * cols).floor(), r = (y / h * rows).floor();
    if (c < 0 || r < 0 || c >= cols || r >= rows) return null;
    return (c, r);
  }

  int idAt(int c, int r) {
    final p = ids.getPixel(c, r);
    return p.r.toInt() * 256 + p.g.toInt();
  }

  bool isSea(int c, int r) => layers['elev']!.valueAt(c, r) == null;

  double? elevAt(int c, int r) => layers['elev']!.valueAt(c, r);

  /// Độ dốc trung bình của ô (độ); null nếu là biển hoặc bản build cũ chưa có lớp slope.
  double? slopeAt(int c, int r) => layers['slope']?.valueAt(c, r);

  /// Tỉ lệ mặt nước nội địa 0..1; null nếu không có lớp water.
  double? waterAt(int c, int r) => layers['water']?.valueAt(c, r);

  double get waterThreshold => layers['water']?.onThreshold ?? 0.5;

  /// Mặt cắt độ cao theo hàng r (Tây -> Đông) — lát cắt khi quét Bắc - Nam. null = biển.
  List<double?> rowProfile(int r) => [for (var c = 0; c < cols; c++) elevAt(c, r)];

  /// Mặt cắt độ cao theo cột c (Bắc -> Nam) — lát cắt khi quét Tây - Đông.
  List<double?> colProfile(int c) => [for (var r = 0; r < rows; r++) elevAt(c, r)];

  double latOfRow(int r) => latTop - (r + 0.5) * step;
  double lonOfCol(int c) => lon0 + (c + 0.5) * step;

  /// Vĩ độ ứng với vị trí y trên dải quần đảo (cùng chiều cao với bản đồ).
  double latAtY(double y, double h) => latTop - y / h * rows * step;

  Island? islandAtY(double y, double h) {
    final lat = latAtY(y, h);
    for (final i in islands) {
      if (lat <= i.latTop && lat >= i.latBottom) return i;
    }
    return null;
  }
}
