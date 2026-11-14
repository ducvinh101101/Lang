// Lắng — bản Flutter.
// Cấu trúc:
//   core/      lưới, địa lý, định dạng số
//   data/      ClimateData (giả lập | output pipeline NASA)
//   audio/     tổng hợp nhạc cụ + backend phát (flutter_soloud)
//   speech/    TTS / trình đọc màn hình
//   features/  globe (quả địa cầu 3D + nghe lệnh liên tục), voice (hiểu lệnh), settings
//   live/      thời tiết thật (Open-Meteo/Google), khí hậu NASA POWER, trợ lý AI Gemini
import 'dart:ui' show AppExitResponse, PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;

import 'app_state.dart';
import 'core/crash_guard.dart';
import 'features/globe/globe_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Web: bật sẵn cây ngữ nghĩa cho trình đọc màn hình (Flutter web mặc định tắt, người khiếm thị phải tìm nút ẩn để bật)
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  // Đọc dấu vết lần chạy trước: nếu app đã văng trong plugin nào thì lần này tự tắt plugin đó (chế độ an toàn).
  CrashGuard.init();
  // Ghi mọi lỗi ra terminal VÀ file nhật ký (đường dẫn hiện trong Cài đặt), không để lỗi Dart làm app thoát.
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    CrashGuard.log('${d.exceptionAsString()}\n${d.stack ?? ''}');
  };
  PlatformDispatcher.instance.onError = (e, st) {
    CrashGuard.log('$e\n$st');
    return true;
  };
  final state = AppState();
  runApp(LangApp(state: state));
  state.init();
}

class LangApp extends StatelessWidget {
  final AppState state;
  const LangApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Lắng',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // Một giao diện duy nhất cho người khiếm thị / nhìn kém: tối "sơn mài", tương phản cao
        builder: (context, child) => Theme(
          data: buildAppTheme(UiMode.blind, MediaQuery.platformBrightnessOf(context)),
          child: child!,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppState? _sRef;
  bool _safeShown = false;

  // Đóng app bình thường / chuyển nền: xoá dấu vết, để lần sau không tưởng là văng
  late final AppLifecycleListener _life = AppLifecycleListener(
    onExitRequested: () async {
      CrashGuard.clean();
      _sRef?.speaker.dispose(); // tắt tiến trình giọng đọc Windows
      return AppExitResponse.exit;
    },
    onHide: CrashGuard.clean,
    onPause: CrashGuard.clean,
    onDetach: CrashGuard.clean,
  );

  @override
  void initState() {
    super.initState();
    _life; // khởi tạo listener
  }

  bool _voiceWarned = false;

  /// Windows chưa có giọng tiếng Việt: câu tiếng Việt sẽ bị đọc bằng giọng Anh → báo một lần và chỉ cách cài.
  void _maybeWarnVoice(AppState s) {
    if (_voiceWarned || !s.speaker.missingVietnamese || s.lang != 'vi') return;
    _voiceWarned = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Câu tiếng Anh trước (giọng Anh đọc đúng), rồi câu tiếng Việt cho người nhìn được đọc
      // Máy chỉ có giọng Anh → nói câu tiếng Anh (đọc đúng) để người khiếm thị biết vì sao giọng nghe lạ
      await s.speaker.say('This computer has no Vietnamese voice. Please ask someone to install Vietnamese speech in Windows settings.');
      if (!mounted || s.blindMode) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.record_voice_over, size: 40),
          title: const Text('Máy chưa có giọng đọc tiếng Việt'),
          content: const Text(
              'Windows trên máy này chỉ có giọng tiếng Anh, nên app sẽ đọc tiếng Việt sai giọng. '
              'Bản web nghe đúng vì Edge/Chrome dùng giọng trực tuyến riêng của trình duyệt.\n\n'
              'Cách cài (khoảng 1 phút, cần mạng): Cài đặt → Thời gian và ngôn ngữ → Giọng nói (Speech) → '
              'Thêm giọng (Add voices) → chọn Tiếng Việt. Xong quay lại app bấm "Kiểm tra lại".'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Để sau')),
            TextButton(
              onPressed: () => s.speaker.openSystemVoiceSettings(),
              child: const Text('Mở cài đặt giọng nói'),
            ),
            FilledButton(
              onPressed: () async {
                await s.recheckVoices();
                if (c.mounted && s.speaker.hasVietnamese) Navigator.pop(c);
              },
              child: const Text('Kiểm tra lại'),
            ),
          ],
        ),
      );
    });
  }

  /// Báo cho người dùng biết app đã tự bật chế độ an toàn (một lần).
  void _maybeShowSafeMode(AppState s) {
    final part = s.safeMode;
    if (part == null || _safeShown) return;
    _safeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vi = part == 'tts'
          ? 'Lần trước app bị tắt đột ngột khi dùng giọng đọc của máy. App đã chuyển sang giọng đọc dự phòng để không bị tắt nữa. Có thể bật lại trong Cài đặt.'
          : 'Lần trước app bị tắt đột ngột khi phát nhạc cụ. App đã tạm tắt nhạc cụ để không bị tắt nữa, giọng đọc vẫn hoạt động. Có thể bật lại trong Cài đặt.';
      final en = part == 'tts'
          ? 'Last time the app closed suddenly while using the system voice. It now uses a backup voice so it will not close again. You can turn it back on in Settings.'
          : 'Last time the app closed suddenly while playing instruments. Instruments are turned off for now; speech still works. You can turn them back on in Settings.';
      s.speaker.say(vi, en);
      if (s.blindMode) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.health_and_safety_outlined, size: 40),
          title: Text(s.t('Chế độ an toàn', 'Safe mode')),
          content: Text('${s.t(vi, en)}\n\n${s.t('Nhật ký lỗi', 'Error log')}: ${CrashGuard.logPath}'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      s.dismissSafeMode();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.read(context);
    s.syncScreenReader(MediaQuery.of(context).accessibleNavigation);
    _sRef = s;
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    s.syncScreenReader(MediaQuery.of(context).accessibleNavigation);
    if (s.loading) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(s.t('Đang lên dây đàn…', 'Tuning the strings…')),
          ]),
        ),
      );
    }
    _maybeShowSafeMode(s);
    _maybeWarnVoice(s);
    // CHỈ có quả địa cầu: không nút, không thanh tab. Mọi thao tác bằng giọng nói (app luôn lắng nghe).
    // Thuần giọng nói: không phím tắt. Cài đặt mở bằng lời: "cài đặt" / "settings".
    return const Scaffold(body: GlobePage());
  }
}
