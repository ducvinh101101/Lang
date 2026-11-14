// BẢN ĐỒ THẾ GIỚI cho quả địa cầu: biên giới các nước (Natural Earth 1:50m, giản lược — tool/mkworld.py),
// tên tiếng Việt, tìm nước theo toạ độ / theo tên nói.
// Chủ quyền Việt Nam: quần đảo HOÀNG SA và TRƯỜNG SA được vẽ và đọc là của Việt Nam; bản đồ KHÔNG có "đường chín đoạn"
// và không gán đảo nào ở Biển Đông cho nước khác. Vùng biển giữa Việt Nam và Philippines gọi là "Biển Đông".
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../voice/commands.dart' show normVi;

class Country {
  final String a3, vi, en;
  final double lx, ly; // điểm đặt tên (kinh độ, vĩ độ)
  final int rank; // 1 = nước lớn (hiện tên sớm)
  final List<Float32List> rings; // mỗi vòng: lon,lat,lon,lat…
  final List<(double, double, double, double)> boxes; // bbox mỗi vòng (w, s, e, n)
  final double cx, cy, cz, radius; // tâm hình cầu (vectơ đơn vị) và bán kính góc để culling cực nhanh
  Country(this.a3, this.vi, this.en, this.lx, this.ly, this.rank, this.rings, this.boxes,
      [this.cx = 0.0, this.cy = 0.0, this.cz = 1.0, this.radius = math.pi]);

  /// Độ rộng lớn nhất (độ) — để chọn mức phóng to vừa khung.
  double get extent {
    var w = 180.0, s = 90.0, e = -180.0, n = -90.0;
    // vòng lớn nhất quyết định (bỏ đảo xa như Alaska/Hawaii kéo khung quá rộng)
    var best = 0.0;
    for (final b in boxes) {
      final area = (b.$3 - b.$1) * (b.$4 - b.$2);
      if (area > best) {
        best = area;
        (w, s, e, n) = b;
      }
    }
    return math.max(e - w, n - s);
  }

  bool contains(double lon, double lat) {
    for (var k = 0; k < rings.length; k++) {
      final b = boxes[k];
      if (lon < b.$1 || lon > b.$3 || lat < b.$2 || lat > b.$4) continue;
      if (_inRing(rings[k], lon, lat)) return true;
    }
    return false;
  }
}

