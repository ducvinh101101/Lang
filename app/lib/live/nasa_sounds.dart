// F2 — BẢN GHI ÂM THẬT CỦA NASA (NASA Historical Sounds): Sputnik, Apollo 11, Apollo 13, sóng vô tuyến Sao Thổ,
// Enceladus, sấm sét Sao Mộc, plasma liên sao (Voyager 1), mã Morse gửi Juno, ánh sáng sao (Kepler), bụi sao chổi.
// File mp3 ở assets/sounds/nasa/, danh mục ở assets/sounds/nasa/catalog.json (pipeline/nasa_sounds.py).
// Thuần Dart (trừ phần nạp file) để test được.
import 'dart:convert';
import 'dart:math' as math;

import '../features/voice/commands.dart' show normVi;

class NasaSound {
  final String id, file;
  final double durationS;
  final String titleVi, titleEn, introVi, introEn;
  final List<String> keys; // đã bỏ dấu
  final int body; // thiên thể liên quan (chỉ số âm thanh hành tinh)
  final String credit, sourceName, sourceUrl;
  final NasaSoundQuiz? quiz;

  const NasaSound({
    this.quiz,
    required this.id,
    required this.file,
    required this.durationS,
    required this.titleVi,
    required this.titleEn,
    required this.introVi,
    required this.introEn,
    required this.keys,
    this.body = 0,
    this.credit = 'NASA',
    this.sourceName = '',
    this.sourceUrl = '',
  });

  String get assetPath => 'assets/sounds/nasa/$file';

  /// Danh mục đã nạp (rỗng nếu chưa nạp) — bộ hiểu lệnh dùng để nhận tên bản ghi.
  static List<NasaSound> loaded = const [];

  factory NasaSound.fromJson(Map<String, dynamic> j) => NasaSound(
        id: '${j['id']}',
        file: '${j['file']}',
        durationS: (j['duration_s'] as num?)?.toDouble() ?? 5,
        titleVi: '${j['title_vi'] ?? ''}',
        titleEn: '${j['title_en'] ?? ''}',
        introVi: '${j['intro_vi'] ?? ''}',
        introEn: '${j['intro_en'] ?? ''}',
        keys: [for (final k in (j['keys'] as List? ?? const [])) normVi('$k')],
        body: (j['body'] as num?)?.toInt() ?? 0,
        credit: '${j['credit'] ?? 'NASA'}',
        sourceName: '${j['source_name'] ?? ''}',
        sourceUrl: '${j['source_url'] ?? ''}',
        quiz: j['quiz'] is Map ? NasaSoundQuiz.fromJson(j['quiz'] as Map<String, dynamic>) : null,
      );

  static List<NasaSound> parseCatalog(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    return [for (final it in (j['items'] as List? ?? const [])) NasaSound.fromJson(it as Map<String, dynamic>)];
  }
}

/// Câu hỏi 2 lựa chọn của trò "Đố âm thanh NASA".
class NasaSoundQuiz {
  final String qVi, qEn;
  final List<String> optsVi, optsEn;
  final int answer;
  const NasaSoundQuiz(this.qVi, this.qEn, this.optsVi, this.optsEn, this.answer);

  factory NasaSoundQuiz.fromJson(Map<String, dynamic> j) => NasaSoundQuiz(
        '${j['q_vi']}',
        '${j['q_en']}',
        [for (final o in j['opts_vi'] as List) '$o'],
        [for (final o in j['opts_en'] as List) '$o'],
        (j['answer'] as num?)?.toInt() ?? 0,
      );

  /// Xáo thứ tự đáp án (đáp án đúng không luôn ở vị trí một).
  NasaSoundQuiz shuffled(math.Random r) {
    final idx = List<int>.generate(optsVi.length, (i) => i)..shuffle(r);
    return NasaSoundQuiz(qVi, qEn, [for (final i in idx) optsVi[i]], [for (final i in idx) optsEn[i]], idx.indexOf(answer));
  }
}

/// Chọn [n] bản ghi có câu hỏi cho một lượt chơi (không trùng).
List<NasaSound> nasaGameRound(math.Random r, List<NasaSound> all, {int n = 3}) =>
    (all.where((s) => s.quiz != null).toList()..shuffle(r)).take(n).toList();

// muốn CHƠI / NGHE KỂ (trò "Đố âm thanh NASA", theo khung truyện – minigame của data_nasa)
final _gameCue = RegExp(r'\b(tro choi|choi|do vui|do am thanh|doan|ke chuyen|truyen|game|story|quiz)\b');

// từ cho biết người dùng muốn NGHE (tránh nhận nhầm câu hỏi kiến thức "Voyager là gì" thành lệnh phát)
final _listenCue = RegExp(r'\b(tieng|am thanh|nghe|ban ghi|ghi am|thu am|phat|mo|sound|sounds|hear|listen|play|recording)\b');
final _allCue = RegExp(r'\b(am thanh that|ban ghi am|ban ghi that|tieng that|am thanh nasa|tieng nasa|ban ghi nasa|'
    r'am thanh lich su|am thanh vu tru that|real sounds?|nasa sounds?|nasa recordings?|historical sounds?)\b');

/// Kết quả nhận lệnh: một bản ghi cụ thể, hoặc [all] = đọc danh sách các bản ghi.
({NasaSound? sound, bool all, bool game})? nasaSoundRequest(String raw, [List<NasaSound>? catalog]) {
  final list = catalog ?? NasaSound.loaded;
  if (list.isEmpty) return null;
  final t = ' ${normVi(raw)} ';
  final cue = _listenCue.hasMatch(t);
  NasaSound? best;
  var bestLen = 0;
  for (final s in list) {
    for (final k in s.keys) {
      if (k.isEmpty || !t.contains(' $k ')) continue;
      if (k.length > bestLen) {
        best = s;
        bestLen = k.length;
      }
    }
  }
  final game = _gameCue.hasMatch(t);
  if (best != null && (cue || game)) {
    return (sound: best, all: false, game: game && !RegExp(r'\b(nghe|hear|listen)\b').hasMatch(t));
  }
  if (_allCue.hasMatch(t) || (game && RegExp(r'\b(am thanh nasa|nasa sounds?|ban ghi nasa)\b').hasMatch(t))) {
    return (sound: null, all: true, game: game);
  }
  return null;
}
