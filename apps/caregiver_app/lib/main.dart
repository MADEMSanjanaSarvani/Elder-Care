import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import 'core/env.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await SetuSupabaseClient.initialize(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: SetuCaregiverApp()));
}

class SetuCaregiverApp extends ConsumerWidget {
  const SetuCaregiverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Setu — Caregiver',
      routerConfig: router,
      theme: SetuTheme.light(),
      darkTheme: SetuTheme.dark(),
    );
  }
}
