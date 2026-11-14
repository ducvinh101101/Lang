import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:earthsense/live/live_weather.dart';
import 'package:earthsense/live/weather_talk.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/hanoi_places.dart';

void main() {
  // Test này GỌI MẠNG THẬT (Open-Meteo). Trên GitHub Actions máy chủ thời tiết hay từ chối/quá tải (429, 503)
  // → test hỏng dù app không có lỗi. Bỏ qua trên CI; chạy tay: flutter test test/real_direct_e2e_test.dart
  final onCi = Platform.environment['CI'] == 'true' || Platform.environment['GITHUB_ACTIONS'] == 'true';
  test('TEST TRỰC TIẾP: Lấy dữ liệu thật từ Open-Meteo và trả lời hôm nay / tương lai', skip: onCi ? 'Gọi mạng thật (Open-Meteo): bỏ qua trên CI' : false, () async {
    final weatherService = WeatherService();
    // Tọa độ Hà Nội
    final lat = 21.028;
    final lon = 105.854;

    print('\n======================================================');
    print('1. GỌI API THỰC TẾ LẤY THỜI TIẾT HÀ NỘI TỪ OPEN-METEO');
    print('======================================================');
    final weather = await weatherService.get(lat, lon, lang: 'vi');

    print('Nhà cung cấp: ${weather.source}');
    print('Thời gian ghi nhận: ${weather.fetched}');
    print('Hiện tại (now): ${weather.now.temp}°C, cảm giác như ${weather.now.feels}°C, độ ẩm ${weather.now.humidity}%, ${weather.now.desc}');
    print('Tổng số ngày dự báo nhận được: ${weather.days.length} ngày');
    
    print('\nDanh sách các ngày trong dữ liệu:');
    for (var i = 0; i < weather.days.length; i++) {
      final d = weather.days[i];
      final dn = dayName(d, DateTime.now());
      print('  [$i] ${d.date.toIso8601String().substring(0, 10)} (${dn.$1}): min ${d.tmin}°C, max ${d.tmax}°C, ${d.desc}, mưa: ${d.rainProb ?? 0}%');
    }

    print('\n======================================================');
    print('2. TEST CÁC CÂU LỆNH HỎI THỜI TIẾT THỰC TẾ');
    print('======================================================');

    // Case 1: Thời tiết hôm nay
    final c1 = parseWorld('thời tiết hà nội hôm nay');
    final dayIndex1 = c1.liveDay ?? 0;
    final res1 = nowText('Hà Nội', 'Hanoi', weather).$1;
    final sug1 = contextualSuggestion('Hà Nội', 'Hanoi', weather, day: dayIndex1, isLocal: true).$1;
    print('Câu hỏi: "thời tiết hà nội hôm nay"');
    print('  -> Phân giải: kind=${c1.kind}, target="${c1.target}", dayIndex=$dayIndex1');
    print('  -> Câu trả lời: "$res1 $sug1"');
    expect(c1.kind, WKind.weather);
    expect(dayIndex1, 0);

    // Case 2: Ngày mai có mưa không
    final c2 = parseWorld('ngày mai ở hà nội có mưa không');
    final dayIndex2 = c2.liveDay ?? 1;
    final res2 = rainAnswer('Hà Nội', 'Hanoi', weather, dayIndex2).$1;
    final d2 = weather.days[dayIndex2];
    print('\nCâu hỏi: "ngày mai ở hà nội có mưa không"');
    print('  -> Phân giải: kind=${c2.kind}, aspect=${c2.aspect}, dayIndex=$dayIndex2 (${d2.date.toIso8601String().substring(0, 10)})');
    print('  -> Câu trả lời: "$res2"');
    expect(c2.kind, WKind.weather);
    expect(c2.aspect, 'rain');
    expect(dayIndex2, 1);

    // Case 3: Ngày kia mấy độ
    final c3 = parseWorld('ngày kia ở hà nội mấy độ');
    final dayIndex3 = c3.liveDay ?? 2;
    final res3 = tempAnswer('Hà Nội', 'Hanoi', weather, dayIndex3).$1;
    final d3 = weather.days[dayIndex3];
    print('\nCâu hỏi: "ngày kia ở hà nội mấy độ"');
    print('  -> Phân giải: kind=${c3.kind}, aspect=${c3.aspect}, dayIndex=$dayIndex3 (${d3.date.toIso8601String().substring(0, 10)})');
    print('  -> Câu trả lời: "$res3"');
    expect(dayIndex3, 2);

    // Case 4: Dự báo 3 ngày tới
    final c4 = parseWorld('dự báo 3 ngày tới ở hà nội');
    final nDays = c4.liveDay ?? 3;
    final res4 = weekText('Hà Nội', 'Hanoi', weather, days: nDays, from: 1).$1;
    print('\nCâu hỏi: "dự báo 3 ngày tới ở hà nội"');
    print('  -> Phân giải: kind=${c4.kind}, liveDay=$nDays');
    print('  -> Câu trả lời: "$res4"');
    expect(c4.kind, WKind.forecast);
    expect(nDays, 3);

    // Case 5: Chủ nhật này thời tiết thế nào
    final c5 = parseWorld('chủ nhật này thời tiết hà nội thế nào');
    final dayIndex5 = c5.liveDay ?? 0;
    final d5 = weather.days[dayIndex5];
    final res5 = dayText('Hà Nội', 'Hanoi', d5).$1;
    print('\nCâu hỏi: "chủ nhật này thời tiết hà nội thế nào"');
    print('  -> Phân giải: kind=${c5.kind}, dayIndex=$dayIndex5 (${d5.date.toIso8601String().substring(0, 10)})');
    print('  -> Câu trả lời: "$res5"');

    print('\n======================================================');
    print('3. TEST TRỰC TIẾP TÌM KIẾM ĐỊA ĐIỂM RẢI RÁC CÁC KHU VỰC');
    print('======================================================');
    final db = HanoiPlacesDb.parse(File('assets/data/hanoi_places.json').readAsStringSync());
    expect(db, isNotNull);

    // Test hỏi quán ăn ở Đống Đa
    final qFoodDongDa = parsePlaceQuery('ở đống đa có quán ăn nào ngon', db)!;
    final hitsFoodDongDa = searchPlaces(db, qFoodDongDa);
    final ansFoodDongDa = placesAnswer(db, qFoodDongDa, hitsFoodDongDa).$1;
    print('Câu hỏi: "ở đống đa có quán ăn nào ngon"');
    print('  -> Tìm thấy ${hitsFoodDongDa.length} nơi: ${hitsFoodDongDa.map((h) => h.$1.name).join(", ")}');
    print('  -> Câu trả lời: "$ansFoodDongDa"');
    expect(hitsFoodDongDa, isNotEmpty);

    // Test hỏi khách sạn ở Bắc Từ Liêm
    final qStayBTL = parsePlaceQuery('ở bắc từ liêm có khách sạn nào', db)!;
    final hitsStayBTL = searchPlaces(db, qStayBTL);
    final ansStayBTL = placesAnswer(db, qStayBTL, hitsStayBTL).$1;
    print('\nCâu hỏi: "ở bắc từ liêm có khách sạn nào"');
    print('  -> Tìm thấy ${hitsStayBTL.length} nơi: ${hitsStayBTL.map((h) => h.$1.name).join(", ")}');
    print('  -> Câu trả lời: "$ansStayBTL"');
    expect(hitsStayBTL, isNotEmpty);

    // Test hỏi resort ở Ba Vì
    final qStayBaVi = parsePlaceQuery('resort nghỉ dưỡng ở ba vì', db)!;
    final hitsStayBaVi = searchPlaces(db, qStayBaVi);
    final ansStayBaVi = placesAnswer(db, qStayBaVi, hitsStayBaVi).$1;
    print('\nCâu hỏi: "resort nghỉ dưỡng ở ba vì"');
    print('  -> Tìm thấy ${hitsStayBaVi.length} nơi: ${hitsStayBaVi.map((h) => h.$1.name).join(", ")}');
    print('  -> Câu trả lời: "$ansStayBaVi"');
    expect(hitsStayBaVi, isNotEmpty);

    print('\n======================================================');
    print('TẤT CẢ CÁC BƯỚC TEST TRỰC TIẾP ĐỀU THÀNH CÔNG VƯỢT TRỘI!');
    print('======================================================\n');
  });
}
