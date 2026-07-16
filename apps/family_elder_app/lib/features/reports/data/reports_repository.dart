import 'package:supabase_flutter/supabase_flutter.dart';

/// AI Visit Reports (PRD Part 7, Batch 4, Module 14). Read-only —
/// reports are generated server-side by the scheduled function. RLS
/// already withholds flagged/held reports from everyone but admin, so a
/// report reaching this query has been cleared for the reader; the app
/// renders whatever comes back.
class ReportsRepository {
  ReportsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchReports(String elderId) async {
    return _client
        .from('ai_visit_reports')
        .select()
        .eq('elder_id', elderId)
        .order('period_end', ascending: false);
  }
}
