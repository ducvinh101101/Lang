// F1 — hiểu khẩu lệnh "lịch sử thời tiết / thiên tai tại <vị trí> trong vòng <khoảng thời gian>" (thuần Dart, test được).
//   "lịch sử thời tiết Hà Nội 3 năm qua"            → weatherHistory, aspect weather, spanMonths 36
//   "lịch sử thiên tai ở Quảng Ninh từ 2015 đến 2020" → aspect disaster, from 1/2015, to 12/2020
//   "lịch sử thời tiết và thiên tai Huế năm 2020"    → aspect both, 1/2020 → 12/2020
//   "nhìn lại thời tiết Đà Nẵng trong vòng 6 tháng"  → spanMonths 6
//   "thiên tai ở Huế 10 năm qua"                     → aspect disaster (thiên tai + khoảng thời gian đã qua)
import '../globe/world_commands.dart' show WCmd, WKind;
import '../voice/commands.dart' show normVi;

const _num = r'(\d+|(?:hai|ba|bon|nam|sau|bay|tam|chin) muoi(?: (?:mot|mot|hai|ba|bon|tu|lam|nam|sau|bay|tam|chin))?|'
    r'muoi(?: (?:mot|hai|ba|bon|tu|lam|nam|sau|bay|tam|chin))?|mot|hai|ba|bon|tu|nam|sau|bay|tam|chin|nua)';

const _units = {
  'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4, 'tu': 4, 'nam': 5, 'lam': 5, 'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9,
};

/// "ba" → 3, "muoi lam" → 15, "hai muoi" → 20, "12" → 12; "nua" → 0 (nửa — xử lý riêng).
int? numVi(String s) {
  s = s.trim();
  final d = int.tryParse(s);
  if (d != null) return d;
  if (s == 'nua') return 0;
  final w = s.split(' ');
  if (w.length == 1) return w.first == 'muoi' ? 10 : _units[w.first];
  if (w.first == 'muoi') return 10 + (_units[w[1]] ?? 0);
  if (w.length >= 2 && w[1] == 'muoi') {
    final tens = _units[w.first];
    if (tens == null) return null;
    return tens * 10 + (w.length > 2 ? (_units[w[2]] ?? 0) : 0);
  }
  return null;
}

class HistoryRangeSpec {
  final int? spanMonths;
  final DateTime? from, to;
  final int start, end; // vị trí cụm thời gian trong câu đã bỏ dấu
  const HistoryRangeSpec({this.spanMonths, this.from, this.to, required this.start, required this.end});
}

