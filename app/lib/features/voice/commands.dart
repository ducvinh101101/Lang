// Hiểu lệnh tiếng Việt nói hoặc gõ (chuyển từ runCommand của web/ban-do.html).
// Thuần Dart, không phụ thuộc giao diện → test được (test/commands_test.dart).
import '../../core/geo.dart';
import '../globe/world_commands.dart' show worldHotwords, extraHotwords;

enum CmdKind {
  stop,
  help,
  repeat,
  louder,
  quieter,
  faster,
  slower,
  zoomOut,
  zoomHere,
  readHere,
  summary,
  layer, // arg: khoá biến
  extreme, // max: true/false, có thể kèm nơi/vùng/biến
  goPlace, // place
  goRegion, // region
  time, // month (0..11) và/hoặc year
  shift, // month = số tháng dời đi (±1 tháng sau/trước, ±12 năm sau/trước)
  live, // thời tiết THẬT (bây giờ / dự báo): liveDay, liveAspect, place
  setHome, // "tôi ở Huế": đặt nơi mặc định cho thời tiết trực tiếp
  mapToday, // "bản đồ hôm nay": bản đồ chạm–nghe hiện số liệu thật hôm nay
  dayMap, // "ngày 15 tháng 10 năm 2024", "hôm qua": bản đồ số liệu của MỘT NGÀY (date), có thể kèm place
  mapHistory, // "dữ liệu NASA": bản đồ hiện dữ liệu khí hậu NASA các năm
  unknown,
}

class Command {
  final CmdKind kind;
  final String? layer;
  final bool max;
  final Place? place;
  final int? region;
  final int? month; // 0..11
  final int? year;

  /// Thời tiết trực tiếp: null = bây giờ, 0 hôm nay, 1 ngày mai, 2 ngày kia, 7 mấy ngày tới.
  final int? liveDay;

  /// 'rain' (có mưa không), 'advice' (nên làm gì) hoặc null (thời tiết chung).
  final String? liveAspect;

  /// true: "thời tiết ở đây" — chỗ đang chạm trên bản đồ.
  final bool here;

  /// Ngày cụ thể (lệnh dayMap).
  final DateTime? date;
  const Command(this.kind,
      {this.layer,
      this.max = true,
      this.place,
      this.region,
      this.month,
      this.year,
      this.liveDay,
      this.liveAspect,
      this.here = false,
      this.date});

  @override
  String toString() => 'Command($kind, layer=$layer, max=$max, place=${place?.name}, region=$region, '
      'month=$month, year=$year, liveDay=$liveDay, liveAspect=$liveAspect, here=$here)';
}

