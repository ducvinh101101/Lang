import 'package:earthsense/features/globe/hanoi_guide.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:earthsense/features/space/planet_facts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bay tới một nơi', () {
    var c = parseWorld('phóng to Paris');
    expect(c.kind, WKind.go);
    expect(c.target, 'Paris');
    c = parseWorld('đến Nhật Bản');
    expect(c.kind, WKind.go);
    expect(c.target, 'Nhật Bản');
    c = parseWorld('Huế');
    expect(c.kind, WKind.go);
    expect(c.target, 'Huế');
    c = parseWorld('cho tôi xem thành phố Hồ Chí Minh nhé');
    expect(c.target, 'thành phố Hồ Chí Minh');
  });

  test('thời tiết', () {
    var c = parseWorld('thời tiết Luân Đôn');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Luân Đôn');
    c = parseWorld('ngày mai ở Đà Nẵng có mưa không');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Đà Nẵng');
    expect(c.liveDay, 1);
    expect(c.aspect, 'rain');
    c = parseWorld('thời tiết ở đây');
    expect(c.kind, WKind.weather);
    expect(c.target, '');
    c = parseWorld('thời tiết tối nay');
    expect(c.target, '');
    expect(parseWorld('dự báo 5 ngày ở Hà Nội').kind, WKind.forecast);
  });

  test('khí hậu NASA và ngày cũ', () {
    var c = parseWorld('khí hậu Hà Nội');
    expect(c.kind, WKind.climate);
    expect(c.target, 'Hà Nội');
    c = parseWorld('tháng 10 năm 2020 ở Huế');
    expect(c.kind, WKind.climate);
    expect(c.month, 9);
    expect(c.year, 2020);
    expect(c.target, 'Huế');
    c = parseWorld('ngày 15 tháng 10 năm 2024 ở Huế');
    expect(c.kind, WKind.day);
    expect(c.target, 'Huế');
  });

  test('điều khiển', () {
    expect(parseWorld('dừng lại').kind, WKind.stop);
    expect(parseWorld('thu nhỏ').kind, WKind.zoomOut);
    expect(parseWorld('phóng to').kind, WKind.zoomIn);
    expect(parseWorld('cả thế giới').kind, WKind.world);
    expect(parseWorld('đây là đâu').kind, WKind.where);
    expect(parseWorld('trợ giúp').kind, WKind.help);
    expect(parseWorld('nghe 24 giờ tới').kind, WKind.hours);
    expect(parseWorld('tạm nghỉ').kind, WKind.pause);
  });

  test('câu hỏi tự nhiên', () {
    var c = parseWorld('ngày mai tại hà nội mưa không');
    expect(c.kind, WKind.weather);
    expect(c.liveDay, 1);
    expect(c.aspect, 'rain');
    expect(c.target, 'hà nội');
    c = parseWorld('mai tôi đi ra ngoài cần chuẩn bị gì');
    expect(c.kind, WKind.weather);
    expect(c.liveDay, 1);
    expect(c.aspect, 'advice');
    expect(c.target, '');
    c = parseWorld('mai tôi đi chơi có phù hợp không');
    expect(c.kind, WKind.weather);
    expect(c.aspect, 'outing');
    expect(c.target, '');
    c = parseWorld('mai tôi đi chơi ở Đà Lạt có hợp không');
    expect(c.aspect, 'outing');
    expect(c.target, 'Đà Lạt');
    c = parseWorld('hôm nay Hà Nội có mưa không');
    expect(c.aspect, 'rain');
    expect(c.target, 'Hà Nội');
    c = parseWorld('nơi nóng nhất');
    expect(c.target, isNot('nhat'));
  });

  test('ba chức năng mới', () {
    var c = parseWorld('chiều nay có mưa không');
    expect(c.kind, WKind.weather);
    expect(c.period, 'chieu');
    expect(c.liveDay, 0);
    expect(c.aspect, 'rain');
    expect(parseWorld('bản tin').kind, WKind.bulletin);
    expect(parseWorld('có bão không').kind, WKind.disasters);
    expect(parseWorld('thiên tai trên thế giới').aspect, 'world');
    expect(parseWorld('tôi đang ở đâu').aspect, 'gps');
    c = parseWorld('quanh Hồ Hoàn Kiếm có gì');
    expect(c.kind, WKind.around);
    expect(c.target, 'Hồ Hoàn Kiếm');
    expect(parseWorld('khám phá bằng tay').kind, WKind.explore);
    expect(parseWorld('thoát').kind, WKind.exitLocal);
    expect(parseWorld('Hà Nội xưa và nay').kind, WKind.history);
    c = parseWorld('kể chuyện Sao Kim');
    expect(c.kind, WKind.planet);
    expect(c.target, 'Sao Kim');
    expect(parseWorld('Sao Mộc').kind, WKind.planet);
    expect(parseWorld('các hành tinh').target, 'space');
    expect(parseWorld('hệ mặt trời').target, 'space');
    expect(parseWorld('ảnh thiên văn hôm nay').kind, WKind.apod);
    expect(parseWorld('cả thế giới').kind, WKind.world);
  });

  test('hỏi vị trí hiện tại vs hỏi thời tiết tại chỗ đứng', () {
    expect(parseWorld('vị trí hiện tại').kind, WKind.around);
    expect(parseWorld('vị trí hiện tại').aspect, 'gps');
    expect(parseWorld('tôi ở đâu').kind, WKind.around);
    expect(parseWorld('tôi ở đâu').aspect, 'gps');
    expect(parseWorld('tôi đang ở đâu').kind, WKind.around);
    expect(parseWorld('tôi đang ở đâu').aspect, 'gps');
    expect(parseWorld('vị trí của tôi').kind, WKind.around);
    expect(parseWorld('vị trí của tôi').aspect, 'gps');
    expect(parseWorld('nơi tôi đứng').kind, WKind.around);
    expect(parseWorld('nơi tôi đứng').aspect, 'gps');
    expect(parseWorld('định vị vị trí').kind, WKind.around);
    expect(parseWorld('định vị vị trí').aspect, 'gps');

    // Các câu hỏi thời tiết tại vị trí hiện tại phải trả về WKind.weather, không nhầm sang around
    expect(parseWorld('thời tiết ở vị trí hiện tại').kind, WKind.weather);
    expect(parseWorld('vị trí hiện tại có mưa không').kind, WKind.weather);
    expect(parseWorld('ở đây có mưa không').kind, WKind.weather);
    expect(parseWorld('thời tiết chỗ tôi').kind, WKind.weather);
  });

  // Các câu THẬT người dùng đã nói khi thử app (lấy từ nhật ký) — trước đây trả lời sai hoặc im lặng.
  test('câu thật từ nhật ký', () {
    var c = parseWorld('sáng mai tôi đi có cần phải mang ô hay áo mưa không');
    expect(c.kind, WKind.weather);
    expect(c.liveDay, 1);
    expect(c.period, 'sang');
    expect(c.aspect, 'rain');
    expect(c.target, '');
    c = parseWorld('bạn không trả lời được dự báo cho tôi hả');
    expect(c.kind, WKind.forecast);
    expect(c.target, '');
    expect(parseWorld('ừ').kind, WKind.ignore);
    c = parseWorld('thời tiết nam cực');
    expect(c.kind, WKind.weather);
    expect(c.target, 'nam cực');
    c = parseWorld('việt nam');
    expect(c.kind, WKind.go);
    expect(c.target, 'việt nam');
    c = parseWorld('dung và bắc cực');
    expect(c.kind, WKind.go);
    expect(c.target, 'bắc cực');
    expect(parseWorld('rum nhỏ lại lấy bản đồ toàn cầu').kind, WKind.world);
    c = parseWorld('bật chế độ tiếng anh');
    expect(c.kind, WKind.language);
    expect(c.target, 'en');
    c = parseWorld('thế ngày mai tôi có nên ra ngoài không');
    expect(c.kind, WKind.weather);
    expect(c.aspect, 'advice');
    expect(c.target, '');
    c = parseWorld('ngày mai ở hà nội tôi có nên ra ngoài không');
    expect(c.target, 'Hà Nội');
    c = parseWorld('chỗ nào đang có bão');
    expect(c.kind, WKind.disasters);
    expect(c.aspect, 'world');
    expect(parseWorld('cả trái đất thì chỗ nào còn đang có bão').aspect, 'world');
    expect(parseWorld('kể cho tôi về sao kim').kind, WKind.planet);
    expect(parseWorld('còn đà nẵng thì sao').followUp, isTrue);
  });

  test('giới thiệu theo từng phần', () {
    var c = parseWorld('thời tiết thế giới');
    expect(c.kind, WKind.help);
    expect(c.target, 'weather');
    c = parseWorld('khám phá các hành tinh');
    expect(c.kind, WKind.help);
    expect(c.target, 'space');
    c = parseWorld('hướng dẫn địa lý');
    expect(c.target, 'geo');
    expect(parseWorld('bạn làm được gì').kind, WKind.help);
    expect(parseWorld('giới thiệu Sao Kim').kind, WKind.planet);
    expect(parseWorld('thời tiết Hà Nội').kind, WKind.weather);
  });

  test('hỏi một chỉ số thời tiết', () {
    var c = parseWorld('nhiệt độ ở Hà Nội hiện tại');
    expect(c.kind, WKind.weather);
    expect(c.aspect, 'temp');
    expect(c.target, 'Hà Nội');
    c = parseWorld('Thanh Hóa có mưa không');
    expect(c.aspect, 'rain');
    expect(c.target, 'Thanh Hóa');
    expect(parseWorld('Huế bây giờ lượng mưa bao nhiêu').aspect, 'rain');
    expect(parseWorld('độ ẩm Đà Nẵng').aspect, 'humid');
    expect(parseWorld('gió ở Vũng Tàu mạnh không').aspect, 'wind');
    expect(parseWorld('chất lượng không khí Hà Nội').aspect, 'air');
    c = parseWorld('thời tiết Hà Nội');
    expect(c.aspect, isNull);
  });

  test('dự báo nhiều ngày', () {
    var c = parseWorld('dự báo 3 ngày tới ở Huế');
    expect(c.kind, WKind.forecast);
    expect(c.liveDay, 3);
    expect(c.target, 'Huế');
    c = parseWorld('thời tiết hà nội mười ngày tới');
    expect(c.kind, WKind.forecast);
    expect(c.liveDay, 10);
    expect(c.target.toLowerCase(), 'hà nội');
    expect(parseWorld('2 ngày tới có mưa không').liveDay, 2);
    expect(parseWorld('dự báo tuần tới').liveDay, 7);
    expect(parseWorld('15 ngày tới').liveDay, 15);
    c = parseWorld('ngày mai Đà Nẵng có mưa không');
    expect(c.kind, WKind.weather);
    expect(c.liveDay, 1);
    expect(parseWorld('một ngày trên sao hỏa dài bao lâu').kind, isNot(WKind.forecast));
    expect(parseWorld('sao thổ').kind, WKind.planet);
  });

  test('nhật ký thiết bị thật: khắc phục lỗi barge-in lặp và nhận diện sai nơi', () {
    // 1. "nếu mai tôi đi tokyo thì ngày mai có cần mang ô không" phải trích xuất đúng Tokyo
    final tokyoCmd = parseWorld('nếu mai tôi đi tokyo thì ngày mai có cần mang ô không');
    expect(tokyoCmd.kind, WKind.weather);
    expect(tokyoCmd.target.toLowerCase(), 'tokyo');
    expect(tokyoCmd.liveDay, 1);
    expect(tokyoCmd.aspect, 'rain');

    // 2. "bạn kể đi" không được bay tới Bản Kẻ
    final tellMeCmd = parseWorld('bạn kể đi');
    expect(tellMeCmd.kind, WKind.unknown);
    expect(tellMeCmd.target, isNot('bạn kể'));

    // 3. Câu đọc số của app bị lọt vào micro nhận dạng thành chữ không được thành tên nơi
    final echoNum1 = parseWorld('chín mươi phần trăm lượng mưa khoảng tám mươi');
    expect(echoNum1.target, '');
    final echoNum2 = parseWorld('bây giờ mười hai độ');
    expect(echoNum2.target, '');

    // 4. isEchoOf phải nhận ra số viết bằng chữ khớp với số ghi bằng số trong caption
    expect(
      isEchoOf('bây giờ mười hai độ', [('Bây giờ 12 độ, nhiều mây', const Duration(seconds: 1))], speaking: true),
      isTrue,
    );
    expect(
      isEchoOf('chín mươi phần trăm lượng mưa khoảng tám mươi',
          [('khoảng 90 phần trăm, lượng mưa khoảng 8 mi-li-mét', const Duration(seconds: 1))], speaking: true),
      isTrue,
    );
  });

  test('lời gọi và khẩu hiệu đánh thức (Wake Words)', () {
    var c = parseWorld('Lắng ơi thời tiết Hà Nội');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Hà Nội');

    c = parseWorld('Ê Lắng bay tới Đà Nẵng');
    expect(c.kind, WKind.go);
    expect(c.target, 'Đà Nẵng');

    c = parseWorld('Trái Đất ơi kể chuyện Sao Hỏa');
    expect(c.kind, WKind.planet);
    expect(c.target, 'Sao Hỏa');

    // Tiếng Anh: "Hey Listen"
    final cEn = parseWorldEn('Hey Listen weather in Tokyo');
    expect(cEn.kind, WKind.weather);
    expect(cEn.target, 'Tokyo');

    final cEn2 = parseWorldEn('Hey Listen tell me about Mars');
    expect(cEn2.kind, WKind.planet);
    expect(cEn2.target, 'Sao Hỏa');

    // Câu hỏi tự nhiên không cần gọi tên (Smart Natural)
    final natural1 = parseWorld('bạn cho mình biết thời tiết ở hà nội hiện tại được không');
    expect(natural1.kind, WKind.weather);
    expect(natural1.target, 'hà nội');

    // Nhận diện dung sai ngữ âm "là ngươi", "làng ngươi"
    final slip1 = parseWorld('làng ngươi cho mình biết thời tiết ở đà nẵng được không');
    expect(slip1.kind, WKind.weather);
    expect(slip1.target, 'đà nẵng');

    // Câu hỏi khoảng cách từ Trái Đất đến Mặt Trăng
    final distCmd = parseWorld('khoảng cách từ trái đất đến mặt trăng');
    expect(distCmd.kind, WKind.planet);
    expect(distCmd.target, 'Mặt Trăng');
    expect(distCmd.raw, 'khoảng cách từ trái đất đến mặt trăng');
    final ans = planetAnswer(4, 'Mặt Trăng', 'The Moon', distCmd.raw, en: false);
    expect(ans, contains('384 nghìn'));

    // Câu hỏi giải thích khoa học / văn hóa tự nhiên (phân tích cả câu qua AI, không ép lệnh cứng)
    expect(parseWorld('tại sao trời lại có mưa').kind, WKind.unknown);
    expect(parseWorld('vì sao lại có bão').kind, WKind.unknown);
    expect(parseWorld('nguyên nhân động đất là gì').kind, WKind.unknown);
    expect(parseWorld('Hà Nội có món gì ngon').kind, WKind.unknown);
    expect(parseWorld('Đà Nẵng mùa nào đẹp nhất').kind, WKind.unknown);

    // Tiếng đàn bầu và âm thanh hành tinh
    expect(parseWorld('tiếng đàn').kind, WKind.music);
    expect(parseWorld('tiếng đàn bầu').kind, WKind.music);
    final soundMoon = parseWorld('tiếng Mặt Trăng');
    expect(soundMoon.kind, WKind.planet);
    expect(soundMoon.target, 'Mặt Trăng');
    expect(soundMoon.aspect, 'sound');
    final soundMars = parseWorld('tiếng Sao Hỏa');
    expect(soundMars.kind, WKind.planet);
    expect(soundMars.target, 'Sao Hỏa');
    expect(soundMars.aspect, 'sound');
    final soundPlanets = parseWorld('tiếng các hành tinh');
    expect(soundPlanets.kind, WKind.game);
    expect(soundPlanets.target, 'sound');

    // Địa danh chi tiết (quận/huyện + tỉnh/thành)
    final hkCmd = parseWorld('tôi muốn nghe thời tiết ở hoàn kiếm hà nội');
    expect(hkCmd.kind, WKind.weather);
    expect(hkCmd.target.toLowerCase(), 'hoàn kiếm hà nội');
  });

  test('chọn trò chơi thông minh, không nhầm sang thứ trong tuần hay thời tiết', () {
    // 1. Trò 3: Nghe tiếng đoán hành tinh
    final g3a = parseWorld('trò ba');
    expect(g3a.kind, WKind.game);
    expect(g3a.target, 'sound');

    final g3b = parseWorld('tôi chọn tròn thứ ba');
    expect(g3b.kind, WKind.game);
    expect(g3b.target, 'sound');

    final g3c = parseWorld('tôi chọn thứ ba lựa chọn');
    expect(g3c.kind, WKind.game);
    expect(g3c.target, 'sound');

    final g3d = parseWorld('tôi chọn ba');
    expect(g3d.kind, WKind.game);
    expect(g3d.target, 'sound');

    final g3e = parseWorld('chọn trò ba');
    expect(g3e.kind, WKind.game);
    expect(g3e.target, 'sound');

    // 2. Trò 2: Tôi là ai / Riddle
    final g2a = parseWorld('trò thứ hai cơ mà');
    expect(g2a.kind, WKind.game);
    expect(g2a.target, 'riddle');

    final g2b = parseWorld('tôi chọn hai');
    expect(g2b.kind, WKind.game);
    expect(g2b.target, 'riddle');

    final g2c = parseWorld('chọn trò hai');
    expect(g2c.kind, WKind.game);
    expect(g2c.target, 'riddle');

    final g2d = parseWorld('trò hai');
    expect(g2d.kind, WKind.game);
    expect(g2d.target, 'riddle');

    // 3. Trò 1: Đố vui / Quiz
    final g1a = parseWorld('chọn trò một');
    expect(g1a.kind, WKind.game);
    expect(g1a.target, 'quiz');

    final g1b = parseWorld('tôi chọn một');
    expect(g1b.kind, WKind.game);
    expect(g1b.target, 'quiz');

    final g1c = parseWorld('trò một');
    expect(g1c.kind, WKind.game);
    expect(g1c.target, 'quiz');

    // 4. Menu trò chơi
    final gm1 = parseWorld('tôi bảo chọn trò');
    expect(gm1.kind, WKind.game);
    expect(gm1.target, '');

    final gm2 = parseWorld('chọn trò');
    expect(gm2.kind, WKind.game);
    expect(gm2.target, '');

    // 5. Câu hỏi thời tiết thật về thứ trong tuần KHÔNG bị ảnh hưởng
    final wTue = parseWorld('thứ ba tuần sau có mưa không');
    expect(wTue.kind, WKind.weather);
    expect(wTue.aspect, 'rain');

    final wMon = parseWorld('thời tiết thứ hai');
    expect(wMon.kind, WKind.weather);

    final wOuting = parseWorld('ngày mai tôi đi chơi có mưa không');
    expect(wOuting.kind, WKind.weather);
    expect(wOuting.aspect, 'outing');

    // 6. Tiếng Anh
    expect(parseWorldEn('game three').kind, WKind.game);
    expect(parseWorldEn('game three').target, 'sound');
    expect(parseWorldEn('game two').kind, WKind.game);
    expect(parseWorldEn('game two').target, 'riddle');
    expect(parseWorldEn('game one').kind, WKind.game);
    expect(parseWorldEn('game one').target, 'quiz');
  });

  test('câu hỏi tự nhiên về chuẩn bị hành trang khi đến nơi khác và lưu ý khi ra ngoài tại chỗ', () {
    // Hỏi khi đến một địa điểm khác (du lịch, công tác, di chuyển tới nơi đó)
    var c = parseWorld('đến Sa Pa cần chuẩn bị gì');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Sa Pa');
    expect(c.aspect, 'advice');

    c = parseWorld('đi Đà Lạt mặc đồ gì');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Đà Lạt');
    expect(c.aspect, 'advice');

    c = parseWorld('khi tới Huế cần mang theo gì');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Huế');
    expect(c.aspect, 'advice');

    c = parseWorld('ra Hà Nội cần lưu ý gì');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Hà Nội');
    expect(c.aspect, 'advice');

    c = parseWorld('vào Đà Nẵng nên mặc gì');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Đà Nẵng');
    expect(c.aspect, 'advice');

    c = parseWorld('đi du lịch Nha Trang cần chuẩn bị những gì');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Nha Trang');
    expect(c.aspect, 'advice');

    // Hỏi khi ra ngoài ở khu vực người dùng đang ở (không nêu tên nơi khác)
    c = parseWorld('bây giờ ra ngoài cần mang gì');
    expect(c.kind, WKind.weather);
    expect(c.target, '');
    expect(c.aspect, 'advice');

    c = parseWorld('ra đường có cần áo khoác không');
    expect(c.kind, WKind.weather);
    expect(c.target, '');
    expect(c.aspect, 'advice');

    c = parseWorld('chiều nay ra ngoài có mưa không');
    expect(c.kind, WKind.weather);
    expect(c.target, '');
    expect(c.period, 'chieu');
    expect(c.aspect, 'rain');

    c = parseWorld('sáng mai đi làm có cần mang áo mưa không');
    expect(c.kind, WKind.weather);
    expect(c.target, '');
    expect(c.liveDay, 1);
    expect(c.period, 'sang');
    expect(c.aspect, 'rain');

    c = parseWorld('tối nay đi dạo ngoài trời có hợp không');
    expect(c.kind, WKind.weather);
    expect(c.target, '');
    expect(c.period, 'toi');
    expect(c.aspect, 'outing');
  });

  test('hỏi địa điểm ăn uống, vui chơi, du lịch tại xã phường ở Hà Nội', () {
    var c = parseWorld('phường Hoàn Kiếm có gì chơi');
    expect(c.kind, WKind.around);
    expect(c.target, 'phường Hoàn Kiếm');
    final g1 = buildHanoiGuide(c.target, c.target, raw: c.raw);
    expect(g1, isNotNull);
    expect(g1!.$1, contains('Hồ Hoàn Kiếm'));

    c = parseWorld('ở phường Tây Hồ ăn gì ngon');
    expect(c.kind, WKind.around);
    expect(c.target, 'phường Tây Hồ');
    final g2 = buildHanoiGuide(c.target, c.target, raw: c.raw);
    expect(g2, isNotNull);
    expect(g2!.$1, kHanoiFoodStayEnabled ? contains('bánh tôm') : contains('tạm ẩn')); // phần ăn uống có thể đang ẩn

    c = parseWorld('xã Bát Tràng có địa điểm du lịch gì');
    expect(c.kind, WKind.around);
    expect(c.target, 'xã Bát Tràng');
    final g3 = buildHanoiGuide(c.target, c.target, raw: c.raw);
    expect(g3, isNotNull);
    expect(g3!.$1, contains('gốm Bát Tràng'));

    c = parseWorld('phường Cầu Giấy có địa điểm ăn uống vui chơi gì');
    expect(c.kind, WKind.around);
    expect(c.target, 'phường Cầu Giấy');
    final g4 = buildHanoiGuide(c.target, c.target, raw: c.raw);
    expect(g4, isNotNull);
    expect(g4!.$1, contains('công viên Cầu Giấy'));

    c = parseWorld('phường Bách Khoa ăn uống ở đâu');
    expect(c.kind, WKind.around);
    expect(c.target, 'phường Bách Khoa');
    final g5 = buildHanoiGuide(c.target, c.target, raw: c.raw);
    expect(g5, isNotNull);
    expect(g5!.$1, kHanoiFoodStayEnabled ? contains('Tạ Quang Bửu') : contains('tạm ẩn'));

    c = parseWorld('xã Đông Anh có gì vui chơi');
    expect(c.kind, WKind.around);
    expect(c.target, 'xã Đông Anh');
    final g6 = buildHanoiGuide(c.target, c.target, raw: c.raw);
    expect(g6, isNotNull);
    expect(g6!.$1, contains('Cổ Loa'));
  });
}


