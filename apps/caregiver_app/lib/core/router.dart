import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/earnings/presentation/earnings_screen.dart';
import '../features/job_queue/presentation/job_queue_screen.dart';
import '../features/otp_visit/presentation/otp_visit_screen.dart';
import '../features/profile/presentation/caregiver_profile_screen.dart';
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
          path: '/home', builder: (context, state) => const JobQueueScreen()),
      GoRoute(
          path: '/earnings',
          builder: (context, state) => const EarningsScreen()),
      GoRoute(
        path: '/booking/:bookingId',
        builder: (context, state) =>
            OtpVisitScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/profile/:caregiverId',
        builder: (context, state) =>
            CaregiverProfileScreen(caregiverId: state.pathParameters['caregiverId']!),
      ),
    ],
  );
});
