// ĂN UỐNG VÀ LƯU TRÚ Ở HÀ NỘI — trả lời từ DỮ LIỆU, không bịa.
//
// Dữ liệu: assets/data/hanoi_places.json (quán ăn, cà phê, phố ẩm thực, khách sạn, hostel, khu nghỉ dưỡng). Mỗi địa điểm có
// tên, địa chỉ, khu vực, toạ độ, món / hạng sao, giá tham khảo, giờ mở cửa (nếu biết), đặc điểm. Thêm quán mới = thêm một
// mục vào tệp JSON, KHÔNG phải sửa code.
//
// Cách trả lời: câu nói → [parsePlaceQuery] tách ý (ăn hay ở, món gì, khu nào, gần đây không, rẻ / sang, mấy sao,
// dưới bao nhiêu tiền, đang mở / ăn sáng / ăn đêm, hỏi riêng một quán) → [searchPlaces] lọc và xếp (gần trước nếu có
// vị trí) → [placesAnswer] đọc 3 nơi một lượt; "còn nữa" nghe tiếp, "chi tiết số 2" nghe kỹ một nơi ([placeFollowUp]).
// Thuần Dart (trừ hàm nạp tệp) nên kiểm thử được — test/hanoi_places_test.dart.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../voice/commands.dart' show normVi;
import 'hanoi_guide.dart' show findHanoiZone, hanoiZones;
import '../../live/vn_admin.dart' show provincesNow, provinceMerged;

// Tỉnh / thành KHÁC Hà Nội: "Bến Tre ăn gì ngon" không được đọc quán ăn Hà Nội
final _otherPlaces = <String>{
  for (final p in [...provincesNow, ...provinceMerged.keys]) normVi(p),
  'sai gon', 'ho chi minh', 'da lat', 'sa pa', 'hoi an', 'nha trang', 'vung tau', 'ha long', 'hue', 'phu quoc', 'phan thiet',
  'mui ne', 'quy nhon', 'buon ma thuot', 'pleiku', 'tam dao', 'moc chau', 'mai chau', 'con dao', 'cat ba', 'sam son', 'cua lo',
}..removeWhere((p) => p.contains('ha noi'));
bool _mentionsOtherPlace(String pt) => _otherPlaces.any((p) => pt.contains(' $p '));

class HnPlace {
  final String id, type, category, name, address, area, zone;
  final List<String> aliases, keywords, dishes, tags;
  final double lat, lon;
  final int? priceMin, priceMax; // quán ăn: giá một người (đồng)
  final int stars; // lưu trú: số sao (0 = không xếp hạng)
  final String? priceBand; // lưu trú: budget | mid | upper | luxury
  final List<(int, int)> hours; // phút tính từ 0 giờ; giờ đóng có thể > 1440 (qua nửa đêm). Rỗng = chưa rõ
  final String noteVi, noteEn;

  const HnPlace({
    required this.id,
    required this.type,
    required this.category,
    required this.name,
    required this.address,
    required this.area,
    required this.zone,
    required this.aliases,
    required this.keywords,
    required this.dishes,
    required this.tags,
    required this.lat,
    required this.lon,
    this.priceMin,
    this.priceMax,
    this.stars = 0,
    this.priceBand,
    this.hours = const [],
    this.noteVi = '',
    this.noteEn = '',
  });

  bool get isFood => type == 'food';
  bool get isStay => type == 'stay';

  static List<String> _strs(dynamic v) => v is List ? [for (final x in v) x.toString()] : const [];

  static int _min(String s) {
    final p = s.split(':');
    return int.parse(p[0]) * 60 + (p.length > 1 ? int.parse(p[1]) : 0);
  }

