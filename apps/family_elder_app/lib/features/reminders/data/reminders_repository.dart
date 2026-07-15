import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads what reminders-dispatch-sweep produced and lets the viewer
/// snooze/dismiss (PRD Part 5, Batch 2, Module 8) — this repository never
/// enqueues; that's always a side effect of the source module's own
/// write path (medications-generate-doses, the appointment trigger).
class RemindersRepository {
  RemindersRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchPending(String elderId) async {
    return _client
        .from('reminders')
        .select()
        .eq('elder_id', elderId)
        .inFilter('status', ['pending', 'sent'])
        .order('remind_at');
  }

  Future<void> snooze(String reminderId, Duration duration) async {
    await _client.from('reminders').update({
      'status': 'snoozed',
      'snoozed_until': DateTime.now().add(duration).toIso8601String(),
    }).eq('id', reminderId);
  }

  Future<void> dismiss(String reminderId) async {
    await _client.from('reminders').update({'status': 'dismissed'}).eq('id', reminderId);
  }
}
