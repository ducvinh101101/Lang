import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/crash_guard.dart';
import '../../core/geo.dart';
import '../../live/gemini_assistant.dart';
import '../../live/live_weather.dart';
import '../../data/asset_data.dart';
import '../../speech/nvidia_asr.dart';
import '../../speech/speaker.dart';
import '../../core/stats.dart';

Future<void> showSettings(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SettingsSheet(),
    );

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(s.t('Cài đặt', 'Settings'), style: tt.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            title: Text(s.t('Ngôn ngữ', 'Language')),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'vi', label: Text('VI')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {s.lang},
              onSelectionChanged: (x) => s.setLang(x.first),
            ),
          ),
          const Divider(),
          Text(s.t('Thời tiết', 'Weather'), style: tt.titleMedium),
          const _LiveSection(advanced: false),
          const Divider(),
          Text(s.t('Lời đọc và âm thanh', 'Speech and sound'), style: tt.titleMedium),
          RadioListTile<String>(
            value: 'auto',
            groupValue: s.speechModePref,
            onChanged: (x) => s.setSpeechMode(x!),
            title: Text(s.t('Tự động', 'Automatic')),
            subtitle: Text(s.t('Nhường TalkBack/VoiceOver đọc nếu đang bật, không thì app tự đọc',
                'Let TalkBack/VoiceOver speak when on, otherwise the app speaks')),
          ),
          RadioListTile<String>(
            value: 'tts',
            groupValue: s.speechModePref,
            onChanged: (x) => s.setSpeechMode(x!),
            title: Text(s.t('App tự đọc', 'App speaks')),
          ),
          RadioListTile<String>(
            value: 'sr',
            groupValue: s.speechModePref,
            onChanged: (x) => s.setSpeechMode(x!),
            title: Text(s.t('Chỉ gửi cho trình đọc màn hình', 'Screen reader only')),
          ),
          if (s.speaker.usingWinVoice || s.speaker.hasBuiltinVoice) const _VoicePicker(),
          if (s.speaker.webMissingVietnamese)
            ListTile(
              leading: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
              title: Text(s.t('Trình duyệt này chưa có giọng đọc tiếng Việt', 'This browser has no Vietnamese voice')),
              subtitle: Text(s.t('Tiếng Việt sẽ bị đọc sai giọng. Hãy mở Lắng bằng Microsoft Edge '
                  '(có giọng tiếng Việt tự nhiên), hoặc cài giọng tiếng Việt cho máy.',
                  'Vietnamese will sound wrong. Open Lang in Microsoft Edge, or install a Vietnamese voice.')),
            ),
          if (!s.speaker.hasVietnamese && !s.speaker.usingFallback)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                s.t('Chưa dò thấy giọng đọc tiếng Việt. App vẫn thử đọc; nếu im lặng hoặc đọc giọng nước ngoài, hãy cài: Cài đặt → Thời gian và ngôn ngữ → Ngôn ngữ → thêm Tiếng Việt (bật Chuyển văn bản thành giọng nói), rồi mở lại app.',
                    'No Vietnamese voice detected. The app still tries to speak; if it is silent or uses a foreign voice, add Vietnamese (with text-to-speech) in Settings → Time & language → Language, then restart the app.'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ListTile(
            title: Text(s.t('Tốc độ đọc', 'Speech rate')),
            subtitle: Slider(
              value: s.speaker.rate,
              min: 0.2,
              max: 0.9,
              divisions: 7,
              label: s.speaker.rate.toStringAsFixed(1),
              onChanged: (x) => s.setRate(x),
            ),
          ),
          ListTile(
            title: Text(s.t('Âm lượng nhạc cụ', 'Instrument volume')),
            subtitle: Slider(
              value: s.audio.volume,
              divisions: 10,
              label: '${(s.audio.volume * 100).round()}%',
              onChanged: (x) => s.setVolume(x),
            ),
          ),
          SwitchListTile(
            value: s.haptics,
            onChanged: s.setHaptics,
            title: Text(s.t('Rung nhẹ khi bay tới nơi mới', 'Vibrate when arriving at a place')),
          ),
          SwitchListTile(
            value: s.earcons,
            onChanged: s.setEarcons,
            title: Text(s.t('Âm báo thao tác', 'Interface sounds')),
          ),
          SwitchListTile(
            value: s.wakeMode,
            onChanged: s.setWakeMode,
            title: Text(s.t('Chế độ gọi tên (Khẩu hiệu đánh thức)', 'Wake word mode')),
            subtitle: Text(s.t(
                'Chỉ nhận lệnh khi gọi "Lắng ơi" (tiếng Anh: "Hey Listen"). Chống bị chèn lời hay tiếng ồn.',
                'Only listen after saying "Hey Listen" (Vietnamese: "Lắng ơi"). Prevents interruptions and background noise.')),
          ),
          const Divider(),
          // Phần kỹ thuật (khoá API, nguồn dữ liệu, khắc phục sự cố) gom vào đây, đóng sẵn — không làm rối người dùng
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: s.safeMode != null || !s.pluginTts || !s.instruments,
            leading: const Icon(Icons.build_outlined),
            title: Text(s.t('Nâng cao', 'Advanced'), style: tt.titleMedium),
            subtitle: Text(s.t('Trợ lý AI, nguồn dữ liệu, thống kê, khắc phục sự cố', 'AI assistant, data sources, statistics, troubleshooting')),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.t('Trợ lý AI và nguồn thời tiết', 'AI assistant and weather source'), style: tt.titleSmall),
              const _LiveSection(advanced: true),
              const Divider(),
              Text(s.t('Nhận diện giọng nói nâng cao (NVIDIA NIM)', 'Advanced speech recognition (NVIDIA NIM)'), style: tt.titleSmall),
              const _NvidiaAsrSection(),
              const Divider(),
              Text(s.t('Nguồn dữ liệu bản đồ (khí hậu NASA)', 'Map data source (NASA climate)'), style: tt.titleSmall),
              const _DataSourceSection(),
              const Divider(),
              SwitchListTile(
                value: Stats.instance.enabled,
                onChanged: s.setStatsEnabled,
                title: Text(s.t('Gửi thống kê lượt dùng ẩn danh', 'Send anonymous usage counts')),
                subtitle: Text(s.t('Chỉ đếm số lượt (mở app, câu lệnh…) để báo cáo dự án. Không gửi giọng nói, câu hỏi hay vị trí.',
                    'Only counts (app opens, commands…) for project reporting. No voice, questions or location.')),
              ),
              const Divider(),
              Text(s.t('Khắc phục sự cố', 'Troubleshooting'), style: tt.titleSmall),
              if (s.safeMode != null || !s.pluginTts || !s.instruments)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    s.t('Chế độ an toàn đang bật: phần từng làm app tắt đột ngột đã được tạm tắt.',
                        'Safe mode is on: the part that crashed the app is turned off for now.'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              SwitchListTile(
                value: s.pluginTts,
                onChanged: s.setPluginTts,
                secondary: const Icon(Icons.record_voice_over),
                title: Text(s.t('Giọng đọc của hệ điều hành', 'System text-to-speech')),
                subtitle: Text(s.t(
                    'Tắt nếu app hay bị tắt đột ngột khi đọc: app dùng giọng dự phòng (Windows) hoặc trình đọc màn hình. Có hiệu lực khi mở lại app.',
                    'Turn off if the app closes while speaking: a backup voice (Windows) or the screen reader is used. Takes effect after restart.')),
              ),
              SwitchListTile(
                value: s.instruments,
                onChanged: s.setInstruments,
                secondary: const Icon(Icons.music_note),
                title: Text(s.t('Nhạc cụ (âm thanh dữ liệu)', 'Instruments (data sound)')),
                subtitle: Text(s.t('Tắt nếu app bị tắt đột ngột khi phát âm thanh. Có hiệu lực khi mở lại app.',
                    'Turn off if the app closes while playing sound. Takes effect after restart.')),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(s.t('Nhật ký lỗi (gửi cho nhóm phát triển)', 'Error log (send to developers)')),
                subtitle: SelectableText(CrashGuard.logPath),
              ),
              if (s.audio.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Audio: ${s.audio.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Chọn nguồn dữ liệu: tự động / NASA đóng gói trong app / NASA tải từ URL / mô phỏng.
class _DataSourceSection extends StatefulWidget {
  const _DataSourceSection();

  @override
  State<_DataSourceSection> createState() => _DataSourceSectionState();
}

class _DataSourceSectionState extends State<_DataSourceSection> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: AppScope.read(context).remoteUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    Widget option(String value, String vi, String en, String subVi, String subEn) => RadioListTile<String>(
          value: value,
          groupValue: s.dataSource,
          onChanged: s.dataBusy ? null : (x) => s.setDataSource(x!, url: _url.text),
          title: Text(s.t(vi, en)),
          subtitle: Text(s.t(subVi, subEn)),
        );
    final d = s.data;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      option('auto', 'Tự động', 'Automatic', 'Dữ liệu NASA trong app nếu có, không thì mô phỏng',
          'Bundled NASA data if present, otherwise simulated'),
      option('assets', 'Dữ liệu NASA trong app', 'Bundled NASA data',
          s.assetData == null ? 'Chưa có — chạy python -m pipeline.update' : 'Đã có, chạy offline',
          s.assetData == null ? 'Not yet — run python -m pipeline.update' : 'Available offline'),
      option('remote', 'Dữ liệu NASA từ URL', 'NASA data from URL', 'Cập nhật dữ liệu mới không cần cài lại app',
          'Get new data without reinstalling the app'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: s.t('URL thư mục dữ liệu', 'Data folder URL'),
                hintText: 'https://…/web/data/',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: s.dataBusy ? null : () => s.setDataSource('remote', url: _url.text),
            child: Text(s.t('Tải', 'Load')),
          ),
        ]),
      ),
      option('synthetic', 'Dữ liệu mô phỏng', 'Simulated data', 'Để thử app khi chưa có mạng/dữ liệu',
          'For trying the app without data'),
      if (s.dataBusy) const LinearProgressIndicator(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('${s.t('Đang dùng', 'In use')}: ${d.label(s.lang)}'),
      ),
      if (d is AssetData && d.credits.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('${s.t('Nguồn', 'Sources')}: ${d.credits.join('; ')}', style: Theme.of(context).textTheme.bodySmall),
        ),
      if (s.dataError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(s.dataError!, style: TextStyle(color: cs.error)),
        ),
    ]);
  }
}


