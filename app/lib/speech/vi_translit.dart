// PHIÊN ÂM TÊN NƯỚC NGOÀI CHO GIỌNG ĐỌC TIẾNG VIỆT.
// Giọng tiếng Việt đọc chữ Anh/Pháp/Đức rất khó nghe ("Albenga", "Whichello", "Stockholm"…). Trước khi đọc, mỗi từ
// KHÔNG phải một tiếng Việt hợp lệ được viết lại thành các tiếng kiểu Việt, theo cách phiên âm quen thuộc:
//   Albenga → An ben ga · Stockholm → Xơ tốc hôn mơ · Johannesburg → Giô ha nét bu gơ · Chicago → Chi ca gô
// Phụ đề vẫn hiện chữ gốc; chỉ cách đọc thay đổi. Tên quen đã có cách gọi riêng (Luân Đôn, Pa ri…) nằm ở danh sách
// trong speaker.dart và được thay trước.

const _onsets = [
  'ngh', 'ng', 'nh', 'ch', 'gh', 'gi', 'kh', 'ph', 'th', 'tr', 'qu', //
  'b', 'c', 'd', 'đ', 'g', 'h', 'k', 'l', 'm', 'n', 'p', 'r', 's', 't', 'v', 'x', '',
];
const _nuclei = [
  'uyê', 'oai', 'oay', 'uây', 'oeo', 'iêu', 'yêu', 'ươi', 'ươu', 'uôi', 'oa', 'oă', 'oe', 'uê', 'uy', 'ia', 'iê', 'ya',
  'yê', 'ua', 'uô', 'ưa', 'ươ', 'ai', 'ao', 'au', 'ay', 'âu', 'ây', 'eo', 'êu', 'iu', 'oi', 'ôi', 'ơi', 'ui', 'ưi', 'ưu',
  'a', 'ă', 'â', 'e', 'ê', 'i', 'o', 'ô', 'ơ', 'u', 'ư', 'y',
];
const _openNuclei = {'ia', 'iê', 'ya', 'yê', 'ua', 'uô', 'ưa', 'ươ', 'oa', 'oă', 'oe', 'uê', 'uy', 'uyê'};
const _codas = {'ng', 'nh', 'ch', 'c', 'm', 'n', 'p', 't', ''};

// bỏ dấu thanh (giữ mũ, móc): "Nẵng" → "Năng"
const _toneFrom = 'àáạảãằắặẳẵầấậẩẫèéẹẻẽềếệểễìíịỉĩòóọỏõồốộổỗờớợởỡùúụủũừứựửữỳýỵỷỹ';
const _toneTo = 'aaaaaăăăăăâââââeeeeeêêêêêiiiiioooooôôôôôơơơơơuuuuuưưưưưyyyyy';

String _noTone(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final k = _toneFrom.indexOf(ch);
    b.write(k >= 0 ? _toneTo[k] : ch);
  }
  return b.toString();
}

/// Từ này có phải MỘT tiếng Việt hợp lệ không ("Nẵng", "Vinh" → có; "Paris", "Hanoi" → không).
bool isVietnameseSyllable(String word) {
  final w = _noTone(word.toLowerCase());
  if (w.isEmpty || !RegExp(r'^[a-zăâđêôơư]+$').hasMatch(w)) return false;
  for (final o in _onsets) {
    if (!w.startsWith(o)) continue;
    final rest = w.substring(o.length);
    for (final n in _nuclei) {
      if (!rest.startsWith(n)) continue;
      final c = rest.substring(n.length);
      if (!_codas.contains(c)) continue;
      // vần kết thúc bằng bán nguyên âm (ai, ao, ơi…) không có thêm phụ âm cuối
      if (c.isNotEmpty && n.length > 1 && 'iouy'.contains(n[n.length - 1]) && !_openNuclei.contains(n)) continue;
      return true;
    }
  }
  return false;
}

