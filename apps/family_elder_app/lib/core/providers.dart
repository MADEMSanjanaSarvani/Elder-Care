import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => SetuSupabaseClient.instance);

final authStateProvider =
    StreamProvider<AuthState>((ref) => SetuSupabaseClient.onAuthStateChange);

/// The signed-in user's `profiles` row — null while signed out or before
/// the row has been created (see `AuthRepository.completeSignIn`).
final currentProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(authStateProvider); // re-fetch on sign-in/sign-out
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;
  return client.from('profiles').select().eq('id', user.id).maybeSingle();
});

final elderProfileByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return client.from('elder_profiles').select().eq('id', elderId).maybeSingle();
});

final regionConfigProvider = FutureProvider<Region>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return RegionConfigClient(client).fetch(Env.activeRegionCode);
});

/// Elder profiles the signed-in user can act on: themself (if they're the
/// elder) or any elder they're actively linked to as family.
final myElderProfilesProvider = FutureProvider<List<ElderProfile>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return [];

  final selfRows =
      await client.from('elder_profiles').select().eq('auth_user_id', user.id);
  final linkedRows = await client
      .from('elder_profiles')
      .select('*, family_links!inner(family_user_id, status)')
      .eq('family_links.family_user_id', user.id)
      .eq('family_links.status', 'active');

  final seen = <String>{};
  final result = <ElderProfile>[];
  for (final row in [...selfRows, ...linkedRows]) {
    final id = row['id'] as String;
    if (seen.add(id)) result.add(ElderProfile.fromJson(row));
  }
  return result;
});
