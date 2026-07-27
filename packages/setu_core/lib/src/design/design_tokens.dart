import 'package:flutter/material.dart';

/// Codifies the palette and type scale from
/// docs/prd/03-prd-part3-execution.html Section 17.
///
/// Plus Jakarta Sans is now bundled (see the app's pubspec) rather than
/// fetched at runtime. Section 20's offline-resilience requirement rules out
/// a network font fetch, and it was the reason this shipped on Roboto for a
/// long time — but a bundled variable font costs 176 KB once and no network
/// at all, which satisfies the requirement instead of dodging it. The
/// difference is visible: the designs lean on 600/700/800 weights that Roboto
/// can only fake.
class SetuColors {
  const SetuColors._();

  // "Warmth & Connection" (final SETU design system). Warm-white ground,
  // warm-orange primary, lavender for calm/AI, peach for warmth, pastel green
  // for success, brick red for emergencies.
  static const Color paperLight = Color(0xFFFAF9F6); // warm white surface
  static const Color paperRaisedLight = Color(0xFFFFFFFF);
  static const Color inkLight = Color(0xFF1A1C1A); // on-surface
  static const Color mutedLight = Color(0xFF54433A); // on-surface-variant
  static const Color borderLight = Color(0xFFE6E3DF); // subtle warm border

  static const Color paperDark = Color(0xFF1B1A18); // warm charcoal
  static const Color paperRaisedDark = Color(0xFF262320);
  static const Color inkDark = Color(0xFFF2F1EE);
  static const Color mutedDark = Color(0xFFD5C4AB);
  static const Color borderDark = Color(0xFF3A342E);

  /// Primary — deep warm orange (#944a18); container is pastel orange #ff9f66.
  static const Color accentLight = Color(0xFF944A18);
  static const Color accentDark = Color(0xFFFFB68D); // inverse-primary

  /// Verified / success — soft pastel green.
  static const Color verifiedLight = Color(0xFF4E8F70);
  static const Color verifiedDark = Color(0xFF8CC6A6);

  /// SOS / critical — brick red (design `error`), used only for emergencies.
  static const Color sosLight = Color(0xFFBA1A1A);
  static const Color sosDark = Color(0xFFFFB4AB);

  /// Lavender (secondary) — calm, mindfulness & the AI companion.
  static const Color lavenderLight = Color(0xFF62549B);
  static const Color lavenderDark = Color(0xFFCBBEFF);

  /// Peach / pastel orange — warmth & human touch (primary-container family).
  static const Color peachLight = Color(0xFFF08A3C);
  static const Color peachDark = Color(0xFFFFB68D);
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

