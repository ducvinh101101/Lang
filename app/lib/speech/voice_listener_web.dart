// NHẬN GIỌNG NÓI trên bản WEB: dùng Web Speech API của trình duyệt (SpeechRecognition, tiếng Việt vi-VN),
// giống nút micro của bản web gốc. Có trên Chrome và Edge (cần mạng); Firefox/Safari cũ không có → app mời gõ lệnh.
// Cùng giao diện với bản máy tính (voice_listener_io.dart) nên bảng "Nói lệnh" không phải sửa gì.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../features/globe/world_commands.dart' show looksUnfinished;
import 'listen_types.dart';
import 'nvidia_asr.dart';

JSFunction? _ctor() {
  final a = globalContext['SpeechRecognition'];
  if (a != null && a.isA<JSFunction>()) return a as JSFunction;
  final b = globalContext['webkitSpeechRecognition'];
  if (b != null && b.isA<JSFunction>()) return b as JSFunction;
  return null;
}

class VoiceListener {
  VoiceListener({this.log, this.nvidiaAsr});
  final void Function(String)? log;

  /// Bộ nhận giọng đám mây NVIDIA NIM làm kênh dự phòng.
  NvidiaAsr? nvidiaAsr;

  /// Ngôn ngữ đang nghe: 'vi' | 'en'.
  String lang = 'vi';

  JSObject? _rec;
  Completer<ListenResult>? _session;

  /// Mã lỗi gần nhất của trình duyệt ('network', 'not-allowed', 'service-not-allowed', 'audio-capture'…), '' nếu không.
  String lastError = '';

  /// Ghi diễn biến nhận giọng ra Console của trình duyệt (F12) — để biết vì sao "nói mà không phản hồi".
  static void _trace(String msg) {
    try {
      (globalContext['console'] as JSObject).callMethod('info'.toJS, '[Lắng micro] $msg'.toJS);
    } catch (_) {}
  }
  /// Nghe liên tục (tự quyết điểm dừng câu) trên máy tính; Android giữ chế độ một câu.
  static final bool _continuous = () {
    try {
      final ua = ((globalContext['navigator'] as JSObject)['userAgent'] as JSString).toDart;
      return !RegExp('Android|iPhone|iPad', caseSensitive: false).hasMatch(ua);
    } catch (_) {
      return false;
    }
  }();

  bool get listening => _session != null;
  bool get ready => _ctor() != null;

  /// Trình duyệt có nhận giọng nói không.
  static Future<bool> bundled() async => _ctor() != null;

  Future<bool> prepare() async => _ctor() != null;

  /// Cùng giao diện với bản cài trên máy: web dùng bộ nghe của trình duyệt, không phải tải mô hình.
  static Future<bool> modelReady(String lang) async => true;
  Future<bool> prepareLang(String l) async => _ctor() != null;
  void Function(int pct)? onDownload;

