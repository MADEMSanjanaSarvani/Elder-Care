import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => SetuSupabaseClient.instance);

final authStateProvider =
    StreamProvider<AuthState>((ref) => SetuSupabaseClient.onAuthStateChange);

/// This caregiver's own row, if their onboarding/verification (PRD Part 1
/// §04 — BGV, police verification, and for clinical roles the council
/// credential check) has already been completed by ops. Null means "not
/// onboarded yet" — this app deliberately does not offer a self-serve
/// path to create this row, since that whole verification workflow is not
/// something a login screen should be able to bypass.
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
