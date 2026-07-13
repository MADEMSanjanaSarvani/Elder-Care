/// Build-time config, injected via `--dart-define` (see README) — never
/// hardcoded, and never a secret: only the Supabase URL and anon key are
/// needed client-side (PRD Part 2 §13). Everything sensitive stays server-
/// side in Edge Function environment variables.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String activeRegionCode = String.fromEnvironment(
    'ACTIVE_REGION_CODE',
    defaultValue: 'vizag-ap-in',
  );

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing --dart-define=SUPABASE_URL and/or SUPABASE_ANON_KEY. See README.md.',
      );
    }
  }
}