  factory HnPlace.fromJson(Map<String, dynamic> j) {
    final price = j['price'];
    final hours = <(int, int)>[];
    final hv = j['hours'];
    if (hv is List) {
      for (final h in hv) {
        if (h is List && h.length == 2) {
          final a = _min(h[0].toString());
          var b = _min(h[1].toString());
          if (b <= a) b += 1440; // đóng sau nửa đêm
          hours.add((a, b));
        }
      }
    }
    return HnPlace(
      id: j['id'].toString(),
      type: (j['type'] ?? 'food').toString(),
      category: (j['category'] ?? '').toString(),
      name: j['name'].toString(),
      address: (j['address'] ?? '').toString(),
      area: (j['area'] ?? '').toString(),
      zone: (j['zone'] ?? '').toString(),
      aliases: [for (final a in _strs(j['aliases'])) normVi(a)],
      keywords: [for (final a in _strs(j['keywords'])) normVi(a)],
      dishes: _strs(j['dishes']),
      tags: _strs(j['tags']),
      lat: (j['lat'] as num).toDouble(),
      lon: (j['lon'] as num).toDouble(),
      priceMin: price is List && price.isNotEmpty ? (price[0] as num).toInt() : null,
      priceMax: price is List && price.length > 1 ? (price[1] as num).toInt() : null,
      stars: (j['stars'] as num?)?.toInt() ?? 0,
      priceBand: j['priceBand']?.toString(),
      hours: hours,
      noteVi: (j['noteVi'] ?? '').toString(),
      noteEn: (j['noteEn'] ?? '').toString(),
    );
  }

  /// Đang mở lúc [t] không. Chưa rõ giờ → false (không khẳng định là đang mở).
  bool openAt(DateTime t) {
    final m = t.hour * 60 + t.minute;
    for (final (a, b) in hours) {
      if (m >= a && m < b) return true;
      if (b > 1440 && m < b - 1440) return true;
    }
    return false;
  }

  bool get hasTag => tags.isNotEmpty;
  bool tagged(String tag) => tags.any((x) => normVi(x).contains(normVi(tag)));
}

class HanoiPlacesDb {
  final List<HnPlace> places;
  final Map<String, String> categories; // mã → tên đọc
  final Map<String, (String, String, int)> bands; // mã → (vi, en, giá tối đa)
  final String updated;

  HanoiPlacesDb(this.places, this.categories, this.bands, this.updated);

  static HanoiPlacesDb? _cache;

  /// Nạp tệp dữ liệu đi kèm app (một lần). null nếu thiếu tệp / hỏng.
  static Future<HanoiPlacesDb?> load() async {
    final c = _cache;
    if (c != null) return c;
    try {
      return _cache = HanoiPlacesDb.parse(await rootBundle.loadString('assets/data/hanoi_places.json'));
    } catch (_) {
      return null;
    }
  }

  factory HanoiPlacesDb.parse(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final cats = <String, String>{};
    final cv = j['categories'];
    if (cv is Map) cv.forEach((k, v) => cats[k.toString()] = v.toString());
    final bands = <String, (String, String, int)>{};
    final bv = j['priceBands'];
    if (bv is Map) {
      bv.forEach((k, v) {
        if (v is Map) bands[k.toString()] = (v['vi'].toString(), v['en'].toString(), (v['max'] as num).toInt());
      });
    }
    return HanoiPlacesDb(
      [for (final p in (j['places'] as List)) HnPlace.fromJson(p as Map<String, dynamic>)],
      cats,
      bands,
      (j['updated'] ?? '').toString(),
    );
  }

  /// Mọi từ khoá món ăn có trong dữ liệu (dài trước).
  late final List<String> foodKeywords = () {
    final s = <String>{for (final p in places) if (p.isFood) ...p.keywords}..removeAll(_genericWords);
    return s.toList()..sort((a, b) => b.length.compareTo(a.length));
  }();
}

// từ quá chung, không dùng để LỌC món ("quán đồ ăn" ≠ chỉ những quán có chữ "đồ ăn")
const _genericWords = {'do an', 'mon viet', 'an dem'};

