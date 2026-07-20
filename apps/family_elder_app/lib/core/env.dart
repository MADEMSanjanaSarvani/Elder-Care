/// Build-time config, injected via `--dart-define` (see README) — never
/// hardcoded, and never a secret: only the Supabase URL and anon key are
/// needed client-side (PRD Part 2 §13). Everything sensitive stays server-
/// side in Edge Function environment variables.
class Env {
  const Env._();

  // Defaults point at the SETU pilot project so a plain build "just
  // works"; a --dart-define at build time still overrides these. The anon key
  // is a public, RLS-gated key (safe to ship in the client) — never a secret.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://veumfexjpxqhxemjaaor.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZldW1mZXhqcHhxaHhlbWphYW9yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwMDM0MzMsImV4cCI6MjA5OTU3OTQzM30.KG59uIrP9I-65LXvQoPq_ssReC3LXZh1zUeLTniB9iQ',
  );
  static const String activeRegionCode = String.fromEnvironment(
    'ACTIVE_REGION_CODE',
    defaultValue: 'vizag-ap-in',
  );

  // Google Sign-In server (Web) client ID — a public OAuth client identifier,
  // safe to ship. Used as google_sign_in's serverClientId so the returned
  // idToken is audienced for Supabase's Google provider.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '870720833565-cgkuqb7lsupbhjnpvggp5s7fcjk1p2qa.apps.googleusercontent.com',
  );

  // Agora RTC App ID — a public identifier (the App Certificate stays a
  // server secret). Empty means video calling stays in its scaffolded state.
  static const String agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: 'b85c1a1c62d240bebc91698e23a9fa41',
  );

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing --dart-define=SUPABASE_URL and/or SUPABASE_ANON_KEY. See README.md.',
      );
    }
  }
}
