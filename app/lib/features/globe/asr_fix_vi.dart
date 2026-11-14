// SỬA LỖI NHẬN DẠNG NGỮ ÂM TIẾNG VIỆT (Vietnamese ASR Phonetic Correction).
// Khi người dùng phát âm vùng miền, micro ở xa hoặc mô hình ASR Zipformer nghe nhầm:
//   "phang xi pang" → "Phan Xi Păng", "vịnh hạ nòng" → "Vịnh Hạ Long",
//   "e vo ret" → "Everest", "nao cai" → "Lào Cai", "sao chim" → "Sao Kim"...
// Tự động chuẩn hóa trước khi chuyển câu vào bộ điều hướng lệnh hoặc AI Agent + RAG.
import '../voice/commands.dart' show normVi;

/// Bản đồ nắn chỉnh nhanh các cụm từ ASR hay nhận dạng sai (ngữ âm tương đồng).
const _phoneticReplacements = <String, String>{
  // Đỉnh núi & Địa hình
  'phang xi pang': 'Phan Xi Păng',
  'phan si pan': 'Phan Xi Păng',
  'phan si pang': 'Phan Xi Păng',
  'phang si pan': 'Phan Xi Păng',
  'fansipan': 'Phan Xi Păng',
  'e vo ret': 'Everest',
  'e ve ret': 'Everest',
  'ê vơ rét': 'Everest',
  'e vơ rét': 'Everest',
  'everest': 'Everest',
  'pu si nung': 'Pu Si Lung',
  'pu xi lung': 'Pu Si Lung',
  'tay con ninh': 'Tây Côn Lĩnh',
  'ngoc ninh': 'Ngọc Linh',
  'nui ba den': 'núi Bà Đen',
  'núi ba đen': 'núi Bà Đen',
  'nui ba đen': 'núi Bà Đen',
  'nang bi ang': 'Lang Biang',
  'lang bi an': 'Lang Biang',
  'ranh mariana': 'rãnh Mariana',
  'vuc mariana': 'rãnh Mariana',
  'vực mariana': 'rãnh Mariana',
  'ma ri a na': 'Mariana',
  'ma ri an na': 'Mariana',

  // Danh lam thắng cảnh & Văn hóa Việt Nam
  'vinh ha nong': 'Vịnh Hạ Long',
  'vịnh hạ nòng': 'Vịnh Hạ Long',
  'vinh ha long': 'Vịnh Hạ Long',
  'yen tu': 'Yên Tử',
  'diên tử': 'Yên Tử',
  'ho guom': 'Hồ Gươm',
  'ho hoan kiem': 'Hồ Hoàn Kiếm',
  'van mieu quoc tu giam': 'Văn Miếu Quốc Tử Giám',
  'hoang thanh thang long': 'Hoàng thành Thăng Long',
  'phong nha ke bang': 'Phong Nha Kẻ Bàng',
  'phong nha kẻ bàng': 'Phong Nha Kẻ Bàng',
  'ba na hills': 'Bà Nà',
  'bà nà hill': 'Bà Nà',
  'hoi an': 'Hội An',
  'thanh dia my son': 'Thánh địa Mỹ Sơn',
  'dia dao cu chi': 'Địa đạo Củ Chi',
  'cho ben thanh': 'Chợ Bến Thành',

  // Tỉnh thành hay nhầm phụ âm l-n / dấu
  'nao cai': 'Lào Cai',
  'nạng son': 'Lạng Sơn',
  'nang son': 'Lạng Sơn',
  'da nang': 'Đà Nẵng',
  'đa nẵng': 'Đà Nẵng',
  'dien bien phu': 'Điện Biên Phủ',
  'sapa': 'Sa Pa',
  'sa pa': 'Sa Pa',
  'dalat': 'Đà Lạt',
  'da lat': 'Đà Lạt',
  'nha trang': 'Nha Trang',
  'phu quoc': 'Phú Quốc',
  'phan thiet': 'Phan Thiết',
  'vung tau': 'Vũng Tàu',
  'sai gon': 'Sài Gòn',
  'ha noi': 'Hà Nội',

  // Thiên thể & Hành tinh
  'sao chim': 'Sao Kim',
  'sao hoa': 'Sao Hỏa',
  'sao thuy': 'Sao Thủy',
  'sao moc': 'Sao Mộc',
  'sao tho': 'Sao Thổ',
  'sao hai vuong': 'Sao Hải Vương',
  'sao thien vuong': 'Sao Thiên Vương',
  'mat troi': 'Mặt Trời',
  'mat trang': 'Mặt Trăng',
};

/// Sửa lỗi nhận diện ngữ âm ASR tiếng Việt.
String fixVietnameseAsr(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return t;

  final lower = t.toLowerCase();
  final norm = normVi(lower);

  // So khớp và thay thế các cụm từ ngữ âm trong từ điển
  for (final entry in _phoneticReplacements.entries) {
    final patternNorm = normVi(entry.key);
    if (norm.contains(patternNorm)) {
      // Thay thế khớp mềm dựa trên chuỗi đã chuẩn hóa
      final regex = RegExp(RegExp.escape(entry.key), caseSensitive: false);
      if (regex.hasMatch(t)) {
        t = t.replaceAll(regex, entry.value);
      } else {
        // Thay theo chuỗi bỏ dấu nếu chuỗi gốc sai dấu
        final words = t.split(RegExp(r'\s+'));
        final patWords = entry.key.split(RegExp(r'\s+'));
        for (var i = 0; i <= words.length - patWords.length; i++) {
          final subNorm = normVi(words.sublist(i, i + patWords.length).join(' '));
          if (subNorm == patternNorm) {
            words.replaceRange(i, i + patWords.length, [entry.value]);
            t = words.join(' ');
            break;
          }
        }
      }
    }
  }

  return t;
}
