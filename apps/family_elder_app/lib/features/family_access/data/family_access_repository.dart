import 'package:supabase_flutter/supabase_flutter.dart';

/// Family Member Management (PRD Part 4, Batch 1, Module 4). Inviting goes
/// through the `family-invite` Edge Function since it needs the service-role
/// Auth Admin API to create an account for someone who may not have one yet.
/// Setting `coordinator` is direct-table — the
/// `trg_enforce_coordinator_change` trigger is the real enforcement, this
/// repository doesn't duplicate that check.
class FamilyAccessRepository {
  FamilyAccessRepository(this._client);

  final SupabaseClient _client;

  /// Reads the circle through the `family_circle` function rather than
  /// selecting family_links with an embedded profiles().
  ///
  /// The direct select returned an empty screen: RLS lets you read your own
  /// link and no one else's, and blocks profiles rows that aren't yours — and
  /// PostgREST turns a blocked embed into a null rather than an error, so even
  /// the visible row came back nameless. Fixing it in RLS would have meant
  /// making every SETU user's name and phone readable by every other user.
  /// See migration 0034.
  Future<List<Map<String, dynamic>>> fetchFamily(String elderId) async {
    final rows = await _client.rpc(
      'family_circle',
      params: {'p_elder_id': elderId},
    ) as List<dynamic>;
    return rows
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList();
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
