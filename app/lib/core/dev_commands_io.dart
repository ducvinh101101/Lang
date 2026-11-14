import 'dart:convert';
import 'dart:io';

Future<List<String>> takeDevCommands() async {
  final sep = Platform.pathSeparator;
  final f = File('${Directory.systemTemp.path}${sep}danbau_trai_dat${sep}thu_lenh.txt');
  try {
    if (!f.existsSync()) return const [];
    final lines = (await f.readAsString(encoding: utf8)).split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    await f.delete();
    return lines;
  } catch (_) {
    return const [];
  }
}
