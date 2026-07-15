import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../features/appointments/presentation/appointments_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/consent/presentation/consent_screen.dart';
import '../features/elder_home/presentation/elder_home_screen.dart';
import '../features/family_access/presentation/family_access_screen.dart';
import '../features/family_home/presentation/family_home_screen.dart';
import '../features/medications/presentation/medications_screen.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/sos/presentation/sos_screen.dart';
import '../features/timeline/presentation/timeline_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: GoRouterRefreshStream(client.auth.onAuthStateChange),
    redirect: (context, state) {
      final signedIn = client.auth.currentUser != null;
      final goingToLogin = state.matchedLocation == '/login';
      if (!signedIn && !goingToLogin) return '/login';
      if (signedIn && goingToLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/home', builder: (context, state) => const HomeRouterScreen()),
      GoRoute(
        path: '/elder/:elderId/sos',
        builder: (context, state) =>
            SosScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/booking',
        builder: (context, state) =>
            BookingScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/consent',
        builder: (context, state) =>
            ConsentScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/timeline',
        builder: (context, state) =>
            TimelineScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/family',
        builder: (context, state) =>
            FamilyAccessScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/medications',
        builder: (context, state) =>
            MedicationsScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/appointments',
        builder: (context, state) =>
            AppointmentsScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/reminders',
        builder: (context, state) =>
            RemindersScreen(elderId: state.pathParameters['elderId']!),
      ),
    ],
  );
});

/// Decides elder-mode vs. family-mode purely from `profiles.role` — see
/// PRD Part 3 §17/§18 for why these are two different presentations of
/// the same underlying data rather than one shrunken UI.
class HomeRouterScreen extends ConsumerWidget {
  const HomeRouterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            final role = profile?['role'] as String?;
            if (role == 'elder') return const ElderHomeScreen();
            return const FamilyHomeScreen();
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Failed to load profile: $err')),
        ),
      ),
    );
  }
}
