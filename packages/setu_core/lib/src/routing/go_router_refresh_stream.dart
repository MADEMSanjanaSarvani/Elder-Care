import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a Supabase auth-state Stream to GoRouter's `Listenable`-based
/// refresh, so sign-in/sign-out actually re-runs `redirect` in both apps'
/// routers instead of leaving the user stranded until the next manual
/// navigation. Shared here rather than duplicated per-app since it's
/// identical, non-app-specific plumbing.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
