import 'package:flutter/material.dart';

/// Codifies the palette and type scale from
/// docs/prd/03-prd-part3-execution.html Section 17.
///
/// No custom font files are bundled for the MVP — Section 20's offline-
/// resilience requirement argues against a network font fetch, and a
/// bundled custom font is a Phase 2 polish item, not an MVP blocker.
/// Platform default fonts (San Francisco / Roboto) carry the type scale
/// below instead.
class SetuColors {
  const SetuColors._();

  static const Color paperLight = Color(0xFFF2F4F0);
  static const Color paperRaisedLight = Color(0xFFFFFFFF);
  static const Color inkLight = Color(0xFF15181A);
  static const Color mutedLight = Color(0xFF57625C);
  static const Color borderLight = Color(0xFFDADFD8);

  static const Color paperDark = Color(0xFF14181A);
  static const Color paperRaisedDark = Color(0xFF1B211F);
  static const Color inkDark = Color(0xFFE9EDE9);
  static const Color mutedDark = Color(0xFF9AA69E);
  static const Color borderDark = Color(0xFF2A312C);

  /// Trust / primary action.
  static const Color accentLight = Color(0xFFB8691A);
  static const Color accentDark = Color(0xFFE0A559);

  /// Verified / success semantic color — distinct hue from the accent.
  static const Color verifiedLight = Color(0xFF1D6C5F);
  static const Color verifiedDark = Color(0xFF4BB6A3);

  /// SOS / critical semantic color — never reused for anything else.
  static const Color sosLight = Color(0xFFA83F2A);
  static const Color sosDark = Color(0xFFE2705C);
}

class SetuSpacing {
  const SetuSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class SetuTheme {
  const SetuTheme._();

  static ThemeData light() => _buildTheme(Brightness.light);
  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color paper = isDark ? SetuColors.paperDark : SetuColors.paperLight;
    final Color ink = isDark ? SetuColors.inkDark : SetuColors.inkLight;
    final Color accent =
        isDark ? SetuColors.accentDark : SetuColors.accentLight;
    final Color border =
        isDark ? SetuColors.borderDark : SetuColors.borderLight;
    final Color surface =
        isDark ? SetuColors.paperRaisedDark : SetuColors.paperRaisedLight;

    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isDark ? SetuColors.inkDark : Colors.white,
      secondary: isDark ? SetuColors.verifiedDark : SetuColors.verifiedLight,
      onSecondary: Colors.white,
      error: isDark ? SetuColors.sosDark : SetuColors.sosLight,
      onError: Colors.white,
      surface:
          isDark ? SetuColors.paperRaisedDark : SetuColors.paperRaisedLight,
      onSurface: ink,
    );

    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    OutlineInputBorder inputBorder(Color c, [double w = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: paper,
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: _textTheme(ink),
      appBarTheme: AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: ink)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(accent, 2),
        floatingLabelStyle: TextStyle(color: accent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          side: BorderSide(color: border, width: 1.4),
          foregroundColor: accent,
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30))),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color ink) {
    return TextTheme(
      headlineLarge:
          TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: ink),
      headlineMedium:
          TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink),
      titleLarge:
          TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: ink),
      bodyLarge: TextStyle(
          fontSize: 18, color: ink), // elder-mode default per Section 17
      bodyMedium: TextStyle(fontSize: 15, color: ink),
      labelSmall: TextStyle(fontSize: 11, letterSpacing: 0.4, color: ink),
    );
  }
}

/// Elder-mode specifically wants larger text than the family-mode default
/// (Section 17: "min 18sp body, 24sp+ headers") — this scales whatever
/// TextTheme it's given rather than hardcoding a second theme.
extension ElderModeTypography on TextTheme {
  TextTheme scaledForElderMode() {
    return copyWith(
      bodyLarge: bodyLarge?.copyWith(fontSize: 20),
      bodyMedium: bodyMedium?.copyWith(fontSize: 18),
      headlineMedium: headlineMedium?.copyWith(fontSize: 28),
    );
  }
}