/// Tìm cụm khoảng thời gian trong câu đã bỏ dấu [t]. [now] để hiểu "năm ngoái", "đến nay".
HistoryRangeSpec? parseHistoryRange(String t, {DateTime? now}) {
  final today = now ?? DateTime.now();
  int mo(String? s) => (int.tryParse(s ?? '') ?? 0).clamp(0, 12);
  // từ (tháng M) (năm) YYYY đến (tháng M) (năm) YYYY
  var m = RegExp(r'\btu (?:thang (\d{1,2}) )?(?:nam )?(\d{4}) (?:den|toi|cho den|den het|sang) (?:thang (\d{1,2}) )?(?:nam )?(\d{4})\b')
      .firstMatch(t);
  if (m != null) {
    final m1 = mo(m.group(1)), m2 = mo(m.group(3));
    return HistoryRangeSpec(
        from: DateTime(int.parse(m.group(2)!), m1 == 0 ? 1 : m1),
        to: DateTime(int.parse(m.group(4)!), m2 == 0 ? 12 : m2),
        start: m.start,
        end: m.end);
  }
  // từ (tháng M) (năm) YYYY (đến nay)
  m = RegExp(r'\b(?:tu|ke tu|bat dau tu) (?:thang (\d{1,2}) )?(?:nam )?(\d{4})(?: (?:den|toi) (?:nay|bay gio|hien tai|gio))?\b').firstMatch(t);
  if (m != null) {
    final m1 = mo(m.group(1));
    return HistoryRangeSpec(from: DateTime(int.parse(m.group(2)!), m1 == 0 ? 1 : m1), start: m.start, end: m.end);
  }
  // thập niên 1990 / thập niên 90 / thập kỷ 2010
  m = RegExp(r'\bthap (?:nien|ky) (?:nam )?(\d{2,4})\b').firstMatch(t);
  if (m != null) {
    var y = int.parse(m.group(1)!);
    if (y < 100) y += y >= 30 ? 1900 : 2000;
    y = y - y % 10;
    return HistoryRangeSpec(from: DateTime(y, 1), to: DateTime(y + 9, 12), start: m.start, end: m.end);
  }
  // N năm / N tháng (qua, gần đây…) — "trong vòng N năm", "suốt N năm", "một thập kỷ qua", "nửa năm qua"
  m = RegExp('\\b(?:(?:trong|trong vong|suot|trong suot|khoang) )?(?:$_num) (nam|thang|thap ky|thap nien)'
          r'(?: (?:qua|gan day|vua qua|gan nhat|tro lai day|lai day|truoc|cuoi cung|vua roi))?\b')
      .firstMatch(t);
  if (m != null) {
    final full = m.group(0)!;
    // phải có dấu hiệu khoảng thời gian (trong/suốt/qua/gần đây…), không bắt nhầm "năm 2020" hay "Quảng Nam"
    final hasCue = RegExp(r'^(trong|suot|khoang)\b|\b(qua|gan day|vua qua|gan nhat|tro lai day|lai day|truoc|cuoi cung|vua roi)$').hasMatch(full);
    final numS = m.group(1);
    final unit = m.group(2)!;
    if (hasCue && numS != null) {
      final n = numVi(numS);
      if (n != null) {
        final months = numS == 'nua'
            ? (unit == 'nam' ? 6 : 1)
            : unit == 'thang'
                ? n
                : (unit == 'nam' ? n * 12 : n * 120);
        if (months > 0) return HistoryRangeSpec(spanMonths: months, start: m.start, end: m.end);
      }
    }
  }
  // năm ngoái / năm trước / năm nay
  m = RegExp(r'\b(nam ngoai|nam truoc|nam roi|nam nay)\b').firstMatch(t);
  if (m != null) {
    final y = m.group(1) == 'nam nay' ? today.year : today.year - 1;
    return HistoryRangeSpec(from: DateTime(y, 1), to: DateTime(y, 12), start: m.start, end: m.end);
  }
  // tháng M năm YYYY  /  năm YYYY
  m = RegExp(r'\bthang (\d{1,2}) (?:nam )?(\d{4})\b').firstMatch(t);
  if (m != null) {
    final d = DateTime(int.parse(m.group(2)!), mo(m.group(1)).clamp(1, 12));
    return HistoryRangeSpec(from: d, to: d, start: m.start, end: m.end);
  }
  m = RegExp(r'\b(?:trong |vao )?nam (\d{4})\b').firstMatch(t);
  if (m != null) {
    final y = int.parse(m.group(1)!);
    return HistoryRangeSpec(from: DateTime(y, 1), to: DateTime(y, 12), start: m.start, end: m.end);
  }
  return null;
}

