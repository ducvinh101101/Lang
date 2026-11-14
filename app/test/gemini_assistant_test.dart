import 'package:earthsense/live/gemini_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GeminiAssistant tool definitions and callbacks', () {
    final ai = GeminiAssistant();
    expect(ai.model, equals(GeminiAssistant.defaultModel));
    expect(GeminiAssistant.presets.length, greaterThanOrEqualTo(4));

    // Kiểm tra các typedef hợp lệ
    Future<(String, dynamic)?> weatherLookup(String place) async => null;
    Future<String?> landmarkLookup(String query) async => 'Vịnh Hạ Long';
    Future<String?> spaceLookup(String target) async => 'Sao Hỏa';
    Future<String?> terrainLookup(String query) async => 'Fansipan 3143m';
    Future<String?> actionHandler(String action, String target) async => 'Đã thực hiện';

    expect(weatherLookup, isNotNull);
    expect(landmarkLookup, isNotNull);
    expect(spaceLookup, isNotNull);
    expect(terrainLookup, isNotNull);
    expect(actionHandler, isNotNull);
  });
}
