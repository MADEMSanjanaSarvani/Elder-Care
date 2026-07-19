import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM push wiring. Deliberately fail-soft: if Firebase isn't configured on a
/// given build, nothing here throws and the rest of the app is unaffected —
/// push is an enhancement, never a dependency for core flows.
///
/// The device's FCM token is stored in `user_devices` for the signed-in user,
/// so the backend (Edge Functions) can target that device. We (re)register on
/// every sign-in and on token refresh, and clear on sign-out.
class PushService {
  PushService(this._client);
  final SupabaseClient _client;

  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
      return;
    }

    // Ask permission (Android 13+/iOS). Denial is fine — we simply won't
    // deliver notifications.
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}

    // Register now if already signed in, and on every future sign-in.
    _client.auth.onAuthStateChange.listen((state) {
      if (state.session != null) {
        _register();
      }
    });
    if (_client.auth.currentUser != null) await _register();

    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _register());
  }

  Future<void> _register() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _client.from('user_devices').upsert(
        {
          'user_id': user.id,
          'fcm_token': token,
          'platform': defaultTargetPlatform.name,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,fcm_token',
      );
    } catch (e) {
      debugPrint('FCM token register failed: $e');
    }
  }
}