    // Full Warmth colour scheme. IMPORTANT: secondary is LAVENDER, not the
    // success-green — Material 3 derives the bottom-nav indicator and the
    // segmented-button selection from secondaryContainer, so leaving green
    // here is what made those elements look like the old sage theme. Green
    // now lives only where we explicitly use SetuColors.verifiedLight (the
    // "safe"/success chips).
    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isDark ? SetuColors.inkDark : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF7A3300) : const Color(0xFFFFDBC9),
      onPrimaryContainer:
          isDark ? const Color(0xFFFFDBC9) : const Color(0xFF773401),
      secondary: isDark ? SetuColors.lavenderDark : SetuColors.lavenderLight,
      onSecondary: isDark ? const Color(0xFF1D0A54) : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF4A3C81) : const Color(0xFFE7DEFF),
      onSecondaryContainer:
          isDark ? const Color(0xFFE7DEFF) : const Color(0xFF4A3C81),
      tertiary: isDark ? SetuColors.peachDark : SetuColors.peachLight,
      onTertiary: Colors.white,
      tertiaryContainer:
          isDark ? const Color(0xFF514632) : const Color(0xFFF2E0C6),
      onTertiaryContainer:
          isDark ? const Color(0xFFF2E0C6) : const Color(0xFF514632),
      error: isDark ? SetuColors.sosDark : SetuColors.sosLight,
      onError: Colors.white,
      errorContainer:
          isDark ? const Color(0xFF93000A) : const Color(0xFFFFDAD6),
      onErrorContainer:
          isDark ? const Color(0xFFFFDAD6) : const Color(0xFF93000A),
      surface: surface,
      onSurface: ink,
      onSurfaceVariant:
          isDark ? SetuColors.mutedDark : SetuColors.mutedLight,
      outline: isDark ? SetuColors.borderDark : const Color(0xFF877369),
      outlineVariant: border,
    );

    // Fully rounded. Every SETU design draws its primary action as a pill,
    // and it is not only a style: a pill reads as a single tappable object at
    // arm's length, where a rounded rectangle at the bottom of a screen can
    // read as a panel. This app is used by people holding a phone further
    // away than the designer was sitting from the mock.
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));

    // 2px, because a 1.4px hairline effectively disappears on the cheap
    // 720p panels most of our users have.
    OutlineInputBorder inputBorder(Color c, [double w = 2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    // The warm lift under every card and bar in the designs. Not a grey
    // drop-shadow: it is the primary hue at very low alpha, which is what
    // makes the surfaces feel lit rather than cut out.
    final warmShadow = [
      BoxShadow(
        color: (isDark ? Colors.black : SetuColors.peachLight)
            .withValues(alpha: isDark ? 0.35 : 0.10),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ];

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: paper,
      colorScheme: colorScheme,
      useMaterial3: true,
      // Bundled with the app (see pubspec). Every SETU design is drawn in it,
      // and its 600/700/800 weights are what give the headings their
      // character — Roboto faux-bolds them and the screens go flat.
      fontFamily: 'Plus Jakarta Sans',
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
          minimumSize: const Size.fromHeight(56),
          shape: buttonShape,
          elevation: 4,
          shadowColor: accent.withValues(alpha: 0.35),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: buttonShape,
          elevation: 4,
          shadowColor: accent.withValues(alpha: 0.35),
          backgroundColor: accent,
          foregroundColor: Colors.white,
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: buttonShape,
          side: BorderSide(color: border, width: 2),
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
          // 24 rather than 20 — the designs are noticeably softer than what
          // the app was rendering, and on a bento grid the difference between
          // 20 and 24 is the difference between tiles and cards.
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
      ),
      // The bottom bar in every design: white, lifted by a warm shadow that
      // falls upward, with the active destination in a filled pill.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 3,
        shadowColor: SetuColors.peachLight.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        indicatorColor: (isDark ? SetuColors.lavenderDark : SetuColors.lavenderLight)
            .withValues(alpha: 0.20),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: ink)),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: border.withValues(alpha: 0.5)),
        backgroundColor: surface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      // Exposed so screens can use the same lift on the plain Containers they
      // build by hand, instead of each inventing its own drop shadow.
      extensions: [SetuSurfaces(cardShadow: warmShadow)],
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30))),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
        ),
      ),
    );
  }

  /// Type scale from the designs: bigger and heavier than Material's
  /// defaults throughout. Screen titles are 40, not 32 — this is an app read
  /// by people with presbyopia, and the mocks are right to shout.
  static TextTheme _textTheme(Color ink) {
    return TextTheme(
      displaySmall: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: ink),
      headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: ink),
      headlineMedium:
          TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink),
      headlineSmall:
          TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ink),
      titleLarge:
          TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: ink),
      bodyLarge: TextStyle(
          fontSize: 18, color: ink), // large, legible base (Warmth system)
      bodyMedium: TextStyle(fontSize: 16, color: ink),
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

/// The warm shadow the designs put under every raised surface, exposed on the
/// theme so screens stop inventing their own.
///
/// Before this, cards built as plain Containers each hard-coded a drop shadow
/// — some grey, some warm, some none — so nominally identical cards on two
/// screens sat at visibly different heights. Reading it from the theme means
/// light and dark get the right treatment without any call site knowing which
/// one is active.
@immutable
class SetuSurfaces extends ThemeExtension<SetuSurfaces> {
  const SetuSurfaces({required this.cardShadow});

  final List<BoxShadow> cardShadow;

  static SetuSurfaces of(BuildContext context) =>
      Theme.of(context).extension<SetuSurfaces>() ??
      const SetuSurfaces(cardShadow: []);

  @override
  SetuSurfaces copyWith({List<BoxShadow>? cardShadow}) =>
      SetuSurfaces(cardShadow: cardShadow ?? this.cardShadow);

  @override
  SetuSurfaces lerp(ThemeExtension<SetuSurfaces>? other, double t) {
    if (other is! SetuSurfaces) return this;
    return SetuSurfaces(
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? cardShadow,
    );
  }
}
