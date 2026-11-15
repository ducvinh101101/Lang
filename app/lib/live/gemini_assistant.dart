// TRỢ LÝ AI (Google Gemini) — trả lời câu hỏi tự do bằng giọng nói: "chiều nay đi chợ có cần áo mưa không",
// "cuối tuần ở Sa Pa lạnh không", "ngày mai trời thế nào để phơi đồ"…
//
//  • Gemini KHÔNG đoán số liệu: nó gọi hàm lay_thoi_tiet(noi) → app lấy thời tiết thật (Open-Meteo/Google)
//    rồi gửi lại cho Gemini viết câu trả lời ngắn, dễ nghe.
//  • Cần khoá Gemini API (Google AI Studio). Không có khoá / mất mạng → app dùng câu trả lời có sẵn (weather_talk.dart).
//  • Nhớ vài lượt hỏi gần nhất để hỏi tiếp được ("còn ngày mai thì sao?").
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'live_weather.dart';

/// Hàm app cung cấp cho Gemini: tên nơi → (tên chuẩn, thời tiết) hoặc null nếu không tìm thấy.
typedef WeatherLookup = Future<(String, LiveWeather)?> Function(String place);

/// Tra cứu thông tin địa danh, di tích, văn hóa Việt Nam (RAG).
typedef LandmarkLookup = Future<String?> Function(String query);

/// Tra cứu thông tin hành tinh, thiên thể trong Hệ Mặt Trời (RAG).
typedef SpaceLookup = Future<String?> Function(String target);

/// Tra cứu thông tin địa hình, đỉnh núi, vực sâu (RAG).
typedef TerrainLookup = Future<String?> Function(String query);

/// Thực hiện hành động điều khiển ứng dụng quả địa cầu (bay tới nơi, phóng to, thu nhỏ, nghe nhạc...).
typedef AppActionHandler = Future<String?> Function(String action, String target);

/// Thực thi công cụ đa năng cho AI Agent (RAG theo yêu cầu).
typedef AgentToolHandler = Future<Map<String, Object?>> Function(String name, Map<String, Object?> args);

class GeminiAssistant {
  String apiKey = '';
  /// Mặc định Gemini 3.5 Flash-Lite: trả lời khoảng 1 giây (Gemini 2.5 Flash-Lite Google đã ngừng cấp cho khoá mới).
  static const defaultModel = 'gemini-3.5-flash-lite';

  /// Các model gợi ý trong Cài đặt: (tên, mô tả tiếng Việt, mô tả tiếng Anh).
  static const presets = <(String, String, String)>[
    ('gemini-3.5-flash-lite', 'Gemini 3.5 Flash-Lite — rất nhanh (khuyên dùng)', 'Gemini 3.5 Flash-Lite — very fast (recommended)'),
    ('gemma-4-26b-a4b-it', 'Gemma 4 26B — nhanh, dùng được nhiều', 'Gemma 4 26B — fast, generous quota'),
    ('gemma-4-31b-it', 'Gemma 4 31B — trả lời kỹ hơn, chậm hơn một chút', 'Gemma 4 31B — more thorough, a bit slower'),
    ('gemini-flash-latest', 'Gemini Flash — thông minh hơn, hạn mức ít hơn', 'Gemini Flash — smarter, smaller quota'),
  ];

  String model = defaultModel;
  http.Client client = http.Client();
  void Function(String)? log;

  final _history = <Map<String, Object?>>[];

  /// Bản web trên Vercel: gọi qua /api/gemini (khoá nằm trên máy chủ, không lộ ra trình duyệt). null = không có.
  Uri? proxy;

  bool _thinkingOff = true;

  /// Tắt "suy nghĩ" theo đúng kiểu từng dòng model: Gemini 2.5 dùng thinkingBudget = 0;
  /// Gemma 4, Gemini 3 và các bí danh *-latest dùng thinkingLevel = "minimal". Model không nhận → app tự gửi lại không kèm.
  Map<String, Object?> _thinkingOffFor(String m) =>
      m.trim().startsWith('gemini-2.5') ? {'thinkingBudget': 0} : {'thinkingLevel': 'minimal'};