bool _inRing(Float32List r, double x, double y) {
  var inside = false;
  final n = r.length ~/ 2;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = r[i * 2], yi = r[i * 2 + 1], xj = r[j * 2], yj = r[j * 2 + 1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

/// Một đảo / điểm có tên (Hoàng Sa, Trường Sa của Việt Nam).
class Isle {
  final String vi, en;
  final double lon, lat;
  const Isle(this.vi, this.en, this.lon, this.lat);
}

/// Quần đảo Hoàng Sa (Đà Nẵng, Việt Nam) — vị trí thật của các đảo chính.
const hoangSa = <Isle>[
  Isle('đảo Hoàng Sa', 'Hoang Sa Island', 111.61, 16.53),
  Isle('đảo Phú Lâm', 'Phu Lam Island', 112.33, 16.83),
  Isle('đảo Cây', 'Cay Island', 112.26, 16.98),
  Isle('đảo Linh Côn', 'Linh Con Island', 112.73, 16.67),
  Isle('đảo Quang Hòa', 'Quang Hoa Island', 111.71, 16.45),
  Isle('đảo Duy Mộng', 'Duy Mong Island', 111.75, 16.46),
  Isle('đảo Tri Tôn', 'Tri Ton Island', 111.20, 15.78),
  Isle('đảo Bạch Quy', 'Bach Quy Island', 111.29, 16.05),
  Isle('đảo Đá Bắc', 'Da Bac Island', 111.50, 17.10),
];

/// Quần đảo Trường Sa (Khánh Hòa, Việt Nam).
const truongSa = <Isle>[
  Isle('đảo Trường Sa', 'Truong Sa Island', 111.92, 8.65),
  Isle('đảo Song Tử Tây', 'Song Tu Tay Island', 114.33, 11.43),
  Isle('đảo Song Tử Đông', 'Song Tu Dong Island', 114.41, 11.45),
  Isle('đảo Sơn Ca', 'Son Ca Island', 114.48, 10.38),
  Isle('đảo Ba Bình', 'Ba Binh Island', 114.36, 10.38),
  Isle('đảo Nam Yết', 'Nam Yet Island', 114.37, 10.18),
  Isle('đảo Sinh Tồn', 'Sinh Ton Island', 114.33, 9.88),
  Isle('đảo Thị Tứ', 'Thi Tu Island', 114.28, 11.05),
  Isle('đảo Loại Ta', 'Loai Ta Island', 114.53, 10.68),
  Isle('đảo An Bang', 'An Bang Island', 112.92, 7.87),
  Isle('đảo Phan Vinh', 'Phan Vinh Island', 113.70, 8.97),
  Isle('đảo Sinh Tồn Đông', 'Sinh Ton Dong Island', 114.57, 9.92),
  Isle('đảo Đá Tây', 'Da Tay Island', 112.25, 8.85),
  Isle('đảo Thuyền Chài', 'Thuyen Chai Island', 113.30, 8.17),
  Isle('đảo Vành Khăn', 'Vanh Khan Island', 115.53, 9.90),
];

/// (w, s, e, n) của hai quần đảo — đọc tên khi điểm nằm trong vùng này.
const hoangSaBox = (110.9, 15.6, 113.0, 17.3);
const truongSaBox = (111.3, 7.3, 116.2, 11.8);

bool _inBox((double, double, double, double) b, double lon, double lat) =>
    lon >= b.$1 && lon <= b.$3 && lat >= b.$2 && lat <= b.$4;

/// Tên gọi khác (đã bỏ dấu) → mã nước. Dùng khi người dùng nói tên ngắn.
const countryAliases = <String, String>{
  'my': 'USA', 'hoa ky': 'USA', 'nuoc my': 'USA', 'usa': 'USA', 'america': 'USA',
  'anh': 'GBR', 'nuoc anh': 'GBR', 'vuong quoc anh': 'GBR', 'england': 'GBR', 'uk': 'GBR',
  'nhat': 'JPN', 'nhat ban': 'JPN', 'han': 'KOR', 'han quoc': 'KOR', 'trieu tien': 'PRK', 'bac trieu tien': 'PRK',
  'trung quoc': 'CHN', 'tau': 'CHN', 'uc': 'AUS', 'nuoc uc': 'AUS', 'nga': 'RUS', 'phap': 'FRA', 'duc': 'DEU', 'y': 'ITA',
  'tay ban nha': 'ESP', 'bo dao nha': 'PRT', 'ha lan': 'NLD', 'bi': 'BEL', 'thuy si': 'CHE', 'thuy dien': 'SWE',
  'na uy': 'NOR', 'dan mach': 'DNK', 'phan lan': 'FIN', 'ba lan': 'POL', 'sec': 'CZE', 'ao': 'AUT', 'hy lap': 'GRC',
  'tho nhi ky': 'TUR', 'ai cap': 'EGY', 'nam phi': 'ZAF', 'an do': 'IND', 'thai lan': 'THA', 'thai': 'THA', 'lao': 'LAO',
  'campuchia': 'KHM', 'cam pu chia': 'KHM', 'mien dien': 'MMR', 'myanmar': 'MMR', 'ma lai': 'MYS', 'malaysia': 'MYS',
  'xin ga po': 'SGP', 'singapore': 'SGP', 'in do': 'IDN', 'indonesia': 'IDN', 'in do ne xi a': 'IDN',
  'phi lip pin': 'PHL', 'philippines': 'PHL', 'phi': 'PHL', 'dai loan': 'TWN', 'mong co': 'MNG', 'ca na da': 'CAN',
  'canada': 'CAN', 'me hi co': 'MEX', 'mexico': 'MEX', 'bra xin': 'BRA', 'brazil': 'BRA', 'brasil': 'BRA',
  'ac hen ti na': 'ARG', 'argentina': 'ARG', 'chi le': 'CHL', 'pe ru': 'PER', 'cu ba': 'CUB', 'a rap xe ut': 'SAU',
  'iran': 'IRN', 'i ran': 'IRN', 'irac': 'IRQ', 'i rac': 'IRQ', 'is ra en': 'ISR', 'israel': 'ISR', 'pa ki xtan': 'PAK',
  'pakistan': 'PAK', 'bang la det': 'BGD', 'ne pan': 'NPL', 'nepal': 'NPL', 'sri lan ca': 'LKA', 'niu di lan': 'NZL',
  'new zealand': 'NZL', 'ken ni a': 'KEN', 'kenya': 'KEN', 'ni gie ri a': 'NGA', 'nigeria': 'NGA', 'ma roc': 'MAR',
  'u crai na': 'UKR', 'ukraina': 'UKR', 'ukraine': 'UKR', 'nam cuc': 'ATA', 'chau nam cuc': 'ATA', 'greenland': 'GRL',
  'dao greenland': 'GRL', 'viet nam': 'VNM', 'vietnam': 'VNM', 'nuoc ta': 'VNM', 'que huong': 'VNM',
};

/// Tên thành phố nói theo kiểu Việt → tên tra cứu được.
const cityAliases = <String, String>{
  'bac kinh': 'Beijing', 'thuong hai': 'Shanghai', 'quang chau': 'Guangzhou', 'tham quyen': 'Shenzhen',
  'hong kong': 'Hong Kong', 'huong cang': 'Hong Kong', 'dai bac': 'Taipei', 'to ky o': 'Tokyo', 'tokyo': 'Tokyo',
  'tokio': 'Tokyo', 'o sa ka': 'Osaka', 'xo un': 'Seoul', 'seoul': 'Seoul', 'binh nhuong': 'Pyongyang',
  'bang coc': 'Bangkok', 'bangkok': 'Bangkok', 'viang chan': 'Vientiane', 'vien chan': 'Vientiane',
  'phnom penh': 'Phnom Penh', 'nom penh': 'Phnom Penh', 'pnom penh': 'Phnom Penh', 'xiem riep': 'Siem Reap',
  'gia cac ta': 'Jakarta', 'jakarta': 'Jakarta', 'cua la lam pua': 'Kuala Lumpur', 'kuala lumpur': 'Kuala Lumpur',
  'ma ni la': 'Manila', 'manila': 'Manila', 'niu oc': 'New York', 'nu u oc': 'New York', 'new york': 'New York',
  'oa sinh ton': 'Washington', 'washington': 'Washington', 'los angeles': 'Los Angeles', 'lot an gio let': 'Los Angeles',
  'san phan xi xco': 'San Francisco', 'cu u': 'San Francisco', 'luan don': 'London', 'london': 'London', 'pa ri': 'Paris',
  'paris': 'Paris', 'ba le': 'Paris', 'bec lin': 'Berlin', 'berlin': 'Berlin', 'mat xco va': 'Moscow', 'mac xco va': 'Moscow',
  'moscow': 'Moscow', 'rom': 'Rome', 'ro ma': 'Rome', 'rome': 'Rome', 'ma drit': 'Madrid', 'madrid': 'Madrid', 'xit ni': 'Sydney',
  'sydney': 'Sydney', 'men bon': 'Melbourne', 'melbourne': 'Melbourne', 'niu de li': 'New Delhi', 'new delhi': 'New Delhi',
  'mum bai': 'Mumbai', 'du bai': 'Dubai', 'dubai': 'Dubai', 'cai ro': 'Cairo', 'cairo': 'Cairo', 'rio': 'Rio de Janeiro',
  'ri o de gia nei ro': 'Rio de Janeiro', 'xing ga po': 'Singapore', 'to ron to': 'Toronto', 'van cu vo': 'Vancouver',
  'pra ha': 'Prague', 'vien': 'Vienna', 'a ten': 'Athens', 'is tan bun': 'Istanbul', 'gio ne vo': 'Geneva',
};

class World {
  final List<Country> countries;
  World(this.countries);

  static World? _cached;
  static Future<World> load() async {
    final c = _cached;
    if (c != null) return c;
    final raw = await rootBundle.loadString('assets/world/countries.json');
    // giải mã ~300 KB bản đồ ở luồng phụ (bản máy tính / điện thoại) → không giật lúc mở app
    final w = await compute(_parse, raw);
    _cached = w;
    return w;
  }

  static World _parse(String raw) {
    final list = jsonDecode(raw) as List;
    final out = <Country>[];
    for (final e in list) {
      final m = e as Map;
      final rings = <Float32List>[];
      final boxes = <(double, double, double, double)>[];
      for (final r in m['r'] as List) {
        final v = r as List;
        final f = Float32List(v.length);
        var w = 999.0, s = 999.0, ea = -999.0, n = -999.0;
        for (var k = 0; k < v.length; k += 2) {
          final x = (v[k] as num) / 100, y = (v[k + 1] as num) / 100;
          f[k] = x;
          f[k + 1] = y;
          w = math.min(w, x);
          ea = math.max(ea, x);
          s = math.min(s, y);
          n = math.max(n, y);
        }
        rings.add(f);
        boxes.add((w, s, ea, n));
      }
      final cu = _calcCull(rings);
      out.add(Country(
        '${m['a']}',
        '${m['vi']}',
        '${m['en']}',
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
        (m['k'] as num?)?.toInt() ?? 5,
        rings,
        boxes,
        cu.$1,
        cu.$2,
        cu.$3,
        cu.$4,
      ));
    }
    return World(out);
  }

  static (double, double, double, double) _calcCull(List<Float32List> rings) {
    double sx = 0, sy = 0, sz = 0;
    var cnt = 0;
    for (final r in rings) {
      for (var i = 0; i + 1 < r.length; i += 2) {
        final p = r[i + 1] * math.pi / 180, l = r[i] * math.pi / 180;
        sx += math.cos(p) * math.cos(l);
        sy += math.cos(p) * math.sin(l);
        sz += math.sin(p);
        cnt++;
      }
    }
    final norm = math.sqrt(sx * sx + sy * sy + sz * sz);
    if (cnt == 0 || norm < 1e-6) return (0.0, 0.0, 1.0, math.pi);
    final x = sx / norm, y = sy / norm, z = sz / norm;
    var rad = 0.0;
    for (final r in rings) {
      for (var i = 0; i + 1 < r.length; i += 2) {
        final p = r[i + 1] * math.pi / 180, l = r[i] * math.pi / 180;
        final d = math.acos((x * math.cos(p) * math.cos(l) + y * math.cos(p) * math.sin(l) + z * math.sin(p)).clamp(-1.0, 1.0));
        if (d > rad) rad = d;
      }
    }
    return (x, y, z, rad + 0.02);
  }

  Country? byCode(String a3) => countries.where((c) => c.a3 == a3).firstOrNull;
  Country? get vietnam => byCode('VNM');

  /// Nước chứa điểm (lon, lat), null nếu là biển.
  Country? countryAt(double lon, double lat) {
    for (final c in countries) {
      if (c.contains(lon, lat)) return c;
    }
    return null;
  }

  /// Tên nước theo câu nói (đã bỏ dấu): khớp đúng cả cụm.
  Country? findCountry(String text) {
    final t = normVi(text);
    if (t.isEmpty) return null;
    final code = countryAliases[t];
    if (code != null) return byCode(code);
    for (final c in countries) {
      if (normVi(c.vi) == t || normVi(c.en) == t) return c;
    }
    return null;
  }

  /// Tên nơi để đọc khi đứng ở (lon, lat): nước, hoặc biển / đại dương. Hoàng Sa, Trường Sa: "của Việt Nam".
  (String, String) placeName(double lon, double lat) {
    if (_inBox(hoangSaBox, lon, lat)) {
      return ('quần đảo Hoàng Sa, Việt Nam', 'the Hoang Sa (Paracel) Islands, Viet Nam');
    }
    if (_inBox(truongSaBox, lon, lat)) {
      return ('quần đảo Trường Sa, Việt Nam', 'the Truong Sa (Spratly) Islands, Viet Nam');
    }
    final c = countryAt(lon, lat);
    if (c != null) return (c.vi, c.en);
    return seaName(lon, lat);
  }

  static (String, String) seaName(double lon, double lat) {
    if (lon >= 105 && lon <= 121 && lat >= 0 && lat <= 23) return ('Biển Đông', 'the East Sea');
    if (lon >= 99 && lon < 105 && lat >= 6 && lat <= 14) return ('Vịnh Thái Lan', 'the Gulf of Thailand');
    if (lon >= 105.5 && lon <= 109.5 && lat >= 17 && lat <= 22) return ('Vịnh Bắc Bộ', 'the Gulf of Tonkin');
    if (lon >= -6 && lon <= 36 && lat >= 30 && lat <= 46) return ('Địa Trung Hải', 'the Mediterranean Sea');
    if (lon >= 27 && lon <= 42 && lat >= 40 && lat <= 47) return ('Biển Đen', 'the Black Sea');
    if (lon >= 32 && lon <= 44 && lat >= 12 && lat < 30) return ('Biển Đỏ', 'the Red Sea');
    if (lon >= -98 && lon <= -80 && lat >= 18 && lat <= 31) return ('Vịnh Mexico', 'the Gulf of Mexico');
    if (lon >= -88 && lon <= -60 && lat >= 9 && lat < 18) return ('Biển Caribe', 'the Caribbean Sea');
    if (lat >= 66) return ('Bắc Băng Dương', 'the Arctic Ocean');
    if (lat <= -60) return ('Nam Đại Dương', 'the Southern Ocean');
    if (lon >= 20 && lon < 100 && lat < 30) return ('Ấn Độ Dương', 'the Indian Ocean');
    if (lon >= 100 && lon < 147 && lat < -10) return ('Ấn Độ Dương', 'the Indian Ocean');
    if ((lon >= -70 && lon < 20) || (lon >= -100 && lon < -70 && lat > 8)) return ('Đại Tây Dương', 'the Atlantic Ocean');
    return ('Thái Bình Dương', 'the Pacific Ocean');
  }
}