/// Bỏ dấu, viết thường, chỉ giữ chữ/số — giống norm() của bản web.
String normVi(String s) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final k = from.indexOf(ch);
    b.write(k >= 0 ? to[k] : ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

bool _hasW(String t, String k) => ' $t '.contains(' $k ');

/// Tỉnh/tên gọi khác → địa danh trong danh sách places.
const _aliases = {
  'sai gon': 'TP. Hồ Chí Minh', 'ho chi minh': 'TP. Hồ Chí Minh', 'tp hcm': 'TP. Hồ Chí Minh', 'hcm': 'TP. Hồ Chí Minh',
  'da lat': 'Đà Lạt', 'quang tri': 'Đông Hà', 'quang binh': 'Đồng Hới', 'quang nam': 'Tam Kỳ', 'binh dinh': 'Quy Nhơn',
  'khanh hoa': 'Nha Trang', 'nghe an': 'Vinh', 'dak lak': 'Buôn Ma Thuột', 'lam dong': 'Đà Lạt', 'dong nai': 'Biên Hòa',
  'kien giang': 'Rạch Giá', 'an giang': 'Long Xuyên', 'thua thien hue': 'Huế', 'quang ninh': 'Hạ Long',
  'gia lai': 'Pleiku', 'phu yen': 'Tuy Hòa', 'ninh thuan': 'Phan Rang', 'binh thuan': 'Phan Thiết',
  'ba ria': 'Vũng Tàu', 'tien giang': 'Mỹ Tho', 'dien bien': 'Điện Biên Phủ',
  'hoang sa': 'quần đảo Hoàng Sa', 'truong sa': 'quần đảo Trường Sa', 'paracel': 'quần đảo Hoàng Sa', 'spratly': 'quần đảo Trường Sa',
};

final List<(String, Place)> _placeIndex = () {
  final out = <(String, Place)>[for (final p in places) (normVi(p.name), p)];
  _aliases.forEach((k, v) {
    final p = places.where((x) => x.name == v);
    if (p.isNotEmpty) out.add((k, p.first));
  });
  out.sort((a, b) => b.$1.length.compareTo(a.$1.length)); // khớp tên dài trước ("da nang" trước "nang")
  return out;
}();

const _regionIndex = <(String, int)>[
  ('dong bang song cuu long', 5), ('dong bang song hong', 1), ('bac trung bo', 2), ('nam trung bo', 3),
  ('tay nguyen', 4), ('tay bac', 0), ('dong bac', 1), ('mien trung', 2), ('mien bac', 1), ('mien nam', 5),
  ('mien tay', 5), ('nam bo', 5),
];

const _monthWords = <String, int>{
  'gieng': 1, 'mot': 1, 'hai': 2, 'ba': 3, 'tu': 4, 'bon': 4, 'nam': 5, 'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9,
  'muoi': 10, 'muoi mot': 11, 'muoi hai': 12, 'chap': 12,
};

(int?, int?) _parseTime(String t) {
  int? month, year;
  final y = RegExp(r'\bnam (\d{4})\b').firstMatch(t) ?? RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(t);
  if (y != null) year = int.parse(y.group(1)!);
  final m = RegExp(r'\bthang (\d{1,2})\b').firstMatch(t);
  if (m != null) {
    final v = int.parse(m.group(1)!);
    if (v >= 1 && v <= 12) month = v - 1;
  } else {
    final w = RegExp(r'\bthang (muoi mot|muoi hai|[a-z]+)\b').firstMatch(t);
    final v = w == null ? null : _monthWords[w.group(1)!];
    if (v != null) month = v - 1;
  }
  return (month, year);
}

/// Ngày cụ thể trong câu: "ngày 15 tháng 10 năm 2024", "ngày 2 tháng chín", "15/10/2024", "15-10", "hôm qua", "hôm kia".
/// Thiếu năm → năm nay; thiếu tháng → tháng này. null nếu câu không nói ngày nào (hoặc ngày không hợp lệ).
DateTime? dateOf(String raw, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final t0 = DateTime(today.year, today.month, today.day);
  final t = normVi(raw);
  if (RegExp(r'\bhom qua\b').hasMatch(t) || RegExp(r'\byesterday\b').hasMatch(t)) return t0.subtract(const Duration(days: 1));
  if (RegExp(r'\bhom kia\b').hasMatch(t)) return t0.subtract(const Duration(days: 2));
  DateTime? make(int d, int m, int y) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final x = DateTime(y, m, d);
    return x.month == m && x.day == d ? x : null; // loại 31/2…
  }

  // dạng số: 15/10/2024, 15-10-2024, 15/10 (không nhận "11/2020" = tháng/năm)
  final sl = RegExp(r'(?<![\d/])(\d{1,2})[/-](\d{1,2})(?:[/-](\d{4}))?(?![\d/])').firstMatch(raw);
  if (sl != null) {
    final r = make(int.parse(sl.group(1)!), int.parse(sl.group(2)!), sl.group(3) == null ? today.year : int.parse(sl.group(3)!));
    if (r != null) return r;
  }
  // dạng chữ: ngày 15 tháng 10 năm 2024 / ngày 2 tháng chín
  final m = RegExp(r'\bngay (\d{1,2})\b(?: thang (\d{1,2}|muoi mot|muoi hai|[a-z]+))?(?: nam (\d{4}))?').firstMatch(t);
  if (m != null) {
    final mo = m.group(2);
    final month = mo == null ? today.month : (int.tryParse(mo) ?? _monthWords[mo]);
    if (month == null) return null;
    return make(int.parse(m.group(1)!), month, m.group(3) == null ? today.year : int.parse(m.group(3)!));
  }
  return null;
}

