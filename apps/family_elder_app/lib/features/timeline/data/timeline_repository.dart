import 'package:supabase_flutter/supabase_flutter.dart';

/// Direct table access, guarded entirely by the
/// `elder_timeline_events_select` RLS policy (PRD Part 4, Batch 1, Module
/// 2) — self, consented family, admin, or the assigned caregiver for a
/// related booking. Rows are written only by Edge Functions via the
/// service-role client, so this repository is read-only.
class TimelineRepository {
  TimelineRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchEvents(String elderId,
      {int limit = 50}) async {
    return _client
        .from('elder_timeline_events')
        .select()
        .eq('elder_id', elderId)
        .order('occurred_at', ascending: false)
        .limit(limit);
  }
}
