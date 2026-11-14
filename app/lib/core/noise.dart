// Hàm băm/nhiễu giống hệt bản web (Math.imul, >>>), để dữ liệu giả lập khớp với demo HTML.
import 'dart:math' as math;

int _imul(int a, int b) => ((a.toSigned(32) * b.toSigned(32)) & 0xFFFFFFFF).toSigned(32);
int _u32(int x) => x & 0xFFFFFFFF;

/// Giá trị giả ngẫu nhiên tất định trong [0, 1).
double hash3(int a, int b, int c) {
  var h = _imul(a, 374761393) ^ _imul(b, 668265263) ^ _imul(c, 1442695041);
  h = h.toSigned(32);
  h = _imul(h ^ (_u32(h) >> 13), 1274126177);
  h = h ^ (_u32(h) >> 16);
  return _u32(h) / 4294967296.0;
}

/// Xấp xỉ phân phối chuẩn (tổng 4 biến đều), trung bình 0, độ lệch ~1.
double gauss3(int a, int b, int c) =>
    (hash3(a, b, c) + hash3(a, b, c + 101) + hash3(a, b, c + 202) + hash3(a, b, c + 303) - 2) * 1.732;

/// Nhiễu giá trị 2D mượt, [0, 1).
double vnoise(double x, double y, int s) {
  final xi = x.floor(), yi = y.floor();
  final xf = x - xi, yf = y - yi;
  double sm(double t) => t * t * (3 - 2 * t);
  final a = hash3(xi, yi, s), b = hash3(xi + 1, yi, s), c = hash3(xi, yi + 1, s), d = hash3(xi + 1, yi + 1, s);
  final u = sm(xf), v = sm(yf);
  return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v;
}

double clamp01(double x) => math.max(0.0, math.min(1.0, x));
