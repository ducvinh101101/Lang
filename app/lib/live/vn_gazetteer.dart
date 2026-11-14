// DANH BẠ ĐƠN VỊ HÀNH CHÍNH VIỆT NAM, CHẠY OFFLINE: 34 tỉnh, thành và đủ 3.321 xã, phường, đặc khu sau sáp nhập
// (từ 1/7/2025), mỗi nơi có toạ độ trụ sở UBND; kèm 10.035 xã, phường, thị trấn CŨ và 691 huyện, quận, thị xã CŨ để
// hiểu cả tên cũ ("xã Đặng Xá", "huyện Gia Lâm") → nơi mới tương ứng.
// Nguồn: atlas34 (MIT) ← thanglequoc/vietnamese-provinces-database v5.2.0 + vietnamadminunits 1.0.4 — xem
// assets/data/NGUON-DVHC.txt. Dùng thay cho tìm trên bản đồ mở (bản đồ mở chưa có đủ xã mới, hay trả về quán, cửa hàng).
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'vn_admin.dart';

/// Một nơi tìm được.
class VnHit {
  /// Tên để đọc: "xã Gia Lâm, Hà Nội" · "xã Đặng Xá cũ, nay thuộc xã Gia Lâm, Hà Nội" · "huyện Gia Lâm cũ, Hà Nội".
  final String label;

  /// Tên ngắn (không tiền tố, không tỉnh): "Gia Lâm".
  final String short;
  final String province; // tỉnh, thành HIỆN NAY
  final double lat, lon;

  /// 'ward' (xã, phường hiện nay) | 'oldWard' (xã, phường, thị trấn cũ) | 'oldDistrict' (huyện, quận, thị xã cũ)
  /// | 'province' (tỉnh, thành hiện nay) | 'oldProvince' (tỉnh cũ trước 1/7/2025, vd "Đắk Nông" → Lâm Đồng)
  final String kind;
  const VnHit(this.label, this.short, this.province, this.lat, this.lon, this.kind);
  bool get current => kind == 'ward' || kind == 'province';

  /// Độ phóng hợp với cỡ nơi đó (tỉnh > huyện cũ > xã).
  double get zoom => switch (kind) { 'province' => 9, 'oldProvince' => 12, 'oldDistrict' => 22, _ => 32 };
  @override
  String toString() => '$label ($lat, $lon)';
}

class VnGazetteer {
  final List<(String code, String name, String en, double lat, double lon)> provinces;
  final List<(String code, String type, String name, int p, double lat, double lon)> wards;
  final List<(String name, String province)> districts; // huyện cũ: (tên đủ "Huyện Gia Lâm", tỉnh cũ)
  final List<(String name, int d, String code)> olds; // xã cũ: (tên đủ, chỉ số huyện cũ, mã xã mới)

  final _byName = <String, List<int>>{}; // tên xã mới (bỏ dấu) → chỉ số
  final _byPart = <String, List<int>>{}; // một vế của tên ghép "Lâm Viên - Đà Lạt"
  final _byCode = <String, int>{};
  final _oldByName = <String, List<int>>{};
  final _distByName = <String, List<int>>{};
  final _distWards = <int, Set<int>>{}; // huyện cũ → các xã mới
  final _exact = <String>{}; // mọi tên (viết thường, CÓ dấu)