class PlaceQuery {
  final String type; // 'food' | 'stay'
  final List<String> want; // món / loại khớp từ khoá dữ liệu
  final String? zoneId; // khu vực Hà Nội nhắc trong câu (hanoi_guide)
  final bool near; // gần đây / quanh đây / chỗ tôi
  final bool cheap, fancy, openNow, late, morning;
  final int? maxPrice;
  final int? stars;
  final String? stayKind; // hotel | hostel | resort | homestay
  final HnPlace? named; // hỏi riêng một nơi ("Phở Thìn ở đâu", "Metropole mấy sao")
  final String raw;

  const PlaceQuery({
    required this.type,
    required this.raw,
    this.want = const [],
    this.zoneId,
    this.near = false,
    this.cheap = false,
    this.fancy = false,
    this.openNow = false,
    this.late = false,
    this.morning = false,
    this.maxPrice,
    this.stars,
    this.stayKind,
    this.named,
  });

  /// Cùng câu hỏi, đổi khu vực ("còn Tây Hồ thì sao" sau "quán phở ở phố cổ").
  PlaceQuery inZone(String zone, String newRaw) => PlaceQuery(
        type: type,
        raw: newRaw,
        want: want,
        zoneId: zone,
        cheap: cheap,
        fancy: fancy,
        openNow: openNow,
        late: late,
        morning: morning,
        maxPrice: maxPrice,
        stars: stars,
        stayKind: stayKind,
      );

  @override
  String toString() => 'PlaceQuery($type, want=$want, zone=$zoneId, near=$near, cheap=$cheap, fancy=$fancy, '
      'open=$openNow, late=$late, morning=$morning, max=$maxPrice, stars=$stars, kind=$stayKind, named=${named?.id})';
}

// "chỗ ở" bỏ dấu trùng "chợ ở" → không tính "chợ ở đâu"
final _stayRe = RegExp(r'\b(khach san|nha nghi|homestay|home stay|hostel|resort|khu nghi duong|nghi duong|cho o(?! dau)|cho ngu|'
    r'luu tru|o lai|ngu lai|ngu dem|qua dem|thue phong|dat phong|phong nghi|nghi dem|hotel|motel)\b');
final _foodRe = RegExp(r'\b(an gi|an o dau|an dau|quan an|quan nao|nha hang|mon gi|mon ngon|do an|an uong|an sang|an trua|'
    r'an toi|an dem|an vat|am thuc|dac san|ngon|quan ngon|cac quan|quan gi|quan nuoc|uong gi|uong ca phe|ca phe|cafe|coffee|an chay|bat pho|an kem|an che|'
    r'an pho|an bun|an banh)\b');
// KHÔNG có "cho toi": "cho tôi quán phở" (đưa cho tôi) bỏ dấu trùng "chỗ tôi"
final _nearRe = RegExp(r'\b(gan day|quanh day|o day|cho toi dang|gan toi|xung quanh|gan nhat|quanh toi|khu nay|cho nay|'
    r'noi toi dang dung|toi dang dung|minh dang dung|gan minh|quanh minh)\b');
