// MÁY HÁT TRÁI ĐẤT (#14): hiểu câu nói, đọc dữ liệu, lưới rê tay, và dữ liệu đóng gói trong assets/eic/.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:earthsense/audio/audio_engine.dart';
import 'package:earthsense/audio/sound_backend.dart';
import 'package:earthsense/features/eic/eic_commands.dart';
import 'package:earthsense/features/eic/eic_data.dart';
import 'package:earthsense/features/eic/eic_player.dart';
import 'package:earthsense/features/voice/commands.dart' show normVi;

EicCmd? open(String s) => parseEicOpen(normVi(s));
EicCmd? inside(String s) => parseEicInside(normVi(s));

void main() {
  group('mở máy hát', () {
    test('tên chế độ', () {
      expect(open('máy hát Trái Đất')?.act, EicAct.open);
      expect(open('máy hát Trái Đất')?.target, isNull);
      expect(open('Earth Jukebox')?.act, EicAct.open);
      expect(open('máy hát có những hình gì')?.act, EicAct.list);
    });
    test('nghe + tên hình', () {
      expect(open('nghe ánh đèn ban đêm')?.target, 'nightlights');
      expect(open('nghe sét')?.target, 'lightning');
      expect(open('cho tôi nghe khí CO2')?.target, 'co2');
      expect(open('nghe nhiệt độ biển')?.target, 'ocean');
      expect(open('nghe chiều cao rừng')?.target, 'forest');
      expect(open('listen to lightning')?.target, 'lightning');
    });
    test('không cướp câu khác', () {
      expect(open('nghe biển'), isNull); // có thể là tiếng sóng
      expect(open('thời tiết Hà Nội'), isNull);
      expect(open('có sét ở Huế không'), isNull);
      expect(open('kể về Sao Hỏa'), isNull);
    });
  });

  group('điều khiển bên trong', () {
    test('các lệnh', () {
      expect(inside('dừng lại')?.act, EicAct.pause);
      expect(inside('tiếp tục')?.act, EicAct.resume);
      expect(inside('nhanh hơn')?.act, EicAct.faster);
      expect(inside('chậm lại')?.act, EicAct.slower);
      expect(inside('nghe lại từ đầu')?.act, EicAct.replay);
      expect(inside('tại sao lại dùng tiếng đàn bầu')?.act, EicAct.why);
      expect(inside('mô tả hình này')?.act, EicAct.describe);
      expect(inside('khung tiếp theo')?.act, EicAct.next);
      expect(inside('năm 2020')?.act, EicAct.year);
      expect(inside('tháng 7')?.act, EicAct.year);
      expect(inside('đổi sang sét')?.target, 'lightning');
      expect(inside('thời tiết Đà Nẵng'), isNull); // lệnh khác → rời máy hát
    });
  });

  group('dữ liệu', () {
    final grid = Uint8List(4 * 2)..setAll(0, [0, 127, 254, 255, 10, 20, 30, 40]);
    final set = EicSet.fromJson({
      'id': 't',
      'title_vi': 'Thử',
      'low': 0,
      'high': 50,
      'unit_vi': 'mét',
      'grid_w': 4,
      'grid_h': 2,
      'sound': {'voice': 'sao', 'pulse': 'trung', 'bed': 'none', 'pitch': 'vn'},
      'sweep': 'space',
      'frames': [
        {'label_vi': 'năm 2012', 'img': 'f00.jpg', 'v': 0.5, 'area': 0.2, 'cx': 0.1, 'd': 0, 'vn': 0.3, 'grid': base64Encode(grid)},
        {'label_vi': 'năm 2020', 'img': 'f01.jpg', 'v': 0.9, 'area': 0.4, 'cx': 0.2, 'd': 1, 'vn': 0.6, 'grid': base64Encode(grid)},
      ],
    }, 'assets/eic/t');

    test('đọc meta', () {
      expect(set.frames.length, 2);
      expect(set.frames.first.image, 'assets/eic/t/f00.jpg');
      expect(set.voice, 'sao');
      expect(set.pitch, 'vn');
      expect(set.sweep, 'space');
    });
    test('lưới rê tay', () {
      expect(set.at(0, 0.0, 0.0), 0.0);
      expect(set.at(0, 0.6, 0.1), 1.0);
      expect(set.at(0, 0.9, 0.1), isNull); // 255 = không có số liệu
      expect(set.real(set.at(0, 0.3, 0.1)!), closeTo(25, 0.2));
    });
    test('tìm khung theo năm', () {
      final p = EicPlayer(audio: AudioEngine(SilentBackend()), say: (_, __) async {}, ds: set);
      expect(p.findFrame('nam 2020'), 1);
      expect(p.findFrame('nam 1999'), isNull);
      expect(p.findFrame('thang 5'), isNull);
      expect(p.main(set.frames[1]), 0.6); // giọng chính đi theo Biển Đông
      expect(p.pitchOf(set.frames[0]), closeTo(0.1, 1e-9)); // trải khoảng giá trị ra cả thang
      expect(p.pitchOf(set.frames[1]), closeTo(0.95, 1e-9));
    });
    test('số tiếng nhịp theo diện tích', () {
      expect(EicPlayer.pulseCount(0), 0);
      expect(EicPlayer.pulseCount(0.1), 1);
      expect(EicPlayer.pulseCount(1), 6);
    });
    test('tên vùng khi rê tay', () {
      expect(placeName(16, 106).vi, 'Việt Nam');
      expect(placeName(12, 114).vi, 'Biển Đông');
      expect(placeName(0, 20).vi, 'châu Phi');
      expect(placeName(-20, -150).vi, 'Thái Bình Dương');
      expect(placeName(45, -35).vi, 'Đại Tây Dương');
    });
  });

  group('dữ liệu đóng gói assets/eic', () {
    final idx = File('assets/eic/index.json');
    test('mỗi bộ đủ khung, ảnh, lưới, mô tả', () {
      final ids = (jsonDecode(idx.readAsStringSync())['sets'] as List).cast<String>();
      expect(ids, isNotEmpty);
      for (final id in ids) {
        final m = jsonDecode(File('assets/eic/$id/meta.json').readAsStringSync()) as Map<String, dynamic>;
        final s = EicSet.fromJson(m, 'assets/eic/$id');
        expect(s.frames.length, greaterThanOrEqualTo(8), reason: id);
        expect(s.describeVi, isNotEmpty, reason: id);
        expect(s.whyVi, isNotEmpty, reason: id);
        expect(s.legendEn, isNotEmpty, reason: id);
        for (final f in s.frames) {
          expect(File(f.image).existsSync(), isTrue, reason: f.image);
          expect(f.grid.length, s.gridW * s.gridH, reason: '$id ${f.labelVi}');
          for (final x in [f.v, f.area, f.d, f.vn]) {
            expect(x, inInclusiveRange(0, 1), reason: '$id ${f.labelVi}');
          }
        }
      }
    }, skip: idx.existsSync() ? false : 'chưa chạy pipeline/build_eic.py');
  });
}
