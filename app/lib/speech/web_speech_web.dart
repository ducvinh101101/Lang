// GIỌNG ĐỌC CỦA TRÌNH DUYỆT, CÓ CHỐNG "IM LẶNG" (bản web).
// speechSynthesis của Chrome / Edge hay im mà không báo lỗi: giọng "Online/Natural" mất mạng, câu dài quá ~15 giây
// bị cắt, nói ngay sau cancel() thì bị nuốt, tab vừa quay lại thì đang "paused". Ở đây:
//   • chia câu dài thành đoạn ngắn (≤ 170 ký tự) và đọc lần lượt
//   • resume() trước mỗi lần đọc, chờ một nhịp sau cancel()
//   • 1,5 giây chưa thấy bắt đầu đọc → đọc lại; giọng online lỗi → chuyển sang giọng có sẵn trong máy
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class WebSpeech {
  static JSObject? get _synth {
    final s = globalContext['speechSynthesis'];
    return s != null && s.isA<JSObject>() ? s as JSObject : null;
  }

  static bool get supported => _synth != null && globalContext.has('SpeechSynthesisUtterance');

  static bool _speaking = false;
  static bool get speaking => _speaking;

  /// Giọng online bị lỗi trong lần dùng này → chỉ dùng giọng có sẵn trong máy.
  static bool _onlineBad = false;

  /// Trình duyệt có giọng cho ngôn ngữ này không ('vi' / 'en'). Chrome nạp danh sách giọng chậm: gọi lại sau là đúng.
  static bool hasVoice(String lang) => _voices().any((v) => _s(v, 'lang').toLowerCase().startsWith(lang));

  /// Số giọng trình duyệt đã nạp (0 = có thể chưa nạp xong).
  static int get voiceCount => _voices().length;

  static bool _unlocked = false;

  /// Safari / iPadOS chỉ cho đọc khi lần đọc ĐẦU TIÊN nằm trong một thao tác của người dùng (chạm, bấm phím).
  /// App thường tự nói câu chào trước khi ai chạm → bị chặn im lặng, trong khi tiếng gió… (Web Audio) vẫn kêu.
  /// Gọi hàm này ngay trong sự kiện chạm: đọc một câu rỗng để "mở khoá" giọng đọc cho cả phiên.
  static void unlock() {
    if (_unlocked) return;
    final synth = _synth;
    if (synth == null || !globalContext.has('SpeechSynthesisUtterance')) return;
    try {
      final ctor = globalContext['SpeechSynthesisUtterance'] as JSFunction;
      final u = ctor.callAsConstructor<JSObject>(' '.toJS);
      u['volume'] = 0.toJS;
      synth.callMethod('resume'.toJS);
      synth.callMethod('speak'.toJS, u);
      _unlocked = true;
    } catch (_) {}
  }

  static String get _ua {
    try {
      final nav = globalContext['navigator'] as JSObject;
      return _s(nav, 'userAgent');
    } catch (_) {
      return '';
    }
  }

  /// iPhone / iPad (mọi trình duyệt trên iOS đều là Safari bên trong) và Firefox: giọng tiếng Việt của trình duyệt
  /// thiếu, khác nhau theo máy hoặc hay im → ưu tiên giọng Việt của app qua máy chủ để mọi trình duyệt nghe như nhau.
  static bool get preferServerVoice {
    final ua = _ua;
    var touchMac = false;
    try {
      final nav = globalContext['navigator'] as JSObject;
      final tp = nav['maxTouchPoints'];
      touchMac = ua.contains('Macintosh') && tp != null && tp.isA<JSNumber>() && (tp as JSNumber).toDartDouble > 1;
    } catch (_) {}
    return ua.contains('iPhone') || ua.contains('iPad') || touchMac || ua.contains('Firefox/');
  }

  static void cancel() {
    try {
      _synth?.callMethod('cancel'.toJS);
    } catch (_) {}
    _speaking = false;
  }

  static List<JSObject> _voices() {
    try {
      final v = _synth?.callMethod<JSAny?>('getVoices'.toJS);
      if (v == null || !v.isA<JSArray>()) return const [];
      return [for (final x in (v as JSArray<JSObject>).toDart) x];
    } catch (_) {
      return const [];
    }
  }

  static String _s(JSObject o, String k) {
    final v = o[k];
    return v != null && v.isA<JSString>() ? (v as JSString).toDart : '';
  }

  static bool _b(JSObject o, String k) {
    final v = o[k];
    return v != null && v.isA<JSBoolean>() && (v as JSBoolean).toDart;
  }

  /// Giọng tốt nhất cho ngôn ngữ: ưu tiên Natural/Online (hay hơn), trừ khi giọng online vừa lỗi.
  static JSObject? _voiceFor(String lang) {
    final want = lang == 'en' ? 'en' : 'vi';
    final vs = [for (final v in _voices()) if (_s(v, 'lang').toLowerCase().startsWith(want)) v];
    if (vs.isEmpty) return null;
    int score(JSObject v) {
      final n = _s(v, 'name').toLowerCase();
      final local = _b(v, 'localService');
      if (_onlineBad) return local ? 10 : 0;
      return (n.contains('natural') ? 4 : 0) + (n.contains('online') ? 2 : 0) + (n.contains('google') ? 1 : 0) + (local ? 0 : 1);
    }

    vs.sort((a, b) => score(b).compareTo(score(a)));
    return vs.first;
  }

  /// Chia câu dài theo dấu câu, mỗi đoạn ≤ [max] ký tự.
  static List<String> _chunks(String text, {int max = 170}) {
    final parts = text.split(RegExp(r'(?<=[.!?;:])\s+|(?<=,)\s+(?=\S{0,}\s)'));
    final out = <String>[];
    var cur = '';
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (cur.isEmpty) {
        cur = t;
      } else if (cur.length + 1 + t.length <= max) {
        cur = '$cur $t';
      } else {
        out.add(cur);
        cur = t;
      }
      while (cur.length > max) {
        final cut = cur.lastIndexOf(' ', max);
        final at = cut > 40 ? cut : max;
        out.add(cur.substring(0, at));
        cur = cur.substring(at).trim();
      }
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }

  /// Đọc [text]; trả về khi đọc xong / bị huỷ. [alive] = false khi đã có câu mới hơn (thì dừng).
  static Future<bool> speak(String text,
      {required String lang, double rate = 1.0, required bool Function() alive, void Function(String)? log}) async {
    final synth = _synth;
    if (synth == null) return false;
    _speaking = true;
    try {
      if (_b(synth, 'speaking') || _b(synth, 'pending')) {
        synth.callMethod('cancel'.toJS);
        await Future<void>.delayed(const Duration(milliseconds: 80)); // Chrome nuốt câu nói ngay sau cancel()
      }
      for (final chunk in _chunks(text)) {
        if (!alive()) return false;
        var ok = false;
        for (var attempt = 0; attempt < 3 && !ok && alive(); attempt++) {
          ok = await _one(synth, chunk, lang, rate, alive, log, attempt);
        }
        if (!ok) return false;
      }
      return true;
    } finally {
      if (alive()) _speaking = false;
    }
  }

  static Future<bool> _one(JSObject synth, String chunk, String lang, double rate, bool Function() alive,
      void Function(String)? log, int attempt) async {
    final ctor = globalContext['SpeechSynthesisUtterance'] as JSFunction;
    final u = ctor.callAsConstructor<JSObject>(chunk.toJS);
    u['lang'] = (lang == 'en' ? 'en-US' : 'vi-VN').toJS;
    u['rate'] = rate.clamp(0.5, 2.0).toJS;
    final voice = _voiceFor(lang);
    if (voice != null) u['voice'] = voice;
    final started = Completer<void>(), ended = Completer<String>();
    u['onstart'] = ((JSAny? _) {
      if (!started.isCompleted) started.complete();
    }).toJS;
    u['onend'] = ((JSAny? _) {
      if (!ended.isCompleted) ended.complete('');
    }).toJS;
    u['onerror'] = ((JSObject e) {
      final err = _s(e, 'error');
      if (!ended.isCompleted) ended.complete(err.isEmpty ? 'error' : err);
    }).toJS;
    try {
      synth.callMethod('resume'.toJS); // tab vừa quay lại: Chrome để speechSynthesis ở trạng thái "paused"
      synth.callMethod('speak'.toJS, u);
    } catch (e) {
      log?.call('[giọng web] speak lỗi: $e');
      return false;
    }
    // 1,5 giây (giọng online: 3 giây) chưa bắt đầu đọc → coi như bị nuốt, đọc lại
    final online = voice != null && !_b(voice, 'localService');
    final waitStart = Duration(milliseconds: online ? 3000 : 1500);
    final r = await Future.any<Object?>([started.future, ended.future, Future<Object?>.delayed(waitStart, () => 'timeout')]);
    if (r == 'timeout' && !started.isCompleted && !ended.isCompleted) {
      log?.call('[giọng web] chưa đọc sau ${waitStart.inMilliseconds} ms (lần ${attempt + 1}) → đọc lại');
      if (online) _onlineBad = true;
      synth.callMethod('cancel'.toJS);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return false;
    }
    // đọc xong, hoặc quá lâu so với độ dài đoạn (Chrome đôi khi không báo onend)
    final maxMs = 4000 + chunk.length * 110 ~/ rate.clamp(0.5, 2.0);
    final res = await Future.any<String>([ended.future, Future<String>.delayed(Duration(milliseconds: maxMs), () => 'late')]);
    if (res == '' || res == 'late') return true;
    if (res == 'interrupted' || res == 'canceled') return true; // bị câu mới hơn ngắt: không đọc lại
    log?.call('[giọng web] lỗi "$res" (lần ${attempt + 1})');
    if (online) _onlineBad = true; // giọng online lỗi mạng → lần sau dùng giọng trong máy
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return false;
  }
}
