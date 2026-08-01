import 'package:supabase_flutter/supabase_flutter.dart';

/// The hospital-stay record: which hospital, admitted when, discharged when.
///
/// The shift-scheduling half of this repository (fetchShifts, linkBooking,
/// fetchLinkableBookings) is gone with the bookings it read from. What remains
/// is the part that is still true months later.
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

  Future<void> markDischarged(String stayId) async {
    await _client.from('hospital_stays').update({
      'status': 'discharged',
      'actual_discharge_at': DateTime.now().toIso8601String(),
    }).eq('id', stayId);
  }
}