/// Chọn giọng đọc (Windows): giọng tiếng Việt lên đầu, chọn là đọc thử. Không có giọng Việt → chỉ cách cài.
class _VoicePicker extends StatelessWidget {
  const _VoicePicker();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final voices = [...s.speaker.winVoices]..sort((a, b) => (b.isVietnamese ? 1 : 0) - (a.isVietnamese ? 1 : 0));
    const app = Speaker.appVoiceName;
    final cur = s.speaker.usingBuiltinVoice ? app : s.speaker.currentVoice;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(
          value: cur == app || voices.any((v) => v.name == cur) ? cur : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: s.t('Giọng đọc', 'Voice')),
          items: [
            if (s.speaker.hasBuiltinVoice)
              DropdownMenuItem(
                value: app,
                child: Text(s.t('Giọng tiếng Việt của app (khuyên dùng)',
                    'App Vietnamese voice (recommended, offline)')),
              ),
            for (final v in voices)
              DropdownMenuItem(
                value: v.name,
                child: Text('${v.name} · ${v.locale}${v.isVietnamese ? s.t(' (tiếng Việt)', ' (Vietnamese)') : ''}'),
              ),
          ],
          onChanged: (n) {
            if (n != null) s.setVoiceName(n);
          },
        ),
        if (s.speaker.missingVietnamese) ...[
          const SizedBox(height: 8),
          Text(
            s.t('Máy chưa có giọng tiếng Việt nên app đọc bằng giọng Anh. Bản web nghe đúng vì trình duyệt có giọng trực tuyến riêng. '
                    'Cài: Cài đặt → Thời gian và ngôn ngữ → Giọng nói → Thêm giọng → Tiếng Việt, rồi bấm Kiểm tra lại.',
                'No Vietnamese voice on this PC, so an English voice is used. Add one: Settings → Time & language → Speech → Add voices → Vietnamese, then tap Check again.'),
            style: TextStyle(color: cs.error),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: s.speaker.openSystemVoiceSettings,
              icon: const Icon(Icons.open_in_new),
              label: Text(s.t('Mở cài đặt giọng nói', 'Open speech settings')),
            ),
            FilledButton.icon(
              onPressed: s.recheckVoices,
              icon: const Icon(Icons.refresh),
              label: Text(s.t('Kiểm tra lại', 'Check again')),
            ),
          ]),
        ],
      ]),
    );
  }
}