final _cheapRe = RegExp(r'\b(re|gia re|binh dan|sinh vien|tiet kiem|khong dat|it tien|vua tui tien|ba lo|du lich bui)\b');
final _fancyRe = RegExp(r'\b(sang trong|cao cap|xin|dat tien|hang sang|thuong luu)\b'); // "5 sao" lọc theo số sao
final _openRe = RegExp(r'\b(dang mo|con mo|con ban|bay gio|luc nay|mo cua khong|dang ban)\b');
final _lateRe = RegExp(r'\b(an dem|dem khuya|khuya|mo khuya|nua dem|ban dem|toi muon|an khuya)\b');
final _morningRe = RegExp(r'\b(an sang|buoi sang|sang som|bua sang|sang nay an)\b');
const _numWords = {'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4, 'tu': 4, 'nam': 5};

/// Câu nói có hỏi chỗ ĂN hay chỗ Ở ở Hà Nội không; null nếu không (để các phần khác của app xử lý).
PlaceQuery? parsePlaceQuery(String raw, HanoiPlacesDb db) {
  final low = raw.toLowerCase();
  final t = normVi(raw);
  final pt = ' $t ';

  // hỏi riêng một nơi có trong dữ liệu (tên / tên gọi khác dài nhất khớp)
  HnPlace? named;
  var nlen = 0;
  for (final p in db.places) {
    for (final a in p.aliases) {
      if (a.length > nlen && pt.contains(' $a ')) {
        named = p;
        nlen = a.length;
      }
    }
  }

  final stay = _stayRe.hasMatch(t);
  // món trong dữ liệu; "phố" (phố cổ, phố Hàng Bạc) bỏ dấu cũng là "pho" → chỉ tính "phở" khi câu có chữ "phở"
  final want = <String>[];
  var rest = pt;
  for (final k in db.foodKeywords) {
    if (rest.contains(' $k ')) {
      if (k == 'pho' && !low.contains('phở') && low.contains('phố')) continue;
      want.add(k);
      rest = rest.replaceAll(' $k ', ' ');
    }
  }
  final zone = findHanoiZone(raw: raw, matchKeywordOnly: true)?.id;
  // có tên món + từ hỏi ("quán phở nào đang mở", "bún chả ở đâu", "bánh mì gần đây", "bún ốc ở phủ tây hồ", "bò tơ ba vì")
  final food = _foodRe.hasMatch(t) ||
      (want.isNotEmpty && (zone != null || RegExp(r'\b(quan|nao|o|tai|o dau|cho nao|dia chi|mo cua|may gio|gan|quanh|re|gia)\b').hasMatch(t)));
  if (named == null && !stay && !food) return null;
  final type = named?.type ?? (stay ? 'stay' : 'food');

  // số sao
  int? stars;
  final sm = RegExp(r'\b(\d|mot|hai|ba|bon|nam) sao\b').firstMatch(t);
  if (sm != null) stars = int.tryParse(sm.group(1)!) ?? _numWords[sm.group(1)!];

  // dưới bao nhiêu tiền: "dưới 500 nghìn", "dưới 1 triệu", "dưới 1,5 triệu", "500k"
  int? maxPrice;
  // (bỏ dấu đã biến "1,5" thành "1 5")
  final pm = RegExp(r'\b(duoi|khong qua|toi da|tam|khoang)\s+(\d+(?: \d)?|mot|hai|ba|bon|nam)\s*(nghin|ngan|k|trieu|tr|cu)\b')
      .firstMatch(t);
  if (pm != null) {
    final n = double.tryParse(pm.group(2)!.replaceAll(' ', '.')) ?? (_numWords[pm.group(2)!] ?? 0).toDouble();
    final unit = pm.group(3)!;
    maxPrice = (n * (unit == 'trieu' || unit == 'tr' || unit == 'cu' ? 1000000 : 1000)).round();
  }

  String? kind;
  if (RegExp(r'\b(hostel|nha nghi tap the|phong tap the|dorm|backpacker|du lich bui|ba lo)\b').hasMatch(t)) {
    kind = 'hostel';
  } else if (RegExp(r'\b(resort|khu nghi duong|nghi duong)\b').hasMatch(t)) {
    kind = 'resort';
  } else if (RegExp(r'\b(homestay|home stay)\b').hasMatch(t)) {
    kind = 'homestay';
  }

  if (zone == null && named == null && _mentionsOtherPlace(pt)) return null;
  return PlaceQuery(
    type: type,
    raw: raw,
    want: type == 'food' ? want : const [],
    zoneId: zone,
    // nhắc tên khu ("xung quanh Hồ Tây") thì lấy khu đó, không lấy vị trí người dùng
    near: zone == null && _nearRe.hasMatch(t),
    cheap: _cheapRe.hasMatch(t) || RegExp(r'\bnha nghi\b').hasMatch(t),
    fancy: _fancyRe.hasMatch(t),
    openNow: _openRe.hasMatch(t),
    late: _lateRe.hasMatch(t),
    morning: _morningRe.hasMatch(t),
    maxPrice: maxPrice,
    stars: stars,
    stayKind: kind,
    named: named,
  );
}

double _km(double lat1, double lon1, double lat2, double lon2) {
  final k = math.cos(lat1 * math.pi / 180);
  final dy = (lat2 - lat1) * 111.2, dx = (lon2 - lon1) * 111.2 * k;
  return math.sqrt(dx * dx + dy * dy);
}

/// Lọc và xếp địa điểm theo câu hỏi. Có [lat]/[lon] (vị trí người dùng) thì gần trước; không thì giữ thứ tự dữ liệu
/// (nơi nổi tiếng hơn đứng trước). Trả về (nơi, khoảng cách km hoặc null).
List<(HnPlace, double?)> searchPlaces(HanoiPlacesDb db, PlaceQuery q, {double? lat, double? lon, DateTime? now}) {
  if (q.named != null) {
    final p = q.named!;
    return [(p, lat == null || lon == null ? null : _km(lat, lon, p.lat, p.lon))];
  }
  final t = now ?? DateTime.now();
  bool keep(HnPlace p, {required bool useZone}) {
    if (p.type != q.type) return false;
    if (useZone && q.zoneId != null && !q.near && p.zone != q.zoneId) return false;
    if (p.isFood) {
      if (q.want.isNotEmpty && !q.want.any((w) => p.keywords.contains(w))) return false;
      if (q.cheap && (p.priceMax ?? 999999) > 60000) return false;
      if (q.fancy && (p.priceMin ?? 0) < 150000 && !p.tagged('sang trong')) return false;
      if (q.maxPrice != null && (p.priceMax ?? 999999) > q.maxPrice!) return false;
      if (q.openNow && !p.openAt(t)) return false;
      if (q.late && !p.openAt(DateTime(t.year, t.month, t.day, 22, 30)) && !p.tagged('mo khuya')) return false;
      if (q.morning && !p.openAt(DateTime(t.year, t.month, t.day, 7)) && !p.tagged('an sang')) return false;
    } else {
      if (q.stayKind != null && p.category != q.stayKind) return false;
      if (q.stars != null && p.stars != q.stars) return false;
      if (q.cheap && p.priceBand != 'budget') return false;
      if (q.fancy && p.priceBand != 'luxury') return false;
      if (q.maxPrice != null) {
        final band = db.bands[p.priceBand];
        if (band == null || band.$3 > q.maxPrice! * 1.25) return false; // hạng giá thường vượt quá mức hỏi → bỏ
      }
    }
    return true;
  }

  var hits = [for (final p in db.places) if (keep(p, useZone: true)) p];
  // khu vực nhắc tên nhưng không có nơi nào ĐÚNG khu đó → lấy nơi trong vòng 3 cây số quanh khu
  if (hits.isEmpty && q.zoneId != null && !q.near) {
    final z = hanoiZones.where((z) => z.id == q.zoneId).firstOrNull;
    if (z != null) {
      hits = [for (final p in db.places) if (keep(p, useZone: false) && _km(z.lat, z.lon, p.lat, p.lon) <= 3) p];
    }
  }
  final out = [for (final p in hits) (p, lat == null || lon == null ? null : _km(lat, lon, p.lat, p.lon))];
  if (lat != null && lon != null) out.sort((a, b) => a.$2!.compareTo(b.$2!));
  return out;
}

// ---------- đọc thành lời ----------
const _ordVi = ['Một', 'Hai', 'Ba', 'Bốn', 'Năm', 'Sáu', 'Bảy', 'Tám', 'Chín', 'Mười'];

String _money(int v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1).replaceAll('.', ',')} triệu';
  }
  return '${(v / 1000).round()} nghìn';
}

