// CỬ CHỈ VUỐT HAI NGÓN (góp ý thử nghiệm: chữ Z một ngón dễ nhầm khi đang rê bản đồ):
//   • hai ngón vuốt XUỐNG  → quay lại (như nói "quay lại")
//   • hai ngón vuốt TRÁI / PHẢI → sang phần kế tiếp / phần trước (thời tiết → địa lý → vũ trụ → máy hát)
// Nhận dạng thuần (không phụ thuộc Flutter, kiểm thử được). Khác với chụm / xoay hai ngón trên quả cầu:
// phải NHANH (≤ maxMs), hai ngón đi CÙNG HƯỚNG, mỗi ngón đi đủ xa, và khoảng cách giữa hai ngón gần như giữ nguyên.
import 'dart:math' as math;

enum Swipe2 { down, up, left, right }

class TwoFingerSwipe {
  TwoFingerSwipe({this.maxMs = 700, this.minDist = 110});

  /// thời gian tối đa từ lúc đặt ngón thứ hai đến lúc nhấc ngón đầu tiên (ms)
  final int maxMs;

  /// quãng đường tối thiểu theo hướng vuốt (điểm ảnh logic)
  final double minDist;

  final _start = <int, (double, double)>{};
  final _last = <int, (double, double)>{};
  int _t0 = 0;
  bool _valid = false;

  void down(int pointer, double x, double y, int tMs) {
    if (_start.isEmpty) _valid = true;
    if (_start.length >= 2) _valid = false; // ngón thứ ba: không phải vuốt hai ngón
    _start[pointer] = (x, y);
    _last[pointer] = (x, y);
    if (_start.length == 2) _t0 = tMs;
  }

  void move(int pointer, double x, double y, int tMs) {
    if (_start.containsKey(pointer)) _last[pointer] = (x, y);
  }

  /// Nhấc một ngón. Trả về hướng vuốt khi nhận ra cử chỉ (chỉ một lần cho mỗi lượt đặt tay).
  Swipe2? up(int pointer, int tMs) {
    Swipe2? r;
    if (_valid && _start.length == 2 && _start.containsKey(pointer) && tMs - _t0 <= maxMs) r = _classify();
    _start.remove(pointer);
    _last.remove(pointer);
    _valid = false; // nhấc một ngón là xong lượt này
    return r;
  }

  void cancel() {
    _start.clear();
    _last.clear();
    _valid = false;
  }

  static double _dist((double, double) a, (double, double) b) => math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

  Swipe2? _classify() {
    final ks = _start.keys.toList();
    final a0 = _start[ks[0]]!, a1 = _last[ks[0]]!, b0 = _start[ks[1]]!, b1 = _last[ks[1]]!;
    final dax = a1.$1 - a0.$1, day = a1.$2 - a0.$2, dbx = b1.$1 - b0.$1, dby = b1.$2 - b0.$2;
    // chụm / mở hai ngón (phóng to, thu nhỏ) → không phải vuốt
    final d0 = _dist(a0, b0), d1 = _dist(a1, b1);
    if ((d1 - d0).abs() > math.max(60.0, d0 * 0.35)) return null;
    final mx = (dax + dbx) / 2, my = (day + dby) / 2;
    final each = minDist * 0.7;
    if (mx.abs() >= my.abs() * 1.5) {
      if (dax.abs() < each || dbx.abs() < each || dax.sign != dbx.sign || mx.abs() < minDist) return null;
      return mx > 0 ? Swipe2.right : Swipe2.left;
    }
    if (my.abs() >= mx.abs() * 1.5) {
      if (day.abs() < each || dby.abs() < each || day.sign != dby.sign || my.abs() < minDist) return null;
      return my > 0 ? Swipe2.down : Swipe2.up; // toạ độ màn hình: y tăng là đi xuống
    }
    return null;
  }
}
