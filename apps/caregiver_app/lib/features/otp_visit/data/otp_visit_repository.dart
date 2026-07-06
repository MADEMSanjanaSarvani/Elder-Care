import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the `otp-start` / `otp-end` Edge Functions (PRD Part 2 §12) —
/// visit-boundary proof, and the trigger for the caregiver's payout to be
/// scheduled once the visit is verified complete.
class OtpVisitRepository {
  OtpVisitRepository(this._client);

  final SupabaseClient _client;

  Future<void> startVisit({required String bookingId, required String otp}) async {
    final response = await _client.functions.invoke('otp-start', body: {'booking_id': bookingId, 'otp': otp});
    if (response.status != 200) throw StateError('Could not start visit: ${response.data}');
  }

  Future<void> endVisit({required String bookingId, required String otp}) async {
    final response = await _client.functions.invoke('otp-end', body: {'booking_id': bookingId, 'otp': otp});
    if (response.status != 200) throw StateError('Could not end visit: ${response.data}');
  }

  /// Calls `ai-visit-summary` (PRD Part 2 §14). Returns the family-facing
  /// summary text if it cleared the guardrail, or null if it's pending
  /// human review — see supabase/README.md for the (currently missing)
  /// admin review queue this depends on.
  Future<String?> submitVisitSummary({required String bookingId, required String rawNotes}) async {
    final response = await _client.functions.invoke(
      'ai-visit-summary',
      body: {'booking_id': bookingId, 'raw_notes': rawNotes},
    );
    if (response.status != 200 && response.status != 202) {
      throw StateError('Could not generate visit summary: ${response.data}');
    }
    final data = response.data as Map<String, dynamic>;
    return data['status'] == 'delivered' ? data['summary'] as String : null;
  }
}