String _priceVi(HnPlace p) {
  final a = p.priceMin, b = p.priceMax;
  if (a == null) return '';
  if (b == null || b == a) return 'khoảng ${_money(a)}';
  // "50 đến 70 nghìn" (cùng đơn vị thì nói đơn vị một lần)
  if (a < 1000000 && b < 1000000) return 'khoảng ${(a / 1000).round()} đến ${(b / 1000).round()} nghìn';
  return 'khoảng ${_money(a)} đến ${_money(b)}';
}

String _priceEn(HnPlace p) {
  final a = p.priceMin, b = p.priceMax;
  if (a == null) return '';
  return b == null || b == a ? 'about ${a ~/ 1000} thousand dong' : 'about ${a ~/ 1000} to ${b ~/ 1000} thousand dong';
}

String _clock(int m) {
  final h = (m ~/ 60) % 24, mm = m % 60;
  return mm == 0 ? '$h giờ' : '$h giờ $mm';
}

String _hoursVi(HnPlace p) =>
    p.hours.isEmpty ? '' : 'mở ${[for (final (a, b) in p.hours) 'từ ${_clock(a)} đến ${_clock(b)}'].join(' và ')}';

String _hoursEn(HnPlace p) => p.hours.isEmpty
    ? ''
    : 'open ${[for (final (a, b) in p.hours) '${(a ~/ 60) % 24}:${(a % 60).toString().padLeft(2, '0')} to ${(b ~/ 60) % 24}:${(b % 60).toString().padLeft(2, '0')}'].join(' and ')}';

