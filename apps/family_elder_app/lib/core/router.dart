import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../features/appointments/presentation/appointments_screen.dart';
import '../features/assistant/presentation/assistant_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/care_plans/presentation/care_plans_screen.dart';
import '../features/companion_visits/presentation/companion_preferences_screen.dart';
import '../features/consent/presentation/consent_screen.dart';
import '../features/elder_home/presentation/elder_home_screen.dart';
import '../features/family_access/presentation/family_access_screen.dart';
import '../features/family_home/presentation/family_home_screen.dart';
import '../features/health_profile/presentation/health_profile_screen.dart';
import '../features/hospital_stays/presentation/hospital_stays_screen.dart';
import '../features/medications/presentation/medications_screen.dart';
import '../features/notifications/presentation/notification_inbox_screen.dart';
import '../features/notifications/presentation/notification_preferences_screen.dart';
import '../features/privacy/presentation/privacy_screen.dart';
import '../features/rating/presentation/rate_visits_screen.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
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
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationInboxScreen(),
      ),
      GoRoute(
        path: '/notifications/preferences',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/elder/:elderId/rate',
        builder: (context, state) =>
            RateVisitsScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/hospital-stays',
        builder: (context, state) =>
            HospitalStaysScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/health-profile',
        builder: (context, state) =>
            HealthProfileScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/companion-preferences',
        builder: (context, state) => CompanionPreferencesScreen(
            elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/assistant',
        builder: (context, state) =>
            AssistantScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/reports',
        builder: (context, state) =>
            ReportsScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/care-plans',
        builder: (context, state) =>
            CarePlansScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/privacy',
        builder: (context, state) =>
            PrivacyScreen(elderId: state.pathParameters['elderId']!),
      ),
    ],
  );
});

/// Decides elder-mode vs. family-mode purely from `profiles.role` — see
/// PRD Part 3 §17/§18 for why these are two different presentations of
/// the same underlying data rather than one shrunken UI. The notification
/// bell (PRD Part 6, Batch 3, Module 9) is an additive app-bar element on
/// this shared shell, not a change to either home screen's own logic.
class HomeRouterScreen extends ConsumerWidget {
  const HomeRouterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final unreadAsync = ref.watch(unreadCountProvider);
    final unread = unreadAsync.asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setu'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
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
