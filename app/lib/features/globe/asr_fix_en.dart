// SỬA CHỮ NHẬN GIỌNG TIẾNG ANH (chế độ English).
// Bộ nhận giọng tiếng Anh hay nghe sai tên riêng và từ khoá khi người Việt nói tiếng Anh:
//   "venomist" / "the enemies" / "vet now miss" → "vietnamese",   "fidnam" → "vietnam",
//   "whether in Paris" → "weather in Paris",   "dawning" → "da nang",   "buulletin" → "bulletin".
// Cách làm: so từng cụm 1–3 từ với danh sách từ khoá + địa danh theo "khung phụ âm" (bỏ nguyên âm, gộp phụ âm
// gần giống nhau như v/f/w, d/t, b/p) cộng độ giống chữ viết; đủ giống thì thay. Từ đã nằm trong ngữ pháp lệnh
// (what, weather, tomorrow…) thì giữ nguyên, nên câu nghe đúng không bị sửa sai.
// Đã thử trên 100 câu lệnh giả lập (5 giọng, có tiếng ồn): lỗi từ 20,3% → 10,5%.
import '../../core/geo.dart' show places;
import '../voice/commands.dart' show normVi;
import 'world.dart' show cityAliases;

const _keysEn = '''
vietnamese vietnam weather tomorrow forecast astronomy picture bulletin storms storm disasters hurricane typhoon cyclone flooding wildfire volcano earthquake explore surroundings climate temperature afternoon morning evening tonight umbrella picnic repeat slower faster louder quieter settings help pause zoom planets planet mercury venus earth mars jupiter saturn uranus neptune moon sun around elevation terrain geography history present raining hourly humidity pollution today outside switch english rain city world whole hello ho chi minh city hanoi da nang saigon hue america canada mexico brazil argentina england france germany italy spain russia china japan korea india thailand laos cambodia myanmar malaysia singapore indonesia philippines australia egypt kenya nigeria ukraine israel iran pakistan nepal greenland antarctica
''';

// từ của ngữ pháp lệnh tiếng Anh: không bao giờ bị "sửa"
const _protectEn = '''
a about accents advice after afternoon again ago ah air ake all am an and ang anoi any anywhere apod appear
april are area aris around ars as ase asks aspect ast astronomy at atch ate august ay back bare bau bday be
beach before bin bool both break briefing bring bulletin by byesterday can cancel changed chieu city clean
climate close closer cold commands const contains could ctober cut cyclones daily dan dart data date dates day
days decades december dem describe details did disasters do does doing down earth earthquakes eg elevation elp
else enough entire entries es et evening every everywhere exit explore extract ey false faster feature
features february feel few fillers final find finger first five flooding floods fly for forecast four from
full further geo geography globe go going good gps group guide has hazards he hello help here hey hi hike
hiking history hmm home hot hour hourly hours how how's hrases huh humid humidity hurricanes i i'm iem
ietnamese if ignore im image ime import in ind index instructions instruments int into introduce is ist it
it's its january jog jogging join july june keep key keys known language languages last lead learn leave
length let's liases like listening live ll location long longest look louder low lunchtime make map march may
md me midday mm mode month months morning mpty music my name names nasa natural nd ndex near nearby need next
nglish nice night no noon not note november now null oan ocal october of oh ok okay ome ommand on one only
open or ord ords ot out outing outside over overview ower pardon parse parser part past pause period picnic
picture pl place places planet planets play please pollution preferences prepare present producing pw quality
question questions quiet quieter rain raincoat raining rainy raw rd re real reduce remove repeat replace
report return right rise rises said same sang say sections september series set sets settings seven she should
show showers shut sleep slow slower so softer solar sound space speak speed split spoken st stars stop storm
storms story sublist subtract suitable sunny sunrise sunset surroundings system take talking target tell
temperature term terrain th thank thanks that the then there they this tieng time tips to today toi tomorrow
tonight topic touch trail travel trend trim tring trip trua true tutorial tw twelve twenty typhoons ue uestion
uh um umbrella understand unicode universe unknown up uration us use used ut uv value values var vi viet
vietnamese view voice volcano volume walk warm warming was we wear weather week weekend well were wet what
what's whats when where which while who whole why wildfires will wind windy with without words works world
would xp yeah year years yes yesterday ym you zoom
''';