String _distVi(double? km) {
  if (km == null) return '';
  if (km < 1) return 'cách khoảng ${math.max(50, (km * 1000 / 50).round() * 50)} mét';
  return 'cách khoảng ${km.toStringAsFixed(1).replaceAll('.', ',')} cây số';
}

String _distEn(double? km) => km == null ? '' : (km < 1 ? 'about ${(km * 1000 / 50).round() * 50} m away' : 'about ${km.toStringAsFixed(1)} km away');

String _whatVi(HanoiPlacesDb db, HnPlace p) {
  if (p.isStay) {
    final kind = db.categories[p.category] ?? 'chỗ ở';
    return p.stars > 0 ? '$kind ${p.stars} sao' : kind;
  }
  return p.dishes.isNotEmpty ? p.dishes.take(2).join(', ') : (db.categories[p.category] ?? '');
}

String _whatEn(HnPlace p) {
  if (p.isStay) return p.stars > 0 ? '${p.stars}-star ${p.category}' : p.category;
  return p.noteEn.isNotEmpty ? p.noteEn.split('.').first : p.category;
}

/// Một nơi, đọc ngắn trong danh sách.
(String, String) _lineOf(HanoiPlacesDb db, HnPlace p, double? km, int i) {
  final vi = [
    '${i < _ordVi.length ? _ordVi[i] : '${i + 1}'}: ${p.name}',
    _whatVi(db, p),
    'ở ${p.address}',
    _distVi(km),
    if (p.isFood) _priceVi(p) else (db.bands[p.priceBand]?.$1.split(',').first ?? ''),
  ].where((x) => x.isNotEmpty).join(', ');
  final en = ['${i + 1}: ${p.name}', _whatEn(p), 'at ${p.address}', _distEn(km), if (p.isFood) _priceEn(p)]
      .where((x) => x.isNotEmpty)
      .join(', ');
  return ('$vi.', '$en.');
}