/// Câu hỏi thời tiết thật → (ngày, khía cạnh), null nếu không phải. Ngày: null = bây giờ.
(int?, String?)? _liveOf(String t) {
  bool i(String re) => RegExp(re).hasMatch(t);
  int? day;
  var isLive = false;
  if (i(r'\b(ngay kia|ngay mot)\b')) {
    day = 2;
  } else if (i(r'\b(ngay mai|sang mai|chieu mai|toi mai|dem mai|tomorrow)\b') || i(r'^mai\b')) {
    day = 1;
  } else if (i(r'\b(du bao|tuan nay|tuan toi|cuoi tuan|may ngay toi|nhung ngay toi|bay ngay|7 ngay|forecast|this week)\b')) {
    day = 7;
  } else if (i(r'\b(hom nay|sang nay|chieu nay|toi nay|dem nay|ca ngay|today|tonight)\b')) {
    day = 0;
  }
  if (day != null) isLive = true;
  if (i(r'\b(bay gio|hien tai|luc nay|dang the nao|ngay luc nay|right now|now)\b')) isLive = true;
  String? aspect;
  if (i(r'\b(co mua khong|mua khong|co mua|mang o|ao mua|phoi do|phoi quan ao|will it rain|umbrella)\b')) {
    aspect = 'rain';
    isLive = true;
  }
  if (i(r'\b(nen lam gi|lam gi|nen mac gi|mac gi|mac ao gi|ra ngoai|di choi|co nen|can mang gi|mang gi|chuan bi gi|'
      r'loi khuyen|khuyen|co nong khong|co lanh khong|nong khong|lanh khong|khong khi|o nhiem|what should|advice)\b')) {
    aspect = 'advice';
    isLive = true;
  }
  if (i(r'\b(thoi tiet|weather)\b')) isLive = true;
  return isLive ? (day, aspect) : null;
}

String? _layerOf(String t) {
  if (RegExp(r'\b(nhiet|nong|lanh|mat|temperature|temp)\b').hasMatch(t)) return 'temp';
  if (RegExp(r'\b(chay|lua|fire)\b').hasMatch(t)) return 'fire';
  if (RegExp(r'\b(mua|rain)\b').hasMatch(t)) return 'rain';
  return null;
}

