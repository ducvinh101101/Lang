// ENGLISH MODE: understand spoken English commands and questions, producing the same WCmd as the Vietnamese parser
// (world_commands.dart), so every feature works the same in both languages.
//   "weather in Paris", "will it rain this afternoon", "is tomorrow good for a picnic in Hue", "what should I bring"
//   "any storms", "storms around the world", "bulletin", "where am I", "what's around Hoan Kiem Lake",
//   "explore by touch", "past and present", "climate of Hanoi", "October 2020 in Hue", "tell me about Mars"
//   "help", "help weather", "zoom out", "whole world", "repeat", "slower", "stop", "pause", "Vietnamese"
import '../history/history_command.dart' show weatherHistoryCmdEn;
import '../../live/nasa_sounds.dart' show nasaSoundRequest;
import '../space/planets.dart' show planetIn;
import '../voice/commands.dart' show parseCommand;
import 'terrain_data.dart' show peakIn;
import 'vn_landmarks.dart' show landmarkIn;
import 'world.dart' show cityAliases;
import 'world_commands.dart';

String _clean(String s) =>
    s.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r"[^a-z0-9' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

const _fillersEn = {
  'uh', 'um', 'hmm', 'ok', 'okay', 'yeah', 'yes', 'no', 'so', 'well', 'the', 'a', 'oh', 'ah', 'right', 'and', 'hey',
  'hello', 'hi', 'thanks', 'thank you', 'all', 'i', 'it', 'on', 'in', 'of', 'is', 'huh', 'what', 'mm', 'uh huh',
  'which', 'who', 'why', 'how', 'when', 'where', 'that', 'this', 'there', 'they', 'he', 'she', 'we', 'you', 'to', 'at',
};

// Phrases BEFORE a place name (longest first).
const _leadEn = [
  "what's the weather going to be like in", 'what is the weather going to be like in', "what's the weather like in",
  'what is the weather like in', "what's the weather in", 'what is the weather in', "how's the weather in",
  'how is the weather in', 'weather forecast for', 'weather forecast in', 'forecast for', 'forecast in', 'weather in',
  'weather at', 'weather for', 'temperature in', 'will it rain in', 'is it raining in', 'tell me the weather in',
  'five day forecast for', '5 day forecast for', 'seven day forecast for', '7 day forecast for', 'take me to', 'go to', 'fly to', 'travel to', 'zoom in on', 'zoom into', 'zoom in to', 'zoom to', 'zoom on',
  'show me', 'find', 'open', 'climate of', 'climate in', 'climate for', "what's around", 'what is around',
  "what's near", 'what is near', 'describe the area around', 'describe', 'terrain of', 'terrain around',
  'elevation of', 'geography of', 'explore by touch around', 'explore by touch', 'explore around', 'how has',
  'how about', 'what about', 'and in', 'and', 'any storms near', 'any storms in', 'storms near', 'storms in',
  'disasters near', 'disasters in', 'hazards near', 'bulletin for', 'weather report for', 'past and present in',
  'past and present of', 'the city of', 'earth sense', 'hey sense', 'hey earth', 'hey listen', 'listen', 'please', 'in', 'at', 'for', 'of', 'near', 'around', 'show', 'weather',
];

// Phrases AFTER a place name.
const _trailEn = [
  'right now', 'now', 'today', 'tonight', 'tomorrow', 'this morning', 'this afternoon', 'this evening',
  'tomorrow morning', 'tomorrow afternoon', 'tomorrow evening', 'tomorrow night', 'please', 'like', 'look like',
  'has changed', 'changed', 'over the years', 'past and present', 'then', 'weather', 'forecast', 'doing', 'is like',
  'climate', 'is', 'in the past', 'over time',
];