  /// Model dự phòng khi model chính bị lỗi phía Google (500 "Internal error" — Gemma 4 thỉnh thoảng bị, thử lại là được).
  static const fallbackModel = 'gemma-4-26b-a4b-it';

  bool get enabled => apiKey.trim().isNotEmpty || proxy != null;

  /// Web: hỏi máy chủ xem đã cài khoá Gemini chưa (GET /api/gemini → {"enabled": true}).
  Future<void> detectProxy(Uri url) async {
    try {
      final r = await client.get(url).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && (jsonDecode(r.body) as Map)['enabled'] == true) proxy = url;
    } catch (_) {}
  }

  void reset() {
    _history.clear();
    _thinkingOff = true; // đổi model: thử lại cách tắt suy nghĩ hợp với model mới
  }

  static String _system({required bool kid, required String lang, required String context}) => lang == 'vi'
      ? '''Bạn là trợ lý AI thông minh trong ứng dụng "Lắng" (quả địa cầu biết nói) dành cho NGƯỜI KHIẾM THỊ và TRẺ EM ở Việt Nam.
Ứng dụng có các tính năng: thời tiết thật khắp thế giới, địa hình độ cao núi biển, địa danh di tích văn hóa Việt Nam, và khám phá Hệ Mặt Trời.
Câu trả lời sẽ được ĐỌC TO bằng giọng máy, nên:
- Trả lời tiếng Việt, tối đa 3-4 câu ngắn, đi thẳng vào ý chính, giọng ấm áp và tôn trọng. Không dùng markdown (*, #, `), gạch đầu dòng, danh sách hay emoji.
- Viết số tự nhiên như lời nói: "29 độ", "3.143 mét", "70 phần trăm", "15 giờ".
- Bạn có sẵn các công cụ (tools) tra cứu dữ liệu thật:
  • lay_thoi_tiet: lấy thời tiết thật (chỉ gọi khi cần nơi khác chưa có số liệu).
  • tra_cuu_dia_danh: tra cứu lịch sử, văn hóa, danh lam thắng cảnh Việt Nam.
  • tra_cuu_vu_tru: tra cứu hành tinh, vũ trụ, so sánh kích thước, khoảng cách.
  • tra_cuu_dia_hinh: tra cứu đỉnh núi, vực sâu, độ cao, địa hình.
  • dieu_khien_app: thực hiện thao tác trên quả cầu nếu người dùng muốn bay tới, phóng to, nghe nhạc, khám phá.
- KHÔNG tự bịa số liệu khoa học hay thời tiết. Hãy dùng các công cụ tra cứu khi cần.
- Nếu người hỏi muốn tới một nơi hoặc hỏi về một địa danh mới, bạn có thể gọi dieu_khien_app(hanh_dong: "bay_toi", tham_so: ...) để quả cầu tự động bay tới đó cho người khiếm thị cảm nhận.
- Khi trả lời về thời tiết hoặc các câu hỏi tự nhiên liên quan đến thời tiết, sinh hoạt, di chuyển: hãy dựa vào số liệu thời tiết thật để chủ động gợi ý thêm ngắn gọn (1 câu cuối):
  • Nếu là khu vực người dùng đang ở (chỗ tôi, ở đây, hoặc trùng nơi ở của người dùng): gợi ý cần chuẩn bị hay lưu ý gì khi ra ngoài (mang ô/áo mưa, mặc áo ấm, đeo khẩu trang, đi chậm tránh đường trơn, tránh nắng gắt...).
  • Nếu là một địa phương/điểm đến khác: gợi ý người dùng cần chuẩn bị hành trang hay lưu ý gì khi đến nơi này tham quan, công tác.
- Thời tiết nguy hiểm (bão, lũ, dông mạnh): nhắc nghe cảnh báo chính thức của cơ quan khí tượng thủy văn.
${kid ? '- Người hỏi là trẻ em dưới 12 tuổi: dùng từ đơn giản, thân thiện, xưng "mình" gọi "bạn".' : ''}
Ngữ cảnh: $context'''
      : '''You are the intelligent AI assistant in the "Lang" app (talking globe) for BLIND users and CHILDREN in Vietnam.
Answers are read aloud: reply in English, at most 3-4 short sentences, no markdown, symbols or emoji.
Write numbers naturally: "29 degrees", "3,143 metres", "70 percent".
Use tools to look up factual data:
- lay_thoi_tiet: real weather.
- tra_cuu_dia_danh: Viet Nam landmarks, heritage, culture.
- tra_cuu_vu_tru: space and solar system facts.
- tra_cuu_dia_hinh: mountains, depth, elevation, terrain.
- dieu_khien_app: navigate or control the globe (fly to, zoom, music).
Never invent numbers. Give practical advice for people who cannot see.
${kid ? 'The user is a child under 12: use simple, friendly words.' : ''}
Context: $context''';

  static const _tools = [
    {
      'functionDeclarations': [
        {
          'name': 'lay_thoi_tiet',
          'description': 'Lấy thời tiết THẬT: bây giờ, 24 giờ tới và 10 ngày tới (nhiệt độ, khả năng mưa, gió, UV, '
              'chất lượng không khí) cho một địa danh ở Việt Nam hoặc thế giới.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'noi': {'type': 'STRING', 'description': 'Tên địa danh, ví dụ "Huế", "Sa Pa", "quận 1 TP Hồ Chí Minh", "Tokyo".'},
            },
            'required': ['noi'],
          },
        },
        {
          'name': 'tra_cuu_dia_danh',
          'description': 'Tra cứu thông tin, câu chuyện lịch sử, văn hóa, danh lam thắng cảnh ở Việt Nam theo tên hoặc vùng miền.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'ten_hoac_vung': {'type': 'STRING', 'description': 'Tên địa danh hoặc vùng, ví dụ "Vịnh Hạ Long", "Hồ Gươm", "miền Trung", "Quảng Ninh".'},
            },
            'required': ['ten_hoac_vung'],
          },
        },
        {
          'name': 'tra_cuu_vu_tru',
          'description': 'Tra cứu kiến thức thiên văn, các hành tinh trong Hệ Mặt Trời (kích thước so với Trái Đất, khoảng cách, mặt trăng, nhiệt độ, khí quyển, phi thuyền).',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'doi_tuong': {'type': 'STRING', 'description': 'Tên hành tinh hoặc thiên thể, ví dụ "Sao Hỏa", "Mặt Trời", "Mặt Trăng", "Sao Mộc", "Sao Kim".'},
            },
            'required': ['doi_tuong'],
          },
        },
        {
          'name': 'tra_cuu_dia_hinh',
          'description': 'Tra cứu độ cao đỉnh núi, vực sâu biển, dãy núi, cao nguyên hoặc đồng bằng trên Trái Đất và Việt Nam.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'dia_diem': {'type': 'STRING', 'description': 'Tên đỉnh núi, vực sâu hoặc địa hình, ví dụ "Fansipan", "Everest", "Mariana", "Hoàng Liên Sơn".'},
            },
            'required': ['dia_diem'],
          },
        },
        {
          'name': 'dieu_khien_app',
          'description': 'Thực hiện hành động điều khiển ứng dụng quả địa cầu (bay tới nơi, phóng to, thu nhỏ, nghe nhạc, khám phá bằng chạm).',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'hanh_dong': {
                'type': 'STRING',
                'description': 'Hành động: "bay_toi" (tới nơi nào đó), "phong_to", "thu_nho", "nghe_nhac" (nghe nhạc cụ dân tộc nơi đó), "kham_pha_cham" (bản đồ chạm), "xem_ca_qua_cau".',
              },
              'tham_so': {
                'type': 'STRING',
                'description': 'Tên nơi hoặc tham số kèm theo, ví dụ "Paris", "Hà Nội", "Hồ Hoàn Kiếm", hoặc để trống nếu không có.',
              },
            },
            'required': ['hanh_dong'],
          },
        },
      ]
    }
  ];

  /// Hỏi Gemini với RAG và Agent Tools.
  ///
  /// [ragContext]: thông tin tri thức nội tại trích xuất được từ câu hỏi đưa thẳng vào prompt.
  /// [toolHandler]: bộ xử lý công cụ đa năng khi Gemini muốn tra cứu thêm.
  /// [known]: số liệu thời tiết đã lấy sẵn {tên nơi: thời tiết}.
  Future<String> ask(String question,
      {required String context,
      String? ragContext,
      WeatherLookup? lookup,
      LandmarkLookup? lookupLandmark,
      SpaceLookup? lookupSpace,
      TerrainLookup? lookupTerrain,
      AppActionHandler? handleAction,
      AgentToolHandler? toolHandler,
      Map<String, LiveWeather> known = const {},
      bool kid = false,
      String lang = 'vi'}) async {
    if (!enabled) throw const LiveError('Chưa có khoá Gemini.', 'No Gemini key.');
    final sw = Stopwatch()..start();
    final rag = (ragContext != null && ragContext.trim().isNotEmpty) ? '\n\n$ragContext' : '';
    final qLower = question.toLowerCase();
    final isWeather = RegExp(r'\b(thoi tiet|nhiet do|mua|nang|gio|uv|do am|ret|lanh|nong|am u|bao|sam|set|tuyet|khong khi|'
            r'aqi|o nhiem|o day troi|ngoai troi|ra ngoai|di choi|mac gi|mang o|ao mua|phoi do|phoi quan ao|'
            r'weather|temperature|rain|wind|forecast|humidity|sunny|cold|hot|storm)\b')
        .hasMatch(qLower);
    final data = (known.isEmpty || !isWeather)
        ? ''
        : '\n\nSố liệu thời tiết thật đã có (JSON): ${jsonEncode({for (final e in known.entries) e.key: e.value.toJson()})}';
    final contents = <Map<String, Object?>>[
      ..._history,
      {
        'role': 'user',
        'parts': [
          {'text': '$question$rag$data'}
        ]
      },
    ];
    // lịch sử chỉ giữ câu hỏi (không kèm số liệu) cho gọn
    final userTurn = {
      'role': 'user',
      'parts': [
        {'text': question}
      ]
    };
    for (var round = 0; round < 4; round++) {
      final resp = await _call(contents, _system(kid: kid, lang: lang, context: context));
      log?.call('[trợ lý AI] lượt ${round + 1}: ${sw.elapsedMilliseconds} ms');
      final cand = (resp['candidates'] as List?)?.firstOrNull;
      final content = cand is Map ? cand['content'] : null;
      final parts = content is Map ? (content['parts'] as List?) ?? const [] : const [];
      final calls = [for (final p in parts) if (p is Map && p['functionCall'] is Map) p['functionCall'] as Map];
      if (calls.isEmpty) {
        final text = [for (final p in parts) if (p is Map && p['text'] is String && p['thought'] != true) p['text'] as String]
            .join(' ');
        final clean = _clean(text);
        if (clean.isEmpty) break;
        // nhớ lượt này (chỉ câu hỏi + câu trả lời, gọn)
        _history
          ..add(userTurn)
          ..add({
            'role': 'model',
            'parts': [
              {'text': clean}
            ]
          });
        while (_history.length > 8) {
          _history.removeAt(0);
        }
        return clean;
      }
      // Gemini muốn gọi công cụ: giữ nguyên lượt của model (kèm chữ ký suy nghĩ nếu có) rồi gửi kết quả
      contents.add({'role': 'model', 'parts': parts});
      // Thực hiện các công cụ được AI yêu cầu (song song nếu có nhiều)
      final replies = await Future.wait([
        for (final c in calls)
          () async {
            final name = c['name'] as String? ?? '';
            final args = c['args'] is Map ? c['args'] as Map : const {};
            Map<String, Object?> result;
            try {
              if (name == 'lay_thoi_tiet' && lookup != null) {
                final place = '${args['noi'] ?? ''}'.trim();
                final r = place.isEmpty ? null : await lookup(place);
                result = r == null
                    ? {'loi': 'Không tìm thấy địa danh "$place"'}
                    : {'noi': r.$1, 'thoi_tiet': r.$2.toJson()};
              } else if (name == 'tra_cuu_dia_danh' && lookupLandmark != null) {
                final q = '${args['ten_hoac_vung'] ?? ''}'.trim();
                final r = q.isEmpty ? null : await lookupLandmark(q);
                result = r == null
                    ? {'thong_tin': 'Không tìm thấy dữ liệu địa danh "$q"'}
                    : {'ket_qua': r};
              } else if (name == 'tra_cuu_vu_tru' && lookupSpace != null) {
                final d = '${args['doi_tuong'] ?? ''}'.trim();
                final r = d.isEmpty ? null : await lookupSpace(d);
                result = r == null
                    ? {'thong_tin': 'Không tìm thấy dữ liệu thiên thể "$d"'}
                    : {'ket_qua': r};
              } else if (name == 'tra_cuu_dia_hinh' && lookupTerrain != null) {
                final d = '${args['dia_diem'] ?? ''}'.trim();
                final r = d.isEmpty ? null : await lookupTerrain(d);
                result = r == null
                    ? {'thong_tin': 'Không tìm thấy dữ liệu địa hình "$d"'}
                    : {'ket_qua': r};
              } else if (name == 'dieu_khien_app' && handleAction != null) {
                final act = '${args['hanh_dong'] ?? ''}'.trim();
                final param = '${args['tham_so'] ?? ''}'.trim();
                final r = await handleAction(act, param);
                result = {'trang_thai': r ?? 'Đã thực hiện'};
              } else if (toolHandler != null) {
                result = await toolHandler(name, Map<String, Object?>.from(args));
              } else if (name == 'lay_thoi_tiet') {
                final place = '${args['noi'] ?? ''}'.trim();
                result = {'loi': 'Không tìm thấy địa danh "$place"'};
              } else if (name == 'tra_cuu_dia_danh') {
                final q = '${args['ten_hoac_vung'] ?? ''}'.trim();
                result = {'thong_tin': 'Không tìm thấy dữ liệu địa danh "$q"'};
              } else if (name == 'tra_cuu_vu_tru') {
                final d = '${args['doi_tuong'] ?? ''}'.trim();
                result = {'thong_tin': 'Không tìm thấy dữ liệu thiên thể "$d"'};
              } else if (name == 'tra_cuu_dia_hinh') {
                final d = '${args['dia_diem'] ?? ''}'.trim();
                result = {'thong_tin': 'Không tìm thấy dữ liệu địa hình "$d"'};
              } else if (name == 'dieu_khien_app') {
                result = {'trang_thai': 'Đã thực hiện'};
              } else {
                result = {'loi': 'Không có công cụ $name'};
              }
            } on LiveError catch (e) {
              result = {'loi': e.vi};
            } catch (e) {
              result = {'loi': '$e'};
            }
            return <String, Object?>{
              'functionResponse': {'name': name, 'response': result}
            };
          }(),
      ]);
      contents.add({'role': 'user', 'parts': replies});
    }
    throw const LiveError('Trợ lý AI chưa trả lời được.', 'The AI assistant could not answer.');
  }

  /// HIỂU CÂU NÓI KHÁC CÁCH (đồng nghĩa): đổi câu người dùng nói thành MỘT câu lệnh chuẩn trong danh sách app hiểu,
  /// ví dụ "cho tôi nghe tình hình nắng mưa ở Đà Lạt" → "thời tiết Đà Lạt". App phân tích lại câu chuẩn bằng bộ
  /// hiểu lệnh của mình (nên AI không thể bắt app làm việc ngoài danh sách). Trả về null nếu không khớp lệnh nào.
  Future<String?> canonicalCommand(String heard, {required String lang}) async {
    const system = 'Bạn chuyển câu nói của người dùng (người khiếm thị, dùng app quả địa cầu biết nói) thành ĐÚNG MỘT câu lệnh '
        'theo các mẫu sau, thay <nơi>, <hành tinh> bằng tên thật trong câu. Chỉ in câu lệnh, không giải thích. '
        'Nếu câu không ứng với mẫu nào, in NONE.\n'
        'Mẫu:\n'
        'thời tiết <nơi>\n'
        'thời tiết\n'
        'ngày mai <nơi> có mưa không\n'
        'chiều nay <nơi> có mưa không\n'
        'mai đi chơi ở <nơi> có hợp không\n'
        'mai ra ngoài cần chuẩn bị gì\n'
        'dự báo 5 ngày <nơi>\n'
        '24 giờ tới <nơi>\n'
        'khí hậu <nơi>\n'
        'bản tin\n'
        'thiên tai trên thế giới\n'
        'thiên tai ở <nơi>\n'
        'đi tới <nơi>\n'
        'quanh <nơi> có gì\n'
        '<nơi> có địa điểm ăn uống vui chơi gì\n'
        '<nơi> ăn gì ngon\n'
        'quanh đây có gì\n'
        'tôi đang ở đâu\n'
        'khám phá bằng tay <nơi>\n'
        'khám phá bằng tay\n'
        'xưa và nay <nơi>\n'
        'kể chuyện <hành tinh>\n'
        'khám phá vũ trụ\n'
        'ảnh thiên văn hôm nay\n'
        'cả thế giới\n'
        'phóng to\n'
        'thu nhỏ\n'
        'đọc lại\n'
        'đọc chậm hơn\n'
        'đọc nhanh hơn\n'
        'dừng lại\n'
        'tạm nghỉ\n'
        'nghe nhạc\n'
        'hướng dẫn thời tiết\n'
        'hướng dẫn địa lý\n'
        'hướng dẫn vũ trụ\n'
        'trợ giúp\n'
        'chuyển sang tiếng Anh\n'
        'chuyển sang tiếng Việt';
    try {
      final j = await _call([
        {
          'role': 'user',
          'parts': [
            {'text': heard}
          ]
        }
      ], system, tools: false, temperature: 0, maxTokens: 40, timeout: const Duration(seconds: 6));
      final parts = ((((j['candidates'] as List?)?.firstOrNull as Map?)?['content'] as Map?)?['parts'] as List?) ?? const [];
      final out = parts.map((p) => (p as Map)['text'] ?? '').join().trim().split('\n').first.trim();
      if (out.isEmpty || out.toUpperCase().startsWith('NONE') || out.length > 80) return null;
      return out.replaceAll(RegExp('^["“”\'`*\\-\\s]+|["“”\'`*\\s.]+\$'), '');
    } catch (e) {
      log?.call('[AI hiểu lệnh] $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _call(List<Map<String, Object?>> contents, String system,
      {bool tools = true,
      double temperature = 0.4,
      int maxTokens = 400,
      Duration timeout = const Duration(seconds: 20),
      int attempt = 0,
      String? useModel}) async {
    final m = (useModel ?? model).trim();
    final useProxy = apiKey.trim().isEmpty && proxy != null;
    final u = useProxy
        ? proxy!.replace(queryParameters: {'model': m})
        : Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$m:generateContent');
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': contents,
      if (tools) 'tools': _tools,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        // tắt "suy nghĩ" (model Flash mới mặc định suy nghĩ vài giây trước khi trả lời) — câu trả lời ngắn không cần
        if (_thinkingOff) 'thinkingConfig': _thinkingOffFor(m),
      },
    });
    final http.Response r;
    try {
      r = await client
          .post(u,
              headers: {'Content-Type': 'application/json', if (!useProxy) 'x-goog-api-key': apiKey.trim()}, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw const LiveError('Trợ lý AI trả lời quá lâu.', 'The AI assistant took too long.');
    } catch (e) {
      log?.call('[Gemini _call error] $e');
      throw const LiveError('Máy chưa kết nối mạng nên chưa hỏi được trợ lý AI.', 'No internet connection for the AI assistant.');
    }
    if (r.statusCode == 400 && _thinkingOff && utf8.decode(r.bodyBytes).toLowerCase().contains('think')) {
      _thinkingOff = false; // model này không cho tắt suy nghĩ → gửi lại không kèm tuỳ chọn đó
      return _call(contents, system,
          tools: tools, temperature: temperature, maxTokens: maxTokens, timeout: timeout, attempt: attempt, useModel: useModel);
    }
    if (r.statusCode != 200) {
      log?.call('[Gemini] ${r.statusCode}: ${apiKey.isEmpty ? utf8.decode(r.bodyBytes) : utf8.decode(r.bodyBytes).replaceAll(apiKey, '***')}');
      // Lỗi tạm thời phía Google (500 Internal error, 502, máy chủ quá 18 giây 504): thử lại một lần cùng model,
      // vẫn lỗi thì hỏi model dự phòng — người dùng không phải nghe "Trợ lý AI báo lỗi 500"
      if (r.statusCode == 500 || r.statusCode == 502 || r.statusCode == 504) {
        if (attempt == 0) {
          // Tắt thinkingConfig khi Google lỗi 500 vì đây là nguyên nhân hàng đầu gây crash internal server
          _thinkingOff = false;
          await Future<void>.delayed(const Duration(milliseconds: 800));
          return _call(contents, system,
              tools: tools, temperature: temperature, maxTokens: maxTokens, timeout: timeout, attempt: 1, useModel: useModel);
        }
        if (attempt == 1 && m != fallbackModel) {
          log?.call('[Gemini] $m lỗi ${r.statusCode} hai lần → hỏi model dự phòng $fallbackModel');
          return _call(contents, system,
              tools: tools, temperature: temperature, maxTokens: maxTokens, timeout: timeout, attempt: 2, useModel: fallbackModel);
        }
        throw const LiveError('Trợ lý AI đang trục trặc, bạn hỏi lại sau ít phút nhé.',
            'The AI assistant is having trouble; please try again in a few minutes.');
      }
      if (model != defaultModel && (r.statusCode == 404 || r.statusCode == 400)) {
        log?.call('[Gemini] Model $model thất bại (${r.statusCode}) -> tự động chuyển sang $defaultModel');
        model = defaultModel;
        return _call(contents, system, tools: tools, temperature: temperature, maxTokens: maxTokens, timeout: timeout);
      }
      if (r.statusCode == 503 && useProxy) {
        throw const LiveError('Trợ lý AI chưa được bật trên máy chủ.', 'The AI assistant is not enabled on the server.');
      }
      if (r.statusCode == 400 || r.statusCode == 403) {
        throw const LiveError('Khoá Gemini không hợp lệ hoặc chưa được bật. Kiểm tra trong Cài đặt.',
            'The Gemini key is invalid or not enabled. Check Settings.');
      }
      if (r.statusCode == 404) {
        throw const LiveError('Không có model Gemini này. Kiểm tra tên model trong Cài đặt.',
            'Unknown Gemini model. Check the model name in Settings.');
      }
      if (r.statusCode == 429) {
        throw const LiveError('Trợ lý AI đang hết lượt dùng, thử lại sau ít phút.', 'The AI assistant is rate limited; try again soon.');
      }
      throw LiveError('Trợ lý AI báo lỗi ${r.statusCode}.', 'The AI assistant returned error ${r.statusCode}.');
    }
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Bỏ ký hiệu markdown để giọng đọc không đọc "sao sao".
  static String _clean(String t) => t
      .replaceAll(RegExp(r'[*_#`>]+'), '')
      .replaceAll(RegExp(r'^\s*[-•]\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
