import 'package:supabase_flutter/supabase_flutter.dart';

/// Consent & Privacy Management (PRD Part 10, Batch 7, Module 24). A
/// presentation layer over existing mechanisms: access history comes from
/// the me-access-history Edge Function; a guardian-consent request is a
/// plain RLS-guarded insert. The actual consent grant/revoke stays in the
/// existing consent screen — this module adds no new access model.
class PrivacyRepository {
  PrivacyRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchAccessHistory(String elderId) async {
    final response = await _client.functions.invoke(
      'me-access-history?elder_id=$elderId',
      method: HttpMethod.get,
    );
    if (response.status != 200) {
      throw StateError('Could not load access history: ${response.data}');
    }
    final data = response.data as Map<String, dynamic>;
    return (data['entries'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchGuardianRequests(String elderId) async {
    return _client
        .from('guardian_consent_requests')
        .select('category, basis_description, status, created_at')
        .eq('elder_id', elderId)
        .order('created_at', ascending: false);
  }

  Future<void> submitGuardianRequest({
    required String elderId,
    required String category,
    required String basisDescription,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    await _client.from('guardian_consent_requests').insert({
      'elder_id': elderId,
      'requested_by': userId,
      'category': category,
      'basis_description': basisDescription,
    });
  }
}
