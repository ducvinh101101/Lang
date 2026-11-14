// Hiểu lệnh nói cho QUẢ ĐỊA CẦU (thuần Dart, test được — test/world_commands_test.dart).
//  "phóng to Paris", "đến Nhật Bản", "xem Huế"            → bay tới đó, đọc chỉ số, chơi nhạc cụ
//  "thời tiết Luân Đôn", "ngày mai ở Huế có mưa không"     → bay tới, đọc thời tiết (ngày mai / mưa / lời khuyên)
//  "khí hậu Hà Nội", "dữ liệu NASA ở đây", "tháng 10 năm 2020" → số liệu NASA POWER, nghe xu hướng các năm
//  "ngày 15 tháng 10 năm 2024 ở Huế", "hôm qua"            → số liệu đúng ngày đó
//  "thu nhỏ", "phóng to", "dừng", "đọc lại", "trợ giúp", "nghe nhạc", "24 giờ tới", "đây là đâu"
//  "chiều nay có mưa không", "bản tin", "có bão không", "thiên tai trên thế giới"
//  "tôi đang ở đâu", "quanh Hồ Hoàn Kiếm có gì", "khám phá bằng tay", "xưa và nay"
//  "kể chuyện Sao Kim", "các hành tinh", "ảnh thiên văn hôm nay"
import 'dart:math' as math;

import '../history/history_command.dart' show weatherHistoryCmdVi;
import '../../live/nasa_sounds.dart' show nasaSoundRequest;
import '../space/planets.dart' show planetIn;
import '../voice/commands.dart';
import '../../live/vn_admin.dart' show provincesNow, provinceMerged;
import 'hanoi_guide.dart' show findHanoiZone;
import 'vn_landmarks.dart' show landmarkIn, landmarksOfProvinceIn, vnLandmarks;
import 'terrain_data.dart' show peakIn;
import 'world.dart' show countryAliases, cityAliases;

/// Đang ở bản đồ RÊ TAY / quét lát cắt / lịch sử: câu ngắn kiểu "quay lại", "trở về", "về thôi", "đóng lại", "ra ngoài",
/// "xong rồi" là muốn THOÁT ra (bình thường "quay lại" là thu nhỏ quả cầu). [t] đã bỏ dấu (normVi).
bool isBackPhrase(String t) {
  t = t.trim();
  if (isHomePhrase(t)) return true;
  return RegExp(r'^(?:(?:toi|minh|cho toi|cho minh|hay|lam on|xin|vui long) )?(?:muon )?'
          r'(?:quay lai|quay ve|tro ve|tro lai|ve|ve thoi|di ve|dong|dong lai|ra ngoai|ra khoi day|ra khoi|'
          r'thoat|thoat ra|xong|xong roi|du roi|thoi du roi|thoi xong roi|back|go back|exit|close|done|i m done)'
          r'(?: (?:di|nhe|thoi|nao|roi|ra|lai|ngay|day|di nhe|nhe ban|giup toi|giup minh|qua dia cau|ban do))*$')
      .hasMatch(t);
}

/// "Về màn hình chính", "trang chủ", "home screen": về màn hình chính của nhánh đang dùng (ở bất kỳ đâu).
bool isHomePhrase(String t) =>
    RegExp(r'\b(man hinh chinh|ve trang chinh|ve trang chu|trang chu|home screen|main screen|go home)\b').hasMatch(t);

enum WKind {
  stop,
  help,
  repeat,
  louder,
  quieter,
  faster,
  slower,
  zoomOut, // thu nhỏ một nấc
  world, // xem cả quả địa cầu
  zoomIn, // phóng to tại chỗ đang xem
  go, // bay tới [target] rồi đọc
  weather, // thời tiết (target có thể rỗng = chỗ đang xem / nơi của bạn)
  forecast, // dự báo mấy ngày tới
  hours, // nghe 24 giờ tới bằng nhạc cụ
  music, // nghe nhạc cụ của chỗ đang xem
  climate, // dữ liệu khí hậu NASA (cả chuỗi năm, hoặc một tháng/năm)
  day, // một ngày cụ thể
  where, // đây là đâu
  setHome, // tôi ở …
  pause, // tạm ngừng nghe
  settings, // mở cài đặt (cho người đi cùng)
  bulletin, // bản tin thời tiết (như bản tin sáng)
  disasters, // thiên tai đang diễn ra (NASA EONET) — target rỗng: quanh chỗ đang xem; aspect 'world': cả thế giới
  around, // địa lý quanh một nơi; aspect 'gps': nơi tôi đứng
  explore, // khám phá bằng chạm (bản đồ quanh một nơi)
  exitLocal, // thoát bản đồ chạm / truyện vũ trụ, về quả địa cầu
  history, // xưa và nay
  nasaSound, // F2: bản ghi âm thật của NASA; target = id bản ghi, '' = đọc danh sách
  weatherHistory, // F1: phát lại lịch sử thời tiết / thiên tai; aspect 'both' | 'weather' | 'disaster'; spanMonths hoặc from/to
  planet, // kể chuyện một thiên thể (target = tên)
  planets, // giới thiệu các hành tinh
  terrain, // địa hình: aspect 'touch' | 'off' | 'height' | 'describe' | 'overview' | 'spine' | 'profile' | 'path' | 'peak' | 'deep'
  game, // trò chơi tìm hiểu Hệ Mặt Trời: target 'quiz' | 'riddle' | 'sound' | '' (chọn trò)
  landmark, // giới thiệu một địa danh Việt Nam (target = tên; rỗng = nơi đang xem)
  landmarks, // kể tên địa danh nổi bật theo vùng / tỉnh (đọc vùng, tỉnh từ raw)
  apod, // ảnh thiên văn hôm nay của NASA
  language, // đổi ngôn ngữ: target 'en' | 'vi'
  ignore, // tiếng đệm / tiếng ồn ("ừ", "à") — không làm gì
  unknown,
}

class WCmd {
  final WKind kind;
  final String target; // địa danh như người dùng nói (giữ dấu), '' = không nói
  final int? liveDay; // null bây giờ, 0 hôm nay, 1 mai, 2 ngày kia
  final String? aspect; // 'rain' | 'advice' | 'outing' (đi chơi có hợp không) | 'gps' | 'world'

  /// Buổi trong ngày: 'sang' | 'trua' | 'chieu' | 'toi' | 'dem' (null = cả ngày / bây giờ).
  final String? period;
  final int? month, year; // dữ liệu NASA một tháng/năm
  final DateTime? date;
  final String raw;

  /// Lịch sử thời tiết: "3 năm qua" = 36 tháng (tính lùi từ tháng cuối có số liệu).
  final int? spanMonths;

  /// Lịch sử thời tiết: khoảng tuyệt đối (tháng đầu, tháng cuối — gồm cả hai).
  final DateTime? from, to;

  /// Câu chỉ có một cụm từ, không có từ lệnh (có thể là tiếng ồn / TV) → không tìm thấy thì im lặng.
  final bool bare;

  /// Câu hỏi nối tiếp ("còn Đà Nẵng thì sao", "cả thế giới thì sao") → dùng lại loại câu hỏi trước.
  bool get followUp => RegExp(r'\b(thi sao|the con|con .+ thi sao|con .+ nua|o .+ thi sao|what about|how about|and in)\b').hasMatch(normVi(raw));
  const WCmd(this.kind,
      {this.target = '',
      this.liveDay,
      this.aspect,
      this.period,
      this.month,
      this.year,
      this.date,
      this.raw = '',
      this.bare = false,
      this.spanMonths,
      this.from,
      this.to});

  @override
  String toString() => 'WCmd($kind, "$target", day=$liveDay, period=$period, aspect=$aspect, m=$month, y=$year, date=$date)';
}

// Từ lệnh đứng TRƯỚC địa danh (đã bỏ dấu, dài trước).
const _lead = [
  // "cho tôi nghe thời tiết Huế" (KHÔNG thêm "nghe" trơn: "Nghệ An" bỏ dấu là "nghe an")
  'cho toi nghe', 'cho minh nghe', 'cho tui nghe', 'nghe thu',
  'gio o', 'gio tai', 'mua o', 'troi o', 'troi tai',
  // thời gian đứng ĐẦU câu: "tuần sau Sa Pa có lạnh không", "cuối tuần này Đà Lạt"
  'tuan sau o', 'tuan toi o', 'tuan nay o', 'cuoi tuan nay o', 'cuoi tuan o', 'tuan sau', 'tuan toi', 'tuan nay',
  'cuoi tuan nay', 'cuoi tuan', 'may ngay toi o', 'may ngay toi', 'toi nay o', 'dem nay o', 'sang mai o', 'chieu mai o',
  'toi nay', 'dem nay', 'sang mai', 'chieu mai', 'hom nay', 'ngay kia', 'bua nay o', 'bua ni o', 'bua nay', 'bua ni', 'chu o', 'chu',
  'the thi', 'vay thi', 'the con', 'con o', 'the', 'vay', 'nhung', 'oi', 'ban oi',
  'cho hoi', 'cho minh hoi', 'cho toi hoi', 'cho tui hoi thoi tiet o', 'cho tui hoi thoi tiet', 'cho tui hoi ve', 'cho tui hoi',
  'ke tui nghe ve', 'ke tui nghe coi ve', 'ke tui nghe coi', 'ke tui nghe', 'noi tui nghe ve', 'noi tui nghe', 'noi nghe coi ve', 'noi nghe coi',
  'xem coi thoi tiet o', 'xem coi thoi tiet', 'xem coi',
  'rum vao', 'rum va', 'dum vao', 'dum va', 'zum vao', 'zum va', 'gun vao', 'gun va', 'dung vao', 'dung va', 'giun vao',
  'zoom va', 'rum', 'dum', 'zum',
  'mo ta dia hinh o', 'mo ta dia hinh', 'mo ta xung quanh', 'mo ta khu vuc', 'mo ta', 'dia hinh o', 'dia hinh cua', 'dia hinh',
  'dia ly quanh khu vuc', 'dia ly quanh', 'dia ly o', 'dia ly cua', 'dia ly', 'do cao o', 'do cao cua', 'do cao',
  'cac dia diem an uong vui choi o', 'cac dia diem an uong o', 'cac dia diem vui choi o', 'cac dia diem du lich o',
  'cac dia diem tham quan o', 'cac dia diem quanh khu vuc', 'cac dia diem quanh', 'cac dia diem o', 'cac dia diem tai', 'cac dia diem',
  'dia diem an uong vui choi o', 'dia diem an uong o', 'dia diem vui choi o', 'dia diem du lich o', 'dia diem tham quan o',
  'dia diem quanh khu vuc', 'dia diem quanh', 'dia diem o', 'dia diem tai', 'dia diem',
  'an uong vui choi o', 'an uong o', 'an uong tai', 'vui choi giai tri o', 'vui choi o', 'vui choi tai',
  'quanh khu vuc', 'o khu vuc', 'tai khu vuc', 'khu vuc', 'xung quanh', 'quanh', 'gan',
  'kham pha bang tay o', 'kham pha bang tay', 'kham pha bang cham o', 'kham pha bang cham', 'che do cham', 're tay o', 're tay', 're ngon tay', 'so ban do', 'kham pha quanh', 'kham pha', 'ban do quanh', 'thien tai o', 'thien tai',
  'canh bao o', 'canh bao', 'co bao o', 'co bao', 'ban tin thoi tiet o', 'ban tin o', 'ban tin',
  'toi muon nghe thoi tiet o', 'toi muon nghe thoi tiet tai', 'toi muon nghe thoi tiet',
  'minh muon nghe thoi tiet o', 'minh muon nghe thoi tiet tai', 'minh muon nghe thoi tiet',
  'muon nghe thoi tiet o', 'muon nghe thoi tiet tai', 'muon nghe thoi tiet',
  'toi muon xem thoi tiet o', 'toi muon xem thoi tiet tai', 'toi muon xem thoi tiet',
  'minh muon xem thoi tiet o', 'minh muon xem thoi tiet tai', 'minh muon xem thoi tiet',
  'muon xem thoi tiet o', 'muon xem thoi tiet tai', 'muon xem thoi tiet',
  'toi muon biet thoi tiet o', 'toi muon biet thoi tiet tai', 'toi muon biet thoi tiet',
  'minh muon biet thoi tiet o', 'minh muon biet thoi tiet tai', 'minh muon biet thoi tiet',
  'muon biet thoi tiet o', 'muon biet thoi tiet tai', 'muon biet thoi tiet',
  'toi muon nghe ve', 'minh muon nghe ve', 'muon nghe ve',
  'toi muon biet ve', 'minh muon biet ve', 'muon biet ve',
  'toi muon nghe', 'minh muon nghe', 'muon nghe',
  'toi muon xem', 'minh muon xem', 'muon xem',
  'toi muon biet', 'minh muon biet', 'muon biet',
  'ban cho minh biet thoi tiet o', 'ban cho minh biet thoi tiet tai', 'ban cho minh biet thoi tiet',
  'ban cho toi biet thoi tiet o', 'ban cho toi biet thoi tiet tai', 'ban cho toi biet thoi tiet',
  'cho minh biet thoi tiet o', 'cho minh biet thoi tiet tai', 'cho minh biet thoi tiet',
  'cho toi biet thoi tiet o', 'cho toi biet thoi tiet tai', 'cho toi biet thoi tiet',
  'ban cho minh biet', 'ban cho toi biet', 'cho minh biet o', 'cho toi biet o', 'cho minh biet', 'cho toi biet',
  'co the cho minh biet thoi tiet o', 'co the cho toi biet thoi tiet o',
  'dat noi cua toi la', 'dat noi cua toi o', 'dat noi cua toi', 'noi cua toi la',
  'giup toi voi', 'giup minh voi', 'giup toi', 'giup minh', 'lam on', 'xin', 'cho toi xin', 'cho minh xin',
  'cho toi xem thoi tiet o', 'cho toi xem thoi tiet', 'cho toi xem', 'cho minh xem', 'cho toi', 'cho minh', 'phong to vao', 'phong to den',
  'phong to', 'zoom vao', 'zoom to', 'zoom in', 'zoom out', 'zoom', 'bay den', 'bay toi', 'bay qua', 'di den', 'di toi',
  'di du lich o', 'di du lich tai', 'di du lich', 'du lich o', 'du lich tai', 'du lich',
  'khi den', 'khi toi', 'khi vao', 'khi ra', 'di vao', 'di ra', 'chuyen den',
  'chuyen toi', 'tim kiem', 'tim', 'mo', 'xem thoi tiet o', 'xem thoi tiet tai', 'xem thoi tiet', 'xem khi hau o',
  'xem khi hau', 'xem', 'den', 'toi', 'vao', 'ra', 'thoi tiet hom nay o', 'thoi tiet ngay mai o', 'thoi tiet bay gio o',
  'thoi tiet hom nay tai', 'thoi tiet o', 'thoi tiet tai', 'thoi tiet', 'du bao thoi tiet o', 'du bao thoi tiet',
  'du bao o', 'du bao', 'khi hau o', 'khi hau tai', 'khi hau', 'du lieu nasa o', 'du lieu nasa tai', 'du lieu nasa',
  'nasa o', 'nasa', 'nghe nhac o', 'nghe nhac', 'nhiet do o', 'nhiet do', 'luong mua o', 'mua o', 'ngay mai o',
  'hom nay o', 'bay gio o',
  'o', 'tai', 'weather in', 'weather', 'go to', 'show me', 'show', 'climate of', 'climate',
];

