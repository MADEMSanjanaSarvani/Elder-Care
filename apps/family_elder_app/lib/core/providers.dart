import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => SetuSupabaseClient.instance);

final authStateProvider =
    StreamProvider<AuthState>((ref) => SetuSupabaseClient.onAuthStateChange);

/// True while the user is inside a Supabase password-recovery session — i.e.
/// they just followed the link in a reset email and it re-opened the app.
/// Supabase signs them in with a short-lived recovery session, so without
/// this flag the router would drop them straight on the dashboard and they'd
/// never get the chance to choose a new password. Cleared once it's saved.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

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

/// Caregiver-mode providers (this app now serves caregivers too, chosen by
/// role at login). A caregiver's own row exists only once ops has completed
/// their verification (PRD Part 1 §04) — null means "not onboarded yet",
/// which the caregiver home surfaces as a pending-verification screen. There
/// is deliberately no self-serve path to create this row.
final myCaregiverProvider = FutureProvider<Caregiver?>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;
  final row = await client
      .from('caregivers')
      .select()
      .eq('user_id', user.id)
      .maybeSingle();
  if (row == null) return null;
  return Caregiver.fromJson(row);
});

final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final caregiver = await ref.watch(myCaregiverProvider.future);
  if (caregiver == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('bookings')
      .select()
      .eq('caregiver_id', caregiver.id)
      .inFilter('status', ['matched', 'confirmed', 'in_progress']).order(
          'scheduled_at');
  return rows.map((row) => Booking.fromJson(row)).toList();
});
