import 'package:supabase_flutter/supabase_flutter.dart';

/// Family Member Management (PRD Part 4, Batch 1, Module 4). Reading the
/// list is direct-table (guarded by `family_links_select` /
/// `family_links_select_shared`); inviting goes through the `family-invite`
/// Edge Function since it needs the service-role Auth Admin API to create
/// an account for someone who may not have one yet. Setting `coordinator`
/// is direct-table too — the `trg_enforce_coordinator_change` trigger is
/// the real enforcement, this repository doesn't duplicate that check.
class FamilyAccessRepository {
  FamilyAccessRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchFamily(String elderId) async {
    return _client
        .from('family_links')
        .select('id, relationship, status, coordinator, profiles(display_name, phone)')
        .eq('elder_id', elderId)
        .order('created_at');
  }

  Future<void> invite({
    required String elderId,
    required String inviteeEmail,
    String? relationship,
  }) async {
    await _client.functions.invoke('family-invite', body: {
      'elder_id': elderId,
      'invitee_email': inviteeEmail,
      if (relationship != null) 'relationship': relationship,
    });
  }

  Future<void> setCoordinator(String familyLinkId, bool coordinator) async {
    await _client
        .from('family_links')
        .update({'coordinator': coordinator})
        .eq('id', familyLinkId);
  }
}