/// Thời tiết trực tiếp: nơi của bạn, nguồn (Open-Meteo miễn phí / Google Weather), khoá Gemini cho trợ lý AI.
/// Khoá chỉ lưu trên máy này (cài đặt của app), không gửi đi đâu ngoài chính dịch vụ của Google.
class _LiveSection extends StatefulWidget {
  const _LiveSection({required this.advanced});

  /// false: nơi của bạn + bản đồ hôm nay (ai cũng cần); true: khoá API, nguồn, model, thử kết nối.
  final bool advanced;

  @override
  State<_LiveSection> createState() => _LiveSectionState();
}

class _LiveSectionState extends State<_LiveSection> {
  late final TextEditingController _gw, _gem, _model, _firms;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _gw = TextEditingController(text: s.weather.googleKey);
    _gem = TextEditingController(text: s.ai.apiKey);
    _model = TextEditingController(text: s.ai.model);
    _firms = TextEditingController(text: s.liveGrid.firmsKey);
  }

  @override
  void dispose() {
    _gw.dispose();
    _gem.dispose();
    _model.dispose();
    _firms.dispose();
    super.dispose();
  }

  Future<void> _test(AppState s) async {
    setState(() => _testing = true);
    final p = s.home ?? places.firstWhere((x) => x.name == 'Hà Nội', orElse: () => places.first);
    try {
      final w = await s.weather.get(p.lat, p.lon, force: true, lang: s.lang);
      var msg = 'Đã lấy được thời tiết từ ${w.source}: ${p.name} bây giờ ${w.now.temp.round()} độ, ${w.now.desc}.';
      if (s.weather.provider == 'google' && w.source != 'Google') {
        msg += ' Khoá Google Weather chưa dùng được nên app đang dùng Open-Meteo.';
      }
      if (s.ai.enabled) {
        try {
          final a = await s.ai.ask('Trả lời đúng một câu: trợ lý đã sẵn sàng chưa?',
              context: 'Kiểm tra kết nối.', lookup: (_) async => null, lang: s.lang);
          msg += ' Trợ lý AI trả lời: $a';
        } on LiveError catch (e) {
          msg += ' Trợ lý AI: ${e.vi}';
        }
        s.ai.reset();
      }
      await s.speaker.say(msg, msg);
    } on LiveError catch (e) {
      await s.speaker.say(e.vi, e.en);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    if (!widget.advanced) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: DropdownButtonFormField<String>(
            initialValue: s.homePlace,
            isExpanded: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: s.t('Nơi của bạn', 'Your place'),
              helperText: s.t('Hỏi "thời tiết" mà không nói nơi nào thì đọc ở đây', 'Used when you ask "weather" without a place'),
              helperMaxLines: 2,
            ),
            hint: Text(s.t('Chưa chọn', 'Not set')),
            items: [
              for (final p in places.where((p) => !p.name.startsWith('quần đảo')))
                DropdownMenuItem(value: p.name, child: Text(p.name)),
            ],
            onChanged: (v) => s.setHomePlace(v),
          ),
        ),
        SwitchListTile(
          value: s.liveMap,
          onChanged: (on) => s.setLiveMap(on),
          title: Text(s.t('Bản đồ hiện số liệu hôm nay', 'Map shows today\'s data')),
          subtitle: Text(s.t('Tắt: dữ liệu khí hậu NASA các năm. Chế độ khiếm thị luôn mở ra là hôm nay.',
              'Off: past NASA climate data. Blind mode always starts with today.')),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: TextField(
          controller: _firms,
          obscureText: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: s.t('Khoá NASA FIRMS (MAP_KEY) — điểm cháy hôm nay', 'NASA FIRMS MAP_KEY — fires today'),
            helperText: s.t('Miễn phí tại firms.modaps.eosdis.nasa.gov/api/map_key. Để trống = không có lớp cháy hôm nay.',
                'Free at firms.modaps.eosdis.nasa.gov/api/map_key. Empty = no fire layer today.'),
            helperMaxLines: 3,
          ),
          onChanged: s.setFirmsKey,
        ),
      ),
      RadioListTile<String>(
        value: 'open-meteo',
        groupValue: s.weather.provider,
        onChanged: (v) => s.setWeatherProvider(v!),
        title: Text(s.t('Open-Meteo (miễn phí, không cần khoá)', 'Open-Meteo (free, no key)')),
        subtitle: Text(s.t('Bây giờ, theo giờ, 10 ngày tới và chất lượng không khí', 'Now, hourly, 10 days and air quality')),
      ),
      RadioListTile<String>(
        value: 'google',
        groupValue: s.weather.provider,
        onChanged: (v) => s.setWeatherProvider(v!),
        title: Text(s.t('Google Weather API', 'Google Weather API')),
        subtitle: Text(s.t('Cần khoá Google Maps Platform đã bật Weather API. Lỗi thì tự dùng Open-Meteo.',
            'Needs a Google Maps Platform key with the Weather API enabled. Falls back to Open-Meteo.')),
      ),
      if (s.weather.provider == 'google')
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _gw,
            obscureText: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: s.t('Khoá Google Weather API', 'Google Weather API key'),
            ),
            onSubmitted: s.setGoogleWeatherKey,
            onChanged: s.setGoogleWeatherKey,
          ),
        ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
            s.t('Trợ lý AI (Gemma 4 hoặc Gemini, cùng một khoá): trả lời câu hỏi tự do bằng giọng nói ("chiều nay đi chợ có cần áo mưa không?"), '
                'dựa trên số liệu thời tiết thật. Lấy khoá miễn phí tại aistudio.google.com.',
                'AI assistant (Gemma 4 or Gemini, same key): answers free-form voice questions using real weather data. Get a free key at aistudio.google.com.'),
            style: tt.bodyMedium),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: TextField(
          controller: _gem,
          obscureText: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: s.t('Khoá Gemini API', 'Gemini API key'),
            helperText: s.ai.enabled ? s.t('Đã bật trợ lý AI', 'AI assistant on') : s.t('Để trống = không dùng AI', 'Empty = no AI'),
          ),
          onChanged: (v) => s.setGemini(key: v),
        ),
      ),
      // Chọn nhanh model (cùng một khoá Gemini API dùng được cả Gemma 4 và Gemini)
      for (final (id, vi, en) in GeminiAssistant.presets)
        RadioListTile<String>(
          value: id,
          groupValue: s.ai.model,
          dense: true,
          title: Text(s.t(vi, en)),
          subtitle: Text(id),
          onChanged: (v) {
            _model.text = v!;
            s.setGemini(model: v);
          },
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: TextField(
          controller: _model,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: s.t('Hoặc gõ tên model khác', 'Or type another model name'),
            helperText: s.t('Mặc định ${GeminiAssistant.defaultModel}', 'Default ${GeminiAssistant.defaultModel}'),
          ),
          onSubmitted: (v) => s.setGemini(model: v),
          onChanged: (v) => s.setGemini(model: v),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            onPressed: _testing ? null : () => _test(s),
            icon: _testing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_check),
            label: Text(s.t('Thử kết nối thời tiết và AI', 'Test weather and AI')),
          ),
        ),
      ),
    ]);
  }
}

