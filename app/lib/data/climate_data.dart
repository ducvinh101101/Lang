// Hợp đồng dữ liệu giữa UI và nguồn dữ liệu.
// UI chỉ gọi qua ClimateData, nên đổi từ giả lập sang dữ liệu NASA thật (output pipeline) không phải sửa UI.
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/geo.dart';

const varKeys = ['rain', 'temp', 'fire'];

/// Thứ tự hiển thị: mưa, nhiệt, cháy trước, rồi các biến mới (dữ liệu NASA bổ sung sau này) theo thứ tự trong gói.
List<String> orderedVarKeys(Map<String, VarMeta> vars) =>
    [...varKeys.where(vars.containsKey), ...vars.keys.where((k) => !varKeys.contains(k))];

class VarMeta {
  final String key;
  final String vi, en;
  final String unitVi, unitEn; // hiển thị
  final String spokenVi, spokenEn; // đọc to
  final double min, max;
  final int decimals;
  final bool sqrtScale;

  /// Cách nghe: "danbau" (cao độ liên tục) | "trung" (mật độ nốt, như mưa) | "fire" (lách tách + trống).
  /// Biến mới từ NASA chỉ cần khai báo instrument trong pipeline/config.py là app biết phát thế nào.
  final String instrument;

  /// Số liệu MỘT NGÀY (bản đồ hôm nay) thay vì cả tháng → từ ngữ cho bạn nhỏ dùng ngưỡng theo ngày.
  final bool daily;

  const VarMeta({
    required this.key,
    required this.vi,
    required this.en,
    required this.unitVi,
    required this.unitEn,
    required this.spokenVi,
    required this.spokenEn,
    required this.min,
    required this.max,
    required this.decimals,
    this.sqrtScale = false,
    this.instrument = 'danbau',
    this.daily = false,
  });

  String name(String lang) => lang == 'vi' ? vi : en;
  String unit(String lang) => lang == 'vi' ? unitVi : unitEn;
  String spoken(String lang) => lang == 'vi' ? spokenVi : spokenEn;

  /// Chuẩn hóa về [0, 1] cho màu và cao độ (căn bậc hai với mưa, giống bản web).
  double norm(double x) {
    final t = (x - min) / (max - min);
    final c = math.max(0.0, math.min(1.0, t));
    return sqrtScale ? math.sqrt(c) : c;
  }
}

class RegionSeries {
  final Float32List values; // (năm*12), NaN = thiếu
  final Float32List z; // so với chuẩn từng tháng
  final double lo, hi;
  RegionSeries(this.values, this.z, this.lo, this.hi);

  int get length => values.length;
  double norm(double x) => (x - lo) / ((hi - lo) == 0 ? 1 : (hi - lo));

  factory RegionSeries.fromValues(Float32List s, Float32List z) {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final x in s) {
      if (x.isNaN) continue;
      lo = math.min(lo, x);
      hi = math.max(hi, x);
    }
    if (!lo.isFinite) {
      lo = 0;
      hi = 1;
    }
    return RegionSeries(s, z, lo, hi);
  }
}

abstract class ClimateData {
  /// 'synthetic' hoặc 'assets'
  String get id;
  bool get isSimulated;
  String label(String lang);

  GeoGrid get geo;
  List<int> get years;
  Map<String, VarMeta> get vars;

  int get firstYear => years.first;
  int get monthCount => years.length * 12;

  /// Nạp dữ liệu một năm (frames từ assets). Phải gọi trước values() với năm đó.
  Future<void> ensureYear(String v, int year);

  /// Giá trị mọi ô (độ dài nCells), NaN với ô không phải đất liền Việt Nam hoặc thiếu dữ liệu.
  /// m: 0..11
  Float32List values(String v, int year, int m);

  /// Trung bình chuẩn khí hậu của ô i, tháng m.
  double clim(String v, int i, int m);

  /// Độ lệch chuẩn của ô i, tháng m (để tính |z|).
  double sd(String v, int i, int m);

  RegionSeries series(int region, String v);

  /// Tên sự kiện đã biết (chỉ có ở dữ liệu giả lập), null nếu không có.
  String? eventLabel(int region, String v, int year, int m, String lang) => null;
}
