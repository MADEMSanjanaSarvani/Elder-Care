import 'package:supabase_flutter/supabase_flutter.dart';

/// Hospital Companion Services (PRD Part 6, Batch 3, Module 11). All
/// plain RLS-guarded operations — booking creation for individual shifts
/// still goes through the unmodified existing bookings-create flow; this
/// repository only manages the stay record and the junction rows that
/// group shifts into it.
class HospitalStaysRepository {
  HospitalStaysRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchStays(String elderId) async {
    return _client
        .from('hospital_stays')
        .select()
        .eq('elder_id', elderId)
        .order('admission_at', ascending: false);
  }

  Future<void> createStay({
    required String elderId,
    required String hospitalName,
    required String createdBy,
    DateTime? expectedDischargeAt,
  }) async {
    await _client.from('hospital_stays').insert({
      'elder_id': elderId,
      'hospital_name': hospitalName,
      'created_by': createdBy,
      if (expectedDischargeAt != null)
        'expected_discharge_at': expectedDischargeAt.toIso8601String(),
    });
  }

  /// Shifts with their linked booking's schedule/status, ordered
  /// chronologically — the stay detail screen's shift timeline.
  Future<List<Map<String, dynamic>>> fetchShifts(String stayId) async {
    return _client
        .from('hospital_stay_bookings')
        .select('booking_id, shift_note, bookings(scheduled_at, status)')
        .eq('hospital_stay_id', stayId);
  }

  Future<void> linkBooking(String stayId, String bookingId) async {
    await _client.from('hospital_stay_bookings').insert({
      'hospital_stay_id': stayId,
      'booking_id': bookingId,
    });
  }

  /// Marking discharged never auto-cancels still-scheduled shifts — the
  /// caller is responsible for prompting about them first (PRD §13).
  Future<void> markDischarged(String stayId) async {
    await _client.from('hospital_stays').update({
      'status': 'discharged',
      'actual_discharge_at': DateTime.now().toIso8601String(),
    }).eq('id', stayId);
  }

  Future<List<Map<String, dynamic>>> fetchLinkableBookings(String elderId) async {
    final linked = await _client.from('hospital_stay_bookings').select('booking_id');
    final linkedIds = linked.map((row) => row['booking_id'] as String).toSet();
    final bookings = await _client
        .from('bookings')
        .select('id, scheduled_at, status, service_catalog(code, name)')
        .eq('elder_id', elderId)
        .inFilter('status', ['requested', 'matched', 'confirmed', 'in_progress'])
        .order('scheduled_at');
    return bookings.where((b) {
      final service = b['service_catalog'] as Map<String, dynamic>?;
      return service?['code'] == 'hospital_companion' && !linkedIds.contains(b['id'] as String);
    }).toList();
  }
}