  VnGazetteer.fromJson(Map<String, dynamic> j)
      : provinces = [
          for (final p in j['p'] as List) ('${p[0]}', '${p[1]}', '${p[2]}', (p[3] as num).toDouble(), (p[4] as num).toDouble())
        ],
        wards = [
          for (final w in j['w'] as List)
            ('${w[0]}', '${w[1]}', '${w[2]}', (w[3] as num).toInt(), (w[4] as num).toDouble(), (w[5] as num).toDouble())
        ],
        districts = [for (final d in j['d'] as List) ('${d[0]}', '${d[1]}')],
        olds = [for (final o in j['o'] as List) ('${o[0]}', (o[1] as num).toInt(), '${o[2]}')] {
    for (var i = 0; i < wards.length; i++) {
      final w = wards[i];
      _byCode[w.$1] = i;
      (_byName[foldVi(w.$3)] ??= []).add(i);
      _exact.add(exact(w.$3));
      if (w.$3.contains(' - ')) {
        for (final part in w.$3.split(' - ')) {
          (_byPart[foldVi(part)] ??= []).add(i);
          _exact.add(exact(part));
        }
      }
    }
    for (var i = 0; i < olds.length; i++) {
      (_oldByName[foldVi(_strip(olds[i].$1))] ??= []).add(i);
      _exact.add(exact(_strip(olds[i].$1)));
      final wi = _byCode[olds[i].$3];
      if (wi != null) (_distWards[olds[i].$2] ??= {}).add(wi);
    }
    for (var i = 0; i < districts.length; i++) {
      (_distByName[foldVi(_strip(districts[i].$1))] ??= []).add(i);
      _exact.add(exact(_strip(districts[i].$1)));
      (_oldProvDistricts[foldVi(_strip(districts[i].$2))] ??= []).add(i);
    }
    for (var i = 0; i < provinces.length; i++) {
      _provByName[foldVi(provinces[i].$2)] = i;
    }
    // tên gọi khác của tỉnh cũ ("Sài Gòn", "Bà Rịa Vũng Tàu", "Thừa Thiên Huế") → tỉnh cũ trong dữ liệu
    final oldKeys = _oldProvDistricts.keys.toList();
    for (final e in provinceMerged.entries) {
      final k = foldVi(e.key);
      if (_oldProvDistricts.containsKey(k) || _provByName.containsKey(k)) continue;
      final target = foldVi(e.value);
      final ok = oldKeys.where((o) => o != target && (o.contains(k) || k.contains(o))).firstOrNull;
      if (ok != null) {
        _oldProvDistricts[k] = _oldProvDistricts[ok]!;
      } else if (_provByName.containsKey(target)) {
        _provAlias[k] = _provByName[target]!;
      }
    }
    final hcm = _provByName['ho chi minh'];
    if (hcm != null) {
      for (final a in const ['hcm', 'sai gon', 'tphcm', 'tp hcm', 'thanh pho ho chi minh']) {
        _provAlias[a] = hcm;
      }
    }
  }

  final _provByName = <String, int>{}; // tỉnh, thành hiện nay (bỏ dấu) → chỉ số
  final _provAlias = <String, int>{}; // "sai gon", "tp hcm" → tỉnh hiện nay
  final _oldProvDistricts = <String, List<int>>{}; // tỉnh cũ (bỏ dấu) → các huyện cũ của tỉnh đó

  static const _cities = {'Hà Nội', 'Huế', 'Hải Phòng', 'Đà Nẵng', 'Hồ Chí Minh', 'Cần Thơ'};