const _coda = {
  'ʝ': 'ch', 'ç': 'ch', 'ŋ': 'ng', 'l': 'n', 'r': '', 's': 't', 'f': 'p', 'v': 'p', 'b': 'p', 'p': 'p', 'd': 't', 't': 't',
  'g': 'c', 'k': 'c', 'z': 't', 'h': '', 'm': 'm', 'n': 'n', 'w': '',
};
const _onset = {'ʝ': 'gi', 'ç': 'ch', 'f': 'ph', 'k': 'c', 'd': 'đ', 's': 'x', 'z': 'd', 'v': 'v', 'w': 'u', 'h': 'h'};
const _vowelMap = {
  'ia': 'ia', 'io': 'iô', 'ua': 'oa', 'ue': 'uê', 'ui': 'ui', 'oa': 'oa', 'ai': 'ai', 'ao': 'ao', 'eu': 'êu', 'oi': 'ôi',
  'iu': 'iu', 'au': 'ô', 'ou': 'u', 'ie': 'i', 'ea': 'i', 'ee': 'i', 'oo': 'u', 'eo': 'êô', 'iou': 'iu', 'eau': 'ô',
};
const _accentIn = 'aăâeêioôơuưy';
const _accentOut = 'áắấéếíóốớúứý';

String _sac(String s) {
  final idx = [for (var i = 0; i < s.length; i++) if (_accentIn.contains(s[i])) i];
  if (idx.isEmpty) return s;
  final pick = idx.firstWhere((i) => 'âêôơư'.contains(s[i]), orElse: () => idx.last);
  return s.substring(0, pick) + _accentOut[_accentIn.indexOf(s[pick])] + s.substring(pick + 1);
}

String _onsetOf(String u) => _onset[u] ?? u;

String _vowel(String v) {
  if (v == 'â') return 'ây';
  final m = _vowelMap[v];
  if (m != null) return m;
  final f = v[0];
  return f == 'o' ? 'ô' : f;
}

String _syl(String on, String v, String co) {
  if (v.length > 1 && 'iuoy'.contains(v[v.length - 1]) && !const {'ia', 'oa', 'uê', 'iô'}.contains(v)) co = '';
  if (v == 'ây') co = '';
  var s = '$on$v$co';
  if (s.startsWith('c') && s.length > 1 && 'eiêy'.contains(s[1])) s = 'k${s.substring(1)}';
  if (on != 'gi' && s.startsWith('g') && !s.startsWith('gh') && s.length > 1 && 'eiê'.contains(s[1])) s = 'gh${s.substring(1)}';
  if (s.startsWith('ng') && !s.startsWith('ngh') && s.length > 2 && 'eiê'.contains(s[2])) s = 'ngh${s.substring(2)}';
  if (const {'p', 't', 'c', 'ch'}.contains(co)) s = _sac(s);
  return s;
}

// chữ Latinh có dấu của tiếng nước ngoài → chữ thường không dấu
const _latinFrom = 'àáâãäåāèéêëēìíîïīòóôõöøōùúûüūýÿñçšžčřłßæœ';
const _latinTo = 'aaaaaaaeeeeeiiiiiooooooouuuuuyyncszcrlsae';

