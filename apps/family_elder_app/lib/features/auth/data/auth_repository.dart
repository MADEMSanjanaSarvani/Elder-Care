import 'package:supabase_flutter/supabase_flutter.dart';

/// Phone-OTP auth via Supabase Auth. Phone OTP (rather than email/password)
/// matches the primary elder persona from PRD Part 1 §05 — a phone number
/// is something Raghunath already has memorized and dials daily; a
/// password is one more thing to forget.
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