  /// Toạ độ TRUNG TÂM HÀNH CHÍNH (tỉnh lỵ) — hỏi thời tiết "Lâm Đồng" là hỏi Đà Lạt, "Thành phố Hồ Chí Minh" là trung tâm
  /// thành phố, không phải tâm hình học của cả tỉnh sau sáp nhập (tâm TP.HCM mới rơi vào Bình Dương cũ).
  /// Khoá: tên đã bỏ dấu. Gồm 34 tỉnh, thành hiện nay và 29 tỉnh cũ đã sáp nhập.
  static const _capitals = <String, (double, double)>{
    'ha noi': (21.0285, 105.8542), 'hue': (16.4637, 107.5909), 'lai chau': (22.3964, 103.4582),
    'dien bien': (21.3860, 103.0230), 'son la': (21.3256, 103.9188), 'lang son': (21.8537, 106.7615),
    'quang ninh': (20.9599, 107.0425), 'thanh hoa': (19.8067, 105.7852), 'nghe an': (18.6796, 105.6813),
    'ha tinh': (18.3428, 105.9057), 'cao bang': (22.6657, 106.2577), 'tuyen quang': (21.8236, 105.2140),
    'lao cai': (21.7229, 104.9113), 'thai nguyen': (21.5942, 105.8482), 'phu tho': (21.3227, 105.4019),
    'bac ninh': (21.2731, 106.1946), 'hung yen': (20.6464, 106.0511), 'hai phong': (20.8449, 106.6881),
    'ninh binh': (20.2506, 105.9745), 'quang tri': (17.4689, 106.6223), 'da nang': (16.0544, 108.2022),
    'quang ngai': (15.1214, 108.8044), 'gia lai': (13.7820, 109.2197), 'khanh hoa': (12.2388, 109.1967),
    'lam dong': (11.9404, 108.4583), 'dak lak': (12.6667, 108.0500), 'ho chi minh': (10.7769, 106.7009),
    'dong nai': (10.9574, 106.8427), 'tay ninh': (10.5359, 106.4137), 'can tho': (10.0452, 105.7469),
    'vinh long': (10.2537, 105.9722), 'dong thap': (10.3600, 106.3600), 'ca mau': (9.1769, 105.1500),
    'an giang': (10.0125, 105.0809),
    // tỉnh cũ: tỉnh lỵ cũ
    'ha giang': (22.8233, 104.9836), 'yen bai': (21.7229, 104.9113), 'bac kan': (22.1470, 105.8348),
    'vinh phuc': (21.3089, 105.6049), 'hoa binh': (20.8171, 105.3376), 'bac giang': (21.2731, 106.1946),
    'thai binh': (20.4463, 106.3366), 'hai duong': (20.9373, 106.3146), 'ha nam': (20.5411, 105.9139),
    'nam dinh': (20.4388, 106.1621), 'quang binh': (17.4689, 106.6223), 'quang nam': (15.5736, 108.4740),
    'kon tum': (14.3497, 108.0005), 'binh dinh': (13.7820, 109.2197), 'ninh thuan': (11.5636, 108.9885),
    'dak nong': (12.0045, 107.6907), 'binh thuan': (10.9289, 108.1021), 'phu yen': (13.0882, 109.0929),
    'binh phuoc': (11.5349, 106.8832), 'binh duong': (10.9804, 106.6519), 'ba ria vung tau': (10.4963, 107.1684),
    'long an': (10.5359, 106.4137), 'soc trang': (9.6025, 105.9739), 'hau giang': (9.7845, 105.4701),
    'ben tre': (10.2434, 106.3756), 'tra vinh': (9.9347, 106.3455), 'tien giang': (10.3600, 106.3600),
    'bac lieu': (9.2941, 105.7278), 'kien giang': (10.0125, 105.0809),
  };

  /// Tên đọc của một tỉnh, thành hiện nay: "tỉnh Lâm Đồng", "thành phố Huế".
  static String provinceLabel(String name) => '${_cities.contains(name) ? 'thành phố' : 'tỉnh'} $name';

  /// Cả câu chỉ là tên MỘT tỉnh, thành (mới hoặc cũ): "Đắk Nông", "tỉnh Hà Giang", "Sài Gòn", "thành phố Huế".
  VnHit? provinceHit(String text) {
    // KHÔNG bỏ tiền tố "làng", "bản"… ở đây: "Lạng Sơn" bỏ dấu là "lang son" (không phải "làng Sơn")
    final key = foldVi(text.trim().replaceFirst(RegExp(r'^(thành phố|tp\.?|tỉnh)\s+', caseSensitive: false), ''));
    if (key.isEmpty) return null;
    final pi = _provByName[key] ?? _provAlias[key];
    if (pi != null) {
      final p = provinces[pi];
      final cap = _capitals[foldVi(p.$2)];
      return VnHit(provinceLabel(p.$2), p.$2, p.$2, cap?.$1 ?? p.$4, cap?.$2 ?? p.$5, 'province');
    }
    final ds = _oldProvDistricts[key];
    if (ds == null) return null;
    final ws = <int>{for (final d in ds) ...?_distWards[d]};
    if (ws.isEmpty) return null;
    final cnt = <int, int>{};
    var la = 0.0, lo = 0.0;
    for (final wi in ws) {
      cnt[wards[wi].$4] = (cnt[wards[wi].$4] ?? 0) + 1;
      la += wards[wi].$5;
      lo += wards[wi].$6;
    }
    la /= ws.length;
    lo /= ws.length;
    // trụ sở xã gần giữa tỉnh cũ nhất (chắc chắn nằm trong tỉnh)
    final c = ws.reduce((a, b) => _d2(wards[a].$5, wards[a].$6, la, lo) <= _d2(wards[b].$5, wards[b].$6, la, lo) ? a : b);
    final pn = provinces[cnt.entries.reduce((a, b) => a.value >= b.value ? a : b).key].$2;
    final oldName = _strip(districts[ds.first].$2);
    final cap = _capitals[foldVi(oldName)];
    return VnHit('tỉnh $oldName cũ, nay thuộc ${provinceLabel(pn)}', oldName, pn, cap?.$1 ?? wards[c].$5, cap?.$2 ?? wards[c].$6,
        'oldProvince');
  }

