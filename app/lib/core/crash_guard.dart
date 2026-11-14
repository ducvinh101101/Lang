// Chống văng "dứt điểm" khi không có log: app tự ghi lại mình đang gọi thư viện gốc nào (giọng đọc / âm thanh).
// Nếu app chết NGAY TRONG lệnh gọi đó (lỗi trong code C++ của plugin — Dart không bắt được), lần mở sau
// app đọc lại dấu vết, tự tắt phần gây văng (chế độ an toàn) và báo cho người dùng. Ghi kèm nhật ký lỗi ra file
// để gửi cho nhóm phát triển.
//
//  • Dấu "cứng" (đang ở TRONG lệnh gọi gốc): 1 lần là bật chế độ an toàn cho phần đó.
//  • Dấu "mềm" (đang đọc dở một câu): có thể chỉ là người dùng đóng app giữa chừng → cần 2 lần liên tiếp.
//  • Khi app được đóng bình thường hoặc chuyển nền, dấu được xoá.
import 'dart:io';

import 'package:flutter/foundation.dart';

class CrashGuard {
  CrashGuard._();

  static Directory? _dir;
  static File? _crumb, _log;
  static final _counts = <String, int>{};
  static String _current = '';

  /// Phần đã làm app văng ở lần chạy trước và đã đủ điều kiện bật chế độ an toàn: 'tts' | 'audio' | null.
  static String? crashedPart;

  /// Mô tả dấu vết lần trước (để ghi log / hiển thị), null nếu lần trước thoát bình thường.
  static String? previousTrace;

  static String get logPath => _log?.path ?? '(chưa có)';

  /// [dirPath]: chỉ dùng trong test (để không đụng vào nhật ký thật của app trên máy).
  static void init({String? dirPath}) {
    crashedPart = null;
    previousTrace = null;
    _counts.clear();
    _current = '';
    if (kIsWeb) return; // web: không có thư mục tạm; trình duyệt tự cách ly lỗi
    try {
      final d = Directory(dirPath ?? '${Directory.systemTemp.path}${Platform.pathSeparator}danbau_trai_dat');
      if (!d.existsSync()) d.createSync(recursive: true);
      _dir = d;
      _crumb = File('${d.path}${Platform.pathSeparator}crumb.txt');
      _log = File('${d.path}${Platform.pathSeparator}nhat-ky-loi.txt');
      final strikes = File('${d.path}${Platform.pathSeparator}strikes.txt');
      final prev = _crumb!.existsSync() ? _crumb!.readAsStringSync().trim() : '';
      if (prev.isNotEmpty && prev != 'ok') {
        previousTrace = prev;
        // prev dạng "hard:tts:speak" hoặc "soft:tts:speaking"
        final parts = prev.split(':');
        final kind = parts.isNotEmpty ? parts[0] : '';
        final part = parts.length > 1 ? parts[1] : '';
        var n = 1;
        if (strikes.existsSync()) {
          final old = strikes.readAsStringSync().split(':');
          if (old.length == 2 && old[0] == part) n = (int.tryParse(old[1]) ?? 0) + 1;
        }
        strikes.writeAsStringSync('$part:$n', flush: true);
        if (part == 'tts' || part == 'audio') {
          if (kind == 'hard' || n >= 2) crashedPart = part;
        }
        log('Lần chạy trước kết thúc bất thường khi: $prev (lần thứ $n liên tiếp)');
      } else if (strikes.existsSync()) {
        strikes.writeAsStringSync('', flush: true);
      }
      _write('ok');
    } catch (e) {
      debugPrint('[crash-guard] $e');
    }
  }

  static void _write(String s) {
    if (_current == s) return;
    _current = s;
    try {
      _crumb?.writeAsStringSync(s, flush: true);
    } catch (_) {}
  }

  /// Gọi NGAY TRƯỚC một lệnh gốc có thể làm văng. Chỉ ghi `limit` lần đầu mỗi loại (đủ để bắt lỗi, không tốn).
  static void enter(String part, String what, {int limit = 40}) {
    final key = '$part:$what';
    final n = (_counts[key] ?? 0) + 1;
    _counts[key] = n;
    if (n <= limit) _write('hard:$key');
  }

  /// Gọi ngay sau lệnh gốc trả về.
  static void leave() {
    if (_current.startsWith('hard:')) _write('ok');
  }

  /// Đánh dấu "đang đọc dở" (dấu mềm) — xoá khi đọc xong.
  static void soft(String part, String what) => _write('soft:$part:$what');

  static void clearSoft() {
    if (_current.startsWith('soft:')) _write('ok');
  }

  /// App đóng bình thường / chuyển nền: không coi là văng.
  static void clean() => _write('ok');

  /// Ghi một dòng vào nhật ký lỗi (giới hạn ~200 KB, tự cắt phần cũ).
  static void log(String msg) {
    debugPrint('${tagOf(msg)} $msg');
    try {
      final f = _log;
      if (f == null) return;
      if (f.existsSync() && f.lengthSync() > 200 * 1024) {
        final s = f.readAsStringSync();
        f.writeAsStringSync(s.substring(s.length ~/ 2));
      }
      f.writeAsStringSync('${DateTime.now().toIso8601String()}  $msg\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static final _errRe = RegExp(
      r'lỗi|exception|error|failed|bất thường|không (dùng|mở|nạp|chạy|đọc)|quá \d+ giây|chế độ an toàn|#\d+\s',
      caseSensitive: false);

  /// Nhãn cho dòng nhật ký: chỉ dòng thật sự là lỗi mới gắn [LỖI], còn lại là [nhật ký].
  static String tagOf(String msg) {
    // phần trước khi app nói / nghe là nội dung cuộc trò chuyện, không phải lỗi dù có chữ "lỗi"
    if (msg.startsWith('[app nói]') || msg.startsWith('[lệnh] "') || msg.startsWith('[thử lệnh]')) {
      return msg.startsWith('[lệnh] lỗi') ? '[LỖI]' : '[nhật ký]';
    }
    // im lặng / bị ngắt khi đang nghe là bình thường, không phải lỗi
    if (msg.endsWith('lỗi: no-speech') || msg.endsWith('lỗi: aborted')) return '[nhật ký]';
    return _errRe.hasMatch(msg) ? '[LỖI]' : '[nhật ký]';
  }

  /// Xoá dấu "đã văng" sau khi người dùng tự bật lại phần đó trong Cài đặt.
  static void forgive() {
    crashedPart = null;
    try {
      final d = _dir;
      if (d != null) File('${d.path}${Platform.pathSeparator}strikes.txt').writeAsStringSync('', flush: true);
    } catch (_) {}
  }
}
