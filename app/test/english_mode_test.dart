import 'package:earthsense/features/globe/transcript_dialog.dart';
import 'package:earthsense/features/globe/weather_card.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:earthsense/live/live_weather.dart';
import 'package:earthsense/live/weather_talk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LiveWeather _mockWeather({
  int code = 2,
  double temp = 28.0,
  double feels = 31.0,
  int humidity = 78,
  double wind = 14.0,
  double? uv = 7.5,
  int? aqi = 65,
}) {
  final now = DateTime.now();
  final wmo = wmoText(code);
  return LiveWeather(
    'open-meteo',
    now,
    LiveNow(
      temp: temp,
      feels: feels,
      humidity: humidity,
      precip: 0.0,
      desc: wmo.$1,
      code: code,
      wind: wind,
      uv: uv,
    ),
    List.generate(
      12,
      (i) => LiveHour(
        now.add(Duration(hours: i)),
        temp - i * 0.5,
        i == 3 ? 60 : 10,
        i == 3 ? 61 : code,
        i == 3 ? 'mưa nhỏ' : wmo.$1,
        uv: uv != null ? uv - i * 0.5 : null,
      ),
    ),
    List.generate(
      5,
      (i) => LiveDay(
        now.add(Duration(days: i)),
        32.0 - i,
        24.0 - i,
        i == 1 ? 70 : 20,
        i == 1 ? 12.0 : 0.0,
        i == 1 ? 63 : code,
        i == 1 ? 'mưa vừa' : wmo.$1,
        7.0,
        15.0,
      ),
    ),
    aqi: aqi,
  );
}