// Từ đứng SAU địa danh.
const _trail = [
  // dài trước (danh sách xét theo thứ tự, gặp cụm khớp đầu tiên là cắt)
  // "Hà Nội sao rồi", "Huế thế nào rồi"
  'the nao roi', 'ra sao roi', 'sao roi', 'sao the', 'sao vay',
  'bua ni rang rua', 'bua ni rang he', 'bua ni', 'bua nay sao ta', 'bua nay', 'bua hom', 'bua qua',
  'nghe nhac cu', 'nghe nhac', 'choi nhac', 'nghe am thanh', 'nghe dan bau', 'nghe dan', 'nhac cu',
  'co manh khong', 'manh khong', 'gio co manh khong', 'gio manh khong', 'co to khong', 'gio to khong', 'may do roi', 'bao nhieu do roi', 'may do the', 'bao nhieu do the', 'may do', 'bao nhieu do', 'nhiet do bao nhieu',
  'nhiet do the nao', 'nong chua', 'mua chua', 'roi',
  'co ret khong', 'ret khong', 'co lanh khong', 'lanh khong', 'co nong khong', 'nong khong', 'co nang khong',
  'nang khong', 'co gio khong', 'co ret', 'co lanh', 'co nong', 'co mua',
  'tuan sau', 'tuan toi', 'tuan nay', 'cuoi tuan nay', 'cuoi tuan', 'may ngay toi', 'vao cuoi tuan', 'vao tuan sau',
  'co chi khong', 'co chi dep khong', 'co chi dep', 'co chi choi khong', 'co chi choi', 'co chi noi tieng khong', 'co chi noi tieng', 'co chi noi bat', 'co chi la', 'co chi hay', 'co chi',
  'co gi choi hong ne', 'co gi choi hong ta', 'co gi choi hong', 'co gi choi', 'co gi khong', 'co nhung gi', 'co gi',
  'co dia diem an uong vui choi gi', 'co dia diem an uong gi', 'co dia diem vui choi gi', 'co dia diem du lich gi',
  'co dia diem gi', 'co gi an uong', 'co gi vui choi', 'co gi tham quan', 'co gi du lich', 'co gi ngon', 'co dac san gi',
  'an uong vui choi o dau', 'an uong o dau', 'vui choi o dau', 'di choi o dau', 'du lich o dau', 'tham quan o dau',
  'an gi ngon', 'an gi', 'an uong gi', 'choi gi vui', 'choi gi', 'vui choi gi', 'nen an gi', 'nen choi gi', 'nen di dau choi', 'nen di dau',
  'co mua hong ne', 'co mua hong ta', 'co mua hong', 'mua hong', 'duoc hong ta', 'duoc hong ne', 'duoc hong',
  'sao ta', 'sao di', 'nhieu di', 'the lao', 'xem nao',
  'rang rua he', 'rang rua', 'chi rua he', 'chi rua', 'rang he', 'chi he',
  'xua va nay', 'thay doi the nao', 'thay doi ra sao', 'da thay doi the nao',
  'da thay doi ra sao', 'thay doi nhu the nao', 'thay doi', 'co bao khong', 'co thien tai khong', 'cao bao nhieu',
  'toi nay', 'dem nay', 'sang nay', 'chieu nay', 'trua nay', 'sang mai', 'chieu mai', 'toi mai', 'trua mai', 'dem mai', 'luc nay',
  'hien tai duoc khong', 'bay gio duoc khong', 'duoc khong ban', 'hien tai', 'co mua khong', 'mua khong', 'the nao', 'ra sao', 'nhu the nao', 'bay gio', 'hom nay', 'ngay mai', 'ngay kia',
  'duoc khong a', 'duoc khong', 'gium minh voi', 'gium toi voi', 'gium minh nhe', 'gium toi nhe',
  'gium minh nha', 'gium toi nha', 'gium minh', 'gium toi', 'ho minh', 'ho toi',
  'giup toi voi', 'giup minh voi', 'giup toi nhe', 'giup minh nhe', 'giup toi', 'giup minh',
  'ngay nhe', 'ngay nha', 'ngay di', 'mot chut', 'chut nhe', 'chut nha', 'chut di', 'chut coi', 'chut',
  'nhe ban', 'nha ban', 'nhe', 'nha', 'di ban', 'di nao', 'di', 'nao', 'voi', 'coi', 'thoi nhe', 'thoi nha', 'thoi',
  'can chuan bi nhung gi', 'can chuan bi gi', 'chuan bi nhung gi', 'chuan bi gi',
  'can mang theo nhung gi', 'can mang theo gi', 'mang theo nhung gi', 'mang theo gi', 'can mang gi', 'mang gi',
  'nen mac do gi', 'nen mac ao gi', 'nen mac gi', 'mac do gi', 'mac ao gi', 'mac gi',
  'can luu y nhung gi', 'can luu y gi', 'luu y nhung gi', 'luu y gi', 'can gi',
  'nen lam gi', 'co nong khong', 'co lanh khong', 'cac nam', 'qua cac nam',
  'khong', 'hong ne', 'hong ta', 'hong', 'a', 'oi', 'thoi tiet', 'khi hau', 'now', 'today', 'please',
  'thi sao', 'the nao nhi', 'nhi', 'nhể', 'nhở', 'nhe', 'nho', 'nghen', 'coi', 'he', 'rua', 'rang', 'nua', 'vay', 'the',
];

const _notPlace = {
  'day', 'nay', 'cho nay', 'noi nay', 'o day', 'hien tai', 'bay gio', 'hom nay', 'ngay mai', 'ngay kia', 'toi',
  'minh', 'gan day', 'xung quanh', 'thu do', 'len', 'xuong', 'them', 'nua', 'hon', 'lai', 'chut', 'ra', 'khu nay',
  'vung nay', 'noi day', 'quanh day', 'toi dung', 'noi toi dung', 'ra ngoai', 'ra duong', 'ngoai troi', 'ngoai duong',
  'di lam', 'di hoc', 'di cho', 'di dao', 'di bo', 'di xe may',
  'dao', 'lam', 'hoc', 'cho', 'bo', 'bien', 'tam bien', 'leo nui', 'cam trai', 'da ngoai', 'tap the duc', 'chay bo', 'xe may',
  'qua cau', 'qua dia cau', 'trai dat', 'ban do', 'the gioi', 'toan cau',
  'lai gan', 'lai gan hon', 'tien lai', 'tien lai gan', 'gan hon', 'nhin gan', 'nhin gan hon', 'nhin xa', 'nhin xa ra', 'nhin xa hon', 'lui ra', 'lui ra xa', 'lui lai', 'xa hon', 'ra xa',
  'bang cham', 'bang tay', 'che do cham', 're tay', 're ngon tay', 'so ban do', 'cham',
  'in', 'out', 'zoom in', 'zoom out',
};

/// Tách địa danh khỏi câu: bỏ từ lệnh ở đầu và cuối, giữ nguyên chữ có dấu của phần còn lại.
String extractTarget(String raw) {
  final words = raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final norm = [for (final w in words) normVi(w)];
  // bỏ từ không còn chữ (dấu câu)
  final keep = [for (var i = 0; i < words.length; i++) if (norm[i].isNotEmpty) i];
  var ws = [for (final i in keep) words[i].replaceAll(RegExp(r'[^\p{L}\p{N}\-]', unicode: true), '')];
  var ns = [for (final i in keep) norm[i]];
  bool stripLead() {
    for (final l in _lead) {
      final lw = l.split(' ');
      if (ns.length >= lw.length && ns.take(lw.length).join(' ') == l) {
        ws = ws.sublist(lw.length);
        ns = ns.sublist(lw.length);
        return true;
      }
    }
    return false;
  }

  bool stripTrail() {
    for (final l in _trail) {
      final lw = l.split(' ');
      if (ns.length >= lw.length && ns.sublist(ns.length - lw.length).join(' ') == l) {
        ws = ws.sublist(0, ws.length - lw.length);
        ns = ns.sublist(0, ns.length - lw.length);
        return true;
      }
    }
    return false;
  }

  // vài vòng: "cho tôi xem thời tiết ở Huế hôm nay nhé"
  for (var k = 0; k < 6; k++) {
    final a = stripLead(), b = stripTrail();
    if (!a && !b) break;
  }
  // bỏ phần ngày tháng còn sót: "Huế tháng 10 năm 2020", "Huế ngày 15/10"
  bool dateWord(int k) {
    final w = ns[k];
    final next = k + 1 < ns.length ? ns[k + 1] : '';
    if (RegExp(r'^\d').hasMatch(w)) return true;
    if (w == 'hom') return next == 'qua' || next == 'kia' || next == 'nay';
    if (w == 'bua') return next == 'nay' || next == 'ni' || next == 'hom' || next == 'qua' || next == 'kia';
    if (w == 'thang' || w == 'ngay') return RegExp(r'^(\d|mot|hai|ba|tu|bon|nam|sau|bay|tam|chin|muoi|gieng|chap|mai|kia)').hasMatch(next);
    if (w == 'nam') return RegExp(r'^(\d|hai nghin|truoc|ngoai|nay|sau|toi)').hasMatch(ns.skip(k + 1).take(2).join(' '));
    return false;
  }

  var cut = -1;
  for (var k = 0; k < ns.length; k++) {
    if (dateWord(k)) {
      cut = k;
      break;
    }
  }
  if (cut > 0) {
    ws = ws.sublist(0, cut);
    ns = ns.sublist(0, cut);
    while (ns.isNotEmpty && (ns.last == 'o' || ns.last == 'tai' || ns.last == 'vao')) {
      ws.removeLast();
      ns.removeLast();
    }
  } else if (cut == 0) {
    // "tháng 10 năm 2020 ở Huế": địa danh nằm sau chữ "ở" / "tại" cuối cùng
    final at = [ns.lastIndexOf('o'), ns.lastIndexOf('tai')].reduce((a, b) => a > b ? a : b);
    if (at < 0 || at == ns.length - 1) return '';
    ws = ws.sublist(at + 1);
    ns = ns.sublist(at + 1);
    while (stripTrail()) {}
  }
  // bỏ "mai" ở đầu nếu phần sau là địa danh: "mai Sa Pa", "mai Hà Nội", "mai Đà Lạt"
  if (ns.isNotEmpty && ns.first == 'mai' && ns.length > 1) {
    final rest = ns.skip(1).join(' ');
    if (parseCommand(rest).place != null || cityAliases.containsKey(rest) || landmarkIn(rest) != null || _provinceFolds.contains(rest) || _aliasTargets.containsKey(rest)) {
      ws = ws.sublist(1);
      ns = ns.sublist(1);
    }
  }
  final t = ns.join(' ');
  if (t.isEmpty || _notPlace.contains(t)) return '';
  final hit = _aliasTargets[t];
  if (hit != null) return hit;
  return ws.join(' ');
}

/// Tên địa danh bị ASR nghe nhầm dấu thanh hoặc cách viết liền → tên chuẩn
const _aliasTargets = <String, String>{
  'sapa': 'Sa Pa',
  'nha trang': 'Nha Trang',
  'can gio': 'Cần Giờ',
  'con dao': 'Côn Đảo',
  'tan chieu': 'Tân Triều',
};

/// Tiếng đệm / câu cụt — bỏ qua, không trả lời.
const _fillers = {
  'u', 'uh', 'um', 'a', 'a a', 'o', 'oi', 'ha', 'he', 'vang', 'da', 'da vang', 'ok', 'oke', 'roi', 'uhm', 'hmm', 'ukm',
  'u u', 'the', 'vay', 'nhe', 'nao', 'di', 'thung', 'su', 'ay',
  // nghe lọt từ tiếng nói chuyện xung quanh (nhật ký thật): "đây", "liệu", "ơi chị", "bảy mươi triệu đồng"…
  'day', 'lieu', 'oi chi', 'oi anh', 'oi em', 'chi oi', 'anh oi', 'em oi', 'me oi', 'bo oi', 'a lo', 'alo', 'ai',
  'gi', 'sao', 'co', 'khong', 'cai gi', 'the a', 'that a', 'u ha', 'ua', 'hu', 'hi', 'hehe', 'haha', 'cam on',
};

// Từ chỉ có trong CÂU HỎI, không có trong tên nơi → cụm còn lại là cả câu, không phải địa danh.
const _questionWords = {
  'toi', 'em', 'tui', 'khong', 'gi', 'chi', 'nen', 'di', 'choi', 'ra', 'ngoai', 'chuan', 'hop', 'duoc', 'thi', 'se', 'va', 'hay',
  'nao', 'nhieu', 'muon', 'dinh', 'sap', 'lieu', 'can', 'mang', 'mac', 'phai', 'co', 'hong', 'rua', 'rang', 'he', 'ta', 'lao', 'coi', 'nghen', 'chu',
};

bool _hasWord(String t, String k) => ' $t '.contains(' $k ');

/// Câu hỏi tự nhiên ("mai tôi đi chơi ở Đà Lạt có hợp không"): tìm địa danh thật trong câu.
/// Trả về '' nếu câu không nhắc nơi nào (dùng nơi đang xem / nơi của bạn).
String _placeInQuestion(String raw, String target) {
  final tr = normVi(raw);
  if (RegExp(r'^(ban |minh |em )?(ke|noi|doc|nghe|bat dau|tiep)( di| tiep| nhe| thoi| nhe ban)?$').hasMatch(tr)) return '';
  if (RegExp(r'\b(chet nguoi|nang bao nhieu|bao nhieu ky|bao nhieu kg)\b').hasMatch(tr)) return '';
  final nt = normVi(target);
  bool isQ(String w, int idx, List<String> list) {
    if (!_questionWords.contains(w)) return false;
    if (w == 'chi' && ((idx > 0 && list[idx - 1] == 'ho') || (idx + 1 < list.length && list[idx + 1] == 'minh'))) return false;
    if (w == 'dinh' && _inProvinceName(list, idx)) return false;
    return true;
  }
  final ws = nt.split(' ');
  if (nt.isNotEmpty && !ws.asMap().entries.any((e) => isQ(e.value, e.key, ws))) {
    return _aliasTargets[nt] ?? target; // đã là địa danh gọn
  }
  // 1) phần sau chữ "ở" / "tại" / "đến" / "đi"
  final words = raw.trim().split(RegExp(r'\s+'));
  final norm = [for (final w in words) normVi(w)];
  for (var k = norm.length - 2; k >= 0; k--) {
    if (norm[k] == 'o' || norm[k] == 'tai' || norm[k] == 'den' || norm[k] == 'di' ||
        (norm[k] == 'toi' && (k == 0 || const {'di', 'bay', 'chuyen', 'khi', 'neu', 'sap', 'muon', 'dinh'}.contains(norm[k - 1]))) ||
        (norm[k] == 'ra' && norm[k + 1] != 'ngoai' && norm[k + 1] != 'duong' && norm[k + 1] != 'sao' && norm[k + 1] != 'xa') ||
        (norm[k] == 'vao' && norm[k + 1] != 'cuoi' && norm[k + 1] != 'tuan' && norm[k + 1] != 'mua' && norm[k + 1] != 'ngay' && norm[k + 1] != 'thang') ||
        (norm[k] == 'la' && k > 0 && norm[k - 1] == 'toi')) {
      final sub = <String>[];
      for (var j = k + 1; j < words.length; j++) {
        final w = norm[j];
        final isQuestion = _questionWords.contains(w) &&
            !(w == 'chi' && ((j > 0 && norm[j - 1] == 'ho') || (j + 1 < norm.length && norm[j + 1] == 'minh'))) &&
            !(w == 'dinh' && _inProvinceName(norm, j));
        if (isQuestion || w == 'hom' || w == 'ngay' || w == 'mai') break;
        sub.add(words[j]);
      }
      if (sub.isNotEmpty) {
        final subText = sub.join(' ');
        final nSub = normVi(subText);
        final isCityOrProv = cityAliases.containsKey(nSub) || _provinceFolds.contains(nSub) || _aliasTargets.containsKey(nSub);
        if (!isCityOrProv) {
          final lmSub = landmarkIn(subText);
          if (lmSub != null) return lmSub.name;
        }
        final cand = extractTarget(subText);
        final nc = normVi(cand);
        if (nc.isNotEmpty && nc != 'nha' && !nc.split(' ').asMap().entries.any((e) => isQ(e.value, e.key, nc.split(' ')))) {
          final p = parseCommand(cand).place;
          if (p != null) {
            final np = normVi(p.name);
            if (nc == np || _aliasTargets[nc] == p.name) return p.name;
            return _aliasTargets[nc] ?? cand;
          }
          return _aliasTargets[nc] ?? cand;
        }
      }
      final afterText = words.sublist(k + 1).join(' ');
      final nAfter = normVi(afterText);
      final isAfterCityOrProv = cityAliases.containsKey(nAfter) || _provinceFolds.contains(nAfter) || _aliasTargets.containsKey(nAfter);
      if (!isAfterCityOrProv) {
        final lmAfter = landmarkIn(afterText);
        if (lmAfter != null) return lmAfter.name;
      }
      final after = extractTarget(afterText);
      final na = normVi(after);
      if (na.isNotEmpty && na != 'nha' && !na.split(' ').asMap().entries.any((e) => isQ(e.value, e.key, na.split(' ')))) {
        final p = parseCommand(after).place;
        if (p != null) {
          final np = normVi(p.name);
          if (na == np || _aliasTargets[na] == p.name) return p.name;
          return _aliasTargets[na] ?? after;
        }
        return _aliasTargets[na] ?? after;
      }
    }
  }
  // 2) địa danh biết trước nằm trong câu: ưu tiên địa danh cụ thể trong nước trước
  final t = normVi(raw);
  final lm = landmarkIn(raw);
  if (lm != null) return lm.name;
  final p = parseCommand(raw).place;
  if (p != null) return p.name;
  String? best;
  for (final k in cityAliases.keys) {
    if ((k.contains(' ') || k.length >= 4) && _hasWord(t, k) && (best == null || k.length > best.length)) best = k;
  }
  for (final k in countryAliases.keys) {
    if ((k.contains(' ') || k.length >= 6) && _hasWord(t, k) && (best == null || k.length > best.length)) best = k;
  }
  return best ?? '';
}

/// Câu đã bỏ dấu, dùng để ĐOÁN Ý; riêng tên xã / phường / huyện (cụm "xã …") được thay bằng "dd" để chữ trong tên
/// không bị hiểu thành lệnh: "xã Quyết Thắng Hải Phòng" (≠ "tháng hai"), "xã Nghĩa Dũng Nghệ An" (≠ "dừng nghe"),
/// "xã Tự Do Cao Bằng" (≠ "độ cao"), "xã Hòn Đất" (≠ "xa hơn").
String _intentText(String raw) {
  final t = normVi(raw);
  final adm = _adminTarget(raw);
  if (adm == null) return t;
  final fa = normVi(adm);
  final ws = fa.split(' ');
  final pre = ws.length > 2 && const {'thi tran', 'thi xa', 'dac khu', 'thanh pho'}.contains('${ws[0]} ${ws[1]}') ? '${ws[0]} ${ws[1]}' : ws.first;
  return t.replaceFirst(fa, '$pre dd');
}

// ======================= LỚP NGOÀI: sửa các chỗ tiếng Việt dễ nhầm nghĩa trước khi hiểu lệnh =======================
const _quanNum = {
  'mot': '1', 'hai': '2', 'ba': '3', 'bon': '4', 'tu': '4', 'nam': '5', 'sau': '6', 'bay': '7', 'tam': '8', 'chin': '9',
  'muoi': '10', 'muoi mot': '11', 'muoi hai': '12',
};