  static VnGazetteer? _cache;
  static Future<VnGazetteer?>? _loading;

  /// Nạp từ assets (một lần). Lỗi → null (app vẫn chạy, chỉ tìm xã bằng bản đồ mở).
  static Future<VnGazetteer?> load() {
    if (_cache != null) return Future.value(_cache);
    return _loading ??= () async {
      try {
        final s = await rootBundle.loadString('assets/data/vn_dvhc.json');
        _cache = VnGazetteer.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        _cache = null;
        // bản web: trình duyệt có thể còn nhớ lỗi 404 của bản deploy cũ (chưa có tệp này) → tải lại, bỏ qua bộ nhớ đệm
        if (kIsWeb) {
          try {
            final r = await http
                .get(Uri.base.resolve('assets/assets/data/vn_dvhc.json?v=${DateTime.now().millisecondsSinceEpoch ~/ 3600000}'))
                .timeout(const Duration(seconds: 20));
            if (r.statusCode == 200) {
              _cache = VnGazetteer.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
            }
          } catch (_) {}
        }
      }
      _loading = null;
      return _cache;
    }();
  }

  /// Bỏ tiền tố hành chính kể cả "thành phố", "tỉnh": "Thành phố Bắc Ninh" → "Bắc Ninh".
  static String _strip(String s) =>
      stripAdminPrefix(s.trim()).replaceFirst(RegExp(r'^(thành phố|tp\.?|tỉnh)\s+', caseSensitive: false), '');

