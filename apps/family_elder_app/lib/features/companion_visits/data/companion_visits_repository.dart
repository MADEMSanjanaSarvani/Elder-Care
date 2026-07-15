import 'package:supabase_flutter/supabase_flutter.dart';

/// Companion Visits (PRD Part 6, Batch 3, Module 10): the preference is a
/// plain RLS-guarded row; the matching tiebreak that consumes it lives in
/// bookings-match. Activity logs are written by the caregiver app during
/// a visit — this repository only reads them for family/elder viewing.
class CompanionVisitsRepository {
  CompanionVisitsRepository(this._client);

  final SupabaseClient _client;

  static const availableInterests = [
    'walking',
    'cards',
    'reading',
    'music',
    'gardening',
    'watching_tv',
    'chatting',
  ];

  Future<Map<String, dynamic>?> fetchPreference(String elderId) async {
    return _client
        .from('companion_visit_preferences')
        .select()
        .eq('elder_id', elderId)
        .maybeSingle();
  }

  Future<void> savePreference({
    required String elderId,
    String? preferredCaregiverId,
    required List<String> interests,
  }) async {
    await _client.from('companion_visit_preferences').upsert({
      'elder_id': elderId,
      'preferred_caregiver_id': preferredCaregiverId,
      'interests': interests,
    }, onConflict: 'elder_id');
  }

  /// Caregivers this elder has actually completed a visit with — the only
  /// sensible candidates for "request the same caregiver again."
  Future<List<Map<String, dynamic>>> fetchPastCaregivers(String elderId) async {
    final rows = await _client
        .from('bookings')
        .select('caregiver_id, caregivers(id, profiles(display_name))')
        .eq('elder_id', elderId)
        .eq('status', 'completed')
        .not('caregiver_id', 'is', null);
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['caregiver_id'] as String?;
      if (id != null && seen.add(id)) result.add(row);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchActivityLog(String bookingId) async {
    return _client.from('visit_activity_logs').select().eq('booking_id', bookingId);
  }
}