/// Hiểu câu nói tiếng Việt → lệnh. Trước khi phân tích, sửa các chỗ dễ nhầm nghĩa:
///  • chữa lời: "không phải Hà Nội mà là Hà Nam", "không, ý tôi là Đà Nẵng" → hỏi lại câu trước với nơi MỚI
///  • "còn Huế thì sao": bỏ chữ "còn" khỏi tên nơi (không bỏ dấu để khỏi cắt nhầm "Côn Đảo")
///  • tên nơi dính hoạt động / hiện tượng: "đi ăn phở có mưa không" → không có tên nơi (hỏi chỗ đang xem)
///  • "quận ba" → "quận 3"
WCmd parseWorld(String raw) {
  // "thời tiết ở quê tôi Nghệ An" → "thời tiết ở Nghệ An"
  // (chỉ khi đứng sau "ở": "quê tôi ở Huế" là câu ĐẶT NHÀ, giữ nguyên)
  raw = raw.replaceAll(RegExp(r'(?<=ở )quê (của )?(tôi|mình|em|tớ|tui|tao)( là| ở)?\s*', caseSensitive: false), '');
  // "thời tiết Huế năm ngoái" → "… năm <năm trước>" (phần khí hậu theo năm hiểu được số năm)
  if (RegExp(r'\b(thời tiết|khí hậu|nhiệt độ|lượng mưa|mưa)\b', caseSensitive: false).hasMatch(raw)) {
    raw = raw.replaceAll(RegExp(r'năm (ngoái|rồi)\b', caseSensitive: false), 'năm ${DateTime.now().year - 1}');
  }
  final words = raw.trim().split(RegExp(r'[\s,.;:!?…]+')).where((w) => w.isNotEmpty).toList();
  final t = [for (final w in words) normVi(w)].join(' ');
  // hỏi giờ / ngày (không phải thời tiết): app tự trả lời
  if (RegExp(r'^(bay gio |hien tai |luc nay )?(la )?may gio( roi)?( a| nhi| vay)?$').hasMatch(t)) return WCmd(WKind.ignore, target: 'time', raw: raw);
  if (RegExp(r'^(hom nay |bay gio )(la )?(thu may|ngay bao nhieu|ngay may|ngay gi|ngay nao|mung may)( a| nhi| vay)?$').hasMatch(t) ||
      RegExp(r'^(hom nay )?(la )?(thu may|ngay may|mung may)( a| nhi| vay)?$').hasMatch(t)) {
    return WCmd(WKind.ignore, target: 'date', raw: raw);
  }
  // nói chuyện về bản thân ("tôi tên là Mai") — không phải tên nơi: để trợ lý AI trò chuyện
  if (RegExp(r'^(toi|minh|em|tui|to) (ten|ten la|la) ').hasMatch(t) && !RegExp(r'\b(o|dang o|song o)\b').hasMatch(t)) {
    return WCmd(WKind.unknown, raw: raw);
  }
  // hỏi quán ăn / chỗ ở ở NƠI KHÁC Hà Nội (Hà Nội đã có dữ liệu riêng, trả lời trước bước này): không có dữ liệu →
  // để trợ lý AI trả lời, KHÔNG bay tới nơi tên "quán cà phê nào đẹp" hay tả bản đồ
  if (RegExp(r'\b(khach san|nha nghi|homestay|resort|quan an|quan ca phe|quan nao ngon|an gi|mon gi|nha hang|cho o(?! dau)|luu tru|o dau ngon)\b').hasMatch(t) &&
      !RegExp(r'\b(gan day|quanh day|o day|cho nay|quanh toi|gan toi|ha noi)\b').hasMatch(t) &&
      findHanoiZone(raw: raw, matchKeywordOnly: true) == null) {
    return WCmd(WKind.unknown, raw: raw);
  }
  // "chi tiết số 2", "quán số 3" mà không có danh sách nào đang đọc → không phải hỏi thời tiết
  // ("thứ hai" trơn vẫn là ngày thứ Hai)
  if (RegExp(r'^(?:(?:chi tiet|ke ve|noi ve)\s+)?(?:(?:quan|noi|cho|khach san)\s+(?:so|thu)|so) (\d+|mot|hai|ba|bon|nam)\b').hasMatch(t) &&
      !RegExp(r'\b(tro|tro choi|chon)\b').hasMatch(t)) {
    return WCmd(WKind.unknown, raw: raw);
  }
  // "ở đó thế nào", "chỗ đó thì sao": hỏi thời tiết nơi vừa nói / đang xem
  if (RegExp(r'^(o|tai|cho|noi|ben) (do|day|kia|nay|ay)( the nao| ra sao| sao roi| thi sao| sao| co gi khong| nhu nao)?$').hasMatch(t)) {
    return WCmd(WKind.weather, raw: raw);
  }
  final fix = RegExp(r'^(?:(?:khong|ko|k) phai\b.*?\b(?:ma la|ma o|ma)|(?:khong |khong phai |nham roi |sai roi )?(?:y toi la|y minh la|toi noi la|minh noi la|y la))\s+')
      .firstMatch(t);
  if (fix != null) {
    final k = fix.group(0)!.trim().split(' ').length;
    final rest = words.skip(k).join(' ');
    if (rest.isNotEmpty) {
      final c = _cleanCmd(_parseWorldCore(rest));
      // chỉ còn tên nơi → coi như hỏi tiếp ("còn Hà Nam thì sao"): app làm lại câu trước với nơi mới
      if (c.kind == WKind.go && c.bare) return _cleanCmd(_parseWorldCore('còn $rest thì sao'));
      return c;
    }
  }
  final c0 = _cleanCmd(_parseWorldCore(raw));
  // "khám phá bằng tay Đà Lạt", "rê tay ở Sa Pa", "chạm địa hình Đà Lạt": giữ tên nơi đứng sau cụm lệnh
  // (bộ hiểu lệnh chung coi cụm "khám phá bằng tay" là lệnh trơn → mất tên nơi, mở bản đồ ở nơi cũ)
  if (c0.target.isEmpty && (c0.kind == WKind.explore || (c0.kind == WKind.terrain && c0.aspect == 'touch'))) {
    final m = RegExp(
            r'^(?:(?:cho tôi|cho mình|tôi muốn|mình muốn|mở|bật|hãy)\s+)*'
            r'(?:khám phá bằng tay|khám phá bằng chạm|rê tay khám phá|rê ngón tay|rê tay|chạm địa hình|sờ địa hình|sờ bản đồ|chạm bản đồ|bản đồ chạm)'
            r'\s+(?:(?:ở|tại|quanh|xung quanh|vùng|khu vực)\s+)?(.+?)(?:\s+(?:đi|nhé|nha|với|giúp tôi|giúp mình))*\s*$',
            caseSensitive: false)
        .firstMatch(raw.trim());
    final rest = m?.group(1) ?? '';
    if (rest.isNotEmpty &&
        !RegExp(r'^(?:ở )?(?:đây|chỗ này|nơi này|quanh đây|khu này|đi|nhé|nha|thử|xem)$', caseSensitive: false).hasMatch(rest)) {
      return WCmd(c0.kind, target: rest, aspect: c0.aspect, raw: raw);
    }
  }
  return c0;
}

WCmd _cleanCmd(WCmd c) {
  var tg = c.target;
  if (tg.isEmpty || tg.contains('|')) return c;
  final low = tg.toLowerCase();
  // "còn Huế" (chữ "còn" CÓ DẤU huyền; "Côn Đảo" giữ nguyên)
  final con = RegExp(r'^(thế còn|vậy còn|còn)\s+').firstMatch(low);
  if (con != null) tg = tg.substring(con.end);
  // hoạt động / hiện tượng thời tiết đứng chỗ tên nơi → không có nơi
  final hz = RegExp(r'^(gió mùa|gió|mưa|nắng|bão|lũ|lụt|ngập|rét|lạnh|nóng|sương mù|sương|trời|ngoài trời)(\s|$)').firstMatch(tg.toLowerCase());
  // (so chữ CÓ DẤU: "ăn" ≠ "An" trong "An Giang", "Long An")
  if (RegExp(r'^(đi )?(ăn|uống|chơi|mặc|mang|tắm biển|bơi|cắm trại|đá bóng|chạy bộ)(\s|$)').hasMatch(tg.toLowerCase())) {
    tg = '';
  } else if (hz != null) {
    // "lũ ở miền Trung" → "miền Trung"; "gió mùa đông bắc về chưa" → không có nơi
    final o = RegExp(r'\s(ở|tại)\s+').firstMatch(tg);
    tg = o != null ? tg.substring(o.end) : '';
  }
  // "quận ba" → "quận 3" (chỉ khi là quận đánh số; không áp dụng nếu phía sau là tên riêng như "Ba Đình", "Hai Bà Trưng")
  final q = RegExp(r'^(quận|quan)\s+(\S+(?:\s+(?:một|mốt|hai))?)(\s+.*)?$', caseSensitive: false).firstMatch(tg);
  if (q != null) {
    final numWord = normVi(q.group(2)!);
    final n = _quanNum[numWord];
    final sepAndRest = q.group(3) ?? '';
    final restNorm = normVi(sepAndRest.trim());
    final isNumberedDistrict = restNorm.isEmpty ||
        RegExp(r'^(phuong|tp|thanh pho|ho chi minh|tphcm|sai gon|,)', caseSensitive: false).hasMatch(restNorm);
    if (n != null && isNumberedDistrict) {
      tg = 'quận $n$sepAndRest';
    }
  }
  if (tg == c.target) return c;
  return WCmd(c.kind,
      target: tg.trim(),
      liveDay: c.liveDay,
      aspect: c.aspect,
      period: c.period,
      month: c.month,
      year: c.year,
      date: c.date,
      raw: c.raw,
      bare: c.bare && tg.trim().isNotEmpty,
      spanMonths: c.spanMonths,
      from: c.from,
      to: c.to);
}