// từ / cụm KHÔNG phải tên nơi (bị bỏ khỏi chỗ tên nơi)
const _core = [
  'lich su', 'nhin lai', 'nghe lai', 'phat lai', 'tua lai', 'qua khu', 'thoi tiet', 'khi hau', 'thien tai', 'bao lu',
  'mua nang',
];
const _edgeStop = {
  'cho', 'toi', 'minh', 'tui', 'em', 'nghe', 'xem', 'biet', 'muon', 'hay', 'phat', 'lai', 'nhin', 'tua', 'o', 'tai', 'cua', 'khu',
  'vuc', 'vung', 'trong', 'vong', 'va', 'hoac', 'the', 'nao', 'ra', 'sao', 'nhu', 'di', 'nhe', 'nha', 'a', 'voi', 've', 'nhung', 'cac',
  'gi', 'co', 'khong', 'lang', 'oi', 'ban', 'day', 'nay', 'qua', 'thoi', 'gian', 'duoc', 'giup', 'chut', 'luc', 'ky', 'cung',
  'xay', 'tung', 'doc',
};
// cặp từ là đầu tên nơi — không cắt từ đầu ("Nghệ An", "Cửa Lò", "Vũng Tàu", "Cô Tô"…)
const _protectPairs = {'nghe an', 'cua lo', 'cua dai', 'cua tung', 'cua viet', 'vung tau', 'co to', 'ban giang', 'tinh gia', 'ha tinh'};

/// Lệnh F1, hoặc null nếu câu không phải hỏi lịch sử thời tiết / thiên tai.
WCmd? weatherHistoryCmdVi(String raw, {DateTime? now}) {
  final orig = <String>[], toks = <String>[];
  for (final w in raw.trim().split(RegExp(r'[\s,.;:!?…/\-]+'))) {
    final n = normVi(w);
    if (n.isEmpty) continue;
    // "TP.HCM" → một từ gốc nhưng nhiều từ bỏ dấu: giữ ánh xạ 1-1 theo từ bỏ dấu
    final parts = n.split(' ');
    for (var k = 0; k < parts.length; k++) {
      orig.add(k == 0 ? w : '');
      toks.add(parts[k]);
    }
  }
  final t = toks.join(' ');
  bool i(String re) => RegExp(re).hasMatch(t);
  // ("diễn biến" so CÓ DẤU: bỏ dấu thì trùng tên tỉnh "Điện Biên")
  final hist = raw.toLowerCase().contains('diễn biến') || i(r'\b(lich su|nhin lai|nghe lai|phat lai|tua lai|trong qua khu|nhung nam qua|cac nam qua|nhung thang qua)\b');
  final weatherW = i(r'\b(thoi tiet|khi hau|mua nang)\b');
  final disasterW = i(r'\b(thien tai|bao lu|bao va lu)\b');
  if (!weatherW && !disasterW) return null;
  final range = parseHistoryRange(t, now: now);
  if (!hist) {
    // không có "lịch sử": chỉ nhận khi có khoảng thời gian ĐÃ QUA (khoảng N năm/tháng, từ… đến…, thập niên);
    // "thời tiết năm 2020", "thời tiết tháng 10 năm 2020" vẫn là phần khí hậu như cũ.
    if (range == null) return null;
    final absoluteOneYear = range.spanMonths == null && range.from != null && range.to != null &&
        range.from!.year == range.to!.year && !i(r'\b(tu|thap nien|thap ky)\b');
    if (absoluteOneYear && !disasterW) return null;
    if (range.spanMonths == null && range.from != null && range.to == null && !disasterW && !i(r'\b(den nay|toi nay|den bay gio)\b')) {
      return null;
    }
  }
  final aspect = weatherW && disasterW ? 'both' : (disasterW ? 'disaster' : 'weather');

  // ---- tên nơi: bỏ cụm thời gian + từ khoá, lấy đoạn liền dài nhất, cắt từ thừa ở hai đầu ----
  final removed = List<bool>.filled(toks.length, false);
  // vị trí ký tự bắt đầu của từng từ trong t
  final starts = <int>[];
  var pos = 0;
  for (final w in toks) {
    starts.add(pos);
    pos += w.length + 1;
  }
  void markChars(int a, int b) {
    for (var k = 0; k < toks.length; k++) {
      final s = starts[k], e = s + toks[k].length;
      if (s < b && e > a) removed[k] = true;
    }
  }

  if (range != null) markChars(range.start, range.end);
  for (final ph in _core) {
    for (final mm in RegExp('\\b$ph\\b').allMatches(t)) {
      markChars(mm.start, mm.end);
    }
  }
  // "diễn biến" (có dấu) → bỏ; "Điện Biên" (tên tỉnh) giữ
  for (var k = 0; k + 1 < toks.length; k++) {
    if (toks[k] == 'dien' && toks[k + 1] == 'bien' && orig[k].toLowerCase().contains('diễn')) {
      removed[k] = removed[k + 1] = true;
    }
  }
  final runs = <List<int>>[];
  var cur = <int>[];
  for (var k = 0; k < toks.length; k++) {
    if (removed[k]) {
      if (cur.isNotEmpty) runs.add(cur);
      cur = <int>[];
    } else {
      cur.add(k);
    }
  }
  if (cur.isNotEmpty) runs.add(cur);
  var best = <int>[];
  for (var run in runs) {
    // cắt từ thừa ở đầu (giữ cặp là tên nơi) và ở cuối
    while (run.isNotEmpty && _edgeStop.contains(toks[run.first])) {
      if (run.length > 1 && _protectPairs.contains('${toks[run[0]]} ${toks[run[1]]}')) break;
      run = run.sublist(1);
    }
    while (run.isNotEmpty && _edgeStop.contains(toks[run.last])) {
      if (run.length > 1 && _protectPairs.contains('${toks[run[run.length - 2]]} ${toks[run.last]}')) break;
      run = run.sublist(0, run.length - 1);
    }
    if (run.length > best.length) best = run;
  }
  final target = [for (final k in best) if (orig[k].isNotEmpty) orig[k]].join(' ').replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');
  return WCmd(WKind.weatherHistory,
      target: target, aspect: aspect, spanMonths: range?.spanMonths, from: range?.from, to: range?.to, raw: raw);
}

