import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Creates an email account. If "Confirm email" is OFF in Supabase Auth
  /// (recommended for testing), a session is returned immediately and the
  /// caller can proceed. If it's ON, `session` is null and the user must
  /// click the emailed link before signing in.
  Future<AuthResponse> signUpWithEmail(
          {required String email, required String password}) =>
      _client.auth.signUp(email: email, password: password);

  Future<void> ensureProfile(
      {required String role, required String preferredLanguage}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    await _client.from('profiles').upsert({
      'id': user.id,
      'role': role,
      'phone': user.phone,
      'preferred_language': preferredLanguage,
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
}