WCmd _parseWorldCore(String raw) {
  raw = _stripVocative(raw); // "Trái Đất ơi, …", "bạn ơi …", "ơ …" ở đầu câu
  final t = _intentText(raw);
  bool i(String re) => RegExp(re).hasMatch(t);
  if (t.isEmpty) return WCmd(WKind.unknown, raw: raw);

  // lệnh điều khiển ngắn — giống bản đồ Việt Nam
  // "rừng lại", "giừng lại": giọng miền Nam / bộ nhận giọng nghe "dừng" thành "rừng", "giừng"
  if (i(r'^(dung|im|thoi|stop|rung|giung|tam dung)( lai| di| doc)?$') || i(r'^(rung|giung) lai\b') ||
      i(r'\b(dung lai|im lang|tat am|tat am thanh|dung am thanh|dung moi am thanh|tat tieng|tat nhac|dung nhac|dung doc)\b')) return WCmd(WKind.stop, raw: raw);
  if (i(r'\b(tam nghi|ngung nghe|tat micro|dung nghe|tat nghe|pause|tam dung nghe|nghi mot lat|tat mic)\b')) return WCmd(WKind.pause, raw: raw);
  if (i(r'\b(cai dat|thiet lap|settings)\b')) return WCmd(WKind.settings, raw: raw);
  // ---------- F1: lịch sử thời tiết & thiên tai (trước phần trợ giúp, thiên tai đang diễn ra, khí hậu) ----------
  final wh = weatherHistoryCmdVi(raw);
  if (wh != null) return wh;
  // Hỏi về MỘT PHẦN của app ("thời tiết thế giới", "khám phá các hành tinh", "hướng dẫn địa lý")
  // hoặc hỏi app làm được gì → giới thiệu đúng phần đó (target: weather | geo | space | '' = tổng quan)
  final asksHelp = i(r'\b(tro giup|huong dan|tim hieu|lam duoc gi|lam gi duoc|noi gi|chuc nang|cach dung|dung the nao|dung nhu the nao|'
      r'gioi thieu|co nhung gi|co gi hay|giup duoc gi|giup gi|biet lam gi|help)\b');
  final topic = (i(r'\b(thoi tiet|du bao|thien tai|khi hau|mua)\b') || (i(r'\bnang\b') && !i(r'\bchuc nang\b')))
      ? 'weather'
      : i(r'\b(dia ly|quanh day|quanh ta|quanh ban|dia diem|an uong|vui choi|vi tri|ban do|dia hinh|kham pha bang tay)\b')
          ? 'geo'
          : i(r'\b(vu tru|hanh tinh|thien van|mat troi|ngoi sao)\b')
              ? 'space'
              : '';
  const sections = {
    'thoi tiet', 'phan thoi tiet', 'thoi tiet the gioi', 'thoi tiet toan cau', 'thoi tiet khap the gioi',
    'thoi tiet tren the gioi', 'xem thoi tiet the gioi', 'dia ly', 'phan dia ly', 'dia ly quanh ta', 'dia ly quanh toi',
    'dia ly quanh ban', 'dia diem quanh ban', 'kham pha quanh ban', 'phan dia diem',
    'vu tru', 'phan vu tru', 'kham pha vu tru', 'hanh tinh', 'cac hanh tinh', 'kham pha cac hanh tinh', 'kham pha hanh tinh',
    'chuyen cac hanh tinh', 'ke chuyen cac hanh tinh', 'he mat troi',
  };
  final namedPlanet = planetIn(raw);
  final namedLandmark = landmarkIn(raw);
  final landmarkListAsk = i(_landmarkListRe);
  final tr = terrainCmdVi(raw);
  final isPlaceOrAroundHelp = _adminTarget(raw) != null ||
      findHanoiZone(name: raw, matchKeywordOnly: true) != null ||
      (i(r'\b(quanh day|xung quanh|gan day|o day|cho nay|noi nay)\b') && i(r'\b(co nhung gi|co gi hay|co gi)\b'));
  if ((asksHelp &&
          !isPlaceOrAroundHelp &&
          tr == null &&
          (namedPlanet == null || namedPlanet.sound == 3 || i(r'\bhe mat troi\b')) &&
          namedLandmark == null &&
          landmarksOfProvinceIn(raw).isEmpty &&
          !landmarkListAsk) ||
      sections.contains(t)) {
    return WCmd(WKind.help, target: topic, raw: raw);
  }

  const politeHead = r'^(cho toi xin|cho minh xin|cho toi|cho minh|lam on|xin|giup toi|giup minh|hay|vui long)? *';
  const politeTail = r'( lai| di| ngay| thoi| nhe| nha| voi| gium minh| ho minh| duoc khong| giup toi| mot chut| coi| ban| nao)*$';
  if (i(r'\b(dung lai|im lang|tat am|dung doc|ngung noi|thoi dung lai|im di|dung ngay|dung di)\b') ||
      (i('$politeHead(dung|im|thoi|stop)$politeTail') && !i(r'\b(thoi tiet|thoi gian|dung the nao|dung nhu the nao|cach dung)\b'))) {
    return WCmd(WKind.stop, raw: raw);
  }
  if (i(r'\b(cai dat|thiet lap|settings)\b')) return WCmd(WKind.settings, raw: raw);

  if (i(r'\b(doc lai|nhac lai|noi lai|lap lai|repeat)\b')) return WCmd(WKind.repeat, raw: raw);
  if (i('$politeHead(to hon|to len|louder)$politeTail') ||
      (i(r'\b(noi to|bat to|cho to|tieng to|am thanh to|to hon|to len|louder)\b') &&
       !i(r'\b(phong to|thu nho|zoom|rum|ban do|toan cau|the gioi)\b'))) {
    return WCmd(WKind.louder, raw: raw);
  }
  if (i('$politeHead(nho hon|nho lai|be hon|be lai|nho thoi|be thoi|nho di|be di|quieter)$politeTail') ||
      (i(r'\b(noi nho|noi be|bat nho|cho nho|tieng nho|am thanh nho|nho hon|nho lai|be hon|be lai|quieter)\b') &&
       !i(r'\b(thu nho|phong to|zoom|rum|ban do|toan cau|the gioi)\b'))) {
    return WCmd(WKind.quieter, raw: raw);
  }
  if (i(r'\b(nhanh hon|doc nhanh|noi nhanh|doc nhanh len|nhanh len|nhanh thoi|nhanh chut|nhanh mot chut|nhanh|faster)\b')) {
    return WCmd(WKind.faster, raw: raw);
  }
  if (i(r'\b(cham hon|doc cham|cham lai|noi cham|cham thoi|cham chut|cham mot chut|tu tu thoi|tu tu|bot nhanh|slower)\b') &&
      !i(r'\bnhanh\b')) {
    return WCmd(WKind.slower, raw: raw);
  }
  // tiếng đệm, câu quá ngắn (thường là tiếng ồn hoặc nghe nhầm): bỏ qua
  if (_fillers.contains(t)) return WCmd(WKind.ignore, raw: raw);
  // lời cảm ơn / chào: đáp một câu ngắn, không hỏi AI, không tìm nơi tên "cảm ơn"
  if (i(r'^(ok |vang |da |thoi )?(cam on|cam on ban|cam on nhe|cam on nhieu|cam on ban nhe|cam on ban nhieu|cam on nhieu nhe|'
      r'cam on lang|cam on lang nhe|cam on nha|cam on ban nha|thank you|thanks|tot qua|hay qua|tuyet voi|gioi qua)( nhe| nha| a| nhieu)?$')) {
    return WCmd(WKind.ignore, target: 'thanks', raw: raw);
  }
  if (i(r'^(ban|lang|may|em) (la ai|la gi|ten (la )?gi|lam duoc gi khong)( vay| the| a| nhi)?$|^ten (cua )?ban la gi$|^ai (dang )?(noi|do)( vay)?$')) {
    return WCmd(WKind.ignore, target: 'who', raw: raw);
  }
  if (i('$politeHead(tieng anh|english)$politeTail') ||
      (i(r'\b(tieng anh|english)\b') && i(r'\b(bat|doi|chuyen|che do|noi|dung|switch|speak)\b'))) {
    return WCmd(WKind.language, target: 'en', raw: raw);
  }
  if (i('$politeHead(tieng viet|vietnamese)$politeTail') ||
      (i(r'\b(tieng viet|vietnamese)\b') && i(r'\b(bat|doi|chuyen|che do|noi|dung|switch|speak)\b'))) {
    return WCmd(WKind.language, target: 'vi', raw: raw);
  }
  // ---------- F2: bản ghi âm thật của NASA ("nghe tiếng Sputnik", "âm thanh Apollo 11", "âm thanh thật của NASA") ----------
  final ns = nasaSoundRequest(raw);
  if (ns != null) return WCmd(WKind.nasaSound, target: ns.sound?.id ?? '', aspect: ns.game ? 'game' : null, raw: raw);
  // ---------- trò chơi tìm hiểu (trước phần vũ trụ: "đố vui hành tinh" là trò chơi, không phải giới thiệu) ----------
  final g = gameKindVi(t);
  if (g != null) return WCmd(WKind.game, target: g, raw: raw);
  // ---------- vũ trụ ----------
  if (i(r'\b(anh thien van|anh vu tru|anh nasa|apod|buc anh hom nay|anh hom nay)\b')) return WCmd(WKind.apod, raw: raw);
  // Nghe tiếng / âm thanh của thiên thể ("tiếng Mặt Trăng", "tiếng Sao Hỏa", "tiếng các hành tinh", "âm thanh vũ trụ")
  final pl = planetIn(raw);
  // F2: "sự thật thú vị về Sao Hỏa" → một sự thật ngẫu nhiên (NASA) của thiên thể đó;
  // không nói tên → thiên thể đang xem, hoặc ngẫu nhiên
  if (i(r'\b(su that thu vi|su that bat ngo|dieu thu vi|dieu bat ngo|chuyen thu vi|thong tin thu vi|co gi thu vi|'
          r'mot su that|su that ve|fun fact)\b') &&
      (pl != null ||
          i(r'\b(hanh tinh|vu tru|thien the|he mat troi|ngoi sao)\b') ||
          i(r'^(cho toi |ke |noi |nghe )?(them )?(mot )?(su that thu vi|dieu thu vi|su that)( nua| khac)?( di| nhe)?$'))) {
    return WCmd(WKind.planet, target: pl?.vi ?? '', aspect: 'fact', raw: raw);
  }
  if (i(r'\b(tieng|am thanh|nghe tieng|am thanh cua|tieng cua)\b') &&
      i(r'\b(mat troi|mat trang|sao thuy|sao kim|trai dat|sao hoa|sao moc|sao tho|sao thien vuong|sao hai vuong|hanh tinh|thien the|vu tru)\b')) {
    if (pl != null) {
      return WCmd(WKind.planet, target: pl.vi, aspect: 'sound', raw: raw);
    }
    return WCmd(WKind.game, target: 'sound', raw: raw);
  }
  if (i(r'\b(he mat troi|cac hanh tinh|tam hanh tinh)\b') || i(r'^ke chuyen$')) return WCmd(WKind.planets, raw: raw);
  final story = i(r'\b(ke chuyen|ke ve|ke cho|ke di|nghe ve|gioi thieu|tap truyen|hanh tinh|tim hieu|kham pha|thien the|ngoi sao)\b');
  // ("xã Mường Hoa tỉnh …" bỏ dấu có "hoa tinh" = Hỏa tinh → đó là tên xã, không phải hành tinh)
  if (pl != null && (pl.sound != 3 || story) && !i(r'\b(moc luc|lan luc|may gio|nang|thoi tiet|nhiet do)\b') && _adminTarget(raw) == null) {
    return WCmd(WKind.planet, target: pl.vi, raw: raw);
  }
  if (i(r'\b(cac hanh tinh|he mat troi|vu tru|ke chuyen vu tru|kham pha vu tru|thien van)\b')) {
    return WCmd(WKind.planets, raw: raw);
  }
  // ---------- địa lý quanh ta ----------
  if (((i(r'^(thoat|thoat ra)\b') || i(r'^(cho toi xin|cho minh xin|cho toi|cho minh|lam on|xin|giup toi|giup minh|hay|vui long|toi muon|minh muon) *(thoat|thoat ra)\b')) && !i(r'\bdia hinh\b')) ||
      i(r'\b(ve qua dia cau|quay lai qua dia cau|tro ve qua dia cau|thoat ban do|dong ban do|tat ban do|thoat khoi ban do|'
          r'thoat re tay|tat re tay|dung re tay|thoat che do re tay)\b') ||
      // "thoát chế độ chạm" (không nói "địa hình"); có "địa hình" thì để lệnh tắt chạm địa hình bên dưới xử lý (cũng thoát)
      (i(r'\b(thoat che do cham|thoat cham|tat che do cham)\b') && !i(r'\bdia hinh\b'))) {
    return WCmd(WKind.exitLocal, raw: raw);
  }
  // ---------- địa hình (độ cao, lát cắt, chạm địa hình trên quả cầu) ----------
  if (tr != null) return tr;
  // ---------- địa danh Việt Nam: giới thiệu một nơi / kể tên theo vùng ----------
  // Phân biệt từ "mùa" (mùa nào, mùa đẹp, mùa du lịch...) với "mưa"
  final isSeasonWord = i(r'\b(mua nao|mua nay|mua gi|mua dep|mua du lich|mua hoa|bon mua|dau mua|cuoi mua)\b');
  final weatherish = !isSeasonWord && i(r'\b(thoi tiet|nhiet do|mua|nang|du bao|do am|khong khi|bao nhieu do)\b');
  final nearWord = i(r'\b(quanh|xung quanh|gan do|gan day)\b');
  final askList = i(r'\b(choi gi|di dau|co gi choi|co chi choi|co gi dep|co chi dep|noi nao dep|cho nao dep|canh dep|co dia danh chi|dia danh gi|co gi|co chi|co nhung gi|co nhung chi)\b');
  final isLandmarkListQuery = askList || i(r'\b(di choi|tham quan|co gi noi tieng|co chi noi tieng|co gi hay|co chi hay|co gi la|co chi la|noi tieng)\b');
  final provLandmarks = landmarksOfProvinceIn(raw);
  final isCommuneOrWard = i(r'\b(xa|phuong|thi tran|huyen|quan)\b');
  final hasPlacesFoodFunWord = i(r'\b(dia diem|an uong|an gi|an ngon|vui choi|giai tri|quan an|am thuc)\b');
  final hzMatch = findHanoiZone(name: raw, matchKeywordOnly: true);
  final askHanoiPlayOrFood = hzMatch != null &&
      i(r'\b(choi gi|co gi choi|co chi choi|choi o dau|di dau choi|an gi|an uong|vui choi|dia diem)\b');
  final askPlacesGuide = !weatherish &&
      !i(r'\b(hop khong|hop hong|duoc khong|duoc hong|co nen|nen khong|nen hong)\b') &&
      (hasPlacesFoodFunWord ||
          (isCommuneOrWard &&
              i(r'\b(co gi|co chi|co nhung gi|co gi hay|choi gi|di choi|di dau|du lich|tham quan|dac san|mon gi|mon ngon|co gi ngon|quanh|xung quanh|gan|gioi thieu|tim hieu|ke ve|noi tieng)\b')) ||
          (hzMatch != null &&
              i(r'\b(co gi|co chi|co nhung gi|co gi hay|choi gi|di choi|di dau|du lich|tham quan|dac san|mon gi|mon ngon|co gi ngon|quanh|xung quanh|gan|gioi thieu|tim hieu)\b')));
  final isSpecificLandmarkName = namedLandmark != null &&
      i(r'\b(pho co|vinh|kinh thanh|hoang thanh|dai noi|chua|den|lang|nha tho|bao tang|thap|dong|hang|deo|dinh|nui|ho|vuon quoc gia|thanh dia|dia dao|ben|cau|ganh|mui)\b');
  if (!weatherish &&
      !hasPlacesFoodFunWord &&
      !askHanoiPlayOrFood &&
      (!nearWord || namedLandmark == null) &&
      provLandmarks.isNotEmpty &&
      (namedLandmark == null || (askList && !isSpecificLandmarkName)) &&
      (isLandmarkListQuery || i(r'\b(tim hieu|gioi thieu)\b')) &&
      !isCommuneOrWard &&
      !i(r'\b(o day|quanh day|gan day|quanh toi|cho nay|noi nay)\b') &&
      !i(r'\b(ke ve|ke cho|ke chuyen|lich su|nam o dau|o dau|o dau day|xay nam nao)\b')) {
    final cand = _placeInQuestion(raw, extractTarget(raw));
    final target = cand.isNotEmpty ? cand : provLandmarks.first.province;
    return WCmd(WKind.landmarks, target: target, raw: raw);
  }
  if (!weatherish && !nearWord && !hasPlacesFoodFunWord && !askHanoiPlayOrFood && !isCommuneOrWard) {
    if (namedLandmark != null &&
        i(r'\b(ke ve|ke cho|ke chuyen|gioi thieu|thong tin|co gi|co chi|o dau|nam o dau|noi tieng|lich su|tim hieu|la gi|la noi nao|'
            r'dac diem|co dep|dep khong|nhu the nao|ra sao|nghe ve)\b')) {
      return WCmd(WKind.landmark, target: namedLandmark.name, raw: raw);
    }
    if (i(r'\b(ke ve|gioi thieu|thong tin ve|tim hieu ve|nghe ve) (day|noi nay|cho nay|o day|dia danh nay|noi do)\b')) {
      return WCmd(WKind.landmark, raw: raw);
    }
    if (landmarkListAsk && !isCommuneOrWard) {
      final p = provLandmarks.isNotEmpty ? provLandmarks.first.province : _placeInQuestion(raw, extractTarget(raw));
      return WCmd(WKind.landmarks, target: p, raw: raw);
    }
  }
  if (askPlacesGuide) {
    var cand = _adminTarget(raw) ?? _placeInQuestion(raw, extractTarget(raw));
    if (cand.isEmpty) {
      final hz = findHanoiZone(name: raw, matchKeywordOnly: true);
      if (hz != null) cand = hz.nameVi;
    }
    if (_onlyWeatherWords(cand)) cand = '';
    return WCmd(WKind.around, target: cand, raw: raw);
  }
  final gps = i(r'\b(toi dang o dau|toi o dau|minh dang o dau|minh o dau|vi tri cua toi|vi tri hien tai|vi tri cua minh|'
      r'vi tri may nay|noi toi dung|noi toi dang dung|cho toi dung|cho toi dang dung|toi dang dung o dau|toi dung o dau|'
      r'xac dinh vi tri|dinh vi vi tri|quanh toi|xung quanh toi|gan toi|where am i|my location)\b');
  // Câu hỏi kiến thức / giải thích nguyên nhân ("tại sao trời lại mưa", "vì sao có bão", "nguyên nhân động đất", "tại sao ban đêm tối")
  // hoặc câu hỏi văn hóa, ẩm thực, du lịch tự nhiên ("Hà Nội có món gì ngon", "Sài Gòn mùa nào đẹp nhất")
  // → Không ép thành lệnh thời tiết hay bay tới địa danh, để AI phân tích cả câu và trả lời toàn diện.
  final asksWhy = i(r'\b(tai sao|vi sao|nguyen nhan|ly do|tai vi sao|hinh thanh the nao|hinh thanh nhu the nao|sinh ra the nao|sinh ra nhu the nao|giai thich)\b');
  final cultureAsk = i(r'\b(mon gi|dac san|hoa gi|mua nao|dep nhat|con nguoi|van hoa|truyen thong|co gi ngon)\b');
  if ((asksWhy || cultureAsk) && pl == null && !story) {
    return WCmd(WKind.unknown, raw: raw);
  }

  // ---------- thiên tai, bản tin ----------
  // ("bão có về Hà Nội không", "lũ ở miền Trung": "bão", "lũ" bỏ dấu dễ trùng "báo", "lu" → xét chữ CÓ DẤU)
  final rawLow = raw.toLowerCase();
  // (không tính: tên nơi có chữ "Bão" — "xã Liên Bão"; "giông bão", "mưa bão" là hỏi mưa → phần thời tiết)
  final stormFlood = RegExp(r'(^|\s)(bão|lũ|lụt|ngập lụt|ngập nước|siêu bão|áp thấp nhiệt đới)(\s|$)').hasMatch(rawLow) &&
      !RegExp(r'(dự báo|bão hòa|bão táp|giông bão|dông bão|mưa bão)').hasMatch(rawLow) &&
      !RegExp(r'(xã|phường|thị trấn|thôn|làng|huyện|quận|ấp|bản)\s+(\S+\s+)?(bão|lũ|lụt)(\s|$)').hasMatch(rawLow) &&
      !RegExp(r'\S\s(Bão|Lũ)\b').hasMatch(raw);
  if (stormFlood ||
      i(r'\b(thien tai|canh bao|con bao|co bao|tin bao|cac con bao|bao lu|lu lut|lu quet|ngap lut|chay rung|nui lua|dong dat|sat lo|typhoon|hurricane)\b')) {
    final world = i(r'\b(the gioi|toan cau|khap noi|trai dat|cho nao|o dau|noi nao|nhung dau|nuoc nao)\b');
    return WCmd(WKind.disasters, target: world ? '' : _placeInQuestion(raw, extractTarget(raw)), aspect: world ? 'world' : null, raw: raw);
  }
  if (i(r'\b(ban tin|tin thoi tiet|tin sang)\b')) {
    return WCmd(WKind.bulletin, target: _placeInQuestion(raw, extractTarget(raw)), raw: raw);
  }
  final exploreWords = i(r'\b(kham pha bang tay|kham pha bang cham|che do cham|re tay|re ngon tay|cham de nghe|so ban do|ban do quanh|'
      r'kham pha quanh|cham ban do|ban do cham|nghe dia hinh|so tay|dung tay|kham pha dia hinh|kham pha khu vuc|kham pha noi nay|'
      r'kham pha cho nay|kham pha o day|kham pha day)\b');
  // "khám phá <một nơi>" (không phải hành tinh / vũ trụ) → bản đồ chạm quanh nơi đó
  final explorePlace = !exploreWords && i(r'^(kham pha|toi muon kham pha|cho toi kham pha|minh muon kham pha)\s+\S') &&
      planetIn(raw) == null && !i(r'\b(vu tru|hanh tinh|thien van|ngoi sao|mat troi|mat trang|he mat troi)\b');
  if (exploreWords || explorePlace) {
    // "khám phá bằng tay" / "khám phá ở đây" không kèm tên nơi → dùng nơi vừa nói tới (đã bay tới trước đó)
    final here = i(r'\b(o day|cho nay|noi nay|khu vuc nay|day)$');
    final pureExplore = i(r'\b(kham pha bang tay|kham pha bang cham|che do cham|re tay|re ngon tay|so ban do|cham de nghe|ban do cham|so tay|dung tay)\b') &&
        !i(r'\b(o|tai|quanh|xung quanh|den|toi) [a-z]');
    return WCmd(WKind.explore,
        target: gps || here || pureExplore ? '' : _placeInQuestion(raw, extractTarget(raw)), aspect: gps ? 'gps' : null, raw: raw);
  }
  if (i(r'\b(xua va nay|ngay xua|thay doi the nao|thay doi ra sao|thay doi nhu the nao|da thay doi|20 nam|30 nam|'
      r'hai muoi nam|ba muoi nam)\b')) {
    return WCmd(WKind.history, target: _placeInQuestion(raw, extractTarget(raw)), raw: raw);
  }
  final isWeatherAsk = i(r'\b(thoi tiet|mua|nang|du bao|nhiet do|lanh|ret|nong|do am|uv|khong khi|gio|bao|tam nhin)\b');
  if (gps && !isWeatherAsk) return WCmd(WKind.around, aspect: 'gps', raw: raw);
  if (!i(r'\bnhiet do\b') && i(r'\b(quanh day co gi|quanh day co nhung gi|xung quanh co gi|xung quanh co nhung gi|gan day co gi|gan day co nhung gi|quanh .+ co gi|mo ta|dia hinh|dia ly|do cao|co song|co nui|'
      r'co ho|xung quanh co|o day co gi|o day co nhung gi|cho nay co gi|noi nay co gi|gan do co gi|canh quan|xung quanh la gi|quanh day la gi|'
      r'xung quanh nhu the nao|xung quanh the nao)\b')) {
    return WCmd(WKind.around, target: _placeInQuestion(raw, extractTarget(raw)), raw: raw);
  }
  if ((pl == null || pl.sound == 3) && (i(r'\b(ca the gioi|toan the gioi|toan cau|ca qua dia cau|toan bo trai dat)\b') ||
      (i(r'\b(qua dia cau|trai dat|the gioi)\b') && !i(r'\b(khi hau|nasa|thu nho|phong to|zoom|thoi tiet|tin|thien tai)\b')))) {
    return WCmd(WKind.world, raw: raw);
  }
  if (i(r'\b(thu nho|thu nho lai|zoom out|ra xa|xa hon|quay lai|lui ra|lui ra xa|lui lai|nhin xa hon|nhin xa ra|nhin xa)\b') && !i(r'\b(phong to|zoom in)\b') && _adminTarget(raw) == null) {
    return WCmd(WKind.zoomOut, raw: raw);
  }
  if (i(r'\b(day la dau|dang xem o dau|o dau day|cho nay la dau|noi nay la dau|vi tri nay la dau)\b')) return WCmd(WKind.where, raw: raw);

  var target = _placeInQuestion(raw, extractTarget(raw));
  // "bây giờ trời", "trời có nắng", "đường có trơn"… chỉ là lời hỏi, không phải địa danh
  if (_onlyWeatherWords(target)) target = '';
  // "xã Tân Lập tỉnh Tây Ninh", "phường Hải Châu ở Đà Nẵng": giữ nguyên cả cụm từ chữ "xã/phường…" trở đi
  final adm = _adminTarget(raw);
  if (adm != null) target = adm;

  // Sửa lỗi chính tả/dấu thanh do ASR nhận diện sai cho địa danh (kể cả có tiền tố huyện/xã/phường)
  if (target.isNotEmpty) {
    for (final e in _aliasTargets.entries) {
      if (normVi(target).contains(e.key)) {
        if (normVi(target) == e.key) {
          target = e.value;
        } else {
          final parts = target.split(' ');
          for (var idx = 0; idx < parts.length; idx++) {
            for (var len = 1; len <= parts.length - idx; len++) {
              final sub = parts.sublist(idx, idx + len).join(' ');
              if (normVi(sub) == e.key) {
                parts.replaceRange(idx, idx + len, [e.value]);
                target = parts.join(' ');
                break;
              }
            }
          }
        }
      }
    }
  }
  // "nghe 24 giờ tới ở Huế": chữ "nghe" / "đọc" còn sót không phải tên nơi — tên nơi (nếu có) ở sau chữ "ở" / "tại"
  if (const {'nghe', 'nghe thu', 'doc', 'xem'}.contains(normVi(target))) {
    final ws = raw.trim().split(RegExp(r'\s+'));
    final at = ws.lastIndexWhere((w) => const {'o', 'tai'}.contains(normVi(w)));
    target = at >= 0 && at < ws.length - 1 ? extractTarget(ws.sublist(at + 1).join(' ')) : '';
  }
  // thứ trong tuần: "thứ bảy này", "chủ nhật", "thứ hai tuần sau" → số ngày từ hôm nay
  final wdOff = weekdayOffsetVi(t);

  // dự báo NHIỀU NGÀY: "3 ngày tới", "dự báo mười ngày", "tuần tới" → đọc từng ngày (tối đa 10 ngày, liveDay = số ngày)
  final nDays = wdOff == null ? forecastDaysVi(t) : null;
  if (nDays != null) {
    final clean = raw.replaceAll(_nDaysRawRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return WCmd(WKind.forecast, target: _placeInQuestion(clean, extractTarget(clean)), liveDay: nDays, raw: raw);
  }
  // cuối tuần: đọc riêng thứ bảy và chủ nhật
  if (wdOff == null && i(r'\bcuoi tuan\b')) return WCmd(WKind.forecast, target: target, aspect: 'weekend', raw: raw);


  // ("24 giờ TỚI ở Huế", "mấy ngày tới ở Đà Lạt": "tới ở" bỏ dấu cũng là "toi o" — không phải "tôi ở")
  if (target.isNotEmpty &&
      i(r'\b((?<!(gio|ngay|tuan|thang|nam|hom|sap) )toi o|minh o|nha toi o|nha minh o|que toi o|toi song o|dat noi cua toi|noi cua toi la)\b')) {
    return WCmd(WKind.setHome, target: target, raw: raw);
  }
  if (i(r'\b(gio toi|theo gio|tung gio|12 gio|24 gio|muoi hai gio|hai muoi bon gio)\b')) {
    return WCmd(WKind.hours, target: target, raw: raw);
  }
  if (i(r'\b(nghe nhac|choi nhac|nghe am thanh|nhac cu|dan bau|nghe dan|tieng dan|tieng dan bau|nghe tieng dan|bat tieng dan|bat nhac|am thanh dan|tieng nhac|nhac dan bau)\b')) return WCmd(WKind.music, target: target, raw: raw);

  // một ngày cụ thể
  final date = dateOf(raw);
  // "hôm nay nóng hơn hôm qua không" là hỏi HÔM NAY (so với hôm qua), không phải hỏi riêng hôm qua
  if (date != null && !(i(r'\b(hon|so voi)\b') && i(r'\bhom nay\b'))) {
    return WCmd(WKind.day, target: target, date: date, raw: raw);
  }

  // dữ liệu khí hậu NASA: cả chuỗi năm, hoặc một tháng / năm
  final (month, year) = _monthYear(t);
  if (i(r'\b(khi hau|nasa|cac nam|qua cac nam|bien doi khi hau|nong len|am len|xu huong|lich su)\b') ||
      month != null ||
      year != null) {
    return WCmd(WKind.climate, target: target, month: month, year: year, raw: raw);
  }

  // thời tiết
  int? day;
  if (wdOff != null) {
    day = wdOff;
  } else if (i(r'\b(ngay kia|ngay mot)\b')) {
    day = 2;
  } else if (i(r'\b(ngay mai|sang mai|trua mai|chieu mai|toi mai|dem mai|tomorrow)\b') || i(r'^mai\b') ||
      i(r'\bmai (co|troi|thi|mua|nang|lanh|nong|ret|di|o|gio)\b')) {
    day = 1;
  } else if (i(r'\b(hom nay|sang nay|trua nay|chieu nay|toi nay|dem nay|bua nay|bua ni|today)\b')) {
    day = 0;
  }
  String? period;
  for (final (k, p) in const [('sang', 'sang'), ('trua', 'trua'), ('chieu', 'chieu'), ('toi', 'toi'), ('dem', 'dem')]) {
    if (i('\\b$k (nay|mai|ngay mai|hom nay)\\b') || i('\\bbuoi $k\\b')) {
      period = p;
      break;
    }
  }
  String? aspect;
  if (i(r'\b(co mua|mua khong|co mua hong|mua hong|co mua chi|co mua chi khong|mang o|ao mua|will it rain|umbrella|luong mua|mua bao nhieu|dang mua|mua to|mua lon|mua nhieu|'
      r'mua chua|tanh mua|tanh chua|het mua|mua o dau|cho nao mua|noi nao mua|bao gio mua|may gio mua|khi nao mua|'
      r'gio thi mua|luc nao mua|khi nao thi mua|bao gio thi mua|mua luc may gio|co dong|dong set|sam set|sam chop|set danh|'
      r'mua da|mua rao|mua phun|mua a|mua den|mua toi luc|mua keo dai|sap mua|giong|giong bao|troi mua)\b')) {
    aspect = 'rain';
  }
  if (!i(r'\b(co mua|mua khong|co mua hong|mua hong|dang mua|mua chua|tanh mua|het mua|bao gio mua|may gio mua)\b') &&
      i(r'\b(nen lam gi|nen mac gi|mac gi|mac do gi|mac ao gi|ra ngoai|ra duong|co nen|mang gi|mang theo gi|chuan bi gi|chuan bi nhung gi|can gi|'
          r'luu y gi|can luu y|loi khuyen|advice|ao am|ao khoac|mac am|mac them|can chuan bi|can mang theo)\b')) {
    aspect = 'advice';
  }
  if (i(r'\b(di choi|phu hop|thich hop|hop khong|co hop|da ngoai|picnic|du lich|di dao|tap the duc|chay bo|di bien|'
      r'leo nui|cam trai|dep troi|dep khong|good day)\b')) {
    if (aspect != 'advice' || i(r'\b(phu hop|thich hop|hop khong|co hop|dep troi|dep khong|good day)\b')) {
      aspect = 'outing';
    }
  }
  // các câu cụ thể hơn thắng câu chung "có nên…"
  if (i(r'\b(khau trang|bui min)\b')) aspect = 'air';
  if (i(r'\b(mang o|ao mua|mang du|cam o|che mua)\b')) aspect = 'rain';
  if (i(r'\b(phoi (quan ao|do|chan|man|ao|giay|lua|thoc|ca)|phoi duoc|co nen phoi|kho do|do co kho|giat do)\b')) aspect = 'dry';
  if (i(r'\b(duong (co )?tron|tron truot|tron khong|an toan|nguy hiem|can than|ngap nuoc|ngap khong|bi ngap)\b')) aspect = 'advice';
  // Hỏi MỘT chỉ số → chỉ trả lời chỉ số đó (nói "thời tiết", "chi tiết" mới đọc đầy đủ)
  // ("bây giờ", "mấy giờ", "giờ tới" bỏ dấu cũng có chữ "gio" như "gió" → bỏ ra trước khi dò "gió")
  final tw = ' $t '.replaceAll(RegExp(r' (bay gio|gio toi|may gio|bao gio|gio nay|gio thi|luc may gio) '), ' ');
  if (aspect == null && !i(r'\b(thoi tiet|chi tiet|tong quan|day du|tat ca)\b')) {
    if (i(r'\b(mat troi moc|mat troi lan|troi toi|troi sang|binh minh|hoang hon|moc luc|lan luc|toi luc may gio|sunrise|sunset)\b')) {
      aspect = 'sun';
    } else if (i(r'\b(nhiet do|bao nhieu do|may do|nong khong|lanh khong|ret khong|nong bao nhieu|lanh bao nhieu|nong the nao|'
        r'lanh the nao|nong lam khong|lanh lam khong|co nong|co lanh|co ret|nong hon|lanh hon|mat hon|cam giac|nong qua|lanh qua|'
        r'ret qua|nong nhi|lanh nhi|troi lanh|troi nong|troi ret)\b')) {
      aspect = 'temp';
    } else if (i(r'\b(do am|am khong|am the nao|am bao nhieu|nom|oi buc|oi khong)\b')) {
      aspect = 'humid';
    } else if (RegExp(r'\b(toc do gio|huong gio|co gio|gio manh|gio to|gio lon|gio the nao|gio bao nhieu|gio ra sao|gio khong|nhieu gio|'
                r'gio huong nao|gio mua)\b')
            .hasMatch(tw) ||
        RegExp(r'\bgio\b.*\b(manh|lon)\b').hasMatch(tw)) {
      aspect = 'wind';
    } else if (i(r'\b(uv|tia cuc tim|nang gat|nang co gat|nang to|nang lam|chong nang|chay nang)\b')) {
      aspect = 'uv';
    } else if (i(r'\b(troi (co )?nang|co nang khong|nang khong|nhieu may|co may|am u|u am|troi am|quang may|troi quang|troi xanh|'
        r'nang hay mua|troi mu|suong mu|co suong)\b')) {
      aspect = 'sky';
    } else if (i(r'\b(khong khi|o nhiem|aqi|bui min|pm 2 5|pm25|chat luong khong khi)\b')) {
      aspect = 'air';
    }
  }
  // so sánh hai nơi: "Hà Nội và Đà Nẵng nơi nào nóng hơn", "so sánh thời tiết Huế với Đà Nẵng"
  if (i(r'\b(so sanh|hon|noi nao|cho nao)\b')) {
    final two = _twoPlaces(raw);
    if (two != null) {
      return WCmd(WKind.weather, target: '${two.$1}|${two.$2}', aspect: 'compare', liveDay: day, period: period, raw: raw);
    }
  }
  if (wdOff == null && i(r'\b(du bao|tuan nay|tuan toi|cuoi tuan|may ngay toi|bay ngay|7 ngay|5 ngay|forecast)\b')) {
    return WCmd(WKind.forecast, target: target, raw: raw);
  }
  final weatherWord = i(r'\b(thoi tiet|nhiet do|nong|lanh|mua|gio|uv|khong khi|o nhiem|do am|weather|chi so|troi)\b');
  final goWord = i(r'\b(phong to|zoom|bay|den|toi|di|xem|mo|tim|chuyen|go to|show)\b');

  if (target.isNotEmpty && (goWord || weatherWord || day != null || aspect != null)) {
    return WCmd(goWord && !weatherWord && day == null && aspect == null ? WKind.go : WKind.weather,
        target: target, liveDay: day, aspect: aspect, period: period, raw: raw);
  }
  if (weatherWord || day != null || aspect != null || i(r'\b(o day|cho nay|noi nay|doc|chi tiet)\b')) {
    return WCmd(WKind.weather, liveDay: day, aspect: aspect, period: period, raw: raw);
  }
  if ((i(r'^(phong to|zoom|zoom in|ky hon|gan hon|lai gan)\b') ||
       (i(r'\b(phong to|zoom in|ky hon|gan hon|lai gan|lai gan hon|tien lai|tien lai gan|nhin gan hon|nhin gan)\b') && !i(r'\b(thu nho|zoom out)\b'))) &&
      target.isEmpty) {
    return WCmd(WKind.zoomIn, raw: raw);
  }
  // chỉ nói một địa danh: "Paris", "Huế" → bay tới đó.
  // Chỉ coi là bare go nếu target thực sự là một địa danh hợp lệ (tránh câu nói chuyện như "bạn kể đi", "chết người..." bay lung tung).
  // "còn Ninh Bình thì sao": bỏ chữ "còn" (có dấu) trước khi xét có phải tên nơi không
  final tgt = target.replaceFirst(RegExp(r'^(thế còn|vậy còn|còn)\s+', caseSensitive: false), '');
  if (tgt.isNotEmpty && tgt.split(' ').length <= 5) {
    final target = tgt;
    final nt = normVi(target);
    final isKnownPlace = parseCommand(target).place != null ||
        cityAliases.containsKey(nt) ||
        countryAliases.containsKey(nt) ||
        _provinceFolds.contains(nt) ||
        landmarkIn(target) != null ||
        findHanoiZone(raw: target, matchKeywordOnly: true) != null || // khu Hà Nội: Tây Hồ, Cầu Giấy…
        _adminTarget(raw) != null ||
        RegExp(r'\b(bac cuc|nam cuc|hoang sa|truong sa|bien dong)\b').hasMatch(nt) ||
        RegExp(r'^(xa|phuong|thi tran|tp|thanh pho|tinh|huyen|quan|dao|vinh|nui|song|ho|cau|cho)\s').hasMatch(nt);
    if (isKnownPlace) return WCmd(WKind.go, target: target, raw: raw, bare: true);
  }
  return WCmd(WKind.unknown, raw: raw);
}

const _monthWords = <String, int>{
  'gieng': 1, 'mot': 1, 'hai': 2, 'ba': 3, 'tu': 4, 'bon': 4, 'nam': 5, 'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9,
  'muoi': 10, 'muoi mot': 11, 'muoi hai': 12, 'chap': 12,
};

(int?, int?) _monthYear(String t) {
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

/// Lời giới thiệu theo từng phần: '' tổng quan, 'weather', 'geo', 'space'.
(String, String) helpFor(String topic) => switch (topic) {
      'weather' => (
          'Phần thời tiết thế giới và 45 năm lịch sử khí hậu NASA. Bạn nói tên bất kỳ nơi nào, ví dụ: thời tiết Huế, hay phóng to Tokyo. '
              'Mình sẽ bay tới đó, diễn tấu nhiệt độ qua đàn bầu, lượng mưa qua đàn t\'rưng, rồi đọc đầy đủ chỉ số thời tiết. '
              'Bạn hỏi tự nhiên được: chiều nay có mưa không, mai đi chơi có hợp không, cần chuẩn bị gì, dự báo 5 ngày, bản tin, có bão không. '
              'Muốn nghe thời tiết bằng tiếng đàn bầu, nói: nghe nhạc. Muốn nghe khí hậu nhiều năm của NASA, nói: khí hậu Hà Nội. '
              'Muốn phát lại lịch sử thời tiết và thiên tai: lịch sử thời tiết Huế 3 năm qua, bão Yagi, hay chuỗi ấm lên toàn cầu 146 năm. '
              'Muốn nghe sét, nhiệt độ biển hay khí CO2 khắp thế giới qua hình ảnh NASA, nói: máy hát Trái Đất.',
          'Weather around the world and 45-year NASA climate history. Say any place, for example: weather in Hue. '
              'Ask: will it rain this afternoon, is tomorrow good for an outing, 5-day forecast, bulletin, any storms, or weather history of Hue over the last 3 years. '
              'Say "play music" to hear it on the dan bau.'
        ),
      'geo' => (
          'Phần địa lý và khám phá quanh bạn. Nói: chạm địa hình, để mở bản đồ chạm tay nghe sáo trúc vút cao theo độ cao SRTM, '
              'cảm nhận độ dốc sườn núi qua rung haptic, và nghe tiếng sóng, tiếng xe cộ tại các vùng nước và đô thị chuẩn NASA. '
              'Nói: quét mặt cắt địa hình, để quét lát cắt độ cao từ Bắc vào Nam hoặc từ Tây sang Đông. '
              'Nói: quanh đây có gì, tôi đang ở đâu, để nghe định vị hiện tại. '
              'Bạn cũng có thể hỏi bất kỳ xã, phường nào ở Hà Nội để nghe gợi ý địa điểm tham quan, vui chơi và ăn uống đặc sản, '
              'ví dụ: phường Hoàn Kiếm có gì chơi, phường Tây Hồ ăn gì ngon, hay xã Bát Tràng có địa điểm du lịch gì. '
              'Hoặc hỏi độ cao địa hình như: Đà Lạt cao bao nhiêu mét, đi dọc Việt Nam, xưa và nay.',
          'Around you and multimodal tactile geography. Say "what is around here", "touch terrain", or "scan the terrain". '
              'Or ask about dining, entertainment, and sightseeing in any ward or commune in Hanoi, '
              'for example: what to eat and do in Hoan Kiem ward, Tay Ho ward, or Bat Trang commune.'
        ),
      'space' => (
          'Phần khám phá vũ trụ và âm thanh thật từ NASA. Mình có mười tập truyện: Mặt Trời, tám hành tinh từ Sao Thủy đến Sao Hải Vương, và Mặt Trăng. '
              'Mỗi hành tinh có một âm thanh riêng cùng 135 sự thật kỳ thú so sánh khoa học. Bạn nói, ví dụ: kể chuyện Sao Hỏa, hay kể chuyện Sao Mộc. '
              'Giữa các đoạn truyện, bạn nói dừng, tiếp, hoặc hỏi luôn một câu, ví dụ: Sao Hỏa có mấy mặt trăng, to bằng mấy Trái Đất, lên đó nặng bao nhiêu. '
              'Nói: âm thanh thật của NASA, để nghe bản ghi âm lịch sử như bước chân Apollo 11, tiếng gió Sao Hỏa, đĩa vàng Voyager. '
              'Nói: ảnh thiên văn hôm nay, để nghe tả bức ảnh vũ trụ của NASA hôm nay. '
              'Muốn vừa chơi vừa học thì nói: trò chơi, tôi là ai, hoặc: đố âm thanh NASA.',
          'Space. There are ten stories: the Sun, the eight planets and the Moon. Say, for example: tell me about Mars. '
              'Between parts, say stop, continue, or ask a question, like: how many moons, how big is it, how much would I weigh. '
              'You can also say "fun fact about Mars", "NASA sounds", "NASA sound quiz", or "astronomy picture of the day" for NASA\'s picture.'
        ),
      _ => (
          'Lắng là quả địa cầu âm thanh hóa dữ liệu khoa học NASA bằng nhạc cụ dân tộc Việt Nam (đàn bầu, đàn t\'rưng, sáo trúc). '
              'Mình có ba phần: thời tiết khắp thế giới, địa lý và địa điểm quanh bạn, và khám phá vũ trụ. '
              'Muốn biết cách dùng phần nào, bạn nói: hướng dẫn thời tiết, hướng dẫn địa lý, hoặc hướng dẫn vũ trụ. '
              'Muốn nghe các hình ảnh dữ liệu của NASA bằng âm thanh, như ánh đèn ban đêm, sét, khí CO2, nhiệt độ biển, chiều cao rừng, nói: máy hát Trái Đất. '
              'Lúc nào cũng có thể nói: dừng lại, đọc lại, đọc chậm hơn, hoặc tạm nghỉ. Muốn nói chuyện bằng tiếng Anh, nói: chuyển sang tiếng Anh. '
              'Ở nơi ồn, nói: chế độ gọi tên, rồi bắt đầu mỗi câu bằng: Lắng ơi. '
              'Lưu ý: ứng dụng không thay cho cảnh báo chính thức của cơ quan khí tượng.',
          'Three parts: weather around the world, your surroundings, and space. Say "help weather", "help around", or "help space". '
              'To hear NASA data visualizations as sound (night lights, lightning, CO2, sea temperature, forest height), say "Earth Jukebox". '
              'You can always say stop, repeat, slower, or pause. Say "Vietnamese" to switch to Vietnamese. '
              'In a noisy place, say "wake word on", then start each request with "Hey Listen".'
        ),
    };

/// Cụm từ ưu tiên cho bộ nhận giọng (bản máy tính).
/// Từ khoá ưu tiên thêm cho bộ nhận giọng: 34 tỉnh (và tỉnh cũ), địa danh nổi bật, xã/phường, các câu thời tiết, trò chơi.
final List<String> extraHotwords = [
  for (final p in provincesNow) p,
  for (final p in provinceMerged.keys) p,
  for (final l in vnLandmarks) l.name,
  'xã', 'phường', 'thị trấn', 'đặc khu', 'tỉnh', 'thành phố',
  'độ ẩm', 'tia UV', 'mặt trời mọc', 'mặt trời lặn', 'phơi đồ', 'phơi quần áo', 'khẩu trang', 'sương mù', 'nồm', 'mấy độ',
  'bao nhiêu độ', 'cuối tuần', 'thứ bảy', 'chủ nhật', 'tuần sau', 'ngày kia', 'mấy ngày tới', 'dông', 'sấm sét', 'bao giờ tạnh',
  'mang ô', 'áo mưa', 'gió mạnh', 'nắng gắt', 'so sánh', 'nóng hơn', 'mười ngày tới',
  'trò chơi', 'đố vui', 'tôi là ai', 'nghe tiếng đoán hành tinh', 'gợi ý', 'bỏ qua', 'nhắc lại', 'chơi lại',
  'kể về', 'giới thiệu', 'địa danh nổi tiếng', 'miền Bắc', 'miền Trung', 'miền Nam', 'Tây Nguyên',
  'chạm địa hình', 'tắt chạm địa hình', 'địa hình', 'độ cao', 'cao bao nhiêu mét', 'lát cắt địa hình', 'đi dọc Việt Nam',
  'từ bắc vào nam', 'từ tây sang đông', 'núi cao nhất', 'nơi sâu nhất', 'Phan Xi Păng', 'Ngọc Linh', 'Hoàng Liên Sơn',
  'Trường Sơn', 'Bạch Mã', 'Lang Biang', 'cao nguyên', 'đồng bằng',
  'lắng ơi', 'ăn uống', 'vui chơi', 'du lịch', 'tham quan', 'địa điểm ăn uống', 'địa điểm vui chơi',
  'nguồn dữ liệu', 'dữ liệu lấy ở đâu', 'bão Yagi', 'siêu bão Yagi', 'mưa lũ miền Trung', 'điểm cháy rừng',
  'mùa cháy rừng', 'lỗ đen', 'tiếng gió Sao Hỏa', 'nóng lên toàn cầu',
  'lịch sử thời tiết', 'lịch sử thiên tai', 'sự thật thú vị', 'âm thanh thật của NASA', 'đố âm thanh NASA',
  'quét mặt cắt địa hình', 'quét địa hình', 'tiếng Sputnik', 'âm thanh Apollo 11',
];

const worldHotwords = <String>[
  'lắng ơi', 'trái đất ơi', 'chế độ gọi tên', 'luôn nghe', 'mấy mặt trăng', 'cách bao xa', 'to bằng mấy',
  'phóng to', 'thu nhỏ', 'cả thế giới', 'đây là đâu', 'đọc lại', 'dừng lại', 'trợ giúp', 'tạm nghỉ', 'nghe nhạc',
  'hai mươi bốn giờ tới', 'thời tiết', 'khí hậu', 'dữ liệu NASA', 'dự báo', 'ngày mai', 'có mưa không', 'nên làm gì',
  'Việt Nam', 'Hoàng Sa', 'Trường Sa', 'Nhật Bản', 'Hàn Quốc', 'Trung Quốc', 'Thái Lan', 'Lào', 'Campuchia', 'Pháp',
  'Mỹ', 'Anh', 'Nga', 'Úc', 'Đức', 'Ấn Độ', 'Bắc Kinh', 'Tô ky ô', 'Pa ri', 'Luân Đôn', 'Niu Oóc', 'Băng Cốc',
  'chiều nay', 'sáng mai', 'tối nay', 'bản tin', 'có bão không', 'thiên tai', 'tôi đang ở đâu', 'quanh đây có gì',
  'khám phá bằng tay', 'thoát', 'xưa và nay', 'các hành tinh', 'kể chuyện', 'Sao Thủy', 'Sao Kim', 'Sao Hỏa', 'Sao Mộc',
  'Sao Thổ', 'Sao Thiên Vương', 'Sao Hải Vương', 'Mặt Trời', 'Mặt Trăng', 'ảnh thiên văn', 'tiếp', 'đi chơi',
];

const _numVi = {
  'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4, 'tu': 4, 'nam': 5, 'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9, 'muoi': 10,
};
final _nDaysRawRe = RegExp(
    r'(dự báo\s+)?(\d{1,2}|một|hai|ba|bốn|tư|năm|sáu|bảy|tám|chín|mười)(\s+\w+)?\s+ngày(\s+(tới|tiếp theo|tiếp|sắp tới|nữa|sau|đến))?',
    caseSensitive: false);

/// Số ngày người dùng muốn nghe dự báo ("2 ngày tới", "dự báo mười ngày", "tuần tới" = 7). null nếu không hỏi kiểu này.
/// Lớn hơn 10 vẫn trả về (app báo chỉ có tối đa 10 ngày).
int? forecastDaysVi(String t) {
  final m = RegExp(r'\b(\d{1,2}|mot|hai|ba|bon|tu|nam|sau|bay|tam|chin|muoi(?: (?:mot|hai|ba|bon|lam|nam|sau|bay|tam|chin))?) ngay'
          r'( (toi|tiep theo|tiep|sap toi|nua|den|ke tiep))?\b')
      .firstMatch(t);
  if (m != null) {
    final hasNext = m.group(2) != null;
    final forecastWord = RegExp(r'\b(du bao|thoi tiet|mua|nhiet do|nang)\b').hasMatch(t);
    if (hasNext || forecastWord) {
      final w = m.group(1)!;
      final n = int.tryParse(w) ??
          (w.startsWith('muoi ') ? 10 + (_numVi[w.substring(5)] ?? (w.endsWith('lam') ? 5 : 0)) : _numVi[w]);
      if (n != null && n >= 1) return n;
    }
  }
  if (RegExp(r'\b(tuan toi|tuan nay|mot tuan|bay ngay toi|tuan sau)\b').hasMatch(t)) return 7;
  if (RegExp(r'\b(hai tuan|nua thang)\b').hasMatch(t)) return 14;
  return null;
}

/// Hỏi kể tên địa danh nổi bật ("miền Trung có địa danh gì nổi tiếng", "Tây Nguyên có gì đẹp", "nên đi đâu chơi").
const _landmarkListRe = r'\b(dia danh|danh lam|danh thang|thang canh|di tich|diem du lich|cho nao dep|noi nao dep|co gi dep|co chi dep|'
    r'di dau choi|nen di dau|co gi noi tieng|co chi noi tieng|noi nao noi tieng|cho nao noi tieng|canh dep|du lich o dau|co gi choi|co chi choi)\b';

/// Người dùng muốn chơi trò nào: 'quiz' | 'riddle' | 'sound' | '' (chưa chọn) | null (không phải hỏi chơi).
String? gameKindVi(String t) {
  // "đi chơi thứ ba có mưa không", "chơi thứ hai có nắng không": "thứ ba/hai" là NGÀY TRONG TUẦN, không phải trò số 3/2
  final weekday = RegExp(r'\b(di choi|ra ngoai|thoi tiet|mua|nang|nong|lanh|ret|troi|nhiet do|gio|co hop|duoc khong|nen di)\b').hasMatch(t) &&
      !RegExp(r'\b(tro|tro choi|game)\b').hasMatch(t);
  bool i(String re) => !weekday && RegExp(re).hasMatch(t);
  // "thoát trò chơi", "không chơi nữa": là RA KHỎI trò chơi, không phải mở danh sách trò
  if (RegExp(r'\b(thoat|ra khoi|ket thuc|dung choi|bo choi|khong choi|thoi choi|het choi|nghi choi)\b').hasMatch(t)) return null;

  final sound = i(r'\b(nghe tieng doan|doan qua tieng|doan qua am thanh|nghe am thanh doan|tro nghe tieng|doan tieng|tieng nhac|am thanh hanh tinh)\b') ||
      i(r'\b(tro|tro choi|tron)\s*(thu\s*|so\s*)?(ba|3)\b') ||
      i(r'\b(chon|choi|lay|vao)\s+(?:tro\s+|cai\s+|so\s+|phuong an\s+|lua chon\s+)?(?:thu\s+)?(?:ba|3)\b') ||
      i(r'\b(?:thu\s+ba|so\s+ba)\s+(?:lua chon|co ma)\b') ||
      i(r'^(tro\s+ba|so\s+ba|ba|nghe tieng|tieng nhac)$');

  final riddle = i(r'\b(toi la ai|minh la ai|cau do|do me|giai do|doan hanh tinh|doan xem la ai)\b') ||
      i(r'\b(tro|tro choi|tron)\s*(thu\s*|so\s*)?(hai|2)\b') ||
      i(r'\b(chon|choi|lay|vao)\s+(?:tro\s+|cai\s+|so\s+|phuong an\s+|lua chon\s+)?(?:thu\s+)?(?:hai|2)\b') ||
      i(r'\b(?:thu\s+hai|so\s+hai)\s+(?:lua chon|co ma)\b') ||
      i(r'^(tro\s+hai|so\s+hai|hai|toi la ai|doan hanh tinh)$');

  // "đố tôi" chỉ tính ở ĐẦU câu ("nhiệt độ tối nay" bỏ dấu cũng có "do toi")
  final quiz = i(r'\b(do vui|trac nghiem|hoi dap vui|quiz|kiem tra kien thuc)\b') ||
      i(r'^(do toi|do minh|do em|do con)\b') ||
      i(r'\b(tro|tro choi|tron)\s*(thu\s*|so\s*)?(mot|1|nhat)\b') ||
      i(r'\b(chon|choi|lay|vao)\s+(?:tro\s+|cai\s+|so\s+|phuong an\s+|lua chon\s+)?(?:thu\s+)?(?:mot|1|nhat)\b') ||
      i(r'\b(?:thu\s+(?:nhat|mot)|so\s+mot)\s+(?:lua chon|co ma)\b') ||
      i(r'^(tro\s+mot|so\s+mot|mot|do vui|trac nghiem)$');

  final isPlacePlay = i(r'\b(vui choi|di choi|dia diem|an uong|du lich|tham quan|xa|phuong|thi tran|quan|huyen|tinh|thanh pho|quanh|xung quanh)\b') ||
      i(r'\b(o|tai) [a-z]');
  final game = i(r'\b(tro choi|choi game|choi tro|game|choi do|thu thach|chon tro|bao chon tro|toi bao chon tro|vao tro|mo tro|danh sach tro choi)\b') ||
      (!isPlacePlay && i(r'\bchoi gi\b'));

  if (sound) return 'sound';
  if (riddle) return 'riddle';
  if (quiz) return 'quiz';
  if (game) return '';
  return null;
}

// ---------------- hỗ trợ câu hỏi thời tiết ----------------

const _vocatives = [
  'lang nguoi oi', 'la nguoi oi', 'ban lang oi',
  'lang nguoi', 'la nguoi', 'lang oi', 'e lang', 'lang ne', 'hey lang', 'nang oi',
  'qua dia cau oi', 'trai dat oi', 'earthsense oi', 'earth sense oi', 'earth oi',
  'hey listen', 'hey sense', 'sense oi',
  'cho minh hoi', 'cho toi hoi', 'ban oi', 'em oi', 'oi ban', 'oi em', 'oi anh', 'anh oi', 'chi oi', 'oi chi',
  'alo', 'a lo', 'listen', 'sense', 'oi', 'o', 'e',
  'nay', 'u', 'um', 'uhm', 'ok', 'oke',
];

/// Bỏ lời gọi / tiếng đệm ở đầu câu ("Trái Đất ơi thời tiết Hà Nội" → "thời tiết Hà Nội"). Không còn gì thì giữ nguyên.
String _stripVocative(String raw) {
  var words = raw.trim().split(RegExp(r'\s+'));
  var changed = true;
  while (changed && words.length > 1) {
    changed = false;
    final ns = [for (final w in words) normVi(w)];
    for (final v in _vocatives) {
      final vw = v.split(' ');
      if (ns.length > vw.length && ns.take(vw.length).join(' ') == v) {
        words = words.sublist(vw.length);
        changed = true;
        break;
      }
    }
  }
  return words.join(' ');
}

/// Từ chỉ dùng để hỏi thời tiết (không bao giờ là cả một địa danh).
const _weatherVocab = {
  'troi', 'bay', 'gio', 'ngoai', 'nang', 'co', 'khong', 'may', 'am', 'u', 'dong', 'sam', 'set', 'mua', 'huong', 'nao',
  'manh', 'to', 'duong', 'tron', 'di', 'bo', 'an', 'toan', 'phoi', 'quan', 'ao', 'do', 'mat', 'moc', 'lan', 'toi',
  'nhiet', 'cao', 'nhat', 'thap', 'hom', 'nay', 'qua', 'nong', 'lanh', 'ret', 'khau', 'trang', 'deo', 'bui', 'min',
  'kem', 'chong', 'luong', 'bao', 'nhieu', 'dang', 'the', 'sao', 'ra', 'lam', 'con', 'thi', 'nhi', 'a', 'oi', 'dep',
  'xau', 'nhu', 'luc', 'khi', 'tanh', 'chua', 'sang', 'chieu', 'dem', 'trua', 'gat', 'tia', 'cuc', 'tim', 'chi', 'so',
  'cam', 'giac', 'hon', 'duoc', 'nen', 'mac', 'gi', 'can', 'mang', 'o', 'day', 'cho', 'dau', 'cuoi', 'tuan', 'thu',
  'chu', 'hai', 'ba', 'tu', 'nam', 'sau', 'quang', 'xanh', 'mu', 'binh', 'minh', 'hoang', 'ngay', 'mai', 'kia', 'buc',
  'nom', 'hien', 'tai', 'luon', 'van', 'roi', 'chay', 'rao', 'phun', 'chin', 'muoi', 'tam', 'bon', 'mot',
  'tram', 'nghin', 'phan', 'khoang', 'mi', 'li', 'met', 'ki', 'lo', 'chuc',
};

bool onlyWeatherWords(String target) {
  final nt = normVi(target);
  final ws = nt.split(' ').where((w) => w.isNotEmpty).toList();
  if (ws.isEmpty || !ws.every(_weatherVocab.contains)) return false;
  // tên nơi có thật trùng chữ hỏi thời tiết ("Đà Nẵng" bỏ dấu là "da nang" như "đã nắng") → vẫn là địa danh
  if (parseCommand(target).place != null || countryAliases.containsKey(nt) || cityAliases.containsKey(nt)) return false;
  // tên tỉnh (mới / cũ) hay tên xã có thật: "Bình Dương" bỏ dấu "binh duong" trùng chữ "đường" → vẫn là địa danh
  if (_provinceFolds.contains(nt)) return false;
  if (ws.length >= 2 && (vnPlaceNameKnownExact?.call(target) ?? false)) return false;
  return true;
}

bool _onlyWeatherWords(String target) => onlyWeatherWords(target);

final _provinceFolds = {for (final p in [...provincesNow, ...provinceMerged.keys]) normVi(p)};

/// Số ngày từ hôm nay tới thứ được nhắc ("thứ bảy này" → 0..6; "thứ hai tuần sau" khi hôm nay là thứ hai → 7). null nếu không nhắc.
int? weekdayOffsetVi(String t, {DateTime? now}) {
  // Không nhận nhầm số thứ tự chọn trò / câu trả lời / chọn phần ("trò thứ hai", "phần thứ hai", "đáp án thứ ba") thành ngày trong tuần
  if (RegExp(r'\b(tro|choi|game|chon|lua chon|cau|dap an|phuong an|phan|muc)\b').hasMatch(t)) {
    if (!RegExp(r'\b(thoi tiet|du bao|nhiet do|mua|nang|tuan|ngay|hom)\b').hasMatch(t)) {
      return null;
    }
  }
  final m = RegExp(r'\b(thu (hai|ba|tu|nam|sau|bay)|chu nhat)\b').firstMatch(t);
  if (m == null) return null;
  const wd = {'hai': 1, 'ba': 2, 'tu': 3, 'nam': 4, 'sau': 5, 'bay': 6};
  final w = m.group(2) == null ? 7 : wd[m.group(2)]!;
  final today = (now ?? DateTime.now()).weekday;
  var d = (w - today + 7) % 7;
  if (d == 0 && RegExp(r'\b(tuan sau|tuan toi)\b').hasMatch(t)) d = 7;
  return d;
}

const _cmpStop = {
  'nong', 'lanh', 'mat', 'hon', 'mua', 'co', 'khong', 'the', 'ra', 'sao', 'dau', 'bay', 'hom', 'ngay', 'nhieu', 'it',
  'nhu', 'thoi', 'tiet', 'nao', 'gio', 'am', 'dep',
};

/// Hai nơi trong câu so sánh ("Hà Nội và Đà Nẵng nơi nào nóng hơn" → (Hà Nội, Đà Nẵng)). null nếu không đủ hai nơi.
(String, String)? _twoPlaces(String raw) {
  final words = raw.trim().split(RegExp(r'\s+'));
  final ns = [for (final w in words) normVi(w)];
  final k = ns.indexWhere((w) => w == 'va' || w == 'voi' || w == 'hay');
  if (k <= 0 || k >= ns.length - 1) return null;
  // vế trái: bỏ "so sánh", "thời tiết", "giữa", "ở"… đứng đầu
  var a = 0;
  while (a < k && const {'so', 'sanh', 'thoi', 'tiet', 'giua', 'o', 'tai', 'xem', 'nhiet', 'do', 'cua'}.contains(ns[a])) {
    a++;
  }
  // vế phải: dừng ở "nơi nào", "chỗ nào", "ở đâu" hoặc từ so sánh
  var b = k + 1;
  if (b < ns.length && ns[b] == 'o') b++;
  var e = b;
  while (e < ns.length) {
    final bi = e + 1 < ns.length ? '${ns[e]} ${ns[e + 1]}' : '';
    if (_cmpStop.contains(ns[e]) || bi == 'noi nao' || bi == 'cho nao' || bi == 'o dau' || bi == 'ben nao') break;
    e++;
  }
  String clean(List<String> ws) => ws.join(' ').replaceAll(RegExp(r'[,.!?]'), '').trim();
  final left = clean(words.sublist(a, k)), right = clean(words.sublist(b, e));
  if (left.isEmpty || right.isEmpty || left.split(' ').length > 5 || right.split(' ').length > 5) return null;
  if (_onlyWeatherWords(left) || _onlyWeatherWords(right)) return null;
  return (left, right);
}

final _provinceSeqs = [
  for (final p in [...provincesNow, ...provinceMerged.keys]) normVi(p).split(' '),
];

/// Từ thứ [j] có nằm trong một tên tỉnh (mới / cũ) không — "Đắk Nông" có "nông" nhưng không phải "nóng".
bool _inProvinceName(List<String> ns, int j) {
  for (final seq in _provinceSeqs) {
    for (var st = j - seq.length + 1; st <= j; st++) {
      if (st < 0 || st + seq.length > ns.length) continue;
      var ok = true;
      for (var q = 0; q < seq.length; q++) {
        if (ns[st + q] != seq[q]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
  }
  return false;
}

/// Có xã, phường, huyện (mới hoặc cũ) tên này không — app gán khi đã nạp danh bạ hành chính (vn_gazetteer.dart).
/// Giúp tách đủ tên dài / tên có chữ trùng từ hỏi: "xã Tân Mai" ("mai" = ngày mai), "xã Tam Đảo", "phường Hải Đăng".
bool Function(String folded)? vnPlaceNameKnown;

/// Như [vnPlaceNameKnown] nhưng so cả dấu (tên viết như người dùng nói) — để không nối nhầm từ hỏi vào tên
/// ("phường Láng có mưa" ≠ "Lăng Cô").
bool Function(String exactText)? vnPlaceNameKnownExact;

/// Cụm địa danh bắt đầu bằng "xã", "phường", "thị trấn", "huyện", "quận", "thôn", "ấp"… (kèm cả tên tỉnh phía sau).
String? _adminTarget(String raw) {
  final words = raw.trim().replaceAll(RegExp(r'[,.;?!]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty && normVi(w).isNotEmpty).toList();
  final ns = [for (final w in words) normVi(w)];
  const notName = {'ao', 'hon', 'qua', 'lam', 'khong', 'nhat', 'the', 'tam', 'trong', 'sat', 'xoi', 'oi', 'nao', 'day', 'gan', 'xa', 'ra', 'lai'};
  const stop = {'co', 'thoi', 'the', 'ra', 'bay', 'hom', 'ngay', 'mai', 'sang', 'chieu', 'toi', 'dem', 'trua', 'mua', 'nhiet', 'bao',
    'may', 'nong', 'lanh', 'gio', 'troi', 'du', 'luc', 'khi', 'nhu', 'dang', 'se', 'thi', 'nhe', 'nha', 'vay', 'khong', 'hien', 'nay',
    'cao', 'dia'}; // "xã Mường Hoa cao bao nhiêu", "xã X địa hình…" (tên có chữ "Cao" đã được danh bạ nhận ở trên)
  final known = vnPlaceNameKnown;
  for (var k = 0; k < ns.length - 1; k++) {
    final two = k + 2 < ns.length ? '${ns[k]} ${ns[k + 1]}' : '';
    final isDistanceXa = ns[k] == 'xa' && (
      (k > 0 && const {'bao', 'ra', 'lui', 'nhin', 'qua', 'rat', 'cang'}.contains(ns[k - 1])) ||
      (k + 1 < ns.length && const {'rua', 'vay'}.contains(ns[k + 1]))
    );
    var n = isDistanceXa ? 0 : (const {'thi tran', 'thi xa', 'dac khu'}.contains(two) ? 2 : (const {'xa', 'phuong', 'huyen', 'quan', 'thon', 'ap'}.contains(ns[k]) ? 1 : 0));
    // "thành phố Dĩ An", "thành phố Bắc Ninh" (thành phố cũ cấp huyện): chỉ khi danh bạ biết tên đó
    if (n == 0 && two == 'thanh pho' && known != null) {
      for (var j = k + 3; j <= ns.length && j <= k + 6; j++) {
        if (known(ns.sublist(k + 2, j).join(' '))) {
          n = 2;
          break;
        }
      }
    }
    if (n == 0 || k + n >= ns.length) continue;
    // tên có trong danh bạ hành chính: lấy tên DÀI NHẤT khớp (≤ 7 tiếng), kể cả khi có chữ trùng từ hỏi
    var kn = -1;
    if (known != null) {
      for (var j = (k + n + 7).clamp(0, ns.length); j > k + n; j--) {
        if (!known(ns.sublist(k + n, j).join(' '))) continue;
        // phần nối thêm có từ hỏi ("có", "mai", "nay"…) → phải khớp cả dấu mới nhận
        final hasStop = ns.sublist(k + n + 1, j).any(stop.contains);
        final ex = vnPlaceNameKnownExact;
        if (hasStop && (ex == null || !ex(words.sublist(k + n, j).join(' ')))) continue;
        kn = j;
        break;
      }
    }
    if (kn < 0 && notName.contains(ns[k + n])) continue;
    // phần sau tên: tên tỉnh (nếu có) rồi tới các từ hỏi ("có mưa không", "thế nào", "hôm nay"…) thì dừng
    var e = ns.length;
    const stopTwo = {
      'an gi', 'an uong', 'an ngon', 'an o', 'choi gi', 'choi o', 'di choi', 'di dau',
      'vui choi', 'du lich', 'tham quan', 'giai tri', 'nen di', 'nen an', 'mon gi',
      'mon ngon', 'dac san', 'quan an', 'dia diem', 'o dau', 'cho nao', 'noi nao',
      'uong ca', 'ca phe', 'dao mat', 'hong gio', 'di dao', 'ngam canh', 'cuoi tuan',
      'noi tieng', 'co nhung', 'tim hieu', 'gioi thieu',
    };
    for (var j = kn > 0 ? kn : k + n + 1; j < ns.length; j++) { // từ đầu tiên của tên luôn giữ ("xã Mai Lâm", "phường Thị Cầu")
      final isCanGio = ns[j] == 'gio' && j > 0 && ns[j - 1] == 'can';
      final isAlias = j > 0 && _aliasTargets.containsKey('${ns[j - 1]} ${ns[j]}');
      final isLastWord = j == ns.length - 1 && j == k + n + 1;
      final bi = j + 1 < ns.length ? '${ns[j]} ${ns[j + 1]}' : '';
      if (stopTwo.contains(bi) && !_inProvinceName(ns, j)) {
        e = j;
        break;
      }
      if (stop.contains(ns[j]) && !_inProvinceName(ns, j) && !isCanGio && !isAlias && !isLastWord) {
        e = j;
        break;
      }
    }
    if (e <= k + n) continue;
    return words.sublist(k, e).join(' ');
  }
  return null;
}



/// Lệnh địa hình (tiếng Việt), null nếu câu không hỏi về địa hình / độ cao.
///  "chạm địa hình", "địa hình nổi" → touch · "tắt chạm địa hình" → off
///  "Đà Lạt cao bao nhiêu mét", "độ cao của Sa Pa" → height · "địa hình ở Huế thế nào" → describe
///  "địa hình Việt Nam", "địa hình thế giới" → overview (target 'vn' | 'world')
///  "đi dọc Việt Nam", "địa hình từ bắc vào nam" → spine · "lát cắt địa hình Đà Lạt" → profile (aspect 'profile', period 'ns' | 'ew')
///  "địa hình từ Hà Nội đến Sa Pa" → path (target "Hà Nội|Sa Pa") · "núi cao nhất Việt Nam / thế giới" → peak · "nơi sâu nhất" → deep
WCmd? terrainCmdVi(String raw) {
  final t = _intentText(raw);
  bool i(String re) => RegExp(re).hasMatch(t);
  // nước sông, sóng biển, thuỷ triều "cao bao nhiêu" là chuyện lũ / biển, không phải độ cao địa hình
  if (i(r'\b(muc nuoc(?! bien)|song bien|song cao|thuy trieu|trieu cuong|nuoc lu|lu len|nuoc dang|dinh lu)\b')) return null;
  // câu thời tiết ("Đà Nẵng" bỏ dấu có "nang" — không phải "nắng"; "nhiệt độ cao nhất" không phải "độ cao")
  if (i(r'\b(thoi tiet|nhiet do|mua|(?<!da )nang|du bao|do am|gio|khong khi|bao nhieu do|lanh|ret|tuyet|suong mu)\b') &&
      !i(r'\b(dia hinh|(?<!nhiet )do cao|cao bao nhieu|cao may met)\b')) {
    return null;
  }
  if (i(r'\b(tat|thoat|dung|bo) (che do )?(cham )?dia hinh( noi)?\b')) return WCmd(WKind.terrain, aspect: 'off', raw: raw);
  if (i(r'\b(cham dia hinh|so dia hinh|che do dia hinh|dia hinh noi|cam nhan dia hinh|re tay tren qua (dia )?cau|cham (len |vao )?qua (dia )?cau|'
      r'so (len |vao )?qua (dia )?cau|dia hinh 3d|dia hinh ba chieu|ban do noi|qua cau noi|nghe dia hinh tren qua (dia )?cau)\b')) {
    return WCmd(WKind.terrain, aspect: 'touch', raw: raw);
  }
  final terrainWord = i(r'\b(dia hinh|(?<!nhiet )do cao|lat cat|mat cat|cat ngang)\b');
  if (i(r'\b(di doc viet nam|doc viet nam|doc dat nuoc|doc chieu dai (viet nam|dat nuoc)|chay doc viet nam)\b') ||
      (i(r'\b(tu bac vao nam|tu bac xuong nam|tu nam ra bac|tu dau den cuoi)\b') &&
          (i(r'\b(viet nam|dat nuoc|nuoc ta)\b') || (terrainWord && _terrainTarget(raw).isEmpty)))) {
    return WCmd(WKind.terrain, aspect: 'spine', raw: raw);
  }
  if (terrainWord) {
    final ft = _fromToPlaces(raw);
    if (ft != null) return WCmd(WKind.terrain, aspect: 'path', target: '${ft.$1}|${ft.$2}', raw: raw);
  }
  // F3: quét mặt cắt địa hình (bản đồ độ cao của khu vực, lát quét Bắc → Nam rồi Tây → Đông, tiếng sáo theo độ cao)
  if (i(r'\b(quet (mat cat |lat cat |do cao )?(dia hinh|khu vuc|vung)|quet mat cat|quet lat cat|quet do cao|'
      r'am thanh (cua )?dia hinh|nghe am thanh dia hinh|tieng (cua )?dia hinh|nghe tieng dia hinh)\b')) {
    return WCmd(WKind.terrain, aspect: 'scan', target: _terrainTarget(raw), raw: raw);
  }
  if (i(r'\b(lat cat|mat cat|cat ngang)\b') || (terrainWord && i(r'\b(tu tay sang dong|tu dong sang tay|tu bac xuong nam|tu nam len bac)\b'))) {
    // chỉ coi là bắc–nam khi nói rõ hướng (tên "Nam Định", "Bắc Ninh" không tính)
    final ns = i(r'\b(tu bac|tu nam|bac xuong nam|bac vao nam|nam ra bac|nam len bac|chieu bac nam|huong bac nam|bac nam|doc)\b') &&
        !i(r'\b(tu tay|tu dong|tay sang dong|dong sang tay)\b');
    return WCmd(WKind.terrain, aspect: 'profile', period: ns ? 'ns' : 'ew', target: _terrainTarget(raw), raw: raw);
  }
  // nơi sâu nhất: chỉ khi nói về biển / đại dương / thế giới (không phải "hồ sâu nhất", "sông sâu nhất")
  if (i(r'\b(rang? mariana|ranh ma ri a na|ranh mariana|vuc challenger)\b') ||
      (i(r'\b(sau nhat)\b') && i(r'\b(bien|dai duong|the gioi|trai dat|toan cau)\b') && !i(r'\b(ho|song|gieng|hang)\b'))) {
    return WCmd(WKind.terrain, aspect: 'deep', raw: raw);
  }
  if (i(r'\b(nui cao nhat|dinh cao nhat|dinh nui cao nhat|ngon nui cao nhat|noi cao nhat|nui nao cao nhat|dinh nao cao nhat|'
      r'noi nao cao nhat|ngon nui nao cao nhat|noc nha (dong duong|the gioi|viet nam|chau a))\b')) {
    return WCmd(WKind.terrain, aspect: 'peak', target: _peakRegionVi(t), raw: raw);
  }
  final pk = peakIn(raw);
  // "dài / rộng / cách bao nhiêu mét" là đo khoảng cách, không phải độ cao
  final otherMeasure = i(r'\b(dai|rong|xa|cach|chieu dai|be ngang|dien tich|chu vi|be rong)\b') && !i(r'\b(cao|sau|do cao)\b');
  if (!otherMeasure &&
      (i(r'\b((?<!nhiet )do cao|cao bao nhieu|cao may met|bao nhieu met|cao hon mat bien|so voi mat (nuoc )?bien|so voi muc nuoc bien|sau bao nhieu)\b') ||
          (pk != null && i(r'\b(cao khong|cao lam khong|cao the nao|cao nhu the nao)\b')))) {
    return WCmd(WKind.terrain, aspect: 'height', target: pk?.vi ?? _terrainTarget(raw), raw: raw);
  }
  // "nghe địa hình" (không kèm gì) vẫn là bản đồ chạm quanh một nơi như trước
  if (i(r'\bdia hinh\b') && !i(r'\b(kham pha|ban do cham|bang tay|xung quanh co|quanh day co)\b') && t != 'nghe dia hinh') {
    final tg = _terrainTarget(raw);
    final ntg = normVi(tg);
    if (ntg.isEmpty && i(r'\b(viet nam|nuoc ta)\b') || ntg == 'viet nam' || ntg == 'nuoc ta') {
      return WCmd(WKind.terrain, aspect: 'overview', target: 'vn', raw: raw);
    }
    if (i(r'\b(the gioi|trai dat|toan cau)\b') && (ntg.isEmpty || const {'the gioi', 'trai dat', 'toan cau'}.contains(ntg))) {
      return WCmd(WKind.terrain, aspect: 'overview', target: 'world', raw: raw);
    }
    return WCmd(WKind.terrain, aspect: 'describe', target: tg, raw: raw);
  }
  return null;
}

/// Vùng của câu "núi cao nhất …": 'world' | 'vn' | tên tiếng Anh của đỉnh (xem [peaks]) | '' (chưa nói → Việt Nam).
String _peakRegionVi(String t) {
  bool i(String re) => RegExp(re).hasMatch(t);
  if (i(r'\bchau phi\b')) return 'Kilimanjaro';
  if (i(r'\b(chau au)\b')) return 'Mount Elbrus';
  if (i(r'\b(alps|an po|anpo)\b')) return 'Mont Blanc';
  if (i(r'\bbac my\b')) return 'Denali';
  if (i(r'\b(nam my|chau my)\b')) return 'Aconcagua';
  if (i(r'\bdong nam a\b')) return 'Hkakabo Razi';
  if (i(r'\bnhat ban\b')) return 'Mount Fuji';
  if (i(r'\b(malaysia|ma lai)\b')) return 'Mount Kinabalu';
  if (i(r'\b(the gioi|trai dat|toan cau|chau a|noc nha the gioi)\b')) return 'world';
  if (i(r'\b(viet nam|nuoc ta|dong duong)\b')) return 'vn';
  return '';
}

/// Tên nơi trong câu hỏi địa hình: bỏ các cụm hỏi ("độ cao của", "cao bao nhiêu mét", "thế nào"…), giữ dấu.
String _terrainTarget(String raw) {
  var words = raw.trim().replaceAll(RegExp(r'[,.;?!]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  var ns = [for (final w in words) normVi(w)];
  const phrases = [
    // dài trước: "nằm ở độ cao bao nhiêu mét" phải bỏ cả cụm, không để sót "nằm ở độ"
    'nam o do cao bao nhieu met', 'o do cao bao nhieu met', 'do cao bao nhieu met', 'nam o do cao bao nhieu', 'o do cao bao nhieu',
    'do cao bao nhieu', 'nam o do cao', 'o do cao', 'co do cao',
    'so voi muc nuoc bien', 'so voi mat nuoc bien', 'tren muc nuoc bien', 'so voi mat bien', 'cao bao nhieu met', 'sau bao nhieu met',
    'cao bao nhieu', 'sau bao nhieu', 'cao may met', 'bao nhieu met', 'cao hon mat bien', 'nhu the nao', 'the nao', 'ra sao', 'nhu nao',
    // KHÔNG gộp "của", "ở", "vùng" vào cụm: bỏ dấu thì "của" = "Cửa Lò", "vùng" = "Vũng Tàu" → để bước bỏ từ đầu / cuối (so cả dấu) lo
    'quet mat cat', 'quet lat cat', 'quet do cao', 'nghe am thanh', 'am thanh cua', 'am thanh', 'tieng cua', 'nghe tieng', 'quet',
    'do cao', 'dia hinh', 'lat cat', 'mat cat', 'cat ngang', 'tu tay sang dong', 'tu dong sang tay', 'tu bac xuong nam', 'tu nam len bac',
    'tu bac vao nam', 'tu nam ra bac', 'tu dau den cuoi',
    'cho toi biet', 'cho minh biet', 'cho toi hoi', 'cho minh hoi', 'ban oi', 'mo ta', 'gioi thieu', 'cao khong',
    'cao lam khong', 'hien tai', 'la bao nhieu', 'khoang bao nhieu', 'la gi', 'the nao vay',
    'theo chieu bac nam', 'theo huong bac nam', 'chieu bac nam', 'theo chieu dong tay', 'chieu dong tay', 'theo chieu tay dong',
    'ke cho toi nghe ve', 'ke cho minh nghe ve', 'ke ve', 'noi ve', 'tim hieu ve', 'tim hieu', 'nghe ve', 'bao nhieu',
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (final p in phrases) {
      final pw = p.split(' ');
      for (var k = 0; k + pw.length <= ns.length; k++) {
        if (ns.sublist(k, k + pw.length).join(' ') == p) {
          words = [...words.sublist(0, k), ...words.sublist(k + pw.length)];
          ns = [...ns.sublist(0, k), ...ns.sublist(k + pw.length)];
          changed = true;
          break;
        }
      }
    }
  }
  // chỉ bỏ ở ĐẦU / CUỐI và so CẢ DẤU: "hả" ≠ "Hà Nội", "của" ≠ "Cửa Lò", "nghe" ≠ "Nghệ An", "có" ≠ "Cô Tô"
  const edgeExact = {'là', 'thì', 'vậy', 'nhỉ', 'à', 'ạ', 'có', 'không', 'ở', 'tại', 'của', 'hả', 'nhé', 'hỏi', 'mét', 'nghe',
    'xem', 'qua', 'đi', 'cho', 'vùng', 'khu', 'nơi', 'bạn', 'ơi', 'gì', 'đó', 'nằm', 'đang', 'vực'};
  // từ đầu câu có thể viết hoa ("Ở Đà Lạt…"); từ cuối viết hoa là tên ("Mường Nhé", "Phú Quý") → giữ
  bool isEdge(int k) => edgeExact.contains(k == 0 ? words[k].toLowerCase() : words[k]);
  while (ns.isNotEmpty && isEdge(0)) {
    ns = ns.sublist(1);
    words = words.sublist(1);
  }
  while (ns.isNotEmpty && isEdge(ns.length - 1)) {
    ns = ns.sublist(0, ns.length - 1);
    words = words.sublist(0, words.length - 1);
  }
  final s = words.join(' ');
  if (const {'day', 'nay', 'cho nay', 'noi nay', 'o day', 'quanh day', 'khu nay', 'vung nay', 'khu vuc nay', 'toi', 'minh', 'noi day', 'cho toi', 'toi dang'}
      .contains(normVi(s))) {
    return '';
  }
  return s;
}

/// "từ Hà Nội đến Sa Pa" → (Hà Nội, Sa Pa); bỏ qua hướng ("từ bắc vào nam").
(String, String)? _fromToPlaces(String raw) {
  final words = raw.trim().replaceAll(RegExp(r'[,.;?!]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final ns = [for (final w in words) normVi(w)];
  final a = ns.indexOf('tu');
  if (a < 0) return null;
  var b = -1;
  for (var k = a + 2; k < ns.length; k++) {
    if (const {'den', 'toi', 'sang', 'ra', 'vao', 'len', 'xuong'}.contains(ns[k])) {
      b = k;
      break;
    }
  }
  if (b < 0 || b >= ns.length - 1) return null;
  const dirs = {'bac', 'nam', 'dong', 'tay', 'dau', 'cuoi', 'tren', 'duoi', 'trai', 'phai'};
  var e = ns.length;
  for (var k = b + 1; k < ns.length; k++) {
    if (const {'the', 'nhu', 'ra', 'co', 'thi', 'nhe', 'di', 'nao', 'cao', 'doc'}.contains(ns[k]) && k > b + 1) {
      e = k;
      break;
    }
  }
  final left = words.sublist(a + 1, b).join(' '), right = words.sublist(b + 1, e).join(' ');
  if (left.isEmpty || right.isEmpty) return null;
  if (dirs.contains(normVi(left)) || dirs.contains(normVi(right))) return null;
  if (left.split(' ').length > 5 || right.split(' ').length > 5) return null;
  return (left, right);
}

/// Câu chỉ toàn tiếng ậm ừ lúc người nói đang nghĩ ("ừm à ờ", "ờ thì", "uh hmm") — không phải lệnh, app im lặng chờ.
bool isFillerOnly(String raw) {
  final t = normVi(raw).trim();
  if (t.isEmpty) return true;
  return RegExp(r'^((u|um|umm|uh|uhm|a|o|oi|e|hm|hmm|hum|ha|ah|eh|oh|ua|ui|thi|la|nhi|alo|a lo|vang|da|roi)\s*)+$').hasMatch(t);
}

/// Đổi một số nguyên (0..999) thành chữ tiếng Việt không dấu (để so khớp với giọng nhận dạng).
String numToWordsVi(int n) {
  if (n < 0 || n > 999) return '$n';
  const units = ['khong', 'mot', 'hai', 'ba', 'bon', 'nam', 'sau', 'bay', 'tam', 'chin'];
  if (n < 10) return units[n];
  if (n < 20) {
    if (n == 10) return 'muoi';
    final u = n % 10;
    return 'muoi ${u == 5 ? "lam" : units[u]}';
  }
  if (n < 100) {
    final t = n ~/ 10, u = n % 10;
    final tens = '${units[t]} muoi';
    if (u == 0) return tens;
    if (u == 1) return '$tens mot';
    if (u == 4) return '$tens tu';
    if (u == 5) return '$tens lam';
    return '$tens ${units[u]}';
  }
  final h = n ~/ 100, rem = n % 100;
  final hundreds = '${units[h]} tram';
  if (rem == 0) return hundreds;
  if (rem < 10) return '$hundreds linh ${units[rem]}';
  return '$hundreds ${numToWordsVi(rem)}';
}

/// Chuyển các chữ số trong câu thành cả chữ số lẫn chữ viết (để micro thu được "mười hai độ" vẫn khớp với "12 độ").
String expandDigitsVi(String text) {
  return text.replaceAllMapped(RegExp(r'\b\d{1,3}\b'), (m) {
    final v = int.tryParse(m.group(0)!);
    if (v == null) return m.group(0)!;
    final w = numToWordsVi(v);
    return '${m.group(0)} $w';
  });
}

/// Câu vừa nghe có phải TIẾNG VỌNG từ loa (micro thu lại câu app vừa đọc) không.
/// [spoken]: các câu app đã đọc gần đây (đã bỏ dấu) và đã bao lâu kể từ lúc bắt đầu đọc.
bool isEchoOf(String heard, List<(String, Duration)> spoken, {required bool speaking}) {
  final hNorm = normVi(heard).replaceAll('muoi nam', 'muoi lam');
  final h = hNorm.split(' ').where((w) => w.isNotEmpty).toList();
  if (h.isEmpty) return false;
  final hStr = h.join(' ');

  for (final (txt, ago) in spoken) {
    // Mở rộng chữ số thành chữ viết (vd 12 → 12 muoi hai) để khớp với ASR
    final expanded = expandDigitsVi(txt);
    final wNorm = normVi(expanded).replaceAll('muoi nam', 'muoi lam');
    final w = wNorm.split(' ').where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) continue;
    final wStr = w.join(' ');
    final wWordsOnly = w.where((x) => int.tryParse(x) == null).join(' ');
    // ~12 ký tự mỗi giây + 2,5 giây dư: quá thời gian đó thì câu app đọc đã xong lâu, micro không thể thu lại nữa
    final readMs = txt.length * 1000 ~/ 12 + 2500;
    if (!speaking && ago.inMilliseconds > readMs) continue;

    // 1. KHI ĐANG NÓI (speaking == true):
    // Bất kỳ đoạn chữ nào nằm trong câu app đang đọc (kể cả 1-2 từ) đều là tiếng loa vọng lại micro.
    if (speaking) {
      if (wStr.contains(hStr) || (wWordsOnly.isNotEmpty && wWordsOnly.contains(hStr))) return true;
      if (h.length >= 2 && _lcs(h, w) >= h.length) return true;
    }

    // 2. BẮT ĐUÔI CÂU (Tail Echo):
    // Micro rất hay thu lại 1..4 từ cuối cùng của câu app vừa đọc xong (vd: "bạn muốn nghe gì", "nói lại nhé", "mỗi chiều", "rải rác", "nghe gì").
    // Nếu câu nghe được trùng với phần đuôi (tối đa 7 từ cuối) của câu app vừa đọc:
    // Đây 100% là tiếng vọng đuôi câu từ loa, phải chặn để không rơi vào vòng lặp vô tận.
    if (h.length >= 2 || speaking) {
      final tailLen = math.min(7, w.length);
      final tail = w.sublist(w.length - tailLen);
      final tailStr = tail.join(' ');
      final tailWordsOnly = tail.where((x) => int.tryParse(x) == null).join(' ');
      if (tailStr.contains(hStr) || (tailWordsOnly.isNotEmpty && tailWordsOnly.contains(hStr))) return true;
      if (h.length >= 2 && _lcs(h, tail) >= h.length) return true;
    }

    // 3. KHI ĐÃ NÓI XONG (!speaking):
    // Câu ngắn (<= 4 từ) mà KHÔNG nằm ở đuôi câu: là người dùng nói theo gợi ý (vd "khám phá vũ trụ", "Sao Hỏa").
    if (!speaking && h.length <= 4) continue;

    // 4. CÂU DÀI HƠN: kiểm tra trùng lặp theo cửa sổ trượt
    var best = 0;
    final win = h.length + 2;
    for (var j = 0; j < w.length; j++) {
      final seg = w.sublist(j, math.min(w.length, j + win));
      final m = _lcs(h, seg);
      if (m > best) best = m;
      if (j + win >= w.length) break;
    }
    if (best >= 3 && best / h.length >= 0.75) return true;
  }
  return false;
}

/// Độ dài dãy con chung dài nhất (theo thứ tự, không cần liền nhau) của hai dãy chữ.
int _lcs(List<String> a, List<String> b) {
  var prev = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      cur[j] = a[i - 1] == b[j - 1] ? prev[j - 1] + 1 : math.max(prev[j], cur[j - 1]);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Câu nghe được có vẻ CHƯA NÓI XONG (người nói ngập ngừng giữa câu, bộ nghe đã chốt): kết thúc bằng chữ nối /
/// đầu lệnh còn thiếu phần sau ("thời tiết ở", "kể về", "nhiệt độ", "từ Hà Nội đến"). App nghe thêm một nhịp rồi ghép.
bool looksUnfinished(String raw) {
  final t = normVi(raw).trim();
  if (t.isEmpty) return false;
  final ws = t.split(' ');
  const tails = {
    // KHÔNG có 'xa' (bao xa), 'tu' (thứ tư), 'hay' (chuyện hay), 'sang' (sáng): câu đã xong cũng hay kết bằng các chữ đó
    'o', 'tai', 'cua', 'cho', 've', 'den', 'va', 'voi', 'thi', 'la', 'nhu', 'hoac', 'quanh', 'gan',
    'phuong', 'huyen', 'quan', 'tinh', 'chuyen', 'muon', 'can',
    // tiếng đệm cuối câu = người nói đang nghĩ tiếp ("thời tiết Hà Nội ờ…", "cho mình hỏi là…")
    'u', 'um', 'uhm', 'hmm', 'ma', 'nhung', 'hay la', 'kieu', 'kieu nhu', 'hoi',
  };
  if (tails.contains(ws.last) || (ws.length >= 2 && tails.contains('${ws[ws.length - 2]} ${ws.last}'))) return true;
  // cả câu chỉ là ĐẦU LỆNH, thiếu nơi chốn / đối tượng ("nhiệt độ", "kể về", "độ cao", "dự báo thời tiết")
  const heads = {
    'thoi tiet', 'nhiet do', 'do cao', 'ke ve', 'ke chuyen', 'ke cho toi', 'gioi thieu', 'tim hieu', 'tim hieu ve', 'bay den', 'bay toi',
    'di den', 'di toi', 'du bao', 'du bao thoi tiet', 'cho toi biet', 'cho minh biet', 'cho toi nghe', 'cho minh hoi',
    'cho toi hoi', 'toi muon', 'minh muon', 'toi muon nghe', 'minh muon nghe', 'lat cat', 'dia hinh tu', 'thoi tiet xa', 'nhiet do xa', 'chuyen sang', 'thoi tiet ngay',
    'thoi tiet thang', 'nhiet do o', 'xa thi', 'thoi tiet o', 'thoi tiet tai',
  };
  return heads.contains(t);
}

/// Người dùng nói thêm NGAY sau khi app vừa bắt đầu trả lời — phần đuôi câu bị cắt vì ngập ngừng
/// ("thời tiết Hà Nội" … "ngày mai có mưa không", "kể về Sao Hỏa" … "có mấy mặt trăng").
/// Trả về câu ghép để làm lại cho đúng ý, hoặc null nếu đây là câu mới / lệnh dừng.
/// [since]: thời gian từ lúc nghe câu trước. Chỉ ghép trong vài giây đầu (app vừa mới bắt đầu nói).
// câu trước chưa có nơi chốn: không có tên nơi, hoặc chỉ là mở phần hướng dẫn ("thời tiết" → help/weather)
bool _noPlace(WCmd c) => c.kind == WKind.help || c.target.isEmpty;

String? mergeAfterthought(String prev, String add, Duration since) {
  if (prev.trim().isEmpty || since > const Duration(seconds: 5)) return null;
  final a = normVi(add).trim();
  if (a.isEmpty || isFillerOnly(add)) return null;
  // dừng, chữa lời ("không phải", "nhầm") → không ghép
  if (RegExp(r'^(dung|thoi|im|stop|khong phai|nham|sai roi|huy)\b').hasMatch(a)) return null;
  const openers = r'^(ngay mai|ngay kia|hom nay|toi nay|dem nay|chieu nay|sang nay|trua nay|sang mai|chieu mai|toi mai|'
      r'bay gio|luc nay|tuan nay|tuan sau|tuan toi|cuoi tuan|may ngay toi|thu (hai|ba|tu|nam|sau|bay)|chu nhat|'
      r'co mua|co nong|co lanh|co ret|co gio|co bao|co nang|co can|co nen|co may|co bao nhieu|co gi|co nhung gi|'
      r'mua khong|nong khong|lanh khong|the nao|ra sao|nhu the nao|bao nhieu do|may do|nhiet do|do am|gio manh|'
      r'chi so|di choi|nen mac|can mang|mang o|ao mua|duoc khong|to bang|cach (trai dat|mat troi)|nang bao nhieu|'
      r'voi|va|cua|thuoc|nhe|nha)\b';
  final open = RegExp(openers).hasMatch(a);
  // "… ở Đà Nẵng": chỉ ghép khi câu trước CHƯA có nơi chốn (không thì là đổi ý, câu mới)
  final placeTail = RegExp(r'^(o|tai|phuong|xa|quan|huyen|tinh|thanh pho)\b').hasMatch(a) && _noPlace(parseWorld(prev));
  if (!open && !placeTail) return null;
  return '${prev.trim()} ${add.trim()}';
}
