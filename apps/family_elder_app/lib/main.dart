import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await SetuSupabaseClient.initialize(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: SetuFamilyElderApp()));
}

class SetuFamilyElderApp extends ConsumerWidget {
  const SetuFamilyElderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Setu',
      routerConfig: router,
      theme: SetuTheme.light(),
      darkTheme: SetuTheme.dark(),
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
