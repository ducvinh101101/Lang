import 'dart:io';
import 'dart:typed_data';

Directory get _dir => Directory('${Directory.systemTemp.path}${Platform.pathSeparator}danbau_trai_dat'
    '${Platform.pathSeparator}mang');

// FNV-1a 64 bit → tên tệp ngắn (chỉ chạy trên máy, không biên dịch cho web)
String _file(String key) {
  var h = -3750763034362895579; // 0xcbf29ce484222325 (số có dấu 64 bit)
  for (final c in key.codeUnits) {
    h ^= c;
    h *= 0x100000001b3;
  }
  return '${_dir.path}${Platform.pathSeparator}${h.toUnsigned(64).toRadixString(16)}';
}

Future<void> save(String key, Uint8List bytes) async {
  final d = _dir;
  if (!d.existsSync()) d.createSync(recursive: true);
  await File(_file(key)).writeAsBytes(bytes, flush: true);
}

Future<(Uint8List, DateTime)?> load(String key) async {
  final f = File(_file(key));
  if (!f.existsSync()) return null;
  return (await f.readAsBytes(), f.lastModifiedSync());
}

Future<bool> has(String key) async => File(_file(key)).existsSync();
