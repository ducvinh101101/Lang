// MÁY HÁT TRÁI ĐẤT (thử thách #14 — The Earth Information Jukebox): dữ liệu của các hình EIC/SVS.
// Mỗi hình NASA SVS đã được pipeline (pipeline/build_eic.py) cắt thành chuỗi khung hình nhỏ + số liệu từng khung:
//   assets/eic/index.json            danh sách hình
//   assets/eic/<id>/meta.json        mô tả, chú giải, cách nghe, nguồn, số liệu từng khung
//   assets/eic/<id>/fNN.jpg          khung hình (bản đồ phẳng toàn cầu, kinh độ −180…180, vĩ độ 90…−90)
// Số liệu từng khung đều ở thang 0…1 (đã đổi từ màu sang giá trị theo thang màu của SVS):
//   v    giá trị chính toàn cầu   area  tỉ lệ diện tích "đáng kể"   cx  vị trí đông–tây của vùng mạnh nhất (−1…1)
//   d    mức thay đổi so với khung trước (tương đối trong bộ: 0 ít nhất … 1 nhiều nhất)   vn  giá trị riêng vùng Việt Nam – Biển Đông
//   grid lưới W×H giá trị 0…254 (255 = không có dữ liệu) để rê tay trên hình
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

class EicFrame {
  final String labelVi, labelEn, image;
  final double v, area, cx, d, vn;
  final Uint8List grid;
  const EicFrame({
    required this.labelVi,
    required this.labelEn,
    required this.image,
    required this.v,
    required this.area,
    required this.cx,
    required this.d,
    required this.vn,
    required this.grid,
  });

  factory EicFrame.fromJson(Map<String, dynamic> j, String dir) => EicFrame(
        labelVi: (j['label_vi'] ?? j['label'] ?? '') as String,
        labelEn: (j['label_en'] ?? j['label'] ?? '') as String,
        image: '$dir/${j['img']}',
        v: _d(j['v']),
        area: _d(j['area']),
        cx: _d(j['cx']),
        d: _d(j['d']),
        vn: _d(j['vn']),
        grid: j['grid'] is String ? base64Decode(j['grid'] as String) : Uint8List(0),
      );
}

double _d(Object? x) => x is num ? x.toDouble() : 0.0;

class EicSet {
  final String id;
  final String titleVi, titleEn;

  /// mô tả hình (kiểu Section 508: ngắn, so với vật quen thuộc)
  final String describeVi, describeEn;

  /// chú giải âm thanh: nghe gì là gì
  final String legendVi, legendEn;

  /// vì sao chọn cách nghe này (đề #14 yêu cầu giải thích lựa chọn)
  final String whyVi, whyEn;

  /// đơn vị / ý nghĩa của thang 0…1 (vd. "chiều cao tán rừng 0–50 m")
  final String scaleVi, scaleEn;
  final String source, url, svsId;

  /// nhạc cụ: voice 'danbau'|'sao'; pulse 'trong'|'trung'|'crackle'|'none'; bed 'thunder'|'wind'|'rain'|'song'|'none'
  final String voice, pulse, bed;

  /// giọng chính đi theo 'v' (toàn cầu, mặc định) hay 'vn' (vùng Việt Nam – Biển Đông)
  final String pitch;

  /// 'time' (mỗi khung một mốc thời gian) | 'space' (mỗi khung một dải kinh độ, quét Tây → Đông)
  final String sweep;
  final double low, high; // giá trị thật ứng với 0 và 1 (để đọc số)
  final String unitVi, unitEn;
  final int gridW, gridH;
  final List<EicFrame> frames;
  final List<String> aliases;

  const EicSet({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.describeVi,
    required this.describeEn,
    required this.legendVi,
    required this.legendEn,
    required this.whyVi,
    required this.whyEn,
    required this.scaleVi,
    required this.scaleEn,
    required this.source,
    required this.url,
    required this.svsId,
    required this.voice,
    required this.pulse,
    required this.bed,
    this.pitch = 'v',
    this.sweep = 'time',
    required this.low,
    required this.high,
    required this.unitVi,
    required this.unitEn,
    required this.gridW,
    required this.gridH,
    required this.frames,
    required this.aliases,
  });

  factory EicSet.fromJson(Map<String, dynamic> j, String dir) {
    String s(String k) => (j[k] ?? '') as String;
    final snd = (j['sound'] as Map?)?.cast<String, dynamic>() ?? const {};
    return EicSet(
      id: s('id'),
      titleVi: s('title_vi'),
      titleEn: s('title_en'),
      describeVi: s('describe_vi'),
      describeEn: s('describe_en'),
      legendVi: s('legend_vi'),
      legendEn: s('legend_en'),
      whyVi: s('why_vi'),
      whyEn: s('why_en'),
      scaleVi: s('scale_vi'),
      scaleEn: s('scale_en'),
      source: s('source'),
      url: s('url'),
      svsId: '${j['svs_id'] ?? ''}',
      voice: (snd['voice'] ?? 'danbau') as String,
      pulse: (snd['pulse'] ?? 'none') as String,
      bed: (snd['bed'] ?? 'none') as String,
      pitch: (snd['pitch'] ?? 'v') as String,
      sweep: (j['sweep'] ?? 'time') as String,
      low: _d(j['low']),
      high: _d(j['high']),
      unitVi: s('unit_vi'),
      unitEn: s('unit_en'),
      gridW: (j['grid_w'] as num?)?.toInt() ?? 0,
      gridH: (j['grid_h'] as num?)?.toInt() ?? 0,
      frames: [for (final f in (j['frames'] as List? ?? const [])) EicFrame.fromJson((f as Map).cast<String, dynamic>(), dir)],
      aliases: [for (final a in (j['aliases'] as List? ?? const [])) '$a'],
    );
  }

  /// giá trị lưới tại (x, y) ∈ [0,1]² của khung [i] → 0…1, null nếu không có dữ liệu
  double? at(int i, double x, double y) {
    if (i < 0 || i >= frames.length) return null;
    final g = frames[i].grid;
    if (gridW <= 0 || gridH <= 0 || g.length < gridW * gridH) return null;
    final cx = (x * gridW).floor().clamp(0, gridW - 1), cy = (y * gridH).floor().clamp(0, gridH - 1);
    final b = g[cy * gridW + cx];
    return b == 255 ? null : b / 254.0;
  }

  /// giá trị thật (theo đơn vị) từ thang 0…1
  double real(double t) => low + (high - low) * t;
}

class EicLibrary {
  final List<EicSet> sets;
  const EicLibrary(this.sets);

  static EicLibrary? _cache;

  static Future<EicLibrary> load() async {
    final c = _cache;
    if (c != null) return c;
    final sets = <EicSet>[];
    try {
      final idx = jsonDecode(await rootBundle.loadString('assets/eic/index.json')) as Map<String, dynamic>;
      for (final id in (idx['sets'] as List? ?? const [])) {
        try {
          final dir = 'assets/eic/$id';
          final m = jsonDecode(await rootBundle.loadString('$dir/meta.json')) as Map<String, dynamic>;
          final s = EicSet.fromJson(m, dir);
          if (s.frames.isNotEmpty) sets.add(s);
        } catch (_) {}
      }
    } catch (_) {}
    return _cache = EicLibrary(sets);
  }

  EicSet? byId(String id) {
    for (final s in sets) {
      if (s.id == id) return s;
    }
    return null;
  }
}
