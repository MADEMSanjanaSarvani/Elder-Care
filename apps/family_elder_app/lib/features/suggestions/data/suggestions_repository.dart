import 'package:supabase_flutter/supabase_flutter.dart';

/// AI Recommendation Engine (PRD Part 7, Batch 4, Module 15). Read +
/// status-update only; suggestions are generated server-side by the
/// deterministic rules sweep. RLS consent-gates visibility per
/// suggestion type, so this query only returns what the reader is allowed
/// to see.
class SuggestionsRepository {
  SuggestionsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchPending(String elderId) async {
    return _client
        .from('care_suggestions')
        .select()
        .eq('elder_id', elderId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  }

  Future<void> dismiss(String suggestionId) async {
    await _client
        .from('care_suggestions')
        .update({'status': 'dismissed'}).eq('id', suggestionId);
  }

  Future<void> markActedOn(String suggestionId) async {
    await _client
        .from('care_suggestions')
        .update({'status': 'acted_on'}).eq('id', suggestionId);
  }
}