/// Tiếng Anh: "weather history of Hanoi over the last 3 years", "disaster history in Hue from 2015 to 2020".
WCmd? weatherHistoryCmdEn(String raw, {DateTime? now}) {
  final t = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final weatherW = RegExp(r'\b(weather|climate)\b').hasMatch(t);
  final disasterW = RegExp(r'\b(disasters?|hazards?)\b').hasMatch(t);
  if (!RegExp(r'\b(history|historical|past|replay|look back)\b').hasMatch(t) || (!weatherW && !disasterW)) return null;
  int? span;
  DateTime? from, to;
  var m = RegExp(r'\bfrom (\d{4}) (?:to|until|through) (\d{4})\b').firstMatch(t);
  if (m != null) {
    from = DateTime(int.parse(m.group(1)!), 1);
    to = DateTime(int.parse(m.group(2)!), 12);
  } else if ((m = RegExp(r'\b(?:last|past) (\d+|one|two|three|four|five|six|seven|eight|nine|ten|twelve) (years?|months?)\b').firstMatch(t)) != null) {
    const w = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'twelve': 12};
    final n = int.tryParse(m!.group(1)!) ?? w[m.group(1)] ?? 1;
    span = m.group(2)!.startsWith('year') ? n * 12 : n;
  } else if ((m = RegExp(r'\bin (\d{4})\b').firstMatch(t)) != null) {
    from = DateTime(int.parse(m!.group(1)!), 1);
    to = DateTime(int.parse(m.group(1)!), 12);
  }
  final pm = RegExp(r'\b(?:of|in|for|at) ([a-z]+(?: [a-z]+){0,3}?)(?= (?:over|during|from|in|for|last|past)\b|$)').firstMatch(t);
  var target = pm?.group(1)?.trim() ?? '';
  if (RegExp(r'^(the )?(last|past|\d)').hasMatch(target) || const {'here', 'this place'}.contains(target)) target = '';
  return WCmd(WKind.weatherHistory,
      target: target,
      aspect: weatherW && disasterW ? 'both' : (disasterW ? 'disaster' : 'weather'),
      spanMonths: span,
      from: from,
      to: to,
      raw: raw);
}
