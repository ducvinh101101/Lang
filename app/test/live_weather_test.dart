import 'package:earthsense/live/live_weather.dart';
import 'package:earthsense/live/weather_talk.dart';
import 'package:flutter_test/flutter_test.dart';

LiveWeather _w({
  DateTime? now,
  double temp = 28,
  double feels = 30,
  int code = 2,
  List<int> hourProbs = const [10, 10, 10, 10, 10, 10],
  double tmax = 31,
  double tmin = 24,
  int dayProb = 10,
  double rainMm = 0,
  double uv = 5,
  int? aqi,
}) {
  final realNow = now ?? DateTime.now();
  final t0 = DateTime(realNow.year, realNow.month, realNow.day);
  return LiveWeather(
    'test',
    realNow,
    LiveNow(temp: temp, feels: feels, humidity: 80, precip: 0, desc: wmoText(code).$1, code: code, wind: 10),
    [
      for (var k = 0; k < hourProbs.length; k++)
        LiveHour(realNow.add(Duration(hours: k + 1)), temp, hourProbs[k], hourProbs[k] >= 50 ? 61 : code, ''),
    ],
    [
      LiveDay(t0, tmax, tmin, dayProb, rainMm, code, wmoText(code).$1, uv, 15),
      LiveDay(t0.add(const Duration(days: 1)), tmax, tmin, 80, 20, 81, 'mưa rào', uv, 15),
    ],
    aqi: aqi,
  );
}