// Words that only appear in QUESTIONS (not in place names).
const _qWords = {
  'i', 'me', 'my', 'we', 'should', 'will', 'would', 'could', 'can', 'is', 'it', 'what', 'how', 'need', 'wear',
  'bring', 'good', 'go', 'going', 'take', 'do', 'does', 'any', 'there', 'be', 'to', 'out', 'outside', 'rain',
};

String _extractEn(String raw) {
  var words = raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  var low = [for (final w in words) _clean(w)];
  final keep = [for (var k = 0; k < words.length; k++) if (low[k].isNotEmpty) k];
  words = [for (final k in keep) words[k].replaceAll(RegExp(r"[^\p{L}\p{N}'\-]", unicode: true), '')];
  low = [for (final k in keep) low[k]];
  bool lead() {
    for (final p in _leadEn) {
      final pw = p.split(' ');
      if (low.length >= pw.length && low.take(pw.length).join(' ') == p) {
        words = words.sublist(pw.length);
        low = low.sublist(pw.length);
        return true;
      }
    }
    return false;
  }

  bool trail() {
    for (final p in _trailEn) {
      final pw = p.split(' ');
      if (low.length >= pw.length && low.sublist(low.length - pw.length).join(' ') == p) {
        words = words.sublist(0, words.length - pw.length);
        low = low.sublist(0, low.length - pw.length);
        return true;
      }
    }
    return false;
  }

  for (var k = 0; k < 6; k++) {
    final a = lead(), b = trail();
    if (!a && !b) break;
  }
  // cut dates: "Hue in October 2020", "Hue on 15 October"
  final cut = low.indexWhere((w) => RegExp(r'^\d').hasMatch(w) || _months.containsKey(w) || w == 'on' || w == 'yesterday');
  if (cut > 0) {
    words = words.sublist(0, cut);
    low = low.sublist(0, cut);
    while (low.isNotEmpty && const {'in', 'at', 'on', 'for'}.contains(low.last)) {
      words.removeLast();
      low.removeLast();
    }
  } else if (cut == 0) {
    final at = [low.lastIndexOf('in'), low.lastIndexOf('at')].reduce((a, b) => a > b ? a : b);
    if (at < 0 || at == low.length - 1) return '';
    words = words.sublist(at + 1);
    low = low.sublist(at + 1);
    while (trail()) {}
  }
  final t = low.join(' ');
  if (t.isEmpty || const {'here', 'there', 'this place', 'this', 'it', 'me', 'us', 'now', 'today'}.contains(t)) return '';
  return words.join(' ');
}

/// In a natural question, find the real place: after the last "in" / "at" / "to", or a known place name.
String _placeInQuestionEn(String raw, String target) {
  final tw = _clean(target).split(' ').where((w) => w.isNotEmpty).toList();
  if (tw.isNotEmpty && !tw.any(_qWords.contains)) return target;
  final words = raw.trim().split(RegExp(r'\s+'));
  final low = [for (final w in words) _clean(w)];
  for (var k = low.length - 2; k >= 0; k--) {
    if (low[k] == 'in' || low[k] == 'at' || low[k] == 'to' || low[k] == 'near') {
      final after = _extractEn(words.sublist(k + 1).join(' '));
      final a = _clean(after).split(' ').where((w) => w.isNotEmpty).toList();
      if (a.isNotEmpty && !a.any(_qWords.contains)) return after;
      break;
    }
  }
  final p = parseCommand(raw).place; // Vietnamese places said without accents: "Hue", "Da Nang"
  if (p != null) return p.name;
  final t = ' ${_clean(raw)} ';
  for (final city in cityAliases.values.toSet()) {
    if (t.contains(' ${city.toLowerCase()} ')) return city;
  }
  return '';
}

const _months = {
  'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6, 'july': 7, 'august': 8, 'september': 9,
  'october': 10, 'november': 11, 'december': 12,
};

