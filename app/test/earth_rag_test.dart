import 'package:flutter_test/flutter_test.dart';
import 'package:earthsense/live/earth_rag.dart';
import 'package:earthsense/live/gemini_assistant.dart';

void main() {
  group('EarthRag - Trích xuất tri thức RAG nội tại', () {
    test('Trích xuất địa danh Việt Nam', () {
      final ctx = EarthRag.extractContext('Cho tôi hỏi về Vịnh Hạ Long và Hồ Gươm có gì đẹp');
      expect(ctx, contains('Vịnh Hạ Long'));
      expect(ctx, contains('Quảng Ninh'));
      expect(ctx, contains('Hồ Hoàn Kiếm'));
    });

    test('Trích xuất đỉnh núi và địa hình', () {
      final ctx = EarthRag.extractContext('Đỉnh Phan Xi Păng và núi Everest cao bao nhiêu');
      expect(ctx, contains('đỉnh Phan Xi Păng'));
      expect(ctx, contains('3143'));
      expect(ctx, contains('núi Everest'));
      expect(ctx, contains('8849'));
    });

    test('Trích xuất vực sâu Mariana', () {
      final ctx = EarthRag.extractContext('Rãnh Mariana sâu bao nhiêu mét');
      expect(ctx, contains('vực Challenger, rãnh Mariana'));
      expect(ctx, contains('-10935'));
    });

    test('Trích xuất thiên thể vũ trụ', () {
      final ctx = EarthRag.extractContext('Kể cho tôi nghe về Sao Hỏa và Sao Kim');
      expect(ctx, contains('Sao Hỏa'));
      expect(ctx, contains('Sao Kim'));
    });

    test('Ngữ cảnh vị trí hiện tại và chủ quyền', () {
      final ctx = EarthRag.extractContext('thời tiết ở đây thế nào', place: 'Đà Nẵng', lat: 16.05, lon: 108.2);
      expect(ctx, contains('Đà Nẵng'));
      expect(ctx, contains('Hoàng Sa và Trường Sa là của Việt Nam'));
    });
  });

  group('EarthRag - Agent Tools Tra cứu động', () {
    test('lookupLandmark', () {
      final r = EarthRag.lookupLandmark('Vịnh Hạ Long');
      expect(r['ten'], equals('Vịnh Hạ Long'));
      expect(r['tinh_thanh'], equals('Quảng Ninh'));
    });

    test('lookupTerrain đỉnh núi', () {
      final r = EarthRag.lookupTerrain('Fansipan');
      expect(r['ten'], equals('đỉnh Phan Xi Păng'));
      expect(r['do_cao_met'], equals(3143));
    });

    test('lookupTerrain vực sâu Mariana', () {
      final r = EarthRag.lookupTerrain('mariana');
      expect(r['do_sau_met'], equals(-10935));
    });

    test('lookupSpace hành tinh', () {
      final r = EarthRag.lookupSpace('Sao Hỏa');
      expect(r['ten'], equals('Sao Hỏa'));
      expect(r['thong_tin'], isNotNull);
    });
  });

  group('GeminiAssistant - Khởi tạo với công cụ mở rộng', () {
    test('Hỗ trợ đầy đủ 5 công cụ trong tool declarations', () {
      final ai = GeminiAssistant();
      expect(ai.model, equals(GeminiAssistant.defaultModel));
      // Kiểm tra danh sách preset models
      expect(GeminiAssistant.presets.length, greaterThanOrEqualTo(4));
    });
  });
}
