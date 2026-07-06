import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the Supabase Flutter SDK.
///
/// Deliberately thin: per PRD Part 2 §13, no third-party secret (Razorpay,
/// OpenAI, IDfy) is ever held client-side — this class only ever holds the
/// public anon key, and every sensitive operation is a call to an Edge
/// Function (see `packages/setu_core/lib/src/region/region_config_client.dart`
/// for the pattern).
class SetuSupabaseClient {
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get instance => Supabase.instance.client;

  static User? get currentUser => instance.auth.currentUser;

  static Stream<AuthState> get onAuthStateChange => instance.auth.onAuthStateChange;
}