/// Cài đặt NVIDIA NIM ASR (Parakeet CTC 0.6B Vi-En).
/// Dự phòng nhận dạng giọng nói trực tuyến hoặc qua container Docker local.
class _NvidiaAsrSection extends StatefulWidget {
  const _NvidiaAsrSection();

  @override
  State<_NvidiaAsrSection> createState() => _NvidiaAsrSectionState();
}

class _NvidiaAsrSectionState extends State<_NvidiaAsrSection> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _endpointCtrl;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _keyCtrl = TextEditingController(text: s.nvidiaAsr.apiKey);
    _endpointCtrl = TextEditingController(text: s.nvidiaAsr.endpoint);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.t(
              'Nhận diện giọng nói nâng cao (Groq Whisper Large V3 hoặc NVIDIA NIM): '
              'Tăng độ chuẩn xác cho các từ tiếng Anh/Việt lẫn lộn hoặc tên riêng. '
              'App ưu tiên nhận diện offline trên máy, nếu không nghe rõ sẽ tự động dùng Cloud/NIM.',
              'Advanced Speech Recognition (Groq Whisper Large V3 or NVIDIA NIM): '
              'Boosts accuracy for mixed Vietnamese-English and proper nouns. '
              'The app prefers on-device offline recognition, falling back to Cloud/NIM when unclear.',
            ),
            style: tt.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: s.t('Khoá API Key (Groq hoặc NVIDIA)', 'API Key (Groq or NVIDIA)'),
              helperText: s.nvidiaAsr.enabled
                  ? s.t(
                      'Đã bật: ${s.nvidiaAsr.effectiveModel} (${s.nvidiaAsr.effectiveEndpoint})',
                      'Enabled: ${s.nvidiaAsr.effectiveModel} (${s.nvidiaAsr.effectiveEndpoint})',
                    )
                  : s.t(
                      'Nhập Groq API Key (gsk_... tại console.groq.com) hoặc NVIDIA key',
                      'Enter Groq API Key (gsk_... at console.groq.com) or NVIDIA key',
                    ),
              helperMaxLines: 2,
            ),
            onChanged: (v) {
              if (v.trim().startsWith('gsk_')) {
                s.setGroqKey(v);
              } else {
                s.setNvidiaKey(v);
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _endpointCtrl,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: s.t('Endpoint URL (Tùy chọn)', 'Endpoint URL (Optional)'),
              helperText: s.t(
                'Mặc định Groq: ${NvidiaAsr.groqEndpoint}. Hoặc local NIM: ${NvidiaAsr.nvidiaLocalEndpoint}',
                'Default Groq: ${NvidiaAsr.groqEndpoint}. Or local NIM: ${NvidiaAsr.nvidiaLocalEndpoint}',
              ),
              helperMaxLines: 3,
            ),
            onChanged: s.setNvidiaEndpoint,
          ),
        ],
      ),
    );
  }
}

