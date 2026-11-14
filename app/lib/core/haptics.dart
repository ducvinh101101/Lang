// Rung phản hồi cho người khiếm thị (qua ranh giới vùng, chọn nút, đúng/sai…).
//  • Android/iOS: rung của hệ điều hành (HapticFeedback)
//  • Web: navigator.vibrate() — có trên Chrome/Edge Android (bản web gốc cũng rung như vậy); máy tính thì bỏ qua.
import 'package:flutter/services.dart';

import 'haptics_stub.dart' if (dart.library.js_interop) 'haptics_web.dart' as web;

class Haptics {
  /// Nhẹ: sang vùng khác.
  static void light() {
    HapticFeedback.lightImpact();
    web.vibrate(20);
  }

  /// Vừa: xác nhận, phóng to, vào quần đảo.
  static void medium() {
    HapticFeedback.mediumImpact();
    web.vibrate(35);
  }

  /// CẢNH BÁO THIÊN TAI: ba nhịp rung mạnh, dài — khác hẳn mọi kiểu rung khác.
  static Future<void> alert() async {
    web.vibratePattern(const [500, 150, 500, 150, 500]);
    for (var k = 0; k < 3; k++) {
      HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 380));
    }
  }

  /// Rung theo loại địa hình khi rê tay (chế độ khám phá bằng chạm).
  ///  nước: hai nhịp nhẹ · rừng: một tách · khu dân cư: một nhịp vừa · núi/đồi: một nhịp mạnh
  static void terrain(String kind) {
    switch (kind) {
      case 'water':
      case 'river':
        HapticFeedback.lightImpact();
        Future<void>.delayed(const Duration(milliseconds: 90), HapticFeedback.lightImpact);
        web.vibratePattern(const [20, 60, 20]);
      case 'forest':
      case 'park':
        HapticFeedback.selectionClick();
        web.vibrate(12);
      case 'residential':
        HapticFeedback.mediumImpact();
        web.vibrate(40);
      case 'high':
        HapticFeedback.heavyImpact();
        web.vibrate(70);
      default:
        HapticFeedback.selectionClick();
        web.vibrate(8);
    }
  }

  /// Rung theo ĐỘ DỐC địa hình dưới ngón tay (độ): bằng phẳng không rung, dốc thoải rung nhẹ, dốc đứng rung mạnh và dài.
  /// Trả về false khi quá thoải (không rung).
  static bool slope(double deg) {
    if (deg.isNaN || deg < 2) return false;
    if (deg < 6) {
      HapticFeedback.selectionClick();
      web.vibrate(10);
    } else if (deg < 12) {
      HapticFeedback.lightImpact();
      web.vibrate(25);
    } else if (deg < 22) {
      HapticFeedback.mediumImpact();
      web.vibrate(45);
    } else {
      HapticFeedback.heavyImpact();
      web.vibrate(80);
    }
    return true;
  }

  /// Động đất / bão trong phần lịch sử thiên tai: chuỗi rung dồn dập theo mức nặng (1..5).
  static Future<void> rumble(double severity) async {
    final n = (2 + severity).round().clamp(2, 7);
    web.vibratePattern([for (var k = 0; k < n; k++) ...[90, 60]]);
    for (var k = 0; k < n; k++) {
      severity >= 3.5 ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  /// "Tách": chạm lần 1 vào nút, sang ô mới khi phóng to.
  static void tick() {
    HapticFeedback.selectionClick();
    web.vibrate(10);
  }
}