  /// Chuẩn hoá dấu kiểu cũ / mới ("Thuỷ" = "Thủy", "Hoá" = "Hóa"), viết thường — để so CẢ DẤU.
  static String exact(String s) {
    var t = s.toLowerCase().replaceAll(RegExp(r"[-–,.;'’]"), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
    const pairs = {
      'oà': 'òa', 'oá': 'óa', 'oả': 'ỏa', 'oã': 'õa', 'oạ': 'ọa', 'oè': 'òe', 'oé': 'óe', 'oẻ': 'ỏe', 'oẽ': 'õe', 'oẹ': 'ọe',
      'uỳ': 'ùy', 'uý': 'úy', 'uỷ': 'ủy', 'uỹ': 'ũy', 'uỵ': 'ụy',
    };
    pairs.forEach((a, b) => t = t.replaceAll(a, b));
    return t;
  }

  static String _lowerType(String t) => t.isEmpty ? t : t[0].toLowerCase() + t.substring(1);

  /// Loại đơn vị người dùng nói ở đầu tên: 'xa' | 'phuong' | 'dac khu' | 'thi tran' | 'huyen' | 'quan' | 'thi xa' | 'tp' | ''.
  static String prefixOf(String place) {
    final f = foldVi(place);
    for (final p in const ['thi tran', 'thi xa', 'dac khu', 'thanh pho', 'xa', 'phuong', 'huyen', 'quan', 'tp']) {
      if (f.startsWith('$p ')) return p == 'thanh pho' ? 'tp' : p;
    }
    return '';
  }

  int? _provinceIndex(String? province) {
    if (province == null) return null;
    for (var i = 0; i < provinces.length; i++) {
      if (sameProvince(provinces[i].$2, province)) return i;
    }
    return null;
  }

  VnHit _wardHit(int i) {
    final w = wards[i];
    final pn = provinces[w.$4].$2;
    return VnHit('${_lowerType(w.$2)} ${w.$3}, $pn', w.$3, pn, w.$5, w.$6, 'ward');
  }

  /// Tìm theo câu người dùng nói ("xã Tân Lập, Tây Ninh", "phường Hải Châu", "Gia Lâm", "huyện Gia Lâm",
  /// "xã Đặng Xá Hà Nội"). Kết quả: các nơi khớp (xã hiện nay trước, rồi tên cũ). Rỗng nếu không có.
  List<VnHit> find(String text) {
    // cả câu là tên một tỉnh (không nói "xã", "phường"…) → tỉnh đó, kể cả tỉnh cũ đã sáp nhập
    // ("thành phố Lào Cai" là thành phố cũ, KHÔNG phải cả tỉnh; "thành phố Huế", "thành phố Hà Nội" mới là cả thành phố)
    final pf = prefixOf(text);
    if (pf.isEmpty || pf == 'tp') {
      final ph = provinceHit(text);
      if (ph != null && (pf.isEmpty || (ph.kind == 'province' && _cities.contains(ph.short)))) return [ph];
    }
    final r = _find(text, true);
    if (r.isNotEmpty) return r;
    // "xã Nguyễn Huệ" (cuối tên trùng tỉnh "Huế"), "phường Long An": thử lại không tách tên tỉnh
    return _find(text, false);
  }

  List<VnHit> _find(String text, bool split) {
    var sp = split ? splitProvince(text) : (place: text.trim(), province: null, oldProvince: null);
    // "xã Long An", "phường Hà Giang": tên xã trùng tên tỉnh → không tách tỉnh ra (kẻo chỉ còn chữ "xã")
    final pf = foldVi(sp.place);
    if (pf.isEmpty || adminPrefixes.contains(pf) || pf == 'tinh' || pf == 'thanh pho' || pf == 'tp') {
      sp = (place: text.trim(), province: null, oldProvince: null);
    }
    var place = sp.place.trim();
    final prefix = prefixOf(place);
    final key = foldVi(_strip(place));
    if (key.isEmpty) return const [];
    final pi = _provinceIndex(sp.province);
    bool inProv(int p) => pi == null || p == pi;
    final oldProv = sp.oldProvince == null ? null : foldVi(sp.oldProvince!);
    final out = <VnHit>[];
    final seen = <String>{};
    void add(VnHit h) {
      final k = '${h.lat.toStringAsFixed(3)},${h.lon.toStringAsFixed(3)}';
      if (seen.add(k)) out.add(h);
    }

    void districtsHits() {
      for (final di in _distByName[key] ?? const <int>[]) {
        final d = districts[di];
        if (oldProv != null && !foldVi(d.$2).endsWith(oldProv)) continue;
        final dt = foldVi(d.$1);
        if (prefix == 'huyen' && !dt.startsWith('huyen ')) continue;
        if (prefix == 'quan' && !dt.startsWith('quan ')) continue;
        if (prefix == 'thi xa' && !dt.startsWith('thi xa ')) continue;
        if (prefix == 'tp' && !dt.startsWith('thanh pho ')) continue;
        final ws = _distWards[di];
        if (ws == null || ws.isEmpty) continue;
        // tỉnh mới: tỉnh của phần lớn các xã mới
        final cnt = <int, int>{};
        for (final wi in ws) {
          cnt[wards[wi].$4] = (cnt[wards[wi].$4] ?? 0) + 1;
        }
        final p = cnt.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        if (!inProv(p)) continue;
        // giữa vùng: trung bình toạ độ các xã mới (chọn trụ sở gần tâm nhất để chắc chắn nằm trong vùng)
        var la = 0.0, lo = 0.0;
        for (final wi in ws) {
          la += wards[wi].$5;
          lo += wards[wi].$6;
        }
        la /= ws.length;
        lo /= ws.length;
        final c = ws.reduce((a, b) =>
            _d2(wards[a].$5, wards[a].$6, la, lo) <= _d2(wards[b].$5, wards[b].$6, la, lo) ? a : b);
        final pn = provinces[p].$2;
        add(VnHit('${_lowerType(d.$1)} cũ, $pn', stripAdminPrefix(d.$1), pn, wards[c].$5, wards[c].$6, 'oldDistrict'));
      }
    }

    final districtFirst = const {'huyen', 'quan', 'thi xa', 'tp'}.contains(prefix);
    if (districtFirst) districtsHits();
    // 1) xã, phường, đặc khu hiện nay
    if (!const {'huyen', 'quan', 'thi xa', 'thi tran'}.contains(prefix)) {
      final want = switch (prefix) { 'xa' => 'Xã', 'phuong' => 'Phường', 'dac khu' => 'Đặc khu', _ => null };
      final exact = _byName[key] ?? const <int>[];
      for (final i in exact) {
        if (!inProv(wards[i].$4)) continue;
        if (want != null && wards[i].$2 != want) continue;
        add(_wardHit(i));
      }
      if (out.isEmpty) {
        for (final i in _byPart[key] ?? const <int>[]) {
          if (inProv(wards[i].$4) && (want == null || wards[i].$2 == want)) add(_wardHit(i));
        }
      }
    }
    // 2) xã, phường, thị trấn CŨ (đã sáp nhập) → nơi mới tương ứng
    if (!districtFirst || out.isEmpty) {
      for (final oi in _oldByName[key] ?? const <int>[]) {
        final o = olds[oi];
        final ot = foldVi(o.$1);
        if (prefix == 'xa' && !ot.startsWith('xa ')) continue;
        if (prefix == 'phuong' && !ot.startsWith('phuong ')) continue;
        if (prefix == 'thi tran' && !ot.startsWith('thi tran ')) continue;
        final wi = _byCode[o.$3];
        if (wi == null || !inProv(wards[wi].$4)) continue;
        if (oldProv != null && !foldVi(districts[o.$2].$2).endsWith(oldProv)) continue;
        final w = wards[wi];
        // tên cũ trùng tên mới (xã giữ tên) → đã có ở bước 1
        if (foldVi(w.$3) == key && out.any((h) => h.kind == 'ward' && h.lat == w.$5 && h.lon == w.$6)) continue;
        final pn = provinces[w.$4].$2;
        add(VnHit('${_lowerType(o.$1)} cũ, nay thuộc ${_lowerType(w.$2)} ${w.$3}, $pn', stripAdminPrefix(o.$1), pn, w.$5, w.$6,
            'oldWard'));
      }
    }
    // 3) không nói "huyện", "quận" mà tên trùng huyện cũ (vd "Gia Lâm" ngoài xã Gia Lâm) → thêm vào cuối
    if (!districtFirst) districtsHits();
    // tên khác nhau chỉ ở dấu ("Văn Lăng" / "Văn Lang", "Sơn Hạ" / "Sơn Hà"): nơi khớp CẢ DẤU lên trước
    final ex = exact(_strip(place));
    final exactFirst = [
      ...out.where((h) => exact(h.short) == ex),
      ...out.where((h) => exact(h.short) != ex),
    ];
    return exactFirst;
  }

  /// Xã, phường hiện nay có trụ sở GẦN điểm (lat, lon) nhất và khoảng cách (km) — để nói "bạn đang ở gần xã …".
  /// null nếu điểm ở xa Việt Nam (> 40 km tới trụ sở gần nhất).
  (VnHit, double)? nearest(double lat, double lon) {
    var best = -1;
    var bd = double.infinity;
    final k = math.cos(lat * math.pi / 180);
    for (var i = 0; i < wards.length; i++) {
      final dl = wards[i].$5 - lat, dn = (wards[i].$6 - lon) * k;
      final d = dl * dl + dn * dn;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    if (best < 0) return null;
    final km = math.sqrt(bd) * 111.2;
    if (km > 40) return null;
    return (_wardHit(best), km);
  }

  /// Có đơn vị (xã, phường mới / cũ, huyện cũ) mang tên này (đã bỏ dấu) không — cho bộ tách lệnh.
  bool knows(String folded) =>
      _byName.containsKey(folded) ||
      _oldByName.containsKey(folded) ||
      _distByName.containsKey(folded) ||
      _byPart.containsKey(folded);

  /// Như [knows] nhưng so CẢ DẤU ([exact]): "Láng Có" ≠ "Lăng Cô".
  bool knowsExact(String text) => _exact.contains(exact(text));

  static double _d2(double a, double b, double c, double d) => math.pow(a - c, 2).toDouble() + math.pow(b - d, 2).toDouble();

  /// Tên tỉnh hiện nay có xã / phường tên [name] (để báo "có nơi tên … ở …").
  List<String> provincesWith(String name) {
    final key = foldVi(stripAdminPrefix(name));
    return {
      for (final i in _byName[key] ?? const <int>[]) provinces[wards[i].$4].$2,
      for (final oi in _oldByName[key] ?? const <int>[])
        if (_byCode[olds[oi].$3] != null) provinces[wards[_byCode[olds[oi].$3]!].$4].$2,
    }.toList();
  }
}
