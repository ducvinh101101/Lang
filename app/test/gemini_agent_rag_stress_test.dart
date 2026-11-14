import 'dart:convert';
import 'package:earthsense/features/globe/terrain_data.dart';
import 'package:earthsense/features/globe/vn_landmarks.dart';
import 'package:earthsense/features/space/planets.dart';
import 'package:earthsense/live/gemini_assistant.dart';
import 'package:earthsense/live/live_weather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResp(Map<String, dynamic> data, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('1. RAG Knowledge Retrieval Stress Tests', () {
    test('Landmark RAG: tìm chính xác theo tên và alias', () {
      final cases = {
        'Vịnh Hạ Long': 'Quảng Ninh',
        'vinh ha long': 'Quảng Ninh',
        'Hồ Gươm': 'Hà Nội',
        'ho guom': 'Hà Nội',
        'Lăng Bác': 'Hà Nội',
        'Chùa Một Cột': 'Hà Nội',
        'Yên Tử': 'Quảng Ninh',
        'Đà Lạt': 'Lâm Đồng',
        'Bà Nà Hills': 'Đà Nẵng',
        'Phố cổ Hội An': 'Đà Nẵng',
        'Thánh địa Mỹ Sơn': 'Đà Nẵng',
        'Mũi Né': 'Lâm Đồng',
        'Côn Đảo': 'TP. Hồ Chí Minh',
        'Phú Quốc': 'An Giang',
      };

      for (final e in cases.entries) {
        final l = landmarkIn(e.key);
        expect(l, isNotNull, reason: 'Không tìm thấy ${e.key}');
        expect(l!.province, contains(e.value.replaceAll('TP. ', '')), reason: 'Sai tỉnh cho ${e.key}');
      }
    });

    test('Landmark RAG: tìm theo tỉnh thành', () {
      final hanoi = landmarksOfProvinceIn('Hà Nội');
      expect(hanoi.length, greaterThanOrEqualTo(10));
      expect(hanoi.any((l) => l.name == 'Hồ Hoàn Kiếm'), isTrue);

      final qn = landmarksOfProvinceIn('Quảng Ninh');
      expect(qn.any((l) => l.name == 'Vịnh Hạ Long'), isTrue);

      final fake = landmarksOfProvinceIn('Tỉnh Không Tồn Tại 99');
      expect(fake, isEmpty);
    });

    test('Landmark RAG: tìm theo vùng miền', () {
      for (final reg in ['bac', 'trung', 'taynguyen', 'nam']) {
        final list = landmarksOfRegion(reg);
        expect(list, isNotEmpty, reason: 'Vùng $reg không có địa danh nào');
        expect(regionNamesVi[reg], isNotNull);
      }
    });

    test('Space RAG: tìm kiếm 10 thiên thể và alias', () {
      final planetsToTest = {
        'Mặt Trời': 0,
        'mat troi': 0,
        'sun': 0,
        'Sao Thủy': 1,
        'mercury': 1,
        'Sao Kim': 2,
        'sao mai': 2,
        'sao hom': 2,
        'venus': 2,
        'Trái Đất': 3,
        'earth': 3,
        'Mặt Trăng': 4,
        'moon': 4,
        'Sao Hỏa': 5,
        'mars': 5,
        'Sao Mộc': 6,
        'jupiter': 6,
        'Sao Thổ': 7,
        'saturn': 7,
        'Sao Thiên Vương': 8,
        'uranus': 8,
        'Sao Hải Vương': 9,
        'neptune': 9,
      };

      for (final e in planetsToTest.entries) {
        final p = planetIn(e.key);
        expect(p, isNotNull, reason: 'Không tìm thấy ${e.key}');
        expect(p!.sound, equals(e.value), reason: 'Sai index cho ${e.key}');
        expect(p.facts, isNotEmpty);
      }

      expect(planetIn('Krypton 99'), isNull);
    });

    test('Terrain RAG: đỉnh núi Việt Nam và Thế Giới', () {
      final peaksToTest = {
        'Fansipan': 3143,
        'phan xi pang': 3143,
        'Pu Si Lung': 3076,
        'Tây Côn Lĩnh': 2419,
        'Ngọc Linh': 2598,
        'Lang Biang': 2167,
        'núi Bà Đen': 986,
        'Everest': 8849,
        'K2': 8611,
        'Kilimanjaro': 5895,
        'Phú Sĩ': 3776,
      };

      for (final e in peaksToTest.entries) {
        final p = peakIn(e.key);
        expect(p, isNotNull, reason: 'Không tìm thấy ${e.key}');
        expect(p!.h, equals(e.value), reason: 'Sai độ cao cho ${e.key}');
      }

      expect(peakIn('Đỉnh Bánh Mì'), isNull);
      expect(deepest.h, lessThan(-10000));
    });
  });

  group('2. Gemini AI Agent Tool Dispatching Mock Tests', () {
    test('Tool lay_thoi_tiet: AI gọi hàm lấy thời tiết và trả lời', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (callCount == 1) {
          return jsonResp({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'lay_thoi_tiet',
                        'args': {'noi': 'Huế'}
                      }
                    }
                  ]
                }
              }
            ]
          });
        } else {
          final contents = body['contents'] as List;
          expect(contents.length, greaterThanOrEqualTo(3));
          return jsonResp({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Thời tiết ở Huế hiện tại 28 độ, trời có mây.'}
                  ]
                }
              }
            ]
          });
        }
      });

      final ai = GeminiAssistant()
        ..apiKey = 'fake-test-key'
        ..client = mock;

      final now = DateTime.now();
      final answer = await ai.ask('Thời tiết ở Huế thế nào?',
          context: 'Ngữ cảnh test',
          lookup: (place) async => ('Huế', LiveWeather('Huế', now, LiveNow(temp: 28, feels: 30, humidity: 70, precip: 0, desc: 'có mây', code: 2, wind: 5), const [], const [])));

      expect(answer, contains('Huế hiện tại 28 độ'));
      expect(callCount, equals(2));
    });

    test('Tool tra_cuu_dia_danh: AI gọi tool RAG địa danh', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return jsonResp({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'tra_cuu_dia_danh',
                        'args': {'ten_hoac_vung': 'Vịnh Hạ Long'}
                      }
                    }
                  ]
                }
              }
            ]
          });
        }
        return jsonResp({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Vịnh Hạ Long là di sản thiên nhiên thế giới tại Quảng Ninh.'}
                ]
              }
            }
          ]
        });
      });

      final ai = GeminiAssistant()
        ..apiKey = 'fake-test-key'
        ..client = mock;

      var landmarkLookupCalled = false;
      final answer = await ai.ask('Kể cho tôi về Vịnh Hạ Long',
          context: 'Test context',
          lookupLandmark: (query) async {
            landmarkLookupCalled = true;
            final l = landmarkIn(query);
            return l != null ? '${l.name} (${l.province}): ${l.vi}' : null;
          });

      expect(landmarkLookupCalled, isTrue);
      expect(answer, contains('Vịnh Hạ Long'));
    });

    test('Tool tra_cuu_vu_tru: AI gọi tool RAG hành tinh', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return jsonResp({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'tra_cuu_vu_tru',
                        'args': {'doi_tuong': 'Sao Hỏa'}
                      }
                    }
                  ]
                }
              }
            ]
          });
        }
        return jsonResp({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Sao Hỏa có hai mặt trăng nhỏ là Phobos và Deimos.'}
                ]
              }
            }
          ]
        });
      });

      final ai = GeminiAssistant()
        ..apiKey = 'fake-test-key'
        ..client = mock;

      var spaceCalled = false;
      final answer = await ai.ask('Sao Hỏa có mấy mặt trăng?',
          context: 'Space test',
          lookupSpace: (target) async {
            spaceCalled = true;
            final p = planetIn(target);
            return p?.facts;
          });

      expect(spaceCalled, isTrue);
      expect(answer, contains('Phobos và Deimos'));
    });

    test('Tool dieu_khien_app: AI gọi lệnh bay tới nơi', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return jsonResp({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'dieu_khien_app',
                        'args': {'hanh_dong': 'bay_toi', 'tham_so': 'Paris'}
                      }
                    }
                  ]
                }
              }
            ]
          });
        }
        return jsonResp({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Đã đưa bạn bay tới thủ đô Paris của nước Pháp.'}
                ]
              }
            }
          ]
        });
      });

      final ai = GeminiAssistant()
        ..apiKey = 'fake-test-key'
        ..client = mock;

      String? executedAction, executedTarget;
      final answer = await ai.ask('Đưa tôi đến Paris xem sao',
          context: 'Action test',
          handleAction: (action, target) async {
            executedAction = action;
            executedTarget = target;
            return 'Đã bay tới $target';
          });

      expect(executedAction, equals('bay_toi'));
      expect(executedTarget, equals('Paris'));
      expect(answer, contains('Paris'));
    });

    test('Multi-tool: AI gọi nhiều công cụ song song trong 1 lượt', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return jsonResp({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'tra_cuu_dia_danh',
                        'args': {'ten_hoac_vung': 'Hồ Hoàn Kiếm'}
                      }
                    },
                    {
                      'functionCall': {
                        'name': 'dieu_khien_app',
                        'args': {'hanh_dong': 'bay_toi', 'tham_so': 'Hà Nội'}
                      }
                    }
                  ]
                }
              }
            ]
          });
        }
        return jsonResp({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Đã bay tới Hà Nội và tìm thấy Hồ Hoàn Kiếm.'}
                ]
              }
            }
          ]
        });
      });

      final ai = GeminiAssistant()
        ..apiKey = 'fake-test-key'
        ..client = mock;

      var landmarkChecked = false;
      var actionChecked = false;

      final answer = await ai.ask('Bay tới Hà Nội và xem Hồ Gươm',
          context: 'Multi-tool test',
          lookupLandmark: (q) async {
            landmarkChecked = true;
            return 'Hồ Hoàn Kiếm ở giữa trung tâm Hà Nội';
          },
          handleAction: (act, tgt) async {
            actionChecked = true;
            return 'Đã bay tới $tgt';
          });

      expect(landmarkChecked, isTrue);
      expect(actionChecked, isTrue);
      expect(answer, contains('Hà Nội'));
    });

    test('Xử lý an toàn khi Tool ném ngoại lệ bất ngờ', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return jsonResp({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'tra_cuu_dia_hinh',
                        'args': {'dia_diem': 'Fansipan'}
                      }
                    }
                  ]
                }
              }
            ]
          });
        }
        return jsonResp({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Đỉnh Fansipan cao khoảng 3.143 mét.'}
                ]
              }
            }
          ]
        });
      });

      final ai = GeminiAssistant()
        ..apiKey = 'fake-test-key'
        ..client = mock;

      final answer = await ai.ask('Fansipan cao bao nhiêu?',
          context: 'Exception test',
          lookupTerrain: (query) async {
            throw Exception('Lỗi đọc dữ liệu đĩa');
          });

      expect(answer, contains('3.143'));
    });
  });

  group('3. Lọc Markdown và Định dạng TTS', () {
    test('Xóa sạch markdown ký tự đặc biệt để TTS đọc tự nhiên', () async {
      final mock = MockClient((request) async {
        return jsonResp({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': '## Thời tiết hôm nay:\n'
                        '* Nhiệt độ: **28 độ**\n'
                        '- Trời *rất đẹp* và `trong xanh`\n'
                        '> Lời khuyên: Hãy mang ô!'
                  }
                ]
              }
            }
          ]
        });
      });

      final ai = GeminiAssistant()
        ..apiKey = 'fake-test-key'
        ..client = mock;

      final answer = await ai.ask('Thời tiết hôm nay thế nào?', context: 'Clean test');
      expect(answer, isNot(contains('*')));
      expect(answer, isNot(contains('#')));
      expect(answer, isNot(contains('`')));
      expect(answer, isNot(contains('>')));
      expect(answer, contains('Thời tiết hôm nay:'));
      expect(answer, contains('28 độ'));
      expect(answer, contains('Hãy mang ô!'));
    });
  });

  group('4. Boundary & Error Conditions', () {
    test('Không có API key và proxy -> ném LiveError', () async {
      final ai = GeminiAssistant()..apiKey = '';
      expect(() => ai.ask('Hà Nội thế nào?', context: ''), throwsA(isA<LiveError>()));
    });

    test('Lỗi 404 Model không tồn tại -> ném LiveError chính xác', () async {
      final mock = MockClient((request) async => jsonResp({'error': 'Model not found'}, 404));
      final ai = GeminiAssistant()
        ..apiKey = 'test-key'
        ..client = mock;

      expect(() => ai.ask('Test', context: ''), throwsA(predicate((e) => e is LiveError && e.vi.contains('Không có model'))));
    });

    test('Lỗi 429 Quá tải lượt dùng -> ném LiveError hạn mức', () async {
      final mock = MockClient((request) async => jsonResp({'error': 'Rate limited'}, 429));
      final ai = GeminiAssistant()
        ..apiKey = 'test-key'
        ..client = mock;

      expect(() => ai.ask('Test', context: ''), throwsA(predicate((e) => e is LiveError && e.vi.contains('hết lượt'))));
    });
  });
}
