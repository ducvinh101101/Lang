// Bảng màu lấy từ bản web: men ngọc (sáng) / sơn mài (tối), điểm nhấn son đỏ, vàng lá cho dây đàn.
import 'dart:math' as math;

import 'package:flutter/material.dart';

class MapColors {
  final Color sea, land, foreign, coast, accent, gold;
  const MapColors(this.sea, this.land, this.foreign, this.coast, this.accent, this.gold);

  static const light = MapColors(Color(0xFFCFD9DC), Color(0xFFD9D2BF), Color(0xFFC9CDC1), Color(0xFF2F2A23),
      Color(0xFF9B3325), Color(0xFF7A5B14));
  // đúng bảng màu "sơn mài" của web/ban-do.html (--sea, --land, --foreign, --coast, --accent, --gold)
  static const dark = MapColors(Color(0xFF0B151A), Color(0xFF3A3029), Color(0xFF1F1915), Color(0xFFF1E5CC),
      Color(0xFFE2603F), Color(0xFFE4BB63));

  /// Bản đồ LUÔN vẽ kiểu "sơn mài" tối như web: thang màu mưa (càng mưa càng sáng) chỉ đọc được trên nền tối.
  static MapColors of(BuildContext context) => dark;
}

/// Thang màu theo biến; null = màu đất (không mưa / không cháy).
const colorRamps = <String, List<Color?>>{
  // giống web: mưa từ nâu khô → xanh biển → trắng băng (càng sáng càng mưa nhiều); nhiệt từ xanh lạnh → đỏ cam
  'temp': [Color(0xFF2B4F7A), Color(0xFF4F8FA8), Color(0xFFD9C27A), Color(0xFFE08A35), Color(0xFFFF5A3C)],
  'rain': [Color(0xFF2D2621), Color(0xFF2F5D6E), Color(0xFF3B8FB5), Color(0xFF7CC4E0), Color(0xFFE8F6FF)],
  'fire': [null, Color(0xFFDCB860), Color(0xFFE2802C), Color(0xFFC23A1F), Color(0xFF7D1610)],
};

const varColor = <String, Color>{
  'rain': Color(0xFF4F8FB8),
  'temp': Color(0xFFDC8A33),
  'fire': Color(0xFFE2552C),
};

Color rampColor(String v, double t, Color land) {
  final stops = (colorRamps[v] ?? colorRamps['temp']!).map((c) => c ?? land).toList();
  final x = math.max(0.0, math.min(1.0, t)) * (stops.length - 1);
  final k = math.max(0, math.min(stops.length - 2, x.floor()));
  return Color.lerp(stops[k], stops[k + 1], x - k)!;
}

// ======================= Hệ thống giao diện (design tokens) =======================
// Ba "giao diện" cho đúng người dùng, cùng một bộ token:
//  • standard — người lớn / thầy cô: sáng "men ngọc" hoặc tối "sơn mài" theo máy.
//  • kid      — bạn nhỏ: nền giấy ấm, màu tươi, chữ tiêu đề tròn (Baloo 2), nút to bo tròn, chữ to hơn.
//  • blind    — khiếm thị / nhìn kém: LUÔN tối "sơn mài" độ tương phản cao như web/ban-do.html,
//               viền nút rõ, vòng focus vàng dày, chữ to.
// Phông: Be Vietnam Pro (giống bản web, đủ dấu tiếng Việt) + Baloo 2 cho tiêu đề chế độ bạn nhỏ. Đóng gói trong
// assets/fonts (giấy phép OFL), không cần mạng.

enum UiMode { standard, kid, blind }

