import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/env.dart';

/// Where Supabase should send the user back to after they tap the link in a
/// password-reset email. Must be registered twice to work:
///   * Android — the `<intent-filter>` on MainActivity in AndroidManifest.xml
///   * Supabase — Authentication → URL Configuration → Redirect URLs
/// Without it Supabase falls back to the project's Site URL, which defaults
/// to `http://localhost:3000` and dead-ends in the phone's browser.
const String kPasswordResetRedirect = 'in.carehive.app://auth/reset-password';

/// Auth via Supabase Auth. Phone OTP is the primary path — a phone number is
/// something the elder persona (PRD Part 1 §05) already has memorized and
/// dials daily. Email + password is offered as a second option for family
/// members who prefer it (and it needs no SMS provider), so `profiles.phone`
/// is left null for email accounts (the column is nullable by design).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> sendOtp(String phone) =>
      _client.auth.signInWithOtp(phone: phone);

  Future<AuthResponse> verifyOtp(
      {required String phone, required String token}) {
    return _client.auth
        .verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  Future<AuthResponse> signInWithEmail(
          {required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// Creates an email account. The person's name is carried in user metadata
  /// so it can seed `profiles.display_name` once the role is chosen. If
  /// "Confirm email" is OFF in Supabase Auth (recommended for the pilot), a
  /// session is returned immediately; if it's ON, `session` is null and the
  /// user must click the emailed link before signing in.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) =>
      _client.auth.signUp(
        email: email,
        password: password,
        data: (fullName != null && fullName.isNotEmpty)
            ? {'full_name': fullName}
            : null,
      );

  /// Sends a password-reset email via Supabase Auth (no external provider
  /// needed — Supabase's own mailer delivers it).
  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email,
          redirectTo: kPasswordResetRedirect);

  /// Sets a new password for the user currently in a recovery session (i.e.
  /// straight after they followed the emailed link back into the app).
  Future<void> updatePassword(String newPassword) =>
      _client.auth.updateUser(UserAttributes(password: newPassword));

  /// Native Google Sign-In → Supabase. We ask Google for an idToken audienced
  /// to our Web (server) client, then hand it to Supabase's Google provider.
  /// Returns null if the user cancels the Google chooser.
  /// Native Google Sign-In → Supabase, always via the account chooser.
  ///
  /// `signIn()` on its own silently reuses whichever Google account was
  /// authorised last, with no visible picker. On a shared or family phone
  /// that reads as a bug of the worst kind: you pick "sign in with Google",
  /// get someone else's account, and see their care circle — so it looks
  /// like the app leaked data when in fact it faithfully showed the account
  /// Google handed back. Signing out of Google first forces the chooser
  /// every time, which is the behaviour a user expects.
  Future<AuthResponse?> signInWithGoogle() async {
    final google = GoogleSignIn(serverClientId: Env.googleWebClientId);
    await google.signOut();
    final account = await google.signIn();
    if (account == null) return null; // user dismissed the picker
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in did not return an ID token.');
    }
    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
  }

  Future<void> ensureProfile(
      {required String role, required String preferredLanguage}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    // Seed display_name from the name captured at sign-up, if any.
    final metaName = user.userMetadata?['full_name'] as String?;
    // Email accounts have no phone; Supabase returns "" (not null). The
    // profiles.phone column is UNIQUE, so store null for "no phone" — Postgres
    // allows many nulls but only one empty string.
    final phone =
        (user.phone != null && user.phone!.isNotEmpty) ? user.phone : null;
    await _client.from('profiles').upsert({
      'id': user.id,
      'role': role,
      'phone': phone,
      'preferred_language': preferredLanguage,
      if (metaName != null && metaName.isNotEmpty) 'display_name': metaName,
    });
  }

  Future<bool> hasProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    return row != null;
  }

  /// Sign out of Supabase *and* Google.
  ///
  /// Signing out of Supabase alone leaves the Google session intact, so the
  /// next "Continue with Google" silently re-authorises the same account and
  /// the user appears unable to switch. On a family phone that matters: the
  /// daughter who hands the device to her mother must be able to sign out
  /// completely. Google's sign-out is best-effort — if it fails (no Play
  /// Services, or the user never used Google here) the Supabase sign-out must
  /// still happen, so it never blocks getting out of the account.
  Future<void> signOut() async {
    try {
      await GoogleSignIn(serverClientId: Env.googleWebClientId).signOut();
    } catch (_) {
      // Not signed in with Google, or Play Services unavailable. Ignore.
    }
    await _client.auth.signOut();
  }
}
