import 'package:supabase_flutter/supabase_flutter.dart';

/// Direct table access, guarded entirely by `daily_checkins_insert`'s RLS
/// policy (PRD Part 4, Batch 1, Module 3 — `is_elder_self` only, no
/// family-proxy check-in for MVP) — no Edge Function needed since there's
/// no secret and no cross-table rule beyond what the policy already
/// enforces.
class CheckInRepository {
  CheckInRepository(this._client);

  final SupabaseClient _client;

  Future<void> checkIn({required String elderId, String? mood}) async {
    await _client.from('daily_checkins').insert({
      'elder_id': elderId,
      if (mood != null) 'mood': mood,
      'source': 'elder_app',
    });
  }

  /// Null if the elder hasn't checked in yet today (UTC day boundary —
  /// matches `checkins-escalation-sweep`'s own comparison for now; true
  /// per-timezone handling is a named Phase 2+ need, not built here).
  Future<DateTime?> lastCheckInToday(String elderId) async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final rows = await _client
        .from('daily_checkins')
        .select('checked_in_at')
        .eq('elder_id', elderId)
        .gte('checked_in_at', startOfDay.toIso8601String())
        .order('checked_in_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['checked_in_at'] as String);
  }
}
