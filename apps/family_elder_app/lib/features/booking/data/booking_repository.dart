import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  Future<List<SetuService>> fetchServices(String regionId) async {
    final rows = await _client
        .from('service_catalog')
        .select()
        .eq('region_id', regionId)
        .eq('active', true);
    return rows.map((row) => SetuService.fromJson(row)).toList();
  }

  Future<List<Booking>> fetchBookings(String elderId) async {
    final rows = await _client
        .from('bookings')
        .select()
        .eq('elder_id', elderId)
        .order('scheduled_at', ascending: false);
    return rows.map((row) => Booking.fromJson(row)).toList();
  }

  /// PRD Part 2 §12: goes through the `bookings-create` Edge Function, not
  /// a direct insert, so the required-trust-tier check happens server-side
  /// and can never be skipped by a client that "forgot." [caregiverId], when
  /// given, requests that specific caregiver (re-validated server-side); null
  /// means "match me the best available".
  Future<Booking> createBooking({
    required String elderId,
    required String serviceId,
    required DateTime scheduledAt,
    String? caregiverId,
  }) async {
    final response = await _client.functions.invoke(
      'bookings-create',
      body: {
        'elder_id': elderId,
        'service_id': serviceId,
        'scheduled_at': scheduledAt.toIso8601String(),
        if (caregiverId != null) 'caregiver_id': caregiverId,
      },
    );
    if (response.status != 201) {
      throw StateError('Booking failed: ${response.data}');
    }
    return Booking.fromJson(response.data as Map<String, dynamic>);
  }

  /// The caregivers a family can choose from for a given service, curated
  /// server-side (`caregivers-for-service`): only active, verified caregivers
  /// in the elder's region whose trust tier meets the service, with the
  /// family-facing fields (name, role, trust tier, bio, photo, rating).
  Future<List<Map<String, dynamic>>> fetchCaregiversForService({
    required String elderId,
    required String serviceId,
  }) async {
    final response = await _client.functions.invoke(
      'caregivers-for-service',
      body: {'elder_id': elderId, 'service_id': serviceId},
    );
    final data = response.data as Map<String, dynamic>?;
    return ((data?['caregivers'] as List?) ?? []).cast<Map<String, dynamic>>();
  }
}
