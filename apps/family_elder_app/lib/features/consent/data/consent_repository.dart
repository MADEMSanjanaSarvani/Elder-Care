import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Direct table access, guarded entirely by the `consent_grants` RLS
/// policy (PRD Part 2 §12) — no Edge Function needed here since there's
/// no secret involved and the business rule ("only the elder may grant")
/// is exactly what the policy already enforces.
class ConsentRepository {
  ConsentRepository(this._client);

  final SupabaseClient _client;

  Future<List<ConsentGrant>> fetchGrants({required String elderId, required String familyUserId}) async {
    final rows = await _client
        .from('consent_grants')
        .select()
        .eq('elder_id', elderId)
        .eq('family_user_id', familyUserId);
    return rows.map((row) => ConsentGrant.fromJson(row)).toList();
  }

  /// Only succeeds if the caller is the elder themself — the RLS policy
  /// re-checks this regardless of what the client believes.
  Future<void> setGrant({
    required String elderId,
    required String familyUserId,
    required ConsentCategory category,
    required bool granted,
  }) async {
    await _client.from('consent_grants').upsert({
      'elder_id': elderId,
      'family_user_id': familyUserId,
      'category': category.wireValue,
      'granted': granted,
      'granted_via': 'elder_app',
      'granted_at': granted ? DateTime.now().toIso8601String() : null,
      'revoked_at': granted ? null : DateTime.now().toIso8601String(),
    }, onConflict: 'elder_id, family_user_id, category');
  }
}