void main() {
  group('1. WMO Weather Code English Translations', () {
    test('Translates all standard WMO weather codes into English', () {
      expect(wmoText(0).$2, 'clear sky');
      expect(wmoText(1).$2, 'mostly clear');
      expect(wmoText(2).$2, 'partly cloudy');
      expect(wmoText(3).$2, 'overcast');
      expect(wmoText(45).$2, 'fog');
      expect(wmoText(48).$2, 'fog');
      expect(wmoText(51).$2, 'drizzle');
      expect(wmoText(61).$2, 'light rain');
      expect(wmoText(63).$2, 'moderate rain');
      expect(wmoText(65).$2, 'heavy rain');
      expect(wmoText(71).$2, 'snow');
      expect(wmoText(80).$2, 'light showers');
      expect(wmoText(81).$2, 'showers');
      expect(wmoText(82).$2, 'violent showers');
      expect(wmoText(95).$2, 'thunderstorm');
      expect(wmoText(96).$2, 'thunderstorm with hail');
    });
  });

  group('2. WeatherTalk English Speech & Narration', () {
    test('nowText generates fluent English with no Vietnamese text', () {
      final w = _mockWeather(code: 2, temp: 28.4, feels: 31.0);
      final say = nowText('Hà Nội', 'Hanoi', w);
      final en = say.$2;

      expect(en, contains('Now in Hanoi: 28 degrees, partly cloudy'));
      expect(en, contains('feels like 31'));
      expect(en, contains('Humidity 78 percent, wind 14 kilometres per hour'));
      expect(en, isNot(contains('độ')));
      expect(en, isNot(contains('có mây')));
      expect(en, isNot(contains('Hà Nội')));
    });

    test('dayText generates fluent English for tomorrow forecast', () {
      final w = _mockWeather(code: 63);
      final d = w.days[1];
      final say = dayText('Đà Nẵng', 'Da Nang', d);
      final en = say.$2;

      expect(en, contains('Tomorrow in Da Nang: moderate rain, 23 to 31 degrees'));
      expect(en, contains('70 percent chance of rain'));
      expect(en, isNot(contains('mưa vừa')));
      expect(en, isNot(contains('khả năng')));
    });

    test('weekText generates fluent English multi-day summary', () {
      final w = _mockWeather(code: 0);
      final say = weekText('Huế', 'Hue', w, days: 3);
      final en = say.$2;

      expect(en, contains('3-day forecast for Hue.'));
      expect(en, contains('clear sky'));
      expect(en, isNot(contains('Dự báo')));
      expect(en, isNot(contains('trời quang')));
    });
  });

  group('3. English Command Parsing (parseWorldEn)', () {
    test('All English Quick Action Chips commands are parsed correctly', () {
      // 1. My location
      expect(parseWorldEn('where am i').aspect, 'gps');
      expect(parseWorldEn('my location').aspect, 'gps');

      // 2. Hanoi weather
      var c = parseWorldEn('weather in Hanoi');
      expect(c.kind, WKind.weather);
      expect(c.target, 'Hanoi');

      // 3. Da Nang weather
      c = parseWorldEn('weather in Da Nang');
      expect(c.kind, WKind.weather);
      expect(c.target, 'Da Nang');

      // 4. HCMC weather
      c = parseWorldEn('weather in Ho Chi Minh City');
      expect(c.kind, WKind.weather);
      expect(c.target, 'Ho Chi Minh City');

      // 5. Natural disasters
      expect(parseWorldEn('natural disasters').kind, WKind.disasters);

      // 6. Mars
      expect(parseWorldEn('tell me about Mars').kind, WKind.planet);

      // 7. Solar System
      expect(parseWorldEn('Solar System').kind, anyOf(WKind.planet, WKind.help));

      // 8. Rain forecast
      c = parseWorldEn('will it rain tomorrow');
      expect(c.liveDay, 1);
      expect(c.aspect, 'rain');
    });

    test('Specific weather metric queries in English', () {
      expect(parseWorldEn('temperature in London').aspect, 'temp');
      expect(parseWorldEn('humidity in Paris').aspect, 'humid');
      expect(parseWorldEn('wind speed in Tokyo').aspect, 'wind');
      expect(parseWorldEn('UV index in Sydney').aspect, 'uv');
      expect(parseWorldEn('air quality in Bangkok').aspect, 'air');
    });
  });

  group('4. LiveWeatherCard UI in English Mode', () {
    testWidgets('Renders LiveWeatherCard with English labels and Semantics', (tester) async {
      final loc = GlobeLoc('Hà Nội', 'Hanoi', 21.03, 105.85, 11);
      final w = _mockWeather(code: 2, temp: 29.0, feels: 32.0, aqi: 45);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveWeatherCard(
              loc: loc,
              weather: w,
              isEn: true,
              onClose: () {},
            ),
          ),
        ),
      );

      // Verify English location name
      expect(find.text('Hanoi'), findsOneWidget);
      expect(find.text('Hà Nội'), findsNothing);

      // Verify English weather condition
      expect(find.text('partly cloudy'), findsOneWidget);

      // Verify English metrics labels
      expect(find.text('Feels like 32°'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('Wind'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget); // AQI <= 50 is Good in English

      // Verify Semantics announcement
      final semantics = tester.getSemantics(find.byType(LiveWeatherCard));
      expect(semantics.label, contains('Weather card for Hanoi: 29 degrees Celsius, partly cloudy'));
      expect(semantics.label, contains('Feels like 32 degrees'));
      expect(semantics.label, contains('Humidity 78 percent'));
    });
  });

  group('5. Transcript Dialog in English Mode', () {
    testWidgets('Renders Transcript Sheet with English controls and labels', (tester) async {
      final items = [
        TranscriptItem(
          isUser: true,
          text: 'What is the weather in Hanoi?',
          time: DateTime(2026, 11, 3, 10, 0),
        ),
        TranscriptItem(
          isUser: false,
          text: 'Now in Hanoi: 28 degrees, partly cloudy.',
          time: DateTime(2026, 11, 3, 10, 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showTranscriptSheet(
                  ctx,
                  items,
                  isEn: true,
                  onClear: () {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open the sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify English header and buttons
      expect(find.text('Conversation History & Transcript'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      // Verify speaker labels
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Lắng'), findsOneWidget);
      expect(find.text('Bạn'), findsNothing);
      expect(find.text('EarthSense'), findsNothing);
    });
  });
}
