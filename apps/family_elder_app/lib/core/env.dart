/// Build-time config, injected via `--dart-define` (see README) — never
/// hardcoded, and never a secret: only the Supabase URL and anon key are
/// needed client-side (PRD Part 2 §13). Everything sensitive stays server-
/// side in Edge Function environment variables.
class Env {
  const Env._();

  // Defaults point at the CareHive pilot project so a plain build "just
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

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing --dart-define=SUPABASE_URL and/or SUPABASE_ANON_KEY. See README.md.',
      );
    }
  }
}
