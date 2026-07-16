import 'package:supabase_flutter/supabase_flutter.dart';

/// Caregiver rating (PRD Part 8, Batch 5, Module 18). Direct table access,
/// guarded by `caregiver_ratings`' RLS (only someone entitled to the
/// completed booking may insert, once). The low-star auto-flag and the
/// summary recompute are database triggers — this repository just inserts.
class RatingRepository {
  RatingRepository(this._client);

  final SupabaseClient _client;

  /// Completed bookings for this elder that don't yet have a rating —
  /// the ones worth prompting to rate.
  Future<List<Map<String, dynamic>>> unratedCompletedBookings(String elderId) async {
    final bookings = await _client
        .from('bookings')
        .select('id, caregiver_id, scheduled_at, service_catalog(name)')
        .eq('elder_id', elderId)
        .eq('status', 'completed')
        .not('caregiver_id', 'is', null)
        .order('scheduled_at', ascending: false);
    final rated = await _client.from('caregiver_ratings').select('booking_id');
    final ratedIds = rated.map((r) => r['booking_id'] as String).toSet();
    return bookings.where((b) => !ratedIds.contains(b['id'] as String)).toList();
  }

  Future<void> submitRating({
    required String bookingId,
    required String caregiverId,
    required int stars,
    String? reviewText,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    await _client.from('caregiver_ratings').insert({
      'booking_id': bookingId,
      'caregiver_id': caregiverId,
      'rated_by': userId,
      'stars': stars,
      if (reviewText != null && reviewText.isNotEmpty) 'review_text': reviewText,
    });
  }
}
