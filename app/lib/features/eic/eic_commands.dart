// MÁY HÁT TRÁI ĐẤT — hiểu câu nói. [t] đã bỏ dấu (normVi).
//   mở:      "máy hát trái đất", "earth jukebox", "nghe ánh đèn ban đêm", "nghe sét", "nghe khí CO2", "nghe biển", "nghe rừng"
//   trong:   dừng / tiếp tục / nhanh hơn / chậm lại / nghe lại / giải thích / mô tả / chú giải / khung sau / khung trước / năm 2020
//            "danh sách" (đọc các hình), "đổi sang sét"…
import 'eic_data.dart';

enum EicAct { open, list, pause, resume, faster, slower, replay, why, describe, legend, next, prev, year, source }

class EicCmd {
  final EicAct act;

  /// id của hình (khi câu nói chỉ rõ hình nào), null = hình mặc định / hình đang mở
  final String? target;
  final String raw;
  const EicCmd(this.act, {this.target, this.raw = ''});
  @override
  String toString() => 'EicCmd($act, target=$target)';
}

/// Từ khoá cho từng hình (bỏ dấu). Khớp cả bí danh khai báo trong meta.json (aliases).
const eicKeywords = <String, List<String>>{
  'nightlights': ['anh den', 'den ban dem', 'den dem', 'anh sang ban dem', 'anh sang thanh pho', 'night light', 'night lights', 'city lights'],
  'lightning': ['set', 'tia set', 'chop', 'sam set', 'lightning'],
  'co2': ['co2', 'co 2', 'cacbon', 'carbon', 'khi thai', 'dioxide', 'xe o 2'],
  'ocean': ['bien', 'dai duong', 'nhiet do bien', 'dong bien', 'hai luu', 'ocean', 'sea surface', 'sst', 'currents'],
  'forest': ['rung', 'tan rung', 'chieu cao rung', 'cay', 'forest', 'canopy', 'gedi'],
};

bool _w(String t, String k) => ' $t '.contains(' $k ');

/// id hình được nhắc tới trong câu (hoặc null)
String? eicSetIn(String t, [EicLibrary? lib]) {
  for (final e in eicKeywords.entries) {
    for (final k in e.value) {
      if (_w(t, k)) return e.key;
    }
  }
  if (lib != null) {
    for (final s in lib.sets) {
      for (final a in s.aliases) {
        if (a.isNotEmpty && _w(t, a)) return s.id;
      }
    }
  }
  return null;
}

final _openRe = RegExp(r'\b(may hat trai dat|may hat|jukebox|earth jukebox|hop nhac trai dat|nghe hinh nasa|nghe du lieu nasa|'
    r'nghe video nasa|nghe hinh anh nasa|eic)\b');

/// Câu ngoài chế độ: có phải muốn mở máy hát không?
EicCmd? parseEicOpen(String t, [EicLibrary? lib]) {
  if (_openRe.hasMatch(t)) {
    if (RegExp(r'\b(co nhung|danh sach|gom nhung|co gi|list|what s on)\b').hasMatch(t)) return EicCmd(EicAct.list, raw: t);
    return EicCmd(EicAct.open, target: eicSetIn(t, lib), raw: t);
  }
  // "nghe ánh đèn ban đêm", "nghe sét toàn cầu", "listen to lightning": động từ nghe + tên hình
  final s = eicSetIn(t, lib);
  if (s != null && RegExp(r'^(?:(?:cho )?(?:toi|minh) )?(?:muon )?(?:nghe|hat|phat|listen to|play)\b').hasMatch(t)) {
    // "nghe biển" quá chung (có thể là tiếng sóng) → chỉ nhận khi có thêm chữ "nhiệt độ / dòng / nasa / toàn cầu"
    if (s == 'ocean' && !RegExp(r'\b(nhiet do|dong|hai luu|nasa|toan cau|the gioi|ocean|sea surface|currents)\b').hasMatch(t)) {
      return null;
    }
    if (s == 'forest' && !RegExp(r'\b(rung|tan rung|forest|canopy|gedi)\b').hasMatch(t)) return null;
    return EicCmd(EicAct.open, target: s, raw: t);
  }
  return null;
}

/// Câu khi đang ở trong máy hát.
EicCmd? parseEicInside(String t, [EicLibrary? lib]) {
  // nhảy tới mốc: "năm 2020", "2020", "tháng 7"
  if (RegExp(r'\b(nam|year)\s*(19|20)\d\d\b').hasMatch(t) ||
      RegExp(r'^(19|20)\d\d$').hasMatch(t) ||
      RegExp(r'\b(thang|month)\s*\d{1,2}\b').hasMatch(t)) {
    return EicCmd(EicAct.year, raw: t);
  }
  if (RegExp(r'\b(vi sao|tai sao|giai thich|y nghia|why|explain)\b').hasMatch(t)) return EicCmd(EicAct.why, raw: t);
  if (RegExp(r'\b(tam dung|dung lai|dung|pause|stop|im)\b').hasMatch(t)) return EicCmd(EicAct.pause, raw: t);
  if (RegExp(r'\b(tiep tuc|hat tiep|phat tiep|nghe tiep|continue|resume|go on)\b').hasMatch(t)) return EicCmd(EicAct.resume, raw: t);
  if (RegExp(r'\b(nhanh hon|nhanh len|nhanh|faster|speed up)\b').hasMatch(t)) return EicCmd(EicAct.faster, raw: t);
  if (RegExp(r'\b(cham lai|cham hon|cham|slower|slow down)\b').hasMatch(t)) return EicCmd(EicAct.slower, raw: t);
  if (RegExp(r'\b(nghe lai|hat lai|phat lai|lai tu dau|tu dau|again|replay|restart|play again)\b').hasMatch(t)) {
    return EicCmd(EicAct.replay, raw: t);
  }
  if (RegExp(r'\b(chu giai|nghe gi la gi|am thanh nghia la|legend|what do the sounds)\b').hasMatch(t)) return EicCmd(EicAct.legend, raw: t);
  if (RegExp(r'\b(mo ta|hinh gi|hinh nay|tren hinh|describe|what is this)\b').hasMatch(t)) return EicCmd(EicAct.describe, raw: t);
  if (RegExp(r'\b(nguon|source|credit)\b').hasMatch(t)) return EicCmd(EicAct.source, raw: t);
  if (RegExp(r'\b(khung sau|tiep theo|ke tiep|next)\b').hasMatch(t)) return EicCmd(EicAct.next, raw: t);
  if (RegExp(r'\b(khung truoc|truoc do|previous|back one)\b').hasMatch(t)) return EicCmd(EicAct.prev, raw: t);
  if (RegExp(r'\b(danh sach|co nhung hinh|hinh khac|list)\b').hasMatch(t)) return EicCmd(EicAct.list, raw: t);
  final s = eicSetIn(t, lib);
  if (s != null) return EicCmd(EicAct.open, target: s, raw: t);
  return parseEicOpen(t, lib);
}
