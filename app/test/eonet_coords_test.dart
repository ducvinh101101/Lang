// EONET có sự kiện lũ ghi toạ độ NGƯỢC [vĩ độ, kinh độ] (kiểm tra thật ngày 14/11/2026: "Flood in Cambodia 1104174"
// có điểm [13,537; 102,334]). eonetLatLon phải tự đổi lại, nếu không sự kiện bị đặt ở "vĩ độ 102" và bị bỏ qua.
import 'package:earthsense/live/eonet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đúng chuẩn GeoJSON [kinh độ, vĩ độ]', () {
    expect(eonetLatLon([104.78, 21.33]), (21.33, 104.78));
  });
  test('bị ghi ngược [vĩ độ, kinh độ] → tự đổi', () {
    expect(eonetLatLon([13.537, 102.334]), (13.537, 102.334));
  });
  test('dữ liệu hỏng → null', () {
    expect(eonetLatLon(null), isNull);
    expect(eonetLatLon([1]), isNull);
    expect(eonetLatLon([200, 100]), isNull);
    expect(eonetLatLon(['a', 'b']), isNull);
  });
}
