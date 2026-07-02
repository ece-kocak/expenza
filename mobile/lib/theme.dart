import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Uygulama tema modu. Profil ekranındaki düğme bunu değiştirir; main.dart
/// dinleyip tüm ağacı yeniden çizer.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> currencyNotifier = ValueNotifier('₺');

/// Expenza "Quiet Premium" renk paleti.
///
/// Tasarım dili: monokrom, kartsız, hairline çizgiler, tipografi-ağırlıklı.
/// - DARK: saf siyah zemin, beyaz/gri metin, BEYAZ vurgu.
/// - LIGHT: beyaz zemin, koyu metin, LACİVERT (#1E40FF) vurgu.
///
/// Tüm renkler temaya göre değişir → mutable static. [applyMode] tema değişince
/// günceller; ekranlar çalışma anında okuduğu için yeni renkler otomatik yansır.
class AppColors {
  // --- Temaya göre değişen renkler (varsayılan: dark) ---
  static Color background = _dark.background;
  static Color surface = _dark.surface;
  static Color surfaceContainer = _dark.surfaceContainer;
  static Color surfaceContainerHigh = _dark.surfaceContainerHigh;
  static Color surfaceBright = _dark.surfaceBright;
  static Color onSurface = _dark.onSurface;
  static Color onSurfaceVariant = _dark.onSurfaceVariant;
  static Color outline = _dark.outline;
  static Color glass = _dark.glass;
  static Color glassBorder = _dark.glassBorder;
  static Color primary = _dark.accent;
  static Color primaryContainer = _dark.accent;
  static Color onPrimary = _dark.accentInk;
  static Color navBg = _dark.navBg;

  // --- Sabit semantik renkler ---
  static const error = Color(0xFFF2766B);
  static const warn = Color(0xFFE8B931);
  static const catBlue = Color(0xFF6EA8FE);
  static const catPurple = Color(0xFFB68CF0);

  static void applyMode(bool isDark) {
    final p = isDark ? _dark : _light;
    background = p.background;
    surface = p.surface;
    surfaceContainer = p.surfaceContainer;
    surfaceContainerHigh = p.surfaceContainerHigh;
    surfaceBright = p.surfaceBright;
    onSurface = p.onSurface;
    onSurfaceVariant = p.onSurfaceVariant;
    outline = p.outline;
    glass = p.glass;
    glassBorder = p.glassBorder;
    primary = p.accent;
    primaryContainer = p.accent;
    onPrimary = p.accentInk;
    navBg = p.navBg;
  }

  static const _dark = _Pal(
    background: Color(0xFF000000),
    surface: Color(0xFF0E0E0E),
    surfaceContainer: Color(0xFF1C1C1C),
    surfaceContainerHigh: Color(0xFF161616),
    surfaceBright: Color(0xFF0E0E0E),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF9B9B9B),
    outline: Color(0xFF5C5C5C),
    glass: Color(0xFF0E0E0E),
    glassBorder: Color(0xFF1C1C1C),
    accent: Color(0xFFFFFFFF),
    accentInk: Color(0xFF000000),
    navBg: Color(0xDB000000),
  );

  static const _light = _Pal(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F7F9),
    surfaceContainer: Color(0xFFECEEF1),
    surfaceContainerHigh: Color(0xFFE2E5E9),
    surfaceBright: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0A0C10),
    onSurfaceVariant: Color(0xFF6A707A),
    outline: Color(0xFFA6ACB6),
    glass: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFECEEF1),
    accent: Color(0xFF1E40FF),
    accentInk: Color(0xFFFFFFFF),
    navBg: Color(0xE0FFFFFF),
  );
}

class _Pal {
  final Color background,
      surface,
      surfaceContainer,
      surfaceContainerHigh,
      surfaceBright,
      onSurface,
      onSurfaceVariant,
      outline,
      glass,
      glassBorder,
      accent,
      accentInk,
      navBg;
  const _Pal({
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceBright,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.glass,
    required this.glassBorder,
    required this.accent,
    required this.accentInk,
    required this.navBg,
  });
}

/// Para/sayı için tabular figür + sıkışık aralık (premium his).
const List<FontFeature> kTnum = [FontFeature.tabularFigures()];

class AppTheme {
  static ThemeData fromMode(bool isDark) {
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.background,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.primary,
        error: AppColors.error,
        onSurface: AppColors.onSurface,
      ),
      textTheme: _interTextTheme(base.textTheme),
    );
  }

  static TextTheme _interTextTheme(TextTheme t) {
    final scaled = t.copyWith(
      displayLarge: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.0,
          color: AppColors.onSurface),
      headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
      headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface),
      bodyLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w400, color: AppColors.onSurface),
      bodyMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.onSurface),
      labelMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurface),
      labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.onSurfaceVariant),
    );
    return GoogleFonts.interTextTheme(scaled);
  }
}

/// Düz (kartsız) yüzey — hairline çerçeveli. Eski "glass" yerine geçer.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassCard(
      {super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: child,
    );
  }
}

/// Basınca hafifçe küçülen dokunsal sarmalayıcı (premium "press" hissi).
class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Press({super.key, required this.child, this.onTap});

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: _down ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Yüklenince yumuşakça aşağıdan yukarı beliren animasyon (staggered "rise").
class Rise extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const Rise({super.key, required this.child, this.delayMs = 0});

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  double _t = 0;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _t),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: widget.child,
    );
  }
}