DateTime? _dateEn(String t) {
  final now = DateTime.now();
  final t0 = DateTime(now.year, now.month, now.day);
  if (RegExp(r'\bday before yesterday\b').hasMatch(t)) return t0.subtract(const Duration(days: 2));
  if (RegExp(r'\byesterday\b').hasMatch(t)) return t0.subtract(const Duration(days: 1));
  // "15 october 2024", "october 15 2024", "on the 15th of october"
  final m1 = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?(?: of)? (' + _months.keys.join('|') + r')(?: (\d{4}))?\b').firstMatch(t);
  final m2 = RegExp(r'\b(' + _months.keys.join('|') + r') (\d{1,2})(?:st|nd|rd|th)?(?: (\d{4}))?\b').firstMatch(t);
  int? d, m, y;
  if (m1 != null) {
    d = int.parse(m1.group(1)!);
    m = _months[m1.group(2)!];
    y = m1.group(3) == null ? null : int.parse(m1.group(3)!);
  } else if (m2 != null) {
    m = _months[m2.group(1)!];
    d = int.parse(m2.group(2)!);
    y = m2.group(3) == null ? null : int.parse(m2.group(3)!);
  }
  if (d == null || m == null || d < 1 || d > 31) return null;
  final x = DateTime(y ?? now.year, m, d);
  return x.month == m ? x : null;
}