Command parseCommand(String raw) {
  final t = normVi(raw);
  bool i(String re) => RegExp(re).hasMatch(t);
  if (t.isEmpty) return const Command(CmdKind.unknown);

  Place? place;
  for (final (k, p) in _placeIndex) {
    if (_hasW(t, k)) {
      place = p;
      break;
    }
  }
  int? region;
  for (final (k, r) in _regionIndex) {
    if (_hasW(t, k)) {
      region = r;
      break;
    }
  }
  final (month, year) = _parseTime(t);
  final layer = _layerOf(t);

  if (i(r'^(dung|im|thoi|stop)( lai| di)?$') || i(r'\b(dung lai|im lang|tat am)\b')) return const Command(CmdKind.stop);
  if (i(r'\b(tro giup|huong dan|giup|lam duoc gi|help)\b')) return const Command(CmdKind.help);
  if (i(r'\b(doc lai|nhac lai|noi lai|repeat)\b')) return const Command(CmdKind.repeat);
  if (i(r'\b(to hon|to len|louder)\b')) return const Command(CmdKind.louder);
  if (i(r'\b(nho hon|nho lai|be hon|quieter)\b')) return const Command(CmdKind.quieter);
  if (i(r'\b(nhanh hon|doc nhanh|faster)\b')) return const Command(CmdKind.faster);
  if (i(r'\b(cham hon|doc cham|cham lai|slower)\b')) return const Command(CmdKind.slower);
  // "Tôi ở Huế" → nơi mặc định cho thời tiết trực tiếp
  if (place != null && i(r'\b(toi o|minh o|em o|con o|nha toi o|nha minh o|noi cua toi|dat noi|que toi o)\b')) {
    return Command(CmdKind.setHome, place: place);
  }
  // Một NGÀY cụ thể → bản đồ số liệu ngày đó (Open-Meteo: lưu trữ từ 1940 hoặc dự báo 15 ngày)
  final date = dateOf(raw);
  if (date != null) return Command(CmdKind.dayMap, date: date, place: place, layer: layer);
  // Đổi kiểu bản đồ
  if (i(r'\b(ban do hom nay|ban do bay gio|ban do truc tiep|so lieu hom nay|du lieu hom nay|cap nhat ban do)\b')) {
    return const Command(CmdKind.mapToday);
  }
  if (i(r'\b(du lieu nasa|ban do nasa|so lieu nasa|nasa|cac nam truoc|du lieu cu|ban do lich su)\b')) {
    return const Command(CmdKind.mapHistory);
  }
  // Thời tiết THẬT (không nhắc tháng/năm cụ thể của dữ liệu NASA)
  final live = month == null && year == null ? _liveOf(t) : null;
  if (live != null) {
    return Command(CmdKind.live,
        place: place, liveDay: live.$1, liveAspect: live.$2, here: i(r'\b(o day|cho nay|noi nay)\b'));
  }
  if (i(r'\b(thu nho|quay lai|toan quoc|ca nuoc|zoom out|back)\b')) return const Command(CmdKind.zoomOut);
  if (i(r'\b(nhieu nhat|lon nhat|cao nhat|nong nhat|wettest|hottest)\b')) {
    return Command(CmdKind.extreme, max: true, layer: layer, place: place, region: region);
  }
  if (i(r'\b(it nhat|thap nhat|lanh nhat|mat nhat|kho nhat|driest|coldest)\b')) {
    final l = layer ?? (i(r'\b(lanh|mat)\b') ? 'temp' : null);
    return Command(CmdKind.extreme, max: false, layer: l, place: place, region: region);
  }
  if (i(r'\b(tom tat|tong quan|ca khu vuc|summary)\b')) return const Command(CmdKind.summary);
  // "tháng sau / tháng trước / năm sau / năm trước" — phân biệt "tháng sau" với "tháng sáu" nhờ dấu
  final low = raw.toLowerCase();
  if (RegExp(r'tháng (sau|tới|kế tiếp)\b').hasMatch(low) || i(r'\bnext month\b')) return const Command(CmdKind.shift, month: 1);
  if (RegExp(r'tháng (trước|vừa rồi)').hasMatch(low) || i(r'\b(thang truoc|previous month|last month)\b')) {
    return const Command(CmdKind.shift, month: -1);
  }
  if (RegExp(r'năm (sau|tới)\b').hasMatch(low) || i(r'\bnext year\b')) return const Command(CmdKind.shift, month: 12);
  if (RegExp(r'năm (trước|ngoái)').hasMatch(low) || i(r'\b(nam truoc|nam ngoai|last year)\b')) {
    return const Command(CmdKind.shift, month: -12);
  }
  if (month != null || year != null) {
    return Command(CmdKind.time, month: month, year: year, layer: layer, place: place, region: region);
  }
  if (place != null) return Command(CmdKind.goPlace, place: place, layer: layer);
  if (region != null) return Command(CmdKind.goRegion, region: region, layer: layer);
  if (i(r'\b(phong to|zoom|ky hon)\b')) return const Command(CmdKind.zoomHere);
  // "thời tiết ở đây", "nhiệt độ chỗ này", "đọc" → đọc thời tiết chỗ con trỏ (mọi lớp)
  if (i(r'\b(khi hau|o day|cho nay|day la dau|o dau|chi tiet|doc|where|here)\b')) {
    return Command(CmdKind.readHere, layer: layer);
  }
  if (layer != null && t.split(' ').length <= 4) return Command(CmdKind.layer, layer: layer);
  return const Command(CmdKind.unknown);
}