class AppPalette {
  final Brightness brightness;
  final Color bg, surface, surface2, fg, muted, line, lineStrong, accent, onAccent, gold, focus, error, success;
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.fg,
    required this.muted,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.onAccent,
    required this.gold,
    required this.focus,
    required this.error,
    required this.success,
  });

  /// "Sơn mài" — đúng token của web/ban-do.html (--bg, --surface, --fg, --muted, --accent, --gold, --focus…).
  static const lacquer = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF110D0A),
    surface: Color(0xFF1D1612),
    surface2: Color(0xFF2A2019),
    fg: Color(0xFFF5ECDB), // 16,9:1 trên nền
    muted: Color(0xFFC3B49B), // 9,6:1
    line: Color(0xFF3A2E26),
    lineStrong: Color(0xFF6B5848),
    accent: Color(0xFFE2603F),
    onAccent: Color(0xFF160C08), // 5,6:1 trên son đỏ
    gold: Color(0xFFE4BB63),
    focus: Color(0xFF8FD0FF),
    error: Color(0xFFFF8A7A),
    success: Color(0xFF8FD6A0),
  );

  /// "Men ngọc" — sáng, dịu mắt cho người lớn / thầy cô.
  static const celadon = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFEEF1EA),
    surface: Color(0xFFFBFCF8),
    surface2: Color(0xFFE2E7DD),
    fg: Color(0xFF1C1915), // 15:1
    muted: Color(0xFF4F473C), // 8:1
    line: Color(0xFFD3D8CC),
    lineStrong: Color(0xFF8E8676),
    accent: Color(0xFF9B3325),
    onAccent: Color(0xFFFFFFFF), // 7,4:1
    gold: Color(0xFF7A5B14),
    focus: Color(0xFF1565C0),
    error: Color(0xFFB3261E),
    success: Color(0xFF2E7D32),
  );

  /// Bạn nhỏ — nền giấy ấm, cam son tươi, xanh ngọc, vàng sao.
  static const kidPaper = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFFF6E8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFE9CC),
    fg: Color(0xFF2A1F14), // 15:1
    muted: Color(0xFF6B5843), // 6,4:1
    line: Color(0xFFF1DCBD),
    lineStrong: Color(0xFFC9A97F),
    accent: Color(0xFFC2451C), // trắng trên nền này 4,9:1
    onAccent: Color(0xFFFFFFFF),
    gold: Color(0xFFF2B33D),
    focus: Color(0xFF1565C0),
    error: Color(0xFFB3261E),
    success: Color(0xFF2E7D32),
  );

  static AppPalette of(UiMode mode, Brightness system) => switch (mode) {
        UiMode.blind => lacquer,
        UiMode.kid => kidPaper,
        UiMode.standard => system == Brightness.dark ? lacquer : celadon,
      };
}

const fontBody = 'BeVietnamPro';
const fontKid = 'Baloo2';

