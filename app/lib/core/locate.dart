// "NƠI TÔI ĐỨNG": lấy vị trí GPS / định vị của máy (điện thoại, Windows, trình duyệt) qua gói geolocator.
// Trả về null nếu người dùng không cho phép hoặc máy tắt định vị — app sẽ nói rõ lý do.
import 'package:geolocator/geolocator.dart';

enum LocateFail { off, denied, error }

class MyPosition {
  final double lat, lon;
  final double accuracy; // mét
  const MyPosition(this.lat, this.lon, this.accuracy);
}

Future<(MyPosition?, LocateFail?)> locateMe({Duration timeout = const Duration(seconds: 3)}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return (null, LocateFail.off);
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return (null, LocateFail.denied);
    // vị trí máy vừa biết (≤ 5 phút) → trả lời ngay, khỏi chờ bắt sóng GPS
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().difference(last.timestamp).inMinutes < 5) {
        return (MyPosition(last.latitude, last.longitude, last.accuracy), null);
      }
    } catch (_) {} // web không có
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: timeout),
    );
    return (MyPosition(pos.latitude, pos.longitude, pos.accuracy), null);
  } catch (_) {
    try {
      final last = await Geolocator.getLastKnownPosition(); // không có trên web
      if (last != null) return (MyPosition(last.latitude, last.longitude, last.accuracy), null);
    } catch (_) {}
    return (null, LocateFail.error);
  }
}