const helpVi = 'Trợ giúp. Trên bản đồ: chạm một lần để nghe thời tiết ở đó. Rê ngón tay để nghe bằng nhạc cụ. '
    'Chạm đúp để nghe chi tiết. Giữ yên ngón tay một giây để phóng to khu vực đó. '
    'Bốn nút ở bốn góc: trên trái là Menu: thời tiết bây giờ, đọc lại, dự báo, bản đồ, học và chơi, cài đặt giọng đọc. Trên phải là Trợ giúp. '
    'Dưới trái là Nói lệnh. Dưới phải là Đọc chỗ này. Chạm nút một lần để nghe tên, chạm lần nữa để chọn. '
    'Thời tiết thật: nói thời tiết bây giờ, thời tiết Huế, ngày mai có mưa không, hôm nay nên làm gì, dự báo 5 ngày. '
    'Xem ngày khác: nói bản đồ hôm qua, hoặc bản đồ ngày 15 tháng 10 năm 2024. Nói bản đồ hôm nay để quay về hôm nay. '
    'Nói tôi ở, rồi tên tỉnh, để đặt nơi của bạn. Nếu đã bật trợ lý AI, bạn có thể hỏi bất kỳ câu nào về thời tiết. '
    'Dữ liệu các năm trước trên bản đồ: nơi mưa nhiều nhất. Nhiệt độ. Tháng 10 năm 2020. '
    'Tóm tắt. Thu nhỏ. Đọc lại. Đọc chậm hơn. Dừng. '
    'Bàn phím: mũi tên để di chuyển, Enter đọc chi tiết, O mở menu, V nói lệnh, Z phóng to, Esc dừng. '
    'Lưu ý: ứng dụng không thay cho cảnh báo chính thức của cơ quan khí tượng thủy văn.';
const helpEn = 'Help. On the map: tap once to hear the weather there. Drag a finger to hear it as music. '
    'Double-tap for details. Hold still for one second to zoom in. '
    'Four corner buttons: top left Menu: weather now, repeat, forecast, map, learn and play, voice settings. Top right Help. '
    'Bottom left Voice command. Bottom right Read here. Tap a button once to hear it, again to choose. '
    'Live weather: say weather now, weather Hue, will it rain tomorrow, what should I do today, 5-day forecast. '
    'With the AI assistant on, ask any weather question. Past data on the map: wettest place. Temperature. October 2020. '
    'Summary. Zoom out. Repeat. Slower. Stop. '
    'Keyboard: arrows to move, Enter for details, O for menu, V for voice command, Z to zoom, Esc to stop. '
    'This app does not replace official weather warnings.';


// ---------- Hỗ trợ nhận giọng nói ----------

/// Các câu lệnh mẫu (có dấu) — dùng làm "từ khoá ưu tiên" cho bộ nhận giọng và để khớp gần đúng.
const commandPhrases = <String>[
  'dừng lại', 'trợ giúp', 'đọc lại', 'to hơn', 'nhỏ hơn', 'đọc nhanh hơn', 'đọc chậm hơn', 'thu nhỏ', 'phóng to',
  'toàn quốc', 'tóm tắt', 'thời tiết ở đây', 'đây là đâu', 'nhiệt độ', 'lượng mưa', 'cháy rừng',
  'nơi mưa nhiều nhất', 'nơi mưa ít nhất', 'nơi nóng nhất', 'nơi lạnh nhất', 'nơi cháy nhiều nhất',
  'tháng sau', 'tháng trước', 'năm sau', 'năm trước',
  'thời tiết bây giờ', 'thời tiết hôm nay', 'thời tiết ngày mai', 'dự báo', 'dự báo thời tiết', 'có mưa không',
  'ngày mai có mưa không', 'nên làm gì', 'hôm nay nên làm gì', 'nên mặc gì', 'có nên ra ngoài không', 'tôi ở',
  'bản đồ hôm nay', 'dữ liệu NASA', 'cập nhật bản đồ', 'hôm qua', 'bản đồ hôm qua',
];