String _plain(String word) {
  final b = StringBuffer();
  for (final ch in word.toLowerCase().split('')) {
    final k = _latinFrom.indexOf(ch);
    b.write(k >= 0 ? _latinTo[k] : ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z]'), '');
}

/// Viết lại MỘT từ nước ngoài thành các tiếng kiểu Việt để giọng tiếng Việt đọc được.
String phienAm(String word) {
  var w = _plain(word);
  if (w.length < 2) return word;
  if (w.length > 3 && RegExp(r'[^aeiou]e$').hasMatch(w)) w = w.substring(0, w.length - 1); // e câm cuối từ
  for (final (a, b) in const [
    ('sch', 's'), ('tch', 'ç'), ('ch', 'ç'), ('ph', 'f'), ('th', 't'), ('sh', 's'), ('ck', 'k'), ('gh', 'g'), ('wh', 'u'),
    ('qu', 'kv'), ('x', 'ks'), ('ei', 'â'), ('ey', 'â'), ('ay', 'â'), ('aw', 'o'), ('ow', 'ao'),
  ]) {
    w = w.replaceAll(a, b);
  }
  w = w.replaceAllMapped(RegExp(r'([bcdfgklmnprstvz])\1'), (m) => m[1]!);
  w = w.replaceAll(RegExp(r'c(?=[eiy])'), 's').replaceAll('c', 'k');
  w = w.replaceFirst(RegExp(r'^y(?=[aeiou])'), 'd').replaceAll('y', 'i');
  w = w.replaceAll('q', 'k').replaceAll('j', 'ʝ');
  w = w.replaceAll(RegExp(r'w(?=[aeiou])'), 'u');
  w = w.replaceFirst(RegExp(r'ng$'), 'ŋ');
  final toks = [for (final m in RegExp(r'[aeiouâ]+|[^aeiouâ]+').allMatches(w)) m[0]!];
  final out = <String>[];
  var on = '';
  final n = toks.length;
  bool isVowel(String t) => 'aeiouâ'.contains(t[0]);
  for (var i = 0; i < n; i++) {
    final t = toks[i];
    if (!isVowel(t)) {
      if (i != 0) continue;
      var us = t.split('');
      if (us.length > 1) {
        final f = us.where((u) => u != 'h').toList();
        us = f.isEmpty ? ['h'] : f;
      }
      for (final u in us.sublist(0, us.length - 1)) {
        out.add(_syl(_onsetOf(u), 'ơ', ''));
      }
      on = _onsetOf(us.last);
      continue;
    }
    final v = _vowel(t);
    if (i + 1 < n) {
      final us = toks[i + 1].split('');
      if (i + 2 == n) {
        // phụ âm cuối từ: phụ âm đầu cụm làm âm cuối, phần còn lại thành tiếng "ơ"
        out.add(_syl(on, v, _coda[us[0]] ?? ''));
        on = '';
        for (final u in us.skip(1)) {
          if (u == 'h' || u == 'w') continue;
          out.add(_syl(_onsetOf(u), 'ơ', ''));
        }
      } else if (us.length == 1) {
        out.add(_syl(on, v, ''));
        on = _onsetOf(us[0]);
      } else {
        out.add(_syl(on, v, _coda[us[0]] ?? ''));
        final rest = us.sublist(1);
        final mid = [
          for (var k = 0; k < rest.length; k++)
            if (rest[k] != 'h' || k == rest.length - 1) rest[k]
        ];
        if (mid.isEmpty) mid.add('');
        for (final u in mid.sublist(0, mid.length - 1)) {
          out.add(_syl(_onsetOf(u), 'ơ', ''));
        }
        on = _onsetOf(mid.last);
      }
      i++; // đã dùng cụm phụ âm phía sau
    } else {
      out.add(_syl(on, v, ''));
      on = '';
    }
  }
  final r = out.where((x) => x.isNotEmpty).join(' ');
  return r.isEmpty ? word : r[0].toUpperCase() + r.substring(1);
}

/// Phiên âm mọi từ nước ngoài trong một câu tiếng Việt (giữ nguyên tiếng Việt, số, chữ viết tắt in hoa).
String phienAmCau(String text) => text.replaceAllMapped(
      RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿĀ-žƠơƯưẠ-ỹĐđ]+"),
      (m) {
        final w = m[0]!;
        if (w.length < 2) return w;
        if (isVietnameseSyllable(w)) return w;
        if (w.length <= 4 && w == w.toUpperCase()) return w; // USA, UK, NASA… (đã có cách đọc riêng nếu cần)
        if (!RegExp(r'[aeiouy]').hasMatch(_plain(w))) return w; // km, mm, kg: đơn vị viết tắt, không có nguyên âm
        // có chữ riêng của tiếng Việt (ă, â, đ, ơ, ư, dấu thanh) mà vẫn "không hợp lệ" → cứ để giọng đọc tự xử
        if (RegExp(r'[ăâđơưạ-ỹ]', caseSensitive: false).hasMatch(w) && !RegExp(r'[äöüßçñ]').hasMatch(w)) return w;
        return phienAm(w);
      },
    );
