import 'package:supabase_flutter/supabase_flutter.dart';

/// Direct table access, guarded by appointments' RLS (PRD Part 5, Batch
/// 2, Module 7) — no Edge Function needed for CRUD. Reminder enqueue/
/// re-enqueue/cancel on insert, reschedule, and status change is a
/// database trigger (trg_enqueue_appointment_reminder, 0011); this
/// repository never touches `reminders` directly.
class AppointmentsRepository {
  AppointmentsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchAppointments(String elderId) async {
    return _client.from('appointments').select().eq('elder_id', elderId).order('scheduled_at');
  }

  Future<void> createAppointment({
    required String elderId,
    required String title,
    String? location,
    required DateTime scheduledAt,
    required String createdBy,
  }) async {
    await _client.from('appointments').insert({
      'elder_id': elderId,
      'title': title,
      if (location != null && location.isNotEmpty) 'location': location,
      'scheduled_at': scheduledAt.toIso8601String(),
      'created_by': createdBy,
    });
  }

  /// An appointment is not a booking (PRD §03) — this never touches
  /// `bookings`. The linked-booking deep-link is left to the caller
  /// (navigate to the existing, unmodified booking flow).
  Future<void> logOutcome(String appointmentId, String note) async {
    await _client.from('appointments').update({
      'outcome_note': note,
      'status': 'completed',
    }).eq('id', appointmentId);
  }

  Future<void> cancel(String appointmentId) async {
    await _client.from('appointments').update({'status': 'cancelled'}).eq('id', appointmentId);
  }
}