const _regionPhrases = <String>[
  'Tây Bắc', 'Đông Bắc', 'Đồng bằng sông Hồng', 'Bắc Trung Bộ', 'Nam Trung Bộ', 'Tây Nguyên',
  'Đồng bằng sông Cửu Long', 'miền Bắc', 'miền Trung', 'miền Nam', 'miền Tây', 'Sài Gòn', 'Hoàng Sa', 'Trường Sa',
];

String _placeSpoken(Place p) => p.name.replaceAll('TP. ', '').replaceAll('quần đảo ', '');

/// Từ khoá ưu tiên cho bộ nhận giọng (CHỮ HOA có dấu, mỗi dòng một cụm).
List<String> hotwordPhrases() {
  final out = <String>{
    for (final c in commandPhrases) c,
    for (final c in worldHotwords) c,
    for (final c in extraHotwords) c,
    for (final r in _regionPhrases) r,
    'thời tiết',
    for (final p in places) _placeSpoken(p),
  };
  return [
    for (final t in out)
      if (t.trim().isNotEmpty) t.toUpperCase().replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ').replaceAll(RegExp(r' +'), ' ').trim()
  ];
}

final List<(String, String)> _snapCandidates = () {
  final out = <(String, String)>[];
  void add(String t) => out.add((t, normVi(t)));
  for (final c in commandPhrases) {
    add(c);
  }
  for (final r in _regionPhrases) {
    add(r);
  }
  for (final p in places) {
    add(_placeSpoken(p));
    add('thời tiết ${_placeSpoken(p)}');
  }
  return out;
}();

int _lev(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final x = prev[j] + 1, y = cur[j - 1] + 1, z = prev[j - 1] + cost;
      cur[j] = x < y ? (x < z ? x : z) : (y < z ? y : z);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Câu bộ nhận giọng nghe được → câu lệnh chuẩn gần nhất nếu app chưa hiểu câu gốc.
/// Trả về (câu dùng để chạy lệnh, có phải đã sửa không). Ví dụ "thức nào" → "thu nhỏ", "cun ma thuội" → "Buôn Ma Thuột".
(String, bool) snapCommand(String heard) {
  final h = heard.trim();
  if (h.isEmpty || parseCommand(h).kind != CmdKind.unknown) return (h, false);
  final n = normVi(h);
  String? best;
  var bestScore = 0.0;
  for (final (text, key) in _snapCandidates) {
    final score = _similarity(n, key);
    if (score > bestScore) {
      bestScore = score;
      best = text;
    }
  }
  return bestScore >= 0.65 && best != null ? (best, true) : (h, false);
}

double _sim(String a, String b) {
  final m = a.length > b.length ? a.length : b.length;
  return m == 0 ? 1 : 1 - _lev(a, b) / m;
}

/// Giống nhau theo TỪNG TIẾNG (cùng số tiếng: trung bình độ giống của từng tiếng), khác số tiếng thì trừ điểm.
/// Tránh khớp nhầm kiểu "xương này" → "Quảng Ngãi" khi chỉ so cả chuỗi ký tự.
double _similarity(String a, String b) {
  final x = a.split(' '), y = b.split(' ');
  if (x.length == y.length) {
    var t = 0.0;
    for (var k = 0; k < x.length; k++) {
      t += _sim(x[k], y[k]);
    }
    return t / x.length;
  }
  return _sim(a, b) * 0.85;
}
