// Test thuần Dart (không cần thiết bị). Số tham chiếu lấy bằng cách chạy chính code JS của web/index.html,
// để chắc bản Flutter cho ra cùng bản đồ/âm thanh với bản demo web.
import 'package:earthsense/audio/audio_engine.dart';
import 'package:earthsense/core/format.dart';
import 'package:earthsense/core/geo.dart';
import 'package:earthsense/core/noise.dart';
import 'package:earthsense/data/synthetic_data.dart';
import 'package:earthsense/features/describe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hash/gauss/vnoise khớp bản web', () {
    expect(hash3(1, 2, 3), closeTo(0.6394013063982129, 1e-12));
    expect(hash3(-5, 2020, 9), closeTo(0.1372961460147053, 1e-12));
    expect(gauss3(2, 2020, 309), closeTo(0.037146829219534994, 1e-12));
    expect(vnoise(160.5, 24.7, 11), closeTo(0.4418114795917647, 1e-12));
  });

  test('lưới và vùng khớp bản web + pipeline (2849 ô đất liền)', () {
    expect(gw, 100);
    expect(gh, 153);
    final g = GeoGrid.builtin();
    expect(g.type.where((t) => t == cellVn).length, 2849);
    final hue = 7155;
    expect(g.type[hue], cellVn);
    expect(g.region[hue], 2);
    expect(regionOf(105.85, 21.03), 1); // Hà Nội
    expect(regionOf(108.44, 11.94), 4); // Đà Lạt
    expect(regionOf(106.66, 10.78), 5); // TP. Hồ Chí Minh
    expect(g.nearestPlace(107.59, 16.46), 'Huế');
  });

  test('dữ liệu giả lập khớp bản web', () {
    final d = SyntheticData();
    const hue = 7155;
    expect(d.values('rain', 2020, 9)[hue], closeTo(1244.56091461306, 0.01));
    expect(d.values('temp', 2020, 6)[hue], closeTo(28.236272806639562, 0.001));
    expect(d.clim('rain', hue, 9), closeTo(655.4275740513941, 0.01));
    final se = d.series(2, 'rain');
    expect(se.length, 300);
    expect(se.values[237], closeTo(907.945068359375, 0.05)); // 10/2020 Bắc Trung Bộ
    expect(se.z[237], closeTo(2.698, 0.01)); // bất thường → có tiếng chiêng
    expect(d.eventLabel(2, 'rain', 2020, 9, 'vi'), contains('2020'));
  });

  test('thang ngũ cung', () {
    expect(toScale(0), closeTo(130.81, 1e-6));
    expect(toScale(1), closeTo(130.81 * 4 * 1.6818, 0.5)); // 2 quãng tám + 9 nửa cung
    expect(toScale(0.5) > toScale(0.4), isTrue);
  });

  test('định dạng số kiểu Việt', () {
    expect(fmtNum(1234.5, 1), '1.234,5');
    expect(fmtNum(1234.5, 1, lang: 'en'), '1,234.5');
    expect(fmtNum(double.nan, 1), '—');
  });

  test('so sánh với trung bình', () {
    expect(compareText('rain', 1200, 600, 200).vi, 'cao hơn trung bình 100%');
    expect(compareText('rain', 650, 600, 200).vi, 'gần mức trung bình');
    expect(compareText('temp', 30, 28, 0.6).vi, 'cao hơn trung bình 2,0 độ');
  });

  test('từ ngữ cho bạn nhỏ', () {
    expect(kidWord('rain', 700, 0.9).vi, 'mưa rất rất nhiều');
    expect(kidWord('rain', 10, 0.1).vi, 'gần như không mưa');
    expect(kidWord('temp', 35, 0.9).vi, 'rất nóng');
    expect(kidWord('temp', 15, 0.2).vi, 'mát');
  });
}
