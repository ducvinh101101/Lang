// ĐƠN VỊ HÀNH CHÍNH VIỆT NAM (từ 1/7/2025: 34 tỉnh, thành; bỏ cấp huyện; xã, phường mới sau sáp nhập).
// Dùng để hiểu câu như "thời tiết xã Tân Lập, Tây Ninh", "phường Hải Châu Đà Nẵng", "xã Mường Hoa tỉnh Yên Bái"
// (tên tỉnh CŨ vẫn hiểu, đổi sang tỉnh mới để lọc kết quả tìm kiếm).

/// Bỏ dấu, viết thường, chỉ giữ chữ / số.
String foldVi(String s) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// 34 tỉnh, thành hiện nay (tên đọc).
const provincesNow = [
  'Hà Nội', 'Huế', 'Lai Châu', 'Điện Biên', 'Sơn La', 'Lạng Sơn', 'Quảng Ninh', 'Thanh Hóa', 'Nghệ An', 'Hà Tĩnh', 'Cao Bằng',
  'Tuyên Quang', 'Lào Cai', 'Thái Nguyên', 'Phú Thọ', 'Bắc Ninh', 'Hưng Yên', 'Hải Phòng', 'Ninh Bình', 'Quảng Trị', 'Đà Nẵng',
  'Quảng Ngãi', 'Gia Lai', 'Khánh Hòa', 'Lâm Đồng', 'Đắk Lắk', 'Hồ Chí Minh', 'Đồng Nai', 'Tây Ninh', 'Cần Thơ', 'Vĩnh Long',
  'Đồng Tháp', 'Cà Mau', 'An Giang',
];

/// Tỉnh cũ (trước 1/7/2025) → tỉnh mới.
const provinceMerged = {
  'Hà Giang': 'Tuyên Quang', 'Yên Bái': 'Lào Cai', 'Bắc Kạn': 'Thái Nguyên', 'Vĩnh Phúc': 'Phú Thọ', 'Hòa Bình': 'Phú Thọ',
  'Bắc Giang': 'Bắc Ninh', 'Thái Bình': 'Hưng Yên', 'Hải Dương': 'Hải Phòng', 'Hà Nam': 'Ninh Bình', 'Nam Định': 'Ninh Bình',
  'Quảng Bình': 'Quảng Trị', 'Quảng Nam': 'Đà Nẵng', 'Kon Tum': 'Quảng Ngãi', 'Bình Định': 'Gia Lai', 'Ninh Thuận': 'Khánh Hòa',
  'Đắk Nông': 'Lâm Đồng', 'Bình Thuận': 'Lâm Đồng', 'Phú Yên': 'Đắk Lắk', 'Bình Phước': 'Đồng Nai', 'Bình Dương': 'Hồ Chí Minh',
  'Bà Rịa Vũng Tàu': 'Hồ Chí Minh', 'Long An': 'Tây Ninh', 'Sóc Trăng': 'Cần Thơ', 'Hậu Giang': 'Cần Thơ', 'Bến Tre': 'Vĩnh Long',
  'Trà Vinh': 'Vĩnh Long', 'Tiền Giang': 'Đồng Tháp', 'Bạc Liêu': 'Cà Mau', 'Kiên Giang': 'An Giang', 'Thừa Thiên Huế': 'Huế',
  'Sài Gòn': 'Hồ Chí Minh', 'TP HCM': 'Hồ Chí Minh', 'Thành phố Hồ Chí Minh': 'Hồ Chí Minh',
};

/// Tiền tố đơn vị hành chính đứng trước tên ("xã", "phường"…), đã bỏ dấu.
const adminPrefixes = ['thi tran', 'thi xa', 'dac khu', 'xa', 'phuong', 'huyen', 'quan', 'thon', 'lang', 'ban', 'ap', 'khom', 'to dan pho'];

/// Tách tên tỉnh ở CUỐI cụm địa danh: "xã Tân Lập, tỉnh Tây Ninh" → (place: "xã Tân Lập", province: "Tây Ninh").
/// Tỉnh cũ đổi sang tỉnh mới (province) và giữ tên cũ (oldProvince). Không có tỉnh → province null.
({String place, String? province, String? oldProvince}) splitProvince(String text) {
  final words = text.trim().replaceAll(RegExp(r'[,.;]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final fw = [for (final w in words) foldVi(w)];
  final names = <String, (String, String?)>{
    for (final p in provincesNow) foldVi(p): (p, null),
    for (final e in provinceMerged.entries) foldVi(e.key): (e.value, e.key),
  };
  // dài nhất trước ("ba ria vung tau" trước "vung tau")
  final keys = names.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    final kw = k.split(' ');
    if (fw.length <= kw.length) continue; // phải còn tên xã / phường phía trước
    if (fw.sublist(fw.length - kw.length).join(' ') != k) continue;
    var cut = words.length - kw.length;
    // bỏ "tỉnh", "thành phố", "tp", "ở", "thuộc", "tại" đứng ngay trước tên tỉnh — so CẢ DẤU: "xã Vĩnh Thanh, Hà Nội",
    // "huyện Lương Tài, Bắc Ninh", "xã Tân Thạnh, Cần Thơ" thì "Thanh", "Tài", "Thạnh" là một phần tên xã
    String lw(int k) => words[k].toLowerCase().replaceAll(RegExp(r'[,.;]'), '');
    while (cut > 1) {
      final w = lw(cut - 1);
      if (const {'tỉnh', 'tp', 'tp.', 'ở', 'thuộc', 'tại'}.contains(w)) {
        cut--;
      } else if (w == 'phố' && cut > 2 && lw(cut - 2) == 'thành') {
        cut -= 2;
      } else {
        break;
      }
    }
    final (p, old) = names[k]!;
    return (place: words.sublist(0, cut).join(' '), province: p, oldProvince: old);
  }
  return (place: text.trim(), province: null, oldProvince: null);
}

/// Bỏ tiền tố hành chính: "xã Tân Lập" → "Tân Lập".
String stripAdminPrefix(String s) {
  final words = s.trim().split(RegExp(r'\s+'));
  final fw = [for (final w in words) foldVi(w)];
  for (final p in adminPrefixes) {
    final pw = p.split(' ');
    if (fw.length > pw.length && fw.take(pw.length).join(' ') == p) return words.sublist(pw.length).join(' ');
  }
  return s.trim();
}

bool hasAdminPrefix(String s) => stripAdminPrefix(s) != s.trim();

/// Tên tỉnh trong kết quả tìm kiếm ("Tỉnh Tây Ninh", "Thành phố Hồ Chí Minh") có phải tỉnh [province] không.
bool sameProvince(String state, String province) {
  final a = foldVi(state).replaceFirst(RegExp(r'^(tinh|thanh pho) '), '');
  final b = foldVi(province);
  return a == b || a.endsWith(b) || b.endsWith(a);
}
