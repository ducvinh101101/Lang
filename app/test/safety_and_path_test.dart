import 'dart:io';

import 'package:earthsense/core/crash_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashGuard', () {
    // Thư mục riêng cho test, không đụng vào nhật ký lỗi thật của app
    final dir = '${Directory.systemTemp.path}${Platform.pathSeparator}danbau_trai_dat_test';
    void wipe() {
      final d = Directory(dir);
      if (d.existsSync()) d.deleteSync(recursive: true);
    }

    test('thoát bình thường → không bật chế độ an toàn', () {
      wipe();
      CrashGuard.init(dirPath: dir);
      CrashGuard.enter('tts', 'speak');
      CrashGuard.leave();
      CrashGuard.init(dirPath: dir); // giả lập mở lại app
      expect(CrashGuard.crashedPart, isNull);
    });

    test('chết TRONG lệnh gốc → lần sau tắt đúng phần đó', () {
      wipe();
      CrashGuard.init(dirPath: dir);
      CrashGuard.enter('audio', 'play'); // không có leave(): app "văng" tại đây
      CrashGuard.init(dirPath: dir);
      expect(CrashGuard.crashedPart, 'audio');
    });

    test('đang đọc dở (dấu mềm) cần 2 lần liên tiếp', () {
      wipe();
      CrashGuard.init(dirPath: dir);
      CrashGuard.soft('tts', 'speaking');
      CrashGuard.init(dirPath: dir);
      expect(CrashGuard.crashedPart, isNull);
      CrashGuard.soft('tts', 'speaking');
      CrashGuard.init(dirPath: dir);
      expect(CrashGuard.crashedPart, 'tts');
    });
  });

}
