import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/appointments/presentation/appointments_screen.dart';
import '../features/auth/presentation/choose_role_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/set_new_password_screen.dart';
import '../features/consent/presentation/consent_screen.dart';
import '../features/family_access/presentation/family_access_screen.dart';
import '../features/health_profile/presentation/health_profile_screen.dart';
import '../features/health_profile/presentation/medical_id_screen.dart';
import '../features/hospital_stays/presentation/hospital_stays_screen.dart';
import '../features/medical_documents/presentation/medical_documents_screen.dart';
import '../features/medications/presentation/medications_screen.dart';
import '../features/notifications/presentation/notification_inbox_screen.dart';
import '../features/notifications/presentation/notification_preferences_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/privacy/presentation/privacy_screen.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sos/presentation/sos_screen.dart';
import '../features/timeline/presentation/timeline_screen.dart';
import 'app_shells.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);

  // A password-reset deep link re-opens the app and Supabase emits this
  // event once it has exchanged the token for a recovery session. Raise the
  // flag the redirect below reads, so the user lands on "choose a new
  // password" rather than silently on the dashboard.
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
    final event = next.asData?.value.event;
    if (event == AuthChangeEvent.passwordRecovery) {
      ref.read(passwordRecoveryProvider.notifier).state = true;
    }
    // Clear the "show me the role picker" flag on sign-out, so it can't
    // follow a different account into the app on the next sign-in.
    if (event == AuthChangeEvent.signedOut) {
      ref.read(roleReselectProvider.notifier).state = false;
    }
  });

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: GoRouterRefreshStream(client.auth.onAuthStateChange),
    redirect: (context, state) {
      final signedIn = client.auth.currentUser != null;
      final seenOnboarding = ref.read(onboardingSeenProvider);
      final loc = state.matchedLocation;
      // A password-reset link signs the user in with a recovery session. Pin
      // them to the "choose a new password" screen until it's actually saved,
      // otherwise they'd land on the dashboard and never get to change it.
      if (ref.read(passwordRecoveryProvider)) {
        return loc == '/reset-password' ? null : '/reset-password';
      }
      if (!signedIn) {
        // First-time (not yet onboarded) users see the intro carousel first.
        if (!seenOnboarding && loc != '/onboarding') return '/onboarding';
        if (seenOnboarding && loc != '/login') return '/login';
        return null;
      }
      if (loc == '/login' || loc == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/reset-password',
          builder: (context, state) => const SetNewPasswordScreen()),
      GoRoute(
          path: '/home', builder: (context, state) => const HomeRouterScreen()),
      GoRoute(
        path: '/elder/:elderId/sos',
        builder: (context, state) =>
            SosScreen(elderId: state.pathParameters['elderId']!),
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
        path: '/elder/:elderId/medical-id',
        builder: (context, state) =>
            MedicalIdScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/documents',
        builder: (context, state) =>
            MedicalDocumentsScreen(elderId: state.pathParameters['elderId']!),
      ),
      GoRoute(
        path: '/elder/:elderId/privacy',
        builder: (context, state) =>
            PrivacyScreen(elderId: state.pathParameters['elderId']!),
      ),
      // Caregiver-mode routes (reached when the signed-in profile's role is
      // 'caregiver'; the home screen shows the job queue for that role).
      // Live caregiver trips (Uber-style "on the way").
      // Doctor consultations.
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

    return profileAsync.when(
      data: (profile) {
        // Brand-new account with no profile row yet: gate on role selection
        // before showing any home. This is where sign-up lands (the router
        // redirects away from /login the instant a session exists, so the
        // role picker can't live on the login screen and be reliable).
        //
        // Also shown when someone asks to go back and pick again — see
        // roleReselectProvider. Picking a role swaps the entire shell, so
        // "back" from a role has to be handled here rather than by a
        // Navigator that has nothing on its stack to pop.
        if (profile == null || ref.watch(roleReselectProvider)) {
          return const ChooseRoleScreen();
        }
        final role = profile['role'] as String?;
        // Each role gets its own bottom-navigation shell.
        if (role == 'elder') return const ElderShell();
        return const FamilyShell();
      },
      loading: () => const Scaffold(body: SetuLoading()),
      error: (err, stack) => const Scaffold(body: SetuErrorState()),
    );
  }
}
