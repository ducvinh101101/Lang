import 'package:earthsense/features/globe/asr_fix_en.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:flutter_test/flutter_test.dart';

// Câu nghe sai thật (nhật ký) và giả lập: sửa đúng, còn câu nghe đúng thì giữ nguyên.
void main() {
  test('sửa chữ nhận giọng tiếng Anh', () {
    expect(fixEnglishAsr('venomist'), 'vietnamese');
    expect(fixEnglishAsr('winnamis'), 'vietnamese');
    expect(fixEnglishAsr('vet now miss'), 'vietnamese');
    expect(fixEnglishAsr('fidnam'), 'vietnam');
    expect(fixEnglishAsr('switch to the enemies'), 'switch to vietnamese');
    expect(fixEnglishAsr('Weether in Ho Caimon City'), 'weather in ho chi minh city');
    expect(fixEnglishAsr('will it rain tomorrow in dawning'), 'will it rain tomorrow in da nang');
    expect(fixEnglishAsr('Astrony picture of the day'), 'astronomy picture of the day');
    expect(fixEnglishAsr('Read the morning buulletin'), 'read the morning bulletin');
    expect(fixEnglishAsr('Whher in Paris'), 'weather in paris');
    expect(fixEnglishAsr('Where am I'), 'where am i');
    expect(fixEnglishAsr('what is around me'), 'what is around me');
    expect(fixEnglishAsr('tell me about Mars'), 'tell me about mars');
    expect(fixEnglishAsr('zoom in'), 'zoom in');
    expect(fixEnglishAsr('stop'), 'stop');
    expect(fixEnglishAsr('help'), 'help');
    expect(fixEnglishAsr('weather in Paris'), 'weather in paris');
    expect(fixEnglishAsr('what should I wear tomorrow'), 'what should i wear tomorrow');
    expect(fixEnglishAsr('is it good to go out this afternoon'), 'is it good to go out this afternoon');
    expect(fixEnglishAsr('(static)'), '');
    expect(fixEnglishAsr('hello'), 'hello');
    expect(fixEnglishAsr('which'), 'which');
  });

  test('câu đã sửa ra đúng lệnh', () {
    expect(parseWorldEn(fixEnglishAsr('venomist')).kind, WKind.language);
    expect(parseWorldEn(fixEnglishAsr('switch to the enemies')).kind, WKind.language);
    final c = parseWorldEn(fixEnglishAsr('will it rain tomorrow in dawning'));
    expect(c.kind, WKind.weather);
    expect(c.target.toLowerCase(), 'da nang');
    expect(parseWorldEn(fixEnglishAsr('Astrony picture of the day')).kind, WKind.apod);
  });
}