WCmd parseWorldEn(String raw) {
  var t = _clean(raw);
  const enPolitePrefixes = [
    'could you please', 'can you please', 'would you please', 'will you please',
    'could you', 'can you', 'would you', 'will you', 'please',
  ];
  for (final p in enPolitePrefixes) {
    if (t.startsWith('$p ')) {
      t = t.substring(p.length + 1).trim();
      break;
    }
  }
  const enPoliteSuffixes = [
    'right now', 'for me', 'please', 'now',
  ];
  for (final s in enPoliteSuffixes) {
    if (t.endsWith(' $s')) {
      t = t.substring(0, t.length - s.length - 1).trim();
      break;
    }
  }
  bool i(String re) => RegExp(re).hasMatch(t);
  if (t.isEmpty) return WCmd(WKind.unknown, raw: raw);
  if (_fillersEn.contains(t)) return WCmd(WKind.ignore, raw: raw);

  if (i(r'^(stop|quiet|be quiet|cancel|enough|shut up|stop it|stop talking)\b') && !i(r'\b(terrain|touch)\b')) return WCmd(WKind.stop, raw: raw);
  if (i(r'\b(pause|stop listening|turn off mic|go to sleep|sleep mode)\b')) return WCmd(WKind.pause, raw: raw);
  if (i(r'\b(settings|preferences|open settings)\b')) return WCmd(WKind.settings, raw: raw);
  if (i(r'\b(vietnamese|tieng viet)\b')) return WCmd(WKind.language, target: 'vi', raw: raw);
  if (i(r'\b(repeat|say (that|it) again|say again|read again|again please|what did you say|pardon)\b')) return WCmd(WKind.repeat, raw: raw);
  if (i(r'\b(louder|volume up|speak up|turn (it )?up|speak louder)\b')) return WCmd(WKind.louder, raw: raw);
  if (i(r'\b(quieter|softer|volume down|turn (it )?down|speak quieter)\b')) return WCmd(WKind.quieter, raw: raw);
  if (i(r'\b(faster|speak faster|read faster|speed up)\b')) return WCmd(WKind.faster, raw: raw);
  if (i(r'\b(slower|speak slower|read slower|slow down)\b')) return WCmd(WKind.slower, raw: raw);

  // F2: real NASA recordings ("play the Sputnik sound", "NASA sounds")
  final ns = nasaSoundRequest(raw);
  if (ns != null) return WCmd(WKind.nasaSound, target: ns.sound?.id ?? '', aspect: ns.game ? 'game' : null, raw: raw);

  // F1: weather / disaster history playback
  final wh = weatherHistoryCmdEn(raw);
  if (wh != null) return wh;

  // help: overview, or one part
  final asksHelp = i(r'\b(help|what can you do|how do i|how to use|instructions|guide|tutorial|features|introduce|what do you do)\b');
  final topic = i(r'\b(weather|forecast|rain|storm|storms|climate)\b')
      ? 'weather'
      : i(r'\b(geography|around me|map|terrain|location|surroundings|where am i)\b')
          ? 'geo'
          : i(r'\b(space|planet|planets|solar system|astronomy|universe|stars)\b')
              ? 'space'
              : '';
  const sections = {
    'weather', 'world weather', 'weather around the world', 'the weather', 'geography', 'geography around me', 'space',
    'planets', 'the planets', 'solar system', 'the solar system', 'explore the planets', 'explore space', 'astronomy',
  };
  final pl = planetIn(t);
  final tr = terrainCmdEn(raw);
  if (tr != null && !(asksHelp && tr.aspect == 'describe')) return tr;
  if ((asksHelp && (pl == null || pl.sound == 3) && landmarkIn(t) == null) || sections.contains(t)) {
    return WCmd(WKind.help, target: topic, raw: raw);
  }

  // learning games
  if (i(r'\b(sound game|guess the sound|guess by sound|listen and guess|game (three|3)|third game)\b')) return WCmd(WKind.game, target: 'sound', raw: raw);
  if (i(r'\b(who am i|riddle|riddles|guess the planet|game (two|2)|second game)\b')) return WCmd(WKind.game, target: 'riddle', raw: raw);
  if (i(r'\b(quiz|test me|trivia|game (one|1)|first game)\b')) return WCmd(WKind.game, target: 'quiz', raw: raw);
  if (i(r'\b(play a game|a game|games|let s play|lets play|pick a game|choose a game)\b')) return WCmd(WKind.game, raw: raw);

  // space
  if (i(r'\b(picture of the day|astronomy picture|space picture|nasa picture|apod|image of the day)\b')) {
    return WCmd(WKind.apod, raw: raw);
  }
  // F2: "fun fact about Mars" → a random NASA fact about that body
  if (i(r'\b(fun fact|fun facts|interesting fact|cool fact|did you know|surprising fact)\b') &&
      (pl != null || i(r'\b(planet|space|solar system|universe)\b') || i(r'^(another |a |one more )?(fun|interesting|cool) fact$'))) {
    return WCmd(WKind.planet, target: pl?.vi ?? '', aspect: 'fact', raw: raw);
  }
  final story = i(r'\b(tell|story|about|explore|learn|introduce|describe)\b');
  if (pl != null && (pl.sound != 3 || story) && !i(r'\b(rise|rises|set|sets|weather|temperature|sunny|sunrise|sunset)\b')) {
    return WCmd(WKind.planet, target: pl.vi, raw: raw);
  }

  // Vietnamese landmarks
  if (!i(r'\b(weather|temperature|rain|forecast|humid|wind|around|near)\b')) {
    final lm = landmarkIn(t);
    if (lm != null && i(r'\b(tell|about|what is|where is|introduce|describe|famous|history|learn|information|info)\b')) {
      return WCmd(WKind.landmark, target: lm.name, raw: raw);
    }
    if (i(r'\b(tell me about|introduce|describe) (this place|here|it)\b')) return WCmd(WKind.landmark, raw: raw);
    if (i(r'\b(famous places|landmarks?|sights|attractions|places to visit|where to go|tourist spots?|must see)\b')) {
      return WCmd(WKind.landmarks, raw: raw);
    }
  }

  // around you
  if (i(r'^(exit|leave|close map|close the map)$') || i(r'\b(back to (the )?globe|exit (the )?map)\b')) {
    return WCmd(WKind.exitLocal, raw: raw);
  }
  final gps = i(r"\b(where am i|my location|around me|near me|where i am|my surroundings|nearby|around here)\b");
  if (i(r'\b(disasters?|hazards?|storms?|typhoons?|hurricanes?|cyclones?|floods?|flooding|wildfires?|volcano(es)?|earthquakes?)\b')) {
    final world = i(r'\b(world|anywhere|where|globe|earth|everywhere)\b') &&
        !i(r'\b(near|at) [a-z]') &&
        !i(r'\bin (?!the world)[a-z]');
    return WCmd(WKind.disasters,
        target: world ? '' : _placeInQuestionEn(raw, _extractEn(raw)), aspect: world ? 'world' : null, raw: raw);
  }
  if (i(r'\b(bulletin|briefing|morning report|weather report|daily report)\b')) {
    return WCmd(WKind.bulletin, target: _placeInQuestionEn(raw, _extractEn(raw)), raw: raw);
  }
  if (i(r'\b(explore by touch|touch map|touch the map|feel the map|explore with my finger|explore here)\b')) {
    return WCmd(WKind.explore, target: gps ? '' : _placeInQuestionEn(raw, _extractEn(raw)), aspect: gps ? 'gps' : null, raw: raw);
  }
  if (i(r'\b(past and present|how has .* changed|changed over|used to be|decades|years ago|then and now)\b')) {
    return WCmd(WKind.history, target: _placeInQuestionEn(raw, _extractEn(raw)), raw: raw);
  }
  if (gps) return WCmd(WKind.around, aspect: 'gps', raw: raw);
  if (i(r"\b(what'?s around|what is around|what is near|what'?s near|describe|terrain|elevation|geography of|surroundings of)\b")) {
    return WCmd(WKind.around, target: _placeInQuestionEn(raw, _extractEn(raw)), raw: raw);
  }

  // globe & zoom
  if (i(r'\b(whole world|entire world|whole globe|entire globe|world view|show the world|full globe|the whole earth)\b')) {
    return WCmd(WKind.world, raw: raw);
  }
  if (i(r'\b(zoom out|further out)\b') || i(r'^(back|go back)\b')) return WCmd(WKind.zoomOut, raw: raw);
  if (i(r'\b(zoom in|zoom closer|closer|get closer)\b') && !i(r'\b(in|to) [a-z]')) return WCmd(WKind.zoomIn, raw: raw);
  if (i(r'\b(where is this|what is this place|where are we|what place is this)\b')) return WCmd(WKind.where, raw: raw);

  final target0 = _placeInQuestionEn(raw, _extractEn(raw));
  final target = _cleanEnTarget(target0);
  if (target.isNotEmpty && i(r"\b(i live in|i am in|i'm in|my home is|i'm from|i am from)\b")) {
    return WCmd(WKind.setHome, target: target, raw: raw);
  }
  if (i(r'\b(next (12|24|twelve|twenty four) hours|hourly|hour by hour)\b')) return WCmd(WKind.hours, target: target, raw: raw);
  if (i(r'\b(play music|play (the )?sound|play it|instruments|dan bau)\b')) return WCmd(WKind.music, target: target, raw: raw);

  final date = _dateEn(t);
  if (date != null) return WCmd(WKind.day, target: target, date: date, raw: raw);

  // NASA climate: whole series, or one month / year
  int? month, year;
  final ym = RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(t);
  if (ym != null) year = int.parse(ym.group(1)!);
  for (final e in _months.entries) {
    if (i('\\b${e.key}\\b')) {
      month = e.value - 1;
      break;
    }
  }
  if (i(r'\b(climate|nasa data|over the years|warming|trend|long term)\b') || year != null || (month != null && year != null)) {
    return WCmd(WKind.climate, target: target, month: month, year: year, raw: raw);
  }

  // weather
  int? day;
  final wdm = RegExp(r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b').firstMatch(t);
  if (wdm != null) {
    const wds = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    var d = (wds.indexOf(wdm.group(1)!) + 1 - DateTime.now().weekday + 7) % 7;
    if (d == 0 && i(r'\bnext\b')) d = 7;
    day = d;
  } else if (i(r'\b(day after tomorrow)\b')) {
    day = 2;
  } else if (i(r'\b(tomorrow)\b')) {
    day = 1;
  } else if (i(r'\b(today|tonight|this morning|this afternoon|this evening|this noon)\b')) {
    day = 0;
  }
  String? period;
  if (i(r'\b(morning)\b')) {
    period = 'sang';
  } else if (i(r'\b(noon|midday|lunchtime)\b')) {
    period = 'trua';
  } else if (i(r'\b(afternoon)\b')) {
    period = 'chieu';
  } else if (i(r'\b(evening|tonight)\b')) {
    period = 'toi';
  } else if (i(r'\b(night)\b')) {
    period = 'dem';
  }
  if (period != null) day ??= 0;
  String? aspect;
  if (i(r'\b(rain|raining|rainy|umbrella|raincoat|wet|showers?|rainfall)\b')) aspect = 'rain';
  if (i(r'\b(what should i (wear|bring|take|do)|should i bring|prepare|advice|tips|need to bring|what to wear|what to bring)\b')) {
    aspect = 'advice';
  }
  if (i(r'\b(good (day|time|weather) for|picnic|go out|outing|trip|hike|hiking|walk|jog|jogging|beach|nice day|go outside|suitable)\b')) {
    aspect = 'outing';
  }
  if (i(r'\b(laundry|washing|dry (my |the )?(clothes|washing))\b')) aspect = 'dry';
  // one specific value → answer only that ("weather" or "details" reads everything)
  if (aspect == null && !i(r'\b(weather|details?|full|everything|overview)\b')) {
    if (i(r'\b(sunrise|sunset|sun rise|sun set|get dark|gets dark|dark outside|daylight|sun come up|sun go down)\b')) {
      aspect = 'sun';
    } else if (i(r'\b(sunny|cloudy|overcast|clear sky|is it clear|grey sky|gray sky|cloud cover)\b')) {
      aspect = 'sky';
    } else if (i(r'\b(temperature|how hot|how cold|how warm|degrees|is it hot|is it cold|is it warm)\b')) {
      aspect = 'temp';
    } else if (i(r'\b(humidity|humid|muggy)\b')) {
      aspect = 'humid';
    } else if (i(r'\b(wind|windy|wind speed|breeze)\b')) {
      aspect = 'wind';
    } else if (i(r'\b(uv|sunburn|sunscreen|uv index)\b')) {
      aspect = 'uv';
    } else if (i(r'\b(air quality|pollution|aqi|smog|dust|pm2 5)\b')) {
      aspect = 'air';
    }
  }
  // N-day forecast: "next 3 days", "10 day forecast", "next ten days" (liveDay = number of days, max 10)
  final nm = RegExp(r'\b(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|fourteen)[ -]days?\b').firstMatch(t);
  if (nm != null && i(r'\b(next|forecast|coming|ahead|weather|rain)\b')) {
    const words = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      'eleven': 11, 'twelve': 12, 'fourteen': 14};
    final n = int.tryParse(nm.group(1)!) ?? words[nm.group(1)!];
    if (n != null && n >= 1) {
      final clean = raw.replaceAll(RegExp(r'(the\s+)?(next\s+)?\S+[ -]days?(\s+forecast)?', caseSensitive: false), ' ').trim();
      return WCmd(WKind.forecast, target: _placeInQuestionEn(clean, _extractEn(clean)), liveDay: n, raw: raw);
    }
  }
  if (i(r'\bweekend\b')) return WCmd(WKind.forecast, target: _cleanEnTarget(target), aspect: 'weekend', raw: raw);
  if (i(r'\b(next week|this week)\b')) return WCmd(WKind.forecast, target: target, liveDay: 7, raw: raw);
  if (i(r'\b(forecast|this week|next few days|weekend|5 day|five day|7 day|seven day|next days)\b')) {
    return WCmd(WKind.forecast, target: target, raw: raw);
  }
  final weatherWord = i(r'\b(weather|temperature|hot|cold|warm|rain|wind|windy|humid|humidity|uv|air quality|pollution|sunny|'
      r'sunset|sunrise|cloudy|laundry)\b');
  final goWord = i(r'\b(go to|zoom|fly to|show|take me to|travel to|open|find)\b');
  if (target.isNotEmpty && (goWord || weatherWord || day != null || aspect != null)) {
    return WCmd(goWord && !weatherWord && day == null && aspect == null ? WKind.go : WKind.weather,
        target: target, liveDay: day, aspect: aspect, period: period, raw: raw);
  }
  if (weatherWord || day != null || aspect != null || i(r'\b(here|this place|details)\b')) {
    return WCmd(WKind.weather, liveDay: day, aspect: aspect, period: period, raw: raw);
  }
  if (i(r'\b(zoom in|closer|zoom closer)\b') && target.isEmpty) return WCmd(WKind.zoomIn, raw: raw);
  if (target.isNotEmpty && target.split(' ').length <= 5) return WCmd(WKind.go, target: target, raw: raw, bare: true);
  return WCmd(WKind.unknown, raw: raw);
}

