import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// navigator.vibrate(ms) — trình duyệt không hỗ trợ (máy tính, iPhone) thì bỏ qua.
void vibrate(int ms) {
  try {
    final nav = globalContext['navigator'];
    if (nav == null || !nav.isA<JSObject>()) return;
    final n = nav as JSObject;
    if (!n.has('vibrate')) return;
    n.callMethod('vibrate'.toJS, ms.toJS);
  } catch (_) {}
}

/// navigator.vibrate([rung, nghỉ, rung, …]).
void vibratePattern(List<int> ms) {
  try {
    final nav = globalContext['navigator'];
    if (nav == null || !nav.isA<JSObject>()) return;
    final n = nav as JSObject;
    if (!n.has('vibrate')) return;
    n.callMethod('vibrate'.toJS, [for (final x in ms) x.toJS].toJS);
  } catch (_) {}
}