/// Đọc kỹ một nơi: mô tả, địa chỉ, món / hạng, giá, giờ mở cửa, đặc điểm.
(String, String) placeDetail(HanoiPlacesDb db, HnPlace p, {double? km}) {
  final vi = StringBuffer('${p.name}. ');
  if (p.noteVi.isNotEmpty) vi.write('${p.noteVi} ');
  vi.write('Địa chỉ: ${p.address}'); // MỘT địa chỉ ngắn, dễ nghe
  final d = _distVi(km);
  vi.write(d.isEmpty ? '. ' : ', $d. ');
  if (p.isFood) {
    if (p.dishes.isNotEmpty) vi.write('Món chính: ${p.dishes.join(', ')}. ');
    final pr = _priceVi(p);
    if (pr.isNotEmpty) vi.write('Giá tham khảo $pr một người. ');
    final h = _hoursVi(p);
    vi.write(h.isEmpty ? 'Mình chưa có giờ mở cửa của nơi này. ' : 'Thường ${h.replaceFirst('mở', 'mở cửa')}. ');
  } else {
    if (p.stars > 0) vi.write('Hạng ${p.stars} sao. ');
    final band = db.bands[p.priceBand];
    if (band != null) vi.write('Giá phòng ${band.$1}, giá tham khảo. ');
  }
  if (p.tags.isNotEmpty) vi.write('Đặc điểm: ${p.tags.join(', ')}.');
  final en = StringBuffer('${p.name}. ${p.noteEn} Address: ${p.address}. ');
  if (p.isFood) {
    final pr = _priceEn(p);
    if (pr.isNotEmpty) en.write('Price $pr per person. ');
    final h = _hoursEn(p);
    en.write(h.isEmpty ? 'Opening hours unknown. ' : '${h[0].toUpperCase()}${h.substring(1)}. ');
  } else {
    if (p.stars > 0) en.write('${p.stars} stars. ');
    final band = db.bands[p.priceBand];
    if (band != null) en.write('Rooms are ${band.$2}. ');
  }
  return (vi.toString().trim(), en.toString().trim());
}

String _whatAskedVi(HanoiPlacesDb db, PlaceQuery q) {
  if (q.type == 'stay') {
    final k = q.stayKind == null ? 'chỗ ở' : (db.categories[q.stayKind!] ?? 'chỗ ở');
    final parts = [
      k,
      if (q.stars != null) '${q.stars} sao',
      if (q.cheap) 'giá rẻ',
      if (q.fancy) 'sang trọng',
      if (q.maxPrice != null) 'dưới ${_money(q.maxPrice!)}',
    ];
    return parts.join(' ');
  }
  final w0 = q.want.isEmpty ? '' : q.want.first;
  final dish = switch (w0) {
    '' => 'quán ăn',
    'nha hang' => 'nhà hàng',
    'pho am thuc' => 'phố ẩm thực',
    _ => 'quán ${_dishName(db, w0)}',
  };
  return [
    dish,
    if (q.cheap) 'bình dân',
    if (q.fancy) 'sang trọng',
    if (q.maxPrice != null) 'dưới ${_money(q.maxPrice!)}',
    if (q.morning) 'ăn sáng',
    if (q.late) 'mở khuya',
    if (q.openNow) 'đang mở',
  ].join(' ');
}

const _dishNames = {
  'an vat': 'ăn vặt', 'bia hoi': 'bia hơi', 'do nuong': 'đồ nướng', 'an chay': 'chay', 'quan chay': 'chay',
  'nha hang chay': 'chay', 'do chay': 'chay', 'mon chay': 'chay', 'kem': 'kem', 'che': 'chè', 'xoi': 'xôi',
  'oc luoc': 'ốc', 'an oc': 'ốc', 'do ngot': 'đồ ngọt', 'mam tom': 'bún đậu mắm tôm', 'ca phe': 'cà phê', 'cafe': 'cà phê',
  'coffee': 'cà phê', 'ca phe trung': 'cà phê trứng',
};

// tên món có dấu để đọc: lấy từ tên món trong dữ liệu có chứa từ khoá
String _dishName(HanoiPlacesDb db, String key) {
  final fixed = _dishNames[key];
  if (fixed != null) return fixed;
  for (final p in db.places) {
    if (!p.keywords.contains(key)) continue;
    for (final d in [...p.dishes, db.categories[p.category] ?? '']) {
      final n = normVi(d);
      if (n == key || n.startsWith('$key ')) return d.split(' ').take(key.split(' ').length).join(' ');
    }
  }
  return key;
}