const _enWeatherVocab = {
  'what', 'time', 'is', 'the', 'sunset', 'sunrise', 'sun', 'rise', 'set', 'sunny', 'cloudy', 'it', 'dry', 'my', 'laundry', 'can',
  'i', 'today', 'tomorrow', 'weekend', 'this', 'washing', 'clothes', 'will', 'be', 'going', 'to', 'rain', 'on', 'saturday',
  'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'next', 'when', 'does', 'get', 'dark', 'outside', 'a', 'there',
  'weather', 'like', 'how', 'hot', 'cold', 'windy', 'clear', 'sky', 'overcast', 'do', 'should', 'wear',
};

/// "sunset", "is it sunny"… là lời hỏi, không phải địa danh.
String _cleanEnTarget(String target) {
  final ws = target.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return ws.isNotEmpty && ws.every(_enWeatherVocab.contains) ? '' : target;
}



/// Terrain commands (English): "touch terrain", "how high is Da Lat", "elevation of Sa Pa", "terrain of Hue",
/// "terrain of Viet Nam", "along Viet Nam", "terrain profile", "terrain from Hanoi to Sa Pa", "highest mountain", "deepest point".
WCmd? terrainCmdEn(String raw) {
  final t = _clean(raw);
  bool i(String re) => RegExp(re).hasMatch(t);
  // water level / waves / tide "how high" are flood or sea questions, not land height
  if (i(r'\b(water level|waves?|tide|tides|flood|river level)\b')) return null;
  // weather words win unless the sentence clearly asks about land ("how high is the temperature" is weather)
  if (i(r'\b(weather|temperature|rain|forecast|wind|humid|humidity|cold|hot|snow|fog)\b') &&
      !i(r'\b(terrain|elevation|altitude|above sea level)\b')) {
    return null;
  }
  if (i(r'\b(turn off|stop|exit|leave|close|disable) (the )?(touch )?terrain\b')) return WCmd(WKind.terrain, aspect: 'off', raw: raw);
  if (i(r'\b(touch terrain|terrain touch|feel the terrain|terrain mode|relief mode|3d terrain|raised relief|touch the globe|feel the globe)\b')) {
    return WCmd(WKind.terrain, aspect: 'touch', raw: raw);
  }
  // F3: scan the terrain cross-sections (north → south, then west → east)
  if (i(r'\b(scan (the )?terrain|terrain scan|scan (the )?(elevation|cross sections?)|sound of (the )?terrain|hear the terrain|terrain sound)\b')) {
    final m = RegExp(r'\b(?:of|around|in|at|near) (.+)$').firstMatch(t);
    return WCmd(WKind.terrain, aspect: 'scan', target: m == null ? '' : _title(m.group(1)!), raw: raw);
  }
  if (i(r'\b(along viet ?nam|length of viet ?nam|from north to south|north to south)\b')) return WCmd(WKind.terrain, aspect: 'spine', raw: raw);
  final ft = RegExp(r'\b(?:terrain|elevation|profile|cross section)\b.*?\bfrom (.+?) to (.+?)(?: please| now| thanks)?$').firstMatch(t);
  if (ft != null && !RegExp(r'^(north|south|east|west)$').hasMatch(ft.group(1)!)) {
    return WCmd(WKind.terrain, aspect: 'path', target: '${_title(ft.group(1)!)}|${_title(ft.group(2)!)}', raw: raw);
  }
  String place(String s) {
    final p = s
        .replaceAll(RegExp(r"\b(what'?s|what is|the|how high is|how high|how tall is|how tall|elevation of|elevation at|elevation in|elevation|"
            r'altitude of|altitude|height of|above sea level|terrain profile of|terrain profile|cross section of|cross section|'
            r'terrain of|terrain around|terrain in|terrain at|terrain|describe|tell me|please|is it|in metres|in meters|metres|meters|'
            r'like|can you|could you|i want to know|do you know)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirst(RegExp(r'^(of|in|at|for|around) '), '');
    return RegExp(r'^(here|this place|where i am|around here|me)$').hasMatch(p) ? '' : _title(p);
  }

  if (i(r'\b(terrain profile|cross section|elevation profile|west to east|east to west)\b')) {
    return WCmd(WKind.terrain, aspect: 'profile', period: i(r'\b(north|south)\b') && !i(r'\b(east|west)\b') ? 'ns' : 'ew', target: place(t), raw: raw);
  }
  if (i(r'\b(deepest (point|place|spot)|deepest part of the (ocean|sea)|mariana|challenger deep|how deep is the (ocean|sea))\b')) {
    return WCmd(WKind.terrain, aspect: 'deep', raw: raw);
  }
  if (i(r'\b(highest mountain|highest peak|tallest mountain|highest point|roof of)\b')) {
    final tg = i(r'\bafrica\b')
        ? 'Kilimanjaro'
        : i(r'\beurope\b')
            ? 'Mount Elbrus'
            : i(r'\balps\b')
                ? 'Mont Blanc'
                : i(r'\bnorth america\b')
                    ? 'Denali'
                    : i(r'\b(south america|americas)\b')
                        ? 'Aconcagua'
                        : i(r'\bsoutheast asia\b')
                            ? 'Hkakabo Razi'
                            : i(r'\bjapan\b')
                                ? 'Mount Fuji'
                                : i(r'\bmalaysia\b')
                                    ? 'Mount Kinabalu'
                                    : i(r'\b(world|earth|asia)\b')
                                        ? 'world'
                                        : (i(r'\b(viet ?nam|indochina)\b') ? 'vn' : '');
    return WCmd(WKind.terrain, aspect: 'peak', target: tg, raw: raw);
  }
  final pk = peakIn(raw);
  if (i(r'\b(how high|how tall|elevation|altitude|above sea level|height of)\b')) {
    return WCmd(WKind.terrain, aspect: 'height', target: pk?.vi ?? place(t), raw: raw);
  }
  if (i(r'\bterrain\b')) {
    final p = place(t).toLowerCase();
    if (RegExp(r'^(of )?viet ?nam$').hasMatch(p)) return WCmd(WKind.terrain, aspect: 'overview', target: 'vn', raw: raw);
    if (RegExp(r'^(of )?(the )?(world|earth)$').hasMatch(p)) return WCmd(WKind.terrain, aspect: 'overview', target: 'world', raw: raw);
    return WCmd(WKind.terrain, aspect: 'describe', target: place(t), raw: raw);
  }
  return null;
}

String _title(String s) => s.split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
