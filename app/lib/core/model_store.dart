// NƠI CẤT MÔ HÌNH (giọng đọc, nhận giọng) TRÊN MÁY — cho app đỡ nặng:
//  • Thư mục BỀN của app (Android: files/, iOS: Library/Application Support, Windows: AppData) thay cho thư mục tạm:
//    thư mục tạm bị hệ điều hành dọn khi máy đầy → lần mở sau app lại ghép ~140 MB mô hình, lâu "lên dây đàn".
//  • Dọn các bản cũ trong thư mục tạm (mỗi bản ~70–130 MB) để trả lại dung lượng.
//  • Tải mô hình KHÔNG đóng gói sẵn (nhận giọng tiếng Anh ~132 MB) khi người dùng cần lần đầu → file cài nhẹ hơn ~130 MB.
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ModelStore {
  ModelStore._();

  static Future<Directory>? _root;

  /// Thư mục gốc chứa mô hình đã giải nén / tải về.
  static Future<Directory> root() => _root ??= () async {
        Directory base;
        try {
          base = await getApplicationSupportDirectory();
        } catch (_) {
          base = Directory.systemTemp; // máy không có thư mục bền (hiếm) → như cũ
        }
        final d = Directory('${base.path}${Platform.pathSeparator}models')..createSync(recursive: true);
        unawaited(_cleanOldTemp());
        return d;
      }();

  static Future<String> dir(String name) async => '${(await root()).path}${Platform.pathSeparator}$name';

  /// Xoá các bản mô hình cũ app từng chép vào thư mục tạm (giong_vi_*, nghe_*, vad_*).
  static Future<void> _cleanOldTemp() async {
    try {
      final old = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}danbau_trai_dat');
      if (!old.existsSync()) return;
      for (final e in old.listSync()) {
        final n = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (e is Directory && (n.startsWith('giong_vi_') || n.startsWith('nghe_') || n.startsWith('vad_'))) {
          await e.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  /// Tải các phần [parts] (tên tệp) từ [baseUrl] rồi GHÉP thành [outFile]; [extra] là các tệp nhỏ chép nguyên.
  /// Ghi vào tệp tạm rồi mới đổi tên → mất mạng giữa chừng không để lại mô hình hỏng. [progress] nhận 0..100.
  static Future<bool> download({
    required Uri baseUrl,
    required List<String> parts,
    required File outFile,
    List<String> extra = const [],
    void Function(int pct)? progress,
    void Function(String)? log,
  }) async {
    final client = http.Client();
    final tmp = File('${outFile.path}.tai');
    IOSink? sink;
    try {
      outFile.parent.createSync(recursive: true);
      for (final name in extra) {
        final r = await client.get(baseUrl.resolve(name)).timeout(const Duration(seconds: 60));
        if (r.statusCode != 200) throw 'HTTP ${r.statusCode} $name';
        File('${outFile.parent.path}${Platform.pathSeparator}$name').writeAsBytesSync(r.bodyBytes, flush: true);
      }
      final out = tmp.openWrite();
      sink = out;
      var last = -1;
      for (var k = 0; k < parts.length; k++) {
        final req = http.Request('GET', baseUrl.resolve(parts[k]));
        final res = await client.send(req).timeout(const Duration(seconds: 60));
        if (res.statusCode != 200) throw 'HTTP ${res.statusCode} ${parts[k]}';
        final total = res.contentLength ?? 0;
        var got = 0;
        await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
          out.add(chunk);
          got += chunk.length;
          final pct = ((k + (total > 0 ? got / total : 0)) * 100 / parts.length).floor();
          if (pct != last) {
            last = pct;
            progress?.call(pct);
          }
        }
      }
      await out.flush();
      await out.close();
      sink = null;
      if (outFile.existsSync()) outFile.deleteSync();
      tmp.renameSync(outFile.path);
      return true;
    } catch (e) {
      log?.call('[tải mô hình] $e');
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } catch (_) {}
      return false;
    } finally {
      client.close();
    }
  }
}
