// Bản web: giữ trong bộ nhớ trong lần mở trang (trình duyệt cũng tự đệm HTTP).
import 'dart:typed_data';

final _m = <String, (Uint8List, DateTime)>{};

Future<void> save(String key, Uint8List bytes) async {
  if (_m.length > 200) _m.remove(_m.keys.first);
  _m[key] = (bytes, DateTime.now());
}

Future<(Uint8List, DateTime)?> load(String key) async => _m[key];

Future<bool> has(String key) async => _m.containsKey(key);