String _whereVi(PlaceQuery q, {required bool hasLoc}) {
  if (q.near && hasLoc) return 'gần bạn';
  if (q.zoneId != null) {
    final z = hanoiZones.where((z) => z.id == q.zoneId).firstOrNull;
    if (z != null) return 'ở ${z.titleVi}';
  }
  return 'ở Hà Nội';
}

/// Câu trả lời cho một trang danh sách (3 nơi), bắt đầu từ [from].
(String, String) placesAnswer(HanoiPlacesDb db, PlaceQuery q, List<(HnPlace, double?)> hits,
    {int from = 0, int n = 3, bool hasLoc = false}) {
  if (q.named != null && hits.isNotEmpty) return placeDetail(db, hits.first.$1, km: hits.first.$2);
  final what = _whatAskedVi(db, q);
  final where = _whereVi(q, hasLoc: hasLoc);
  if (hits.isEmpty) {
    return (
      'Trong dữ liệu của mình chưa có $what $where. Bạn thử bỏ bớt điều kiện, hoặc hỏi khu khác, ví dụ: quán ăn ở phố cổ, '
          'khách sạn gần Hồ Tây.',
      'I have no ${q.type == 'stay' ? 'places to stay' : 'places to eat'} matching that in my Hanoi data yet. '
          'Try fewer conditions, or another area such as the Old Quarter or West Lake.'
    );
  }
  if (from >= hits.length) {
    return ('Hết rồi, mình đã đọc cả ${hits.length} nơi.', 'That is all ${hits.length} places.');
  }
  final page = hits.skip(from).take(n).toList();
  final vi = StringBuffer();
  final en = StringBuffer();
  if (from == 0) {
    vi.write(hits.length == 1 ? 'Mình có một $what $where. ' : 'Mình có ${hits.length} $what $where. ');
    en.write('I have ${hits.length} ${q.type == 'stay' ? 'places to stay' : 'places to eat'}. ');
  }
  for (var i = 0; i < page.length; i++) {
    final (lv, le) = _lineOf(db, page[i].$1, page[i].$2, from + i);
    vi.write('$lv ');
    en.write('$le ');
  }
  final more = from + page.length < hits.length;
  if (more) {
    vi.write('Nói: còn nữa, để nghe tiếp; hoặc: chi tiết số ${from + 1}, để nghe kỹ một nơi.');
    en.write('Say "more" to hear the rest, or "details number ${from + 1}".');
  } else {
    vi.write('Nói: chi tiết số ${from + 1}, để nghe kỹ một nơi.');
    en.write('Say "details number ${from + 1}" for more about one place.');
  }
  if (from == 0) vi.write(' Giá chỉ để tham khảo.');
  return (vi.toString().trim(), en.toString().trim());
}

/// Hỏi tiếp danh sách vừa đọc: ('more', 0) | ('detail', chỉ số 0..). null nếu không phải.
(String, int)? placeFollowUp(String raw) {
  final t = normVi(raw);
  if (RegExp(r'^(con nua|con nua khong|con nua di|tiep|tiep di|nghe tiep|them nua|con gi nua|con quan nao|con quan nao nua|'
          r'con cho nao|con cho nao nua|con noi nao|con khach san nao|more|next)( khong| nhi| nhe| a)?$')
      .hasMatch(t)) {
    return ('more', 0);
  }
  // chỉ câu BẮT ĐẦU bằng "chi tiết số 2", "quán số 2", "số 2 ở đâu" — không bắt "thời tiết thứ hai"
  final m = RegExp(r'^(chi tiet|ke ve|noi ve|them ve|nghe ve|cho xem)?\s*(?:(?:quan|noi|cho|khach san|cai|dia diem)\s+)?'
          r'(?:so|thu|number)\s+(\d+|mot|nhat|hai|ba|bon|tu|nam)\b')
      .firstMatch(t);
  if (m != null) {
    final w = m.group(2)!;
    final n = int.tryParse(w) ?? (w == 'nhat' ? 1 : _numWords[w] ?? 0);
    if (n >= 1) return ('detail', n - 1);
  }
  return null;
}
