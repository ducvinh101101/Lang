import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English weather questions', () {
    var c = parseWorldEn('What is the weather like in Paris');
    expect(c.kind, WKind.weather);
    expect(c.target, 'Paris');
    c = parseWorldEn('will it rain tomorrow in Da Nang');
    expect(c.kind, WKind.weather);
    expect(c.liveDay, 1);
    expect(c.aspect, 'rain');
    expect(c.target, 'Da Nang');
    c = parseWorldEn('will it rain this afternoon');
    expect(c.period, 'chieu');
    expect(c.liveDay, 0);
    expect(c.target, '');
    c = parseWorldEn('is tomorrow good for a picnic in Hue');
    expect(c.aspect, 'outing');
    expect(c.target, 'Hue');
    c = parseWorldEn('what should I bring tomorrow');
    expect(c.aspect, 'advice');
    expect(c.target, '');
    expect(parseWorldEn('five day forecast for Tokyo').kind, WKind.forecast);
    expect(parseWorldEn('go to Japan').target, 'Japan');
    expect(parseWorldEn('London').kind, WKind.go);
  });

  test('English other features', () {
    expect(parseWorldEn('help').kind, WKind.help);
    expect(parseWorldEn('help weather').target, 'weather');
    expect(parseWorldEn('explore the planets').target, 'space');
    expect(parseWorldEn('tell me about Mars').kind, WKind.planet);
    expect(parseWorldEn('Jupiter').kind, WKind.planet);
    expect(parseWorldEn('astronomy picture of the day').kind, WKind.apod);
    expect(parseWorldEn('any storms').kind, WKind.disasters);
    expect(parseWorldEn('where are the storms in the world').aspect, 'world');
    expect(parseWorldEn('where am I').aspect, 'gps');
    var c = parseWorldEn("what's around Hoan Kiem Lake");
    expect(c.kind, WKind.around);
    expect(c.target, 'Hoan Kiem Lake');
    expect(parseWorldEn('explore by touch').kind, WKind.explore);
    expect(parseWorldEn('exit').kind, WKind.exitLocal);
    expect(parseWorldEn('climate of Hanoi').kind, WKind.climate);
    c = parseWorldEn('October 2020 in Hue');
    expect(c.kind, WKind.climate);
    expect(c.month, 9);
    expect(c.target, 'Hue');
    expect(parseWorldEn('bulletin').kind, WKind.bulletin);
    expect(parseWorldEn('Vietnamese').kind, WKind.language);
    expect(parseWorldEn('stop').kind, WKind.stop);
    expect(parseWorldEn('zoom out').kind, WKind.zoomOut);
    expect(parseWorldEn('whole world').kind, WKind.world);
    expect(parseWorldEn('um').kind, WKind.ignore);
    expect(parseWorldEn('what about Bangkok').followUp, isTrue);
  });

  test('one weather value', () {
    expect(parseWorldEn('temperature in Hanoi now').aspect, 'temp');
    expect(parseWorldEn('humidity in Hue').aspect, 'humid');
    expect(parseWorldEn('weather in Hanoi').aspect, isNull);
  });

  test('n-day forecast', () {
    var c = parseWorldEn('next 3 days in Hanoi');
    expect(c.kind, WKind.forecast);
    expect(c.liveDay, 3);
    expect(parseWorldEn('10 day forecast').liveDay, 10);
  });
}

