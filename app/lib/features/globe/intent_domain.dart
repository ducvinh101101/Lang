// TÁCH PHẦN THỜI TIẾT VÀ PHẦN ĐỊA ĐIỂM (ăn, ở, chơi quanh Hà Nội) để nói không bị nhầm.
//
// Cùng một tên nơi ("Hồ Tây") có thể là hỏi thời tiết hoặc hỏi chỗ ăn chơi. App quyết định theo thứ tự:
//  1. Câu có từ THỜI TIẾT (thời tiết, mưa, nắng, nóng, lạnh, mấy độ, dự báo, gió mạnh, mang ô…) → phần thời tiết.
//     "Mai đi chơi Hồ Tây được không" là hỏi trời có hợp đi chơi không → cũng là thời tiết.
//  2. Câu có từ ĐỊA ĐIỂM (quán, ăn gì, món, khách sạn, chỗ ở, chơi gì, tham quan, đi đâu, có gì…) → phần địa điểm.
//  3. Câu chỉ có tên nơi ("Tây Hồ", "còn Ba Đình thì sao") → theo PHẦN ĐANG DÙNG (câu hỏi trước thuộc phần nào).
//  4. Người dùng chuyển hẳn: "phần địa điểm" / "phần thời tiết"; hoặc chữa lại: "ý tôi là thời tiết",
//     "không phải, hỏi địa điểm cơ" → làm lại câu vừa rồi ở phần kia.
// Thuần Dart — test/intent_domain_test.dart.
import '../voice/commands.dart' show normVi;

enum Domain { weather, places }

// Từ thời tiết, so trên chữ CÓ DẤU: bỏ dấu thì "mưa" trùng "mua" (mua sắm), "nóng" trùng "nông", "lạnh" trùng "lành",
// "nắng" trùng "nặng", "gió" trùng "giờ".
// MẠNH: chắc chắn hỏi trời. YẾU: cũng hay gặp trong câu hỏi quán ("chè lạnh", "phở nóng", "quán ngoài trời") → chỉ tính là
// thời tiết khi câu KHÔNG có từ địa điểm.
final _weatherStrong = RegExp(r'(thời tiết|gió|nhiệt độ|mấy độ|bao nhiêu độ|độ c\b|mưa|dự báo|bão|áp thấp|sương mù|chỉ số uv|tia uv|'
    r'độ ẩm|gió mạnh|gió to|có gió|hướng gió|tốc độ gió|mang ô|áo mưa|khí hậu|giông|sấm sét|chất lượng không khí|bụi mịn)');
final _weatherWeak = RegExp(r'(nắng|nóng|lạnh|rét|oi bức|trời|áo khoác)');
// câu không có dấu (gõ phím, bộ nhận giọng trả chữ không dấu): chỉ dùng các cụm không bị trùng nghĩa
final _weatherPlain = RegExp(r'\b(thoi tiet|nhiet do|may do|bao nhieu do|do am|du bao|ap thap|suong mu|chi so uv|'
    r'mang o|ao mua|khi hau|co mua|mua khong)\b');
final _placesRe = RegExp(r'\b(quan an|quan nao|quan ngon|cac quan|quan gi|an gi|an o dau|an dau|mon gi|mon ngon|ngon|nha hang|'
    r'ca phe|cafe|an sang|an trua|an toi|an dem|an vat|am thuc|dac san|khach san|nha nghi|homestay|hostel|resort|nghi duong|'
    r'cho o|luu tru|thue phong|choi gi|choi o dau|vui choi|giai tri|tham quan|du lich|di dau|nen di dau|co gi|co nhung gi|'
    r'dia diem|dia danh|check in|mua sam|cho dem|pho di bo|di tich|danh lam|choi dau|di choi dau|an choi)\b');
// tên món (so chữ có dấu: "phở" ≠ "phố")
// (đứng riêng thành chữ: "ốc" không bắt trong "Quốc")
final _dishRe = RegExp(r'(^|\s)(phở|bún|bánh mì|bánh cuốn|bánh xèo|chả cá|xôi|chè|kem|lẩu|nem|ốc|cà phê|trà sữa|bia hơi)(\s|$)');
// "đi chơi … được không / có hợp không / có nên" là hỏi TRỜI có hợp đi chơi không
final _outingRe = RegExp(r'\b(di choi|ra ngoai|di dao|da ngoai|picnic|cam trai)\b.*\b(duoc khong|co hop|hop khong|co nen|nen khong|phu hop|on khong)\b');

/// Câu thuộc phần nào; null nếu không có từ nào cho biết (chỉ có tên nơi…).
Domain? domainOf(String raw) {
  // "Mặt Trời" (vũ trụ), "trời ơi" (cảm thán) không phải hỏi trời
  final low = raw.toLowerCase().replaceAll(RegExp(r'mặt trời|trời ơi|ông trời|ôi trời'), ' ');
  final t = normVi(raw);
  final places = _placesRe.hasMatch(t) || _dishRe.hasMatch(low);
  final hasAccent = RegExp(r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]').hasMatch(low);
  final weather = hasAccent
      ? _weatherStrong.hasMatch(low) || (!places && _weatherWeak.hasMatch(low))
      : _weatherPlain.hasMatch(t);
  if (weather || _outingRe.hasMatch(t)) return Domain.weather;
  if (places) return Domain.places;
  return null;
}

/// Chuyển phần / chữa lại phần: ('switch'|'fix', Domain). null nếu không phải.
///  "phần địa điểm", "chuyển sang thời tiết" → ('switch', …)
///  "ý tôi là thời tiết", "không phải, hỏi quán ăn cơ", "tôi hỏi địa điểm mà" → ('fix', …)
(String, Domain)? domainSwitch(String raw) {
  final t = normVi(raw);
  const w = r'(thoi tiet|phan thoi tiet)';
  const p = r'(dia diem|phan dia diem|dia diem quanh ha noi|an uong|an choi|quan an|cho an|cho choi|cho an choi|cho o|khach san|'
      r'du lich|am thuc|luu tru)';
  const tail = r'( co| ma| chu| nhe| nha| a| thoi| di)*$';
  Domain? which(String rest) => RegExp('^$w$tail').hasMatch(rest)
      ? Domain.weather
      : RegExp('^$p$tail').hasMatch(rest)
          ? Domain.places
          : null;
  final sw = RegExp(r'^(phan|che do|chuyen sang|chuyen qua|sang phan|vao phan|mo phan|quay lai|ve phan|cho toi nghe phan)\s+(.*)$')
      .firstMatch(t);
  if (sw != null) {
    // "phần thời tiết" / "chuyển sang phần địa điểm" (bỏ chữ "phần" lặp)
    final rest = sw.group(2)!.replaceFirst(RegExp(r'^phan '), '');
    final d = which(rest);
    if (d != null) return ('switch', d);
  }
  final fx = RegExp(r'^(khong phai\s*)?(y toi la|y minh la|toi hoi|minh hoi|toi muon hoi|minh muon hoi|hoi|toi can|ma la|la)?\s*(ve\s+)?(.*)$')
      .firstMatch(t);
  if (fx != null && (fx.group(1) != null || fx.group(2) != null)) {
    final d = which(fx.group(4)!.trim());
    if (d != null) return ('fix', d);
  }
  return null;
}
