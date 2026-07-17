import 'package:supabase_flutter/supabase_flutter.dart';

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
  /// a session is returned immediately; if ON, `session` is null and the
  /// caregiver must confirm via the emailed link before signing in.
  Future<AuthResponse> signUpWithEmail(
          {required String email, required String password}) =>
      _client.auth.signUp(email: email, password: password);

  /// Creates the `profiles` row only. The matching `caregivers` row —
  /// clinical/non-clinical type, BGV, police verification — is created by
  /// ops after reviewing submitted documents (PRD Part 1 §04), not by this
  /// app; there is deliberately no insert policy on `caregivers` for the
  /// authenticated role (see supabase/migrations/0002_rls.sql).
  Future<void> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    await _client.from('profiles').upsert({
      'id': user.id,
      'role': 'caregiver',
      'phone': user.phone,
      'preferred_language': 'en',
    });
  }
}