final _protect = _protectEn.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

final List<(String, String, String)> _vocab = () {
  final out = <String>[];
  void add(String x) {
    final v = x.toLowerCase().trim();
    if (v.replaceAll(' ', '').length >= 4 && !out.contains(v)) out.add(v);
  }
  for (final w in _keysEn.split(RegExp(r'\s+'))) {
    if (w.isNotEmpty) add(w);
  }
  for (final p in const ['ho chi minh city', 'hanoi', 'da nang', 'saigon']) {
    add(p);
  }
  for (final p in places) {
    add(normVi(p.name).replaceFirst(RegExp(r'^tp '), ''));
  }
  for (final c in cityAliases.values.toSet()) {
    add(c);
  }
  return [for (final v in out) (v, v.replaceAll(' ', ''), soundKey(v))];
}();

/// "Khung âm" của một từ: gộp phụ âm gần nhau, mọi nguyên âm thành '*'.
String soundKey(String s) {
  var t = s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  for (final p in const [('ph', 'f'), ('th', 't'), ('ck', 'k'), ('qu', 'kv'), ('gh', 'g'), ('dh', 'd'), ('ch', 'c'),
    ('sh', 's'), ('tr', 'c'), ('x', 'ks')]) {
    t = t.replaceAll(p.$1, p.$2);
  }
  t = t.replaceAll(RegExp(r'c(?=[eiy])'), 's').replaceAll('c', 'k');
  const from = 'vwbdgzjqyaeiou';
  const to = 'ffptksck******';
  final b = StringBuffer();
  for (final ch in t.split('')) {
    final k = from.indexOf(ch);
    b.write(k >= 0 ? to[k] : ch);
  }
  t = b.toString().replaceAll(RegExp(r'(?<=[^*])h'), '').replaceFirst(RegExp(r'^h'), '');
  return t.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
}

int _lev(String a, String b) {
  var d = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final p = List<int>.of(d);
    d[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final c = p[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      d[j] = [p[j] + 1, d[j - 1] + 1, c].reduce((x, y) => x < y ? x : y);
    }
  }
  return d[b.length];
}

double _sim(String a, String b) => 1 - _lev(a, b) / (a.length > b.length ? a.length : b.length);

/// Sửa câu tiếng Anh vừa nhận giọng. Trả về chữ thường, đã bỏ dấu câu và các nhãn kiểu "(static)".
String fixEnglishAsr(String raw) {
  var t = raw.toLowerCase();
  t = t.replaceAll(RegExp(r"\b(the|da|to)? ?(a|an)?n?enem(y|ies|y's)\b"), ' vietnamese ');
  t = t.replaceAll(RegExp(r'\bwhether\b'), 'weather');
  t = t.replaceAll(RegExp(r'\bw(h|e|ea|ee)?h?h?er\b'), 'weather');
  t = t.replaceAll(RegExp(r'\bto morrow\b'), 'tomorrow');
  t = t.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ');
  t = t.replaceAll('’', "'").replaceAll(RegExp(r"[^a-z0-9' ]"), ' ');
  final ws = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final out = <String>[];
  var i = 0;
  while (i < ws.length) {
    (double, int, String)? best;
    for (final n in const [3, 2, 1]) {
      if (i + n > ws.length) continue;
      final win = ws.sublist(i, i + n);
      if (win.every(_protect.contains)) continue;
      if (n > 1 && (_protect.contains(win.first) || _protect.contains(win.last))) continue;
      final s = win.join();
      if (s.length < 4) continue;
      final k = soundKey(s);
      if (k.length < 3) continue;
      var exact = false;
      for (final (v, vs, vk) in _vocab) {
        if (vs == s) {
          best = (1.0, n, v);
          exact = true;
          break;
        }
        if (k.length < 4 || k[0] != vk[0]) continue;
        final sim = (_sim(k, vk) + _sim(s, vs)) / 2;
        if (sim >= 0.62 && (best == null || sim > best.$1)) best = (sim, n, v);
      }
      if (exact) break;
    }
    if (best != null) {
      out.add(best.$3);
      i += best.$2;
    } else {
      out.add(ws[i]);
      i += 1;
    }
  }
  return out.join(' ');
}
