import 'package:supabase_flutter/supabase_flutter.dart';

/// Caregiver self-service profile + rating view (PRD Part 8, Batch 5,
/// Modules 17 & 18). The rating read goes through
/// caregiver_ratings_anonymized — the caregiver can see their reviews but
/// never who wrote them (the base table isn't readable to them at all,
/// enforced by RLS + the view; this repository couldn't expose rated_by
/// even if it tried).
class CaregiverProfileRepository {
  CaregiverProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchProfile(String caregiverId) async {
    return _client
        .from('caregiver_profile_details')
        .select()
        .eq('caregiver_id', caregiverId)
        .maybeSingle();
  }

  Future<void> saveProfile({
    required String caregiverId,
    String? bio,
    double? serviceRadiusKm,
  }) async {
    await _client.from('caregiver_profile_details').upsert({
      'caregiver_id': caregiverId,
      'bio': bio,
      'service_radius_km': serviceRadiusKm,
    }, onConflict: 'caregiver_id');
  }

  Future<Map<String, dynamic>?> fetchRatingSummary(String caregiverId) async {
    return _client
        .from('caregiver_rating_summary')
        .select()
        .eq('caregiver_id', caregiverId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchAnonymizedReviews(String caregiverId) async {
    return _client
        .from('caregiver_ratings_anonymized')
        .select('stars, review_text, created_at')
        .eq('caregiver_id', caregiverId)
        .order('created_at', ascending: false);
  }
}
