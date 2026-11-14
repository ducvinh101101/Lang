import 'package:earthsense/audio/audio_engine.dart';
import 'package:earthsense/audio/sound_backend.dart';
import 'package:earthsense/features/history/history_player.dart';
import 'package:earthsense/features/history/history_records.dart';
import 'package:earthsense/features/terrain_scan/terrain_scan_view.dart';
import 'package:earthsense/features/terrain_scan/terrain_sense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audio = AudioEngine(SilentBackend());
  final tm = {for (var y = 2019; y <= 2021; y++) y: [for (var m = 0; m < 12; m++) 15.0 + m * 1.5]};
  final rm = {for (var y = 2019; y <= 2021; y++) y: [for (var m = 0; m < 12; m++) m == 8 ? 700.0 : 80.0]};

  for (final size in [const Size(390, 800), const Size(1280, 800)]) {
    testWidgets('F1 lớp phát lại lịch sử dựng được, chạm → giải thích (${size.width.toInt()})', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final range = resolveRange(spanMonths: 12, dataY0: 2019, dataY1: 2021);
      final recs = buildRecords(tempMonth: tm, rainMonth: rm, range: range, events: [
        HazardEvent(HazardKind.storm, DateTime(2021, 9, 10), 4.2, 'Bão Conson', 'Storm Conson'),
      ]);
      final said = <String>[];
      final p = HistoryPlayer(
        audio: audio,
        say: (vi, en) async => said.add(vi),
        quick: (vi, en) {},
        stopSpeech: () async {},
        lang: () => 'vi',
        placeVi: 'Huế',
        placeEn: 'Hue',
        range: range,
        records: recs,
      );
      await t.pumpWidget(MaterialApp(home: Scaffold(body: HistoryPlayerView(player: p, onClose: () {}))));
      unawaited(p.start());
      await t.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Lịch sử'), findsOneWidget);
      expect(find.text('Tháng 1/2021'), findsWidgets);
      // chạm → đọc giải thích của bản ghi đang phát
      await t.tap(find.byType(HistoryPlayerView));
      await t.pump(const Duration(milliseconds: 100));
      expect(said.any((x) => x.startsWith('Tháng 1 năm 2021')), isTrue);
      expect(t.takeException(), isNull);
      p.stop();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('F3 lớp quét mặt cắt dựng được (${size.width.toInt()})', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final g = ElevGrid([
        for (var r = 0; r < 10; r++) [for (var c = 0; c < 10; c++) (r * c * 20 - 100).toDouble()]
      ], 12, 11.5, 108, 108.5);
      final p = TerrainScanPlayer(
          audio: audio, say: (vi, en) async {}, grid: g, placeVi: 'Đà Lạt', placeEn: 'Da Lat', widthKm: 50, heightKm: 50);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: TerrainScanView(player: p, onClose: () {}))));
      final run = p.run();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Bắc → Nam'), findsOneWidget);
      // hai lượt × 10 lát × 320 ms ≈ 6,4 giây
      for (var k = 0; k < 40; k++) {
        await t.pump(const Duration(milliseconds: 250));
      }
      await run;
      expect(p.phase, 'done');
      expect(t.takeException(), isNull);
    });
  }
}

void unawaited(Future<void> f) {}
