// finger_reader.dart — xử lý ngón tay: tra ô, phát âm, rung, đọc tên theo 3 quy tắc lời nói của file 6.
// Khi di tay, mỗi ô mới:
//   - rung theo độ dốc (luôn bật trên đất liền)
//   - tiếng sóng biển ngoài khơi / tiếng nước khi qua sông hồ lớn (luôn bật)
//   - lớp "elev": nốt sáo theo độ cao;  lớp "pop": tiếng xe cộ theo mật độ dân số
import 'dart:async';
import 'touch_map.dart';
import 'touch_rules.dart';
import 'touch_sound.dart';

class FingerReader {
  FingerReader(this.map, this.sound);
  TouchMap map;
  final TouchSound sound;
  String layer = 'elev';
  int _lastId = -1;
  bool _lastSea = false, _lastOutside = false;
  WaterKind _lastWater = WaterKind.none;
  (int, int)? _lastCell;
  Island? _lastIsland;
  Timer? _nameTimer, _detailTimer;

  String get seaName => 'Biển Đông';

  void move(double x, double y, double w, double h) {
    final cell = map.cellAt(x, y, w, h);
    if (cell == null || cell == _lastCell) return;
    _lastCell = cell;
    final (c, r) = cell;
    final id = map.idAt(c, r);
    final sea = map.isSea(c, r);
    final outside = id == 0 && !sea;
    final changed = id != _lastId || sea != _lastSea;
    final water = waterKind(sea: sea, waterFraction: map.waterAt(c, r), threshold: map.waterThreshold);

    if (changed) {
      _lastId = id;
      _nameTimer?.cancel();
      if (outside && !_lastOutside) {
        sound.border();
      } else {
        sound.tick();
      }
      // Chỉ đọc tên khi ngón tay ở lại vùng mới từ 0,3 giây; "Biển Đông" đọc một lần mỗi lần ra biển.
      final text = id > 0 ? (map.regions[id]?.nameVi ?? '') : (sea ? (_lastSea ? '' : seaName) : 'Ngoài biên giới');
      if (text.isNotEmpty) {
        _nameTimer = Timer(const Duration(milliseconds: 300), () => sound.say(text));
      }
    } else if (water == WaterKind.inland && _lastWater != WaterKind.inland) {
      _nameTimer?.cancel();
      _nameTimer = Timer(const Duration(milliseconds: 300), () => sound.say('Sông hồ'));
    }
    _lastSea = sea;
    _lastOutside = outside;
    _lastWater = water;

    // Âm nền nước + rung độ dốc
    sound.water(water);
    if (!sea) sound.slope(map.slopeAt(c, r));

    // Âm theo lớp đang chọn (trên mặt nước nội địa vẫn phát nốt độ cao để biết mặt hồ cao bao nhiêu)
    if (id > 0 && !sea) {
      if (layer == 'elev') {
        final v = map.elevAt(c, r);
        if (v != null) sound.elevNote(v, vol: water == WaterKind.inland ? 0.45 : 0.7);
      }
      if (layer == 'pop' && water == WaterKind.none) sound.traffic(map.layers['pop']?.valueAt(c, r));
    }

    // Dừng yên 1 giây: đọc chi tiết điểm
    _detailTimer?.cancel();
    _detailTimer = Timer(const Duration(seconds: 1), () => sound.say(detailAt(c, r)));
  }

  String detailAt(int c, int r) {
    final id = map.idAt(c, r);
    if (id == 0) return map.isSea(c, r) ? seaName : 'Ngoài biên giới';
    final name = map.regions[id]?.nameVi ?? '';
    final e = map.elevAt(c, r);
    final s = map.slopeAt(c, r);
    final wf = map.waterAt(c, r);
    final p = map.layers['pop']?.valueAt(c, r);
    final parts = <String>[name];
    if (e != null) parts.add('Độ cao chỗ này khoảng ${roundMeters(e)} mét');
    if (s != null) parts.add(_slopeWords(s));
    if (wf != null && wf >= 0.2) parts.add('khoảng ${(wf * 10).round() * 10} phần trăm là mặt nước');
    if (layer == 'pop' && p != null) parts.add('khoảng ${_roundPop(p)} người mỗi ki lô mét vuông');
    return '${parts.join('. ')}.';
  }

  String _slopeWords(double deg) {
    if (deg < 2) return 'bằng phẳng';
    if (deg < 8) return 'dốc thoải';
    if (deg < 18) return 'khá dốc, khoảng ${deg.round()} độ';
    return 'rất dốc, khoảng ${deg.round()} độ';
  }

  String _roundPop(double p) {
    if (p < 100) return '${(p / 10).round() * 10}';
    if (p < 1000) return '${(p / 50).round() * 50}';
    return '${(p / 500).round() * 500}';
  }

  /// Ngón tay trên dải quần đảo ở mép phải.
  void moveIslands(double y, double h) {
    final i = map.islandAtY(y, h);
    if (i == _lastIsland) return;
    _lastIsland = i;
    _lastCell = null;
    sound.water(i == null ? WaterKind.sea : WaterKind.none);
    if (i != null) {
      sound.tick();
      _nameTimer?.cancel();
      _nameTimer = Timer(const Duration(milliseconds: 300), () => sound.say('Quần đảo ${i.nameVi}. ${i.unitVi}.'));
    }
  }

  /// Mã vùng dưới ngón tay (để chạm hai lần mở cấp 2).
  int idAt(double x, double y, double w, double h) {
    final cell = map.cellAt(x, y, w, h);
    return cell == null ? 0 : map.idAt(cell.$1, cell.$2);
  }

  void up() {
    _nameTimer?.cancel();
    _detailTimer?.cancel();
    _lastCell = null;
    _lastId = -1;
    _lastSea = false;
    _lastOutside = false;
    _lastWater = WaterKind.none;
    _lastIsland = null;
    sound.silence();
  }
}
