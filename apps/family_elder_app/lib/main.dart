import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/env.dart';
import 'core/local_reminders.dart';
import 'core/preferences.dart';
import 'core/push_service.dart';
import 'core/router.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await SetuSupabaseClient.initialize(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
  );
  // Push notifications (fail-soft — never blocks startup if Firebase is
  // absent or offline).
  unawaited(PushService(SetuSupabaseClient.instance).init());
  // Dose alarms live on the device, not on the server — see local_reminders.dart.
  // Flushing first sends any "Taken" taps recorded while the app was closed;
  // they carry the time of the tap, so a late sync still records the right
  // minute. Fail-soft and off the startup path: a phone that refuses
  // notification permission still gets a working app, just a silent one.
  unawaited(() async {
    final reminders = LocalReminders(SetuSupabaseClient.instance);
    await reminders.init();
    await reminders.flushPendingMarks();
  }());
  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = prefs.getBool(onboardingSeenKey) ?? false;
  runApp(ProviderScope(
    overrides: [onboardingSeenProvider.overrideWith((ref) => onboardingSeen)],
    child: const SetuFamilyElderApp(),
  ));
}

class SetuFamilyElderApp extends ConsumerWidget {
  const SetuFamilyElderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Accessibility + language preferences (Batch 5) drive the app root:
    // text scale, high-contrast theme, and locale — applied here so every
    // screen inherits them, per Module 19's "system property, not a
    // one-off screen" design. Falls back to sensible defaults while the
    // preferences are still loading or the user is signed out.
    final prefs = ref.watch(userPreferencesProvider).valueOrNull ??
        const UserPreferences();

    final lightTheme =
        prefs.highContrast ? applyHighContrast(SetuTheme.light()) : SetuTheme.light();
    final darkTheme =
        prefs.highContrast ? applyHighContrast(SetuTheme.dark()) : SetuTheme.dark();

    return MaterialApp.router(
      title: 'CareHive',
      routerConfig: router,
      theme: lightTheme,
      darkTheme: darkTheme,
      locale: Locale(prefs.languageCode),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: prefs.textScaleFactor,
        maxScaleFactor: prefs.textScaleFactor,
        child: child ?? const SizedBox.shrink(),
      ),
      // MVP language set (PRD Part 3 §19 Phase 1): English + Visakhapatnam's
      // dominant languages. Full 10-language rollout is Phase 2.
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('te')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
