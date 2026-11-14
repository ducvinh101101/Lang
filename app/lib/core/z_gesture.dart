// CỬ CHỈ CỐ ĐỊNH "VẼ CHỮ Z" (dưới 1 giây) → về màn hình chính của nhánh đang dùng
// (bản đồ Trái Đất hoặc bản đồ Hệ Mặt Trời), dù đang ở rê tay, quét lát cắt, lịch sử hay trò chơi.
//
// Nhận dạng thuần (không phụ thuộc Flutter, kiểm thử được): một nét liền một ngón, gồm
//   1) gạch ngang sang PHẢI  2) gạch chéo xuống TRÁI  3) gạch ngang sang PHẢI
// hoàn thành trong ≤ 1000 ms, đủ lớn (không nhầm với chạm / rê ngắn).
import 'dart:math' as math;

class ZGesture {
  /// thời gian tối đa của cả nét (ms)
  final int maxMs;

  /// kích thước tối thiểu của chữ Z (điểm ảnh logic)
  final double minW, minH;
  ZGesture({this.maxMs = 1000, this.minW = 90, this.minH = 70});

  final _x = <double>[], _y = <double>[], _t = <int>[];
  int? _pointer;
  bool _multi = false;

  /// Ngón đặt xuống. Ngón thứ hai → huỷ (chụm / xoay hai ngón không phải chữ Z).
  void down(int pointer, double x, double y, int tMs) {
    if (_pointer != null && _pointer != pointer) {
      _multi = true;
      return;
    }
    _pointer = pointer;
    _multi = false;
    _x
      ..clear()
      ..add(x);
    _y
      ..clear()
      ..add(y);
    _t
      ..clear()
      ..add(tMs);
  }

  void move(int pointer, double x, double y, int tMs) {
    if (pointer != _pointer || _multi) return;
    _x.add(x);
    _y.add(y);
    _t.add(tMs);
  }

  /// Nhấc ngón: true nếu vừa vẽ xong một chữ Z.
  bool up(int pointer, int tMs) {
    if (pointer != _pointer) return false;
    _pointer = null;
    final ok = !_multi && isZ(_x, _y, _t, maxMs: maxMs, minW: minW, minH: minH);
    _x.clear();
    _y.clear();
    _t.clear();
    _multi = false;
    return ok;
  }

  void cancel() {
    _pointer = null;
    _multi = false;
    _x.clear();
    _y.clear();
    _t.clear();
  }
}

/// Chuỗi điểm (toạ độ màn hình: y hướng xuống) có phải chữ Z vẽ nhanh không.
bool isZ(List<double> xs, List<double> ys, List<int> ts, {int maxMs = 1000, double minW = 90, double minH = 70}) {
  final n = xs.length;
  if (n < 4 || ts.last - ts.first > maxMs) return false;
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final w = maxX - minX, h = maxY - minY;
  if (w < minW || h < minH) return false;
  // đi lại theo nét, lấy mẫu đều mỗi ~4% chiều dài → hướng từng đoạn
  var len = 0.0;
  for (var i = 1; i < n; i++) {
    len += math.sqrt(math.pow(xs[i] - xs[i - 1], 2) + math.pow(ys[i] - ys[i - 1], 2));
  }
  if (len < w + h) return false; // Z thật dài ≈ 2 lần rộng + đường chéo
  final step = len / 25;
  final runs = <(String, double)>[]; // (hướng, độ dài)
  var ax = xs[0], ay = ys[0], acc = 0.0;
  for (var i = 1; i < n; i++) {
    acc += math.sqrt(math.pow(xs[i] - xs[i - 1], 2) + math.pow(ys[i] - ys[i - 1], 2));
    if (acc < step && i < n - 1) continue;
    final dx = xs[i] - ax, dy = ys[i] - ay;
    final seg = math.sqrt(dx * dx + dy * dy);
    ax = xs[i];
    ay = ys[i];
    acc = 0;
    if (seg < 1) continue;
    final a = math.atan2(dy, dx) * 180 / math.pi; // 0 = sang phải, 90 = xuống, 180 = sang trái
    final dir = a.abs() <= 35
        ? 'E'
        : (a >= 95 && a <= 175)
            ? 'D' // chéo xuống trái
            : 'X';
    if (runs.isNotEmpty && runs.last.$1 == dir) {
      runs[runs.length - 1] = (dir, runs.last.$2 + seg);
    } else {
      runs.add((dir, seg));
    }
  }
  // bỏ đoạn lặt vặt ở góc gập (< 10% chiều dài), gộp lại các đoạn cùng hướng
  final main = <(String, double)>[];
  for (final r in runs) {
    if (r.$2 < len * 0.10) continue;
    if (main.isNotEmpty && main.last.$1 == r.$1) {
      main[main.length - 1] = (r.$1, main.last.$2 + r.$2);
    } else {
      main.add(r);
    }
  }
  if (main.length != 3 || main[0].$1 != 'E' || main[1].$1 != 'D' || main[2].$1 != 'E') return false;
  // hai gạch ngang mỗi gạch ít nhất 40% chiều rộng; tổng phần "lạc hướng" nhỏ
  if (main[0].$2 < 0.4 * w || main[2].$2 < 0.4 * w) return false;
  final good = main.fold<double>(0, (s, r) => s + r.$2);
  return good >= 0.75 * len;
}