void main() {
  test('mã thời tiết WMO sang tiếng Việt', () {
    expect(wmoText(0).$1, 'trời quang');
    expect(wmoText(95).$1, 'có dông');
    expect(isRainy(63), isTrue);
    expect(isRainy(2), isFalse);
  });

  test('bây giờ: có nơi, nhiệt độ, trời', () {
    final t = nowText('Huế', 'Hue', _w()).$1;
    expect(t, startsWith('Bây giờ ở Huế: 28 độ, có mây'));
    expect(t, contains('ít khả năng mưa'));
  });

  test('sắp mưa → báo giờ mưa và khuyên mang ô', () {
    final w = _w(hourProbs: [10, 10, 70, 80, 60, 20]);
    expect(rainNext(w).$1, contains('70 phần trăm'));
    expect(adviceFor(w).map((e) => e.$1).join(' '), contains('ô hoặc áo mưa'));
  });

  test('nắng nóng, rét, không khí xấu, trời đẹp', () {
    expect(adviceFor(_w(tmax: 37, feels: 40)).first.$1, contains('Nắng nóng'));
    expect(adviceFor(_w(tmin: 10, tmax: 15, temp: 12, feels: 11)).map((e) => e.$1).join(), contains('rét'));
    expect(adviceFor(_w(aqi: 170)).map((e) => e.$1).join(), contains('khẩu trang'));
    expect(adviceFor(_w()).single.$1, contains('dễ chịu'));
    expect(adviceFor(_w(), kid: true).single.$1, contains('ra ngoài chơi'));
  });

  test('dự báo ngày mai', () {
    final w = _w();
    final t = dayText('Hà Nội', 'Hanoi', w.days[1]).$1;
    expect(t, startsWith('Ngày mai ở Hà Nội: mưa rào, từ 24 đến 31 độ, khả năng mưa 80 phần trăm'));
    expect(adviceText('Hà Nội', 'Hanoi', w, day: 1).$1, contains('áo mưa'));
  });

  test('hỏi mưa: trả lời thẳng, không kèm nhiệt độ', () {
    var t = rainAnswer('Thanh Hóa', 'Thanh Hoa', _w(), 0).$1;
    expect(t, startsWith('Không. Thanh Hóa hiện không mưa'));
    expect(t, isNot(contains('độ.')));
    t = rainAnswer('Thanh Hóa', 'Thanh Hoa', _w(hourProbs: [10, 70, 80, 20, 10, 10], rainMm: 20), 0).$1;
    expect(t, startsWith('Có. Thanh Hóa hiện chưa mưa nhưng nhiều khả năng sẽ mưa, khoảng 80 phần trăm'));
    expect(t, contains('20 mi-li-mét, mưa vừa'));
    t = rainAnswer('Huế', 'Hue', _w(code: 63), 0).$1;
    expect(t, startsWith('Có. Ở Huế đang mưa'));
    t = rainAnswer('Hà Nội', 'Hanoi', _w(), 1).$1;
    expect(t, startsWith('Có. Ngày mai ở Hà Nội nhiều khả năng mưa, khoảng 80 phần trăm, lượng mưa khoảng 20 mi-li-mét'));
  });

  test('hỏi một chỉ số → chỉ chỉ số đó', () {
    final w = _w();
    expect(tempAnswer('Hà Nội', 'Hanoi', w, 0).$1, 'Bây giờ ở Hà Nội 28 độ, cảm giác như 30 độ. Hôm nay thấp nhất 24, cao nhất 31 độ.');
    expect(tempAnswer('Hà Nội', 'Hanoi', w, 1).$1, 'Ngày mai ở Hà Nội thấp nhất 24, cao nhất 31 độ.');
    expect(humidAnswer('Huế', 'Hue', w).$1, startsWith('Độ ẩm ở Huế bây giờ 80 phần trăm'));
    expect(windAnswer('Huế', 'Hue', w, 0).$1, contains('10 ki-lô-mét một giờ, gió nhẹ'));
    expect(airAnswer('Huế', 'Hue', w).$1, startsWith('Chưa có số liệu'));
  });

  test('dự báo N ngày tới', () {
    final w = _w();
    final t = weekText('Huế', 'Hue', w, days: 1, from: 1).$1;
    expect(t, startsWith('Ngày mai ở Huế: mưa rào, 24 đến 31 độ, mưa 80 phần trăm, khoảng 20 mi-li-mét.'));
    final t5 = weekText('Huế', 'Hue', w, days: 5, from: 1).$1;
    expect(t5, startsWith('Mình chỉ có dự báo tối đa 1 ngày tới.'));
  });

  test('trời nắng / mặt trời mọc lặn / phơi đồ / so sánh / cuối tuần', () {
    final w = _w();
    expect(skyAnswer('Huế', 'Hue', w, 0).$1, startsWith('Bây giờ ở Huế'));
    expect(skyAnswer('Huế', 'Hue', _w(code: 63), 0).$1, contains('mưa'));
    expect(sunAnswer('Huế', 'Hue', w, 0).$1, startsWith('Mình chưa có giờ mặt trời mọc'));
    final t0 = DateTime.now();
    final d0 = DateTime(t0.year, t0.month, t0.day);
    final ws = LiveWeather('test', t0, w.now, w.hours, [
      LiveDay(d0, 31, 24, 10, 0, 2, 'có mây', 5, 15, sunrise: d0.add(const Duration(hours: 5, minutes: 52)), sunset: d0.add(const Duration(hours: 17, minutes: 25))),
    ]);
    expect(sunAnswer('Huế', 'Hue', ws, 0).$1, 'Hôm nay ở Huế mặt trời mọc lúc 5 giờ 52, lặn lúc 17 giờ 25. Trời tối hẳn khoảng 17 giờ 50. Ban ngày dài 11 giờ 33 phút.');
    expect(dryAnswer('Huế', 'Hue', _w(now: DateTime(d0.year, d0.month, d0.day, 10, 0), hourProbs: [10, 70, 80, 20, 10, 10]), 0).$1, contains('Không nên phơi'));
    expect(dryAnswer('Huế', 'Hue', _w(code: 63), 0).$1, startsWith('Đang mưa'));
    final c = compareAnswer('Hà Nội', 'Hanoi', _w(temp: 28), 'Đà Nẵng', 'Da Nang', _w(temp: 31, hourProbs: [70, 70, 70, 70, 70, 70]), 0).$1;
    expect(c, startsWith('Bây giờ, Hà Nội 28 độ, Đà Nẵng 31 độ. Đà Nẵng nóng hơn 3 độ.'));
    expect(c, contains('Đà Nẵng dễ mưa hơn'));
    expect(tempAnswer('Huế', 'Hue', w, 0, period: 'toi').$1, anyOf(startsWith('Tối nay ở Huế'), startsWith('Bây giờ ở Huế')));
  });

  test('gợi ý thông minh theo ngữ cảnh: khi ra ngoài (khu vực đang ở) vs khi đến nơi khác', () {
    // 1. Trời sắp mưa / mưa rào:
    final rainyW = _w(hourProbs: [15, 75, 80, 60, 20, 10]);
    final localRain = contextualSuggestion('Hà Nội', 'Hanoi', rainyW, isLocal: true);
    expect(localRain.$1, startsWith('Khi ra ngoài bạn lưu ý:'));
    expect(localRain.$1, contains('mang ô hoặc áo mưa'));
    expect(localRain.$1, contains('Đường có thể trơn'));
    expect(localRain.$2, startsWith('When going out:'));

    final destRain = contextualSuggestion('Huế', 'Hue', rainyW, isLocal: false);
    expect(destRain.$1, startsWith('Nếu đến Huế hoặc ra ngoài tại đây, bạn nên chuẩn bị:'));
    expect(destRain.$1, contains('mang ô hoặc áo mưa'));
    expect(destRain.$2, startsWith('If visiting or going out in Hue:'));

    // 2. Trời rét đậm (Sa Pa):
    final coldW = _w(temp: 10, feels: 8, tmin: 8, tmax: 13);
    final destCold = contextualSuggestion('Sa Pa', 'Sa Pa', coldW, isLocal: false);
    expect(destCold.$1, startsWith('Nếu đến Sa Pa hoặc ra ngoài tại đây, bạn nên chuẩn bị:'));
    expect(destCold.$1, contains('mặc nhiều lớp áo ấm'));

    final localCold = contextualSuggestion('chỗ bạn đứng', 'where you are', coldW, isLocal: true);
    expect(localCold.$1, startsWith('Khi ra ngoài bạn lưu ý:'));
    expect(localCold.$1, contains('mặc nhiều lớp áo ấm'));

    // 3. Trời nắng nóng & bụi mịn / không khí kém:
    final hotPollutedW = _w(temp: 36, feels: 39, tmax: 37, aqi: 165);
    final localHot = contextualSuggestion('Hà Nội', 'Hanoi', hotPollutedW, isLocal: true);
    expect(localHot.$1, contains('Khi ra ngoài bạn lưu ý:'));
    expect(localHot.$1, contains('uống đủ nước'));
    expect(localHot.$1, contains('đeo khẩu trang'));

    // 4. Thời tiết đẹp, dễ chịu:
    final niceW = _w(temp: 26, feels: 26, tmax: 28, tmin: 22, hourProbs: [5, 5, 5, 5, 5, 5]);
    final localNice = contextualSuggestion('Hà Nội', 'Hanoi', niceW, isLocal: true);
    expect(localNice.$1, contains('thuận lợi nếu bạn muốn ra ngoài đi dạo hay đi công việc'));
    final destNice = contextualSuggestion('Đà Lạt', 'Da Lat', niceW, isLocal: false);
    expect(destNice.$1, contains('Thời tiết ở Đà Lạt khá dễ chịu'));
    expect(destNice.$1, contains('đến tham quan hoặc ra ngoài dạo chơi'));

    // 5. adviceText với isLocal = true vs false:
    final advLocal = adviceText('Hà Nội', 'Hanoi', rainyW, isLocal: true);
    expect(advLocal.$1, contains('ở chỗ bạn (Hà Nội), khi ra ngoài lưu ý:'));
    final advDest = adviceText('Huế', 'Hue', rainyW, isLocal: false);
    expect(advDest.$1, startsWith('Hôm nay ở Huế:'));
  });
}