  Future<ListenResult> listen({
    void Function(double level)? onLevel,
    void Function()? onSpeech,
    double maxSeconds = 7,
    double waitSeconds = 5,
  }) async {
    await cancel();
    final ctor = _ctor();
    if (ctor == null) return const ListenResult(ListenEnd.error);
    final session = Completer<ListenResult>();
    _session = session;
    // chỉ phiên nghe LỆNH chính mới nghe liên tục; phiên ngắn lúc app đang nói (ngắt lời) giữ một câu, kẻo gom cả tiếng loa
    final cont = _continuous && waitSeconds >= 5;
    var latest = ''; // chữ tạm mới nhất: trình duyệt dừng mà chưa kịp chốt thì vẫn dùng được
    void finish(ListenResult r) {
      if (!identical(_session, session)) return;
      // dừng / im lặng / bị huỷ nhưng đã nghe được chữ tạm → coi như đã nghe câu đó (đỡ mất lệnh)
      if (r.end == ListenEnd.silence && latest.isNotEmpty) r = ListenResult(ListenEnd.heard, latest.toLowerCase());
      _session = null;
      if (!session.isCompleted) session.complete(r);
    }

    try {
      final rec = ctor.callAsConstructor<JSObject>();
      _rec = rec;
      rec['lang'] = (lang == 'en' ? 'en-US' : 'vi-VN').toJS;
      // nhận cả kết quả tạm: tiếng Việt máy chủ Google chốt chậm hơn tiếng Anh → chữ tạm đứng yên ~0,7 giây là chốt luôn
      rec['interimResults'] = true.toJS;
      // Máy tính: nghe LIÊN TỤC và tự quyết khi nào người nói xong — trình duyệt tự chốt câu sau ~0,7 giây im lặng,
      // nên người ngập ngừng ("thời tiết… ở Hà Nội") bị cắt mất nửa sau. Android: Chrome chế độ liên tục lặp chữ → giữ cũ.
      rec['continuous'] = cont.toJS;
      rec['maxAlternatives'] = 1.toJS;
      rec['onstart'] = ((JSAny? _) => _trace('bắt đầu nghe (${lang == 'en' ? 'en-US' : 'vi-VN'})')).toJS;
      rec['onaudiostart'] = ((JSAny? _) => _trace('micro đã mở')).toJS;
      rec['onspeechstart'] = ((JSAny? _) {
        _trace('nghe thấy tiếng nói');
        onLevel?.call(0.6);
        onSpeech?.call();
      }).toJS;
      Timer? settle;
      rec['onresult'] = ((JSObject ev) {
        try {
          // Edge/Chrome có thể chia câu thành nhiều đoạn kết quả → ghép tất cả lại
          final results = ev['results'] as JSObject;
          final n = (results['length'] as JSNumber?)?.toDartInt ?? 1;
          final buf = StringBuffer();
          var isFinal = n > 0;
          for (var k = 0; k < n; k++) {
            final r = results['$k'] as JSObject?;
            if (r == null) continue;
            final alt = r['0'] as JSObject;
            buf.write('${(alt['transcript'] as JSString).toDart} ');
            final fin = r['isFinal'];
            if (!(fin != null && fin.isA<JSBoolean>() && (fin as JSBoolean).toDart)) isFinal = false;
          }
          final text = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
          _trace('${isFinal ? 'chốt' : 'tạm'}: "$text"');
          if (isFinal && !cont) {
            settle?.cancel();
            if (text.isNotEmpty) latest = text;
            finish(latest.isEmpty ? const ListenResult(ListenEnd.silence) : ListenResult(ListenEnd.heard, latest.toLowerCase()));
            return;
          }
          if (isFinal) {
            // chế độ liên tục: trình duyệt đã chốt một đoạn (sau ~0,7 giây im) — chờ thêm một nhịp xem người nói còn
            // nói tiếp không; câu trông chưa xong ("thời tiết ở…", "cho mình hỏi là…") chờ lâu hơn
            if (text.isNotEmpty) latest = text;
            settle?.cancel();
            if (latest.isEmpty) return;
            settle = Timer(Duration(milliseconds: looksUnfinished(latest) ? 2000 : 700), () {
              if (!identical(_session, session) || latest.isEmpty) return;
              finish(ListenResult(ListenEnd.heard, latest.toLowerCase()));
              try {
                rec.callMethod('abort'.toJS);
              } catch (_) {}
            });
            return;
          }
          if (text.isEmpty || text == latest) return;
          latest = text;
          settle?.cancel();
          // Chữ tạm đứng yên bao lâu thì chốt: 0,7 giây cắt mất nửa sau khi người nói ngập ngừng ("thời tiết… ở Hà Nội").
          // Câu trông chưa xong (kết thúc bằng "ở", "về", "thời tiết"…) chờ lâu hơn; trình duyệt tự chốt thì vẫn nhận ngay.
          settle = Timer(Duration(milliseconds: (looksUnfinished(latest) ? 2200 : 1200) + (cont ? 500 : 0)), () {
            if (!identical(_session, session) || latest.isEmpty) return;
            finish(ListenResult(ListenEnd.heard, latest.toLowerCase()));
            try {
              rec.callMethod('abort'.toJS);
            } catch (_) {}
          });
        } catch (e) {
          log?.call('[nhận giọng web] $e');
          finish(const ListenResult(ListenEnd.error));
        }
      }).toJS;
      rec['onerror'] = ((JSObject ev) {
        final err = ev['error'];
        final code = err != null && err.isA<JSString>() ? (err as JSString).toDart : '';
        log?.call('[nhận giọng web] lỗi: $code');
        _trace('lỗi: $code');
        if (code != 'no-speech' && code != 'aborted') lastError = code;
        switch (code) {
          case 'no-speech':
          case 'aborted':
            finish(const ListenResult(ListenEnd.silence));
          case 'not-allowed':
          case 'service-not-allowed':
          case 'audio-capture':
            finish(const ListenResult(ListenEnd.noMic));
          default:
            finish(const ListenResult(ListenEnd.error));
        }
      }).toJS;
      rec['onend'] = ((JSAny? _) {
        _trace('kết thúc phiên nghe');
        finish(const ListenResult(ListenEnd.silence));
      }).toJS;
      rec.callMethod('start'.toJS);
      onLevel?.call(0.15);
      // Trình duyệt tự dừng khi người nói ngừng; chốt thêm thời gian tối đa cho chắc
      unawaited(Future<void>.delayed(Duration(milliseconds: ((waitSeconds + maxSeconds) * 1000).round()), () {
        if (identical(_session, session)) {
          try {
            rec.callMethod('stop'.toJS);
          } catch (_) {}
        }
      }));
      // Chrome/Edge đôi khi KHÔNG gọi onend sau khi dừng → vòng nghe kẹt mãi, nói gì app cũng không phản hồi.
      // Quá hạn thêm 2,5 giây mà phiên vẫn mở → tự đóng (dùng chữ tạm nếu có) và huỷ hẳn bộ nhận cũ.
      unawaited(Future<void>.delayed(Duration(milliseconds: ((waitSeconds + maxSeconds) * 1000).round() + 2500), () {
        if (!identical(_session, session)) return;
        log?.call('[nhận giọng web] trình duyệt không báo kết thúc → tự đóng phiên nghe');
        finish(const ListenResult(ListenEnd.silence));
        try {
          rec.callMethod('abort'.toJS);
        } catch (_) {}
      }));
    } catch (e) {
      log?.call('[nhận giọng web] không mở được: $e');
      _trace('không mở được: $e');
      lastError = 'start-failed';
      finish(const ListenResult(ListenEnd.noMic));
    }
    return session.future;
  }

  /// Người dùng bấm "nói xong": trình duyệt dừng nghe và trả kết quả ngay.
  void finishNow() {
    final rec = _rec;
    if (rec == null || _session == null) return;
    try {
      rec.callMethod('stop'.toJS);
    } catch (_) {}
  }

  Future<void> cancel() async {
    final s = _session;
    _session = null;
    final rec = _rec;
    _rec = null;
    if (rec != null) {
      try {
        rec.callMethod('abort'.toJS);
      } catch (_) {}
    }
    if (s != null && !s.isCompleted) s.complete(const ListenResult(ListenEnd.cancelled));
  }
}
