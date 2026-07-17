import 'package:supabase_flutter/supabase_flutter.dart';

/// Batch 3 caregiver-side tools (PRD Part 6): emergency health info
/// (Module 12 — readable only during an in-progress booking or dispatched
/// SOS, enforced by elder_health_profile's RLS, not by this class),
/// visit activity logs (Module 10), and hospital-stay handoff notes
/// (Module 11). All plain RLS-guarded operations.
class VisitToolsRepository {
  VisitToolsRepository(this._client);

  final SupabaseClient _client;

  static const availableActivities = [
    'walked',
    'played_a_game',
    'read_together',
    'watched_tv',
    'chatted',
    'other',
  ];

  static const availableMoods = ['content', 'okay', 'low', 'agitated'];

  /// Returns null both when there's no profile and when RLS denies the
  /// read (e.g. the booking isn't in progress yet) — the UI treats both
  /// as "nothing to show," which is exactly right.
  Future<Map<String, dynamic>?> fetchEmergencyHealthInfo(String elderId) async {
    return _client
        .from('elder_health_profile')
        .select('blood_type, allergies, chronic_conditions, emergency_medical_notes')
        .eq('elder_id', elderId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> fetchActivityLog(String bookingId) async {
    return _client
        .from('visit_activity_logs')
        .select()
        .eq('booking_id', bookingId)
        .maybeSingle();
  }

  Future<void> saveActivityLog({
    required String bookingId,
    required List<String> activities,
    String? observedMood,
    String? note,
  }) async {
    await _client.from('visit_activity_logs').upsert({
      'booking_id': bookingId,
      'activities': activities,
      'caregiver_observed_mood': observedMood,
      'note': note,
    }, onConflict: 'booking_id');
  }

  /// The stay this booking is a shift of, if any — plus every other
  /// shift's handoff note in the same stay, which is exactly what the
  /// deliberately-extended cross-caregiver read policy exists for.
  Future<Map<String, dynamic>?> fetchStayForBooking(String bookingId) async {
    return _client
        .from('hospital_stay_bookings')
        .select('hospital_stay_id, shift_note, hospital_stays(hospital_name, status)')
        .eq('booking_id', bookingId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchStayShiftNotes(String stayId) async {
    return _client
        .from('hospital_stay_bookings')
        .select('booking_id, shift_note, bookings(scheduled_at)')
        .eq('hospital_stay_id', stayId)
        .not('shift_note', 'is', null);
  }

  Future<void> saveHandoffNote(String bookingId, String note) async {
    await _client
        .from('hospital_stay_bookings')
        .update({'shift_note': note}).eq('booking_id', bookingId);
  }
}
