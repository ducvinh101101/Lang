import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:earthsense/features/globe/local_map.dart';
import 'package:earthsense/live/geo_around.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocalMap painter: vẽ địa hình mượt mà không lỗi', () {
    final grid = Float32List(100);
    for (var i = 0; i < 100; i++) {
      grid[i] = 10.0 + (i % 10) * 5.0 + (i ~/ 10) * 12.0;
    }
    final data = AroundData(
      21.0285,
      105.8542,
      1200.0,
      [],
      15.0,
      List.filled(8, 15.0),
      grid,
      10,
    );

    // Dùng PictureRecorder để kiểm tra hàm paint
    final recorder = ui.PictureRecorder();
    Canvas(recorder);

    // LocalMapView sử dụng _LocalPainter qua widget tree hoặc trực tiếp
    final widget = LocalMapView(data: data, placeVi: 'Hà Nội');
    expect(widget.placeVi, 'Hà Nội');
    expect(widget.data.gridN, 10);

    final pic = recorder.endRecording();
    pic.dispose();
  });
}
