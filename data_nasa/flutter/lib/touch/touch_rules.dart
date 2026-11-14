// touch_rules.dart — luật đổi số liệu thành âm thanh / rung cho F3. Thuần Dart, không phụ thuộc Flutter,
// để kiểm thử được bằng `flutter test` (xem test/touch_rules_test.dart).
import 'dart:math' as math;

const pentaSteps = [0, 2, 5, 7, 9]; // ngũ cung hơi Bắc: Đô Rê Fa Sol La

/// Làm tròn nốt MIDI về nốt ngũ cung gần nhất (hoà thì lấy nốt thấp).
int snapPenta(int midi) {
  var best = midi, bestD = 1 << 30;
  for (var o = midi ~/ 12 - 1; o <= midi ~/ 12 + 1; o++) {
    for (final s in pentaSteps) {
      final n = o * 12 + s, d = (n - midi).abs();
      if (d < bestD || (d == bestD && n < best)) {
        best = n;
        bestD = d;
      }
    }
  }
  return best;
}

/// Độ cao -> nốt sáo: 0 m = MIDI 60, từ 2 000 m = MIDI 84, ở giữa chia đều rồi về ngũ cung.
int elevToMidi(double m) => snapPenta((60 + (m.clamp(0, 2000) / 2000) * 24).round());

double midiToHz(int m) => 440 * math.pow(2, (m - 69) / 12).toDouble();

/// Một nhịp rung theo độ dốc.
class SlopePulse {
  const SlopePulse(this.ms, this.amplitude, this.level);
  final int ms; // thời lượng rung
  final int amplitude; // 1..255 (Android có điều khiển cường độ)
  final int level; // 1 = thoải, 2 = dốc, 3 = rất dốc (cho iOS/web: light/medium/heavy)
}

/// Độ dốc trung bình của ô (độ) -> nhịp rung. Dưới 2° coi là bằng phẳng: không rung.
/// 2° -> 15 ms, cường độ 40; từ 25° trở lên -> 60 ms, cường độ 255; ở giữa tăng tuyến tính.
/// Rung ngắn (≤ 60 ms) để không lẫn với rung 150 ms khi vượt biên giới.
SlopePulse? slopePulse(double? deg) {
  if (deg == null || deg < 2) return null;
  final t = ((deg - 2) / 23).clamp(0.0, 1.0);
  return SlopePulse((15 + 45 * t).round(), (40 + 215 * t).round(), deg < 8 ? 1 : (deg < 18 ? 2 : 3));
}

/// Mật độ dân số (người/km²) -> số xe chạy qua trong mỗi cửa sổ 2 giây: 0 khi < 50 người/km²,
/// tăng theo log10, tối đa 6 xe. Âm lượng 0,25..0,8 theo cùng thang.
int carsPerWindow(double? density) {
  if (density == null || density < 50) return 0;
  return (1.5 * (math.log(density / 50) / math.ln10 + 1)).round().clamp(1, 6);
}

double trafficVolume(double? density) {
  if (density == null || density < 50) return 0;
  final t = ((math.log(density) / math.ln10 - 1.7) / 2.3).clamp(0.0, 1.0); // 50 -> 0, 10 000 -> 1
  return 0.25 + 0.55 * t;
}

/// Loại âm nền nước dưới ngón tay.
enum WaterKind { none, sea, inland }

WaterKind waterKind({required bool sea, double? waterFraction, double threshold = 0.5}) {
  if (sea) return WaterKind.sea;
  if (waterFraction != null && waterFraction >= threshold) return WaterKind.inland;
  return WaterKind.none;
}

/// Trung bình các giá trị có số liệu (bỏ null). Không có giá trị nào -> null.
double? meanOf(Iterable<double?> values) {
  var sum = 0.0, n = 0;
  for (final v in values) {
    if (v != null) {
      sum += v;
      n++;
    }
  }
  return n == 0 ? null : sum / n;
}

/// Thời lượng một lượt quét: tối đa 8 giây (yêu cầu F3); lưới ít lát thì quét nhanh hơn
/// (40 ms mỗi lát) nhưng không dưới 3 giây để kịp nghe.
Duration sweepDuration(int slices, {Duration max = const Duration(seconds: 8)}) {
  final ms = (slices * 40).clamp(3000, max.inMilliseconds);
  return Duration(milliseconds: ms);
}

/// Lát đang quét tại thời điểm [elapsed] của lượt quét dài [total] gồm [slices] lát.
int sliceAt(Duration elapsed, Duration total, int slices) {
  if (elapsed >= total) return slices - 1;
  return (elapsed.inMicroseconds * slices ~/ total.inMicroseconds).clamp(0, slices - 1);
}

/// Đọc số mét cho dễ nghe: làm tròn 10 m dưới 200 m, 50 m từ 200 m trở lên.
int roundMeters(double m) => m < 200 ? (m / 10).round() * 10 : (m / 50).round() * 50;