ThemeData buildAppTheme(UiMode mode, Brightness system) {
  final p = AppPalette.of(mode, system);
  final kid = mode == UiMode.kid, blind = mode == UiMode.blind;
  final radius = kid ? 22.0 : (blind ? 18.0 : 14.0);
  final btnH = blind ? 64.0 : (kid ? 60.0 : 52.0);
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: Color.alphaBlend(p.accent.withValues(alpha: 0.18), p.surface),
    onPrimaryContainer: p.fg,
    secondary: p.gold,
    onSecondary: p.brightness == Brightness.dark ? const Color(0xFF1A1206) : Colors.white,
    secondaryContainer: Color.alphaBlend(p.gold.withValues(alpha: 0.22), p.surface),
    onSecondaryContainer: p.fg,
    tertiary: kid ? const Color(0xFF1F7A6E) : p.focus,
    onTertiary: Colors.white,
    tertiaryContainer: Color.alphaBlend((kid ? const Color(0xFF1F7A6E) : p.focus).withValues(alpha: 0.18), p.surface),
    onTertiaryContainer: p.fg,
    error: p.error,
    onError: p.brightness == Brightness.dark ? const Color(0xFF2B0A06) : Colors.white,
    errorContainer: Color.alphaBlend(p.error.withValues(alpha: 0.22), p.surface),
    onErrorContainer: p.fg,
    surface: p.surface,
    onSurface: p.fg,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surface2,
    surfaceContainerHighest: p.surface2,
    outline: p.lineStrong,
    outlineVariant: p.line,
    inverseSurface: p.fg,
    onInverseSurface: p.bg,
    inversePrimary: p.gold,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  // Chữ: thân Be Vietnam Pro; tiêu đề bạn nhỏ dùng Baloo 2 tròn trịa, dễ đọc với trẻ
  final head = kid ? fontKid : fontBody;
  final k = blind ? 1.12 : (kid ? 1.06 : 1.0);
  TextStyle t(double size, FontWeight w, {String? family, double h = 1.35}) =>
      TextStyle(fontFamily: family ?? fontBody, fontSize: size * k, fontWeight: w, height: h, color: p.fg);
  final text = TextTheme(
    displaySmall: t(34, FontWeight.w700, family: head, h: 1.15),
    headlineLarge: t(30, FontWeight.w700, family: head, h: 1.2),
    headlineMedium: t(26, FontWeight.w700, family: head, h: 1.22),
    headlineSmall: t(22, FontWeight.w600, family: head, h: 1.3),
    titleLarge: t(20, FontWeight.w600, family: head, h: 1.3),
    titleMedium: t(17, FontWeight.w600),
    titleSmall: t(15, FontWeight.w600),
    bodyLarge: t(17, FontWeight.w400, h: 1.5),
    bodyMedium: t(15.5, FontWeight.w400, h: 1.5),
    bodySmall: t(13.5, FontWeight.w400, h: 1.45).copyWith(color: p.muted),
    labelLarge: t(15, FontWeight.w600),
    labelMedium: t(13.5, FontWeight.w600),
    labelSmall: t(12.5, FontWeight.w600),
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  // Vòng focus rõ (bàn phím, trình đọc màn hình): vàng ở nền tối, xanh ở nền sáng
  final focusRing = BorderSide(color: p.brightness == Brightness.dark ? p.gold : p.focus, width: 3);
  WidgetStateProperty<BorderSide?> side(BorderSide normal) =>
      WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.focused) ? focusRing : normal);

  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    fontFamily: fontBody,
    textTheme: text,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.line,
    focusColor: (p.brightness == Brightness.dark ? p.gold : p.focus).withValues(alpha: 0.28),
    materialTapTargetSize: MaterialTapTargetSize.padded, // vùng chạm ≥ 48dp
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      shape: Border(bottom: BorderSide(color: p.line)),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: p.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(64, btnH)),
        shape: WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
        side: side(BorderSide.none),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(64, btnH - 4)),
        shape: WidgetStatePropertyAll(shape),
        foregroundColor: WidgetStatePropertyAll(p.fg),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        side: side(BorderSide(color: p.lineStrong, width: 1.5)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        side: side(BorderSide.none),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        side: side(BorderSide.none),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      height: kid ? 80 : 72,
      indicatorColor: p.accent.withValues(alpha: p.brightness == Brightness.dark ? 0.28 : 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith(
          (st) => text.labelMedium!.copyWith(color: st.contains(WidgetState.selected) ? p.fg : p.muted)),
      iconTheme: WidgetStateProperty.resolveWith(
          (st) => IconThemeData(size: kid ? 30 : 26, color: st.contains(WidgetState.selected) ? p.fg : p.muted)),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      iconColor: p.fg,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodyMedium!.copyWith(color: p.muted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface2,
      side: BorderSide(color: p.line),
      labelStyle: text.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius + 4)),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radius + 6))),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      thumbColor: p.accent,
      inactiveTrackColor: p.line,
      trackHeight: kid || blind ? 6 : 4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.onAccent : p.muted),
      trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.accent : p.surface2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius - 2), borderSide: BorderSide(color: p.lineStrong)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(radius - 2), borderSide: BorderSide(color: p.lineStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius - 2), borderSide: focusRing),
      labelStyle: text.bodyMedium!.copyWith(color: p.muted),
      hintStyle: text.bodyLarge!.copyWith(color: p.muted),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent, linearTrackColor: p.line),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.fg,
      contentTextStyle: text.bodyLarge!.copyWith(color: p.bg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.fg, borderRadius: BorderRadius.circular(8)),
      textStyle: text.labelMedium!.copyWith(color: p.bg),
    ),
  );
}

/// Giữ cho mã cũ: giao diện chuẩn theo độ sáng.
ThemeData buildTheme(Brightness b) => buildAppTheme(UiMode.standard, b);
