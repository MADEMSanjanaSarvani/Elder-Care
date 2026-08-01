import 'package:supabase_flutter/supabase_flutter.dart';

/// Direct table access, guarded by the elder_medications /
/// medication_doses / medication_stock RLS policies (PRD Part 5, Batch 2,
/// Modules 5-6) — no Edge Function needed for CRUD or dose marking, same
/// reasoning as the existing ConsentRepository. Dose *generation* and
/// reminder *delivery* are owned server-side by
/// medications-generate-doses / reminders-dispatch-sweep; this repository
/// only reads what those produced and marks doses taken/missed/skipped.
class MedicationsRepository {
  MedicationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchMedications(String elderId) async {
    return _client
        .from('elder_medications')
        .select()
        .eq('elder_id', elderId)
        .eq('active', true)
        .order('created_at');
  }

  Future<void> addMedication({
    required String elderId,
    required String name,
    required String dosage,
    required List<String> times,
    required String addedBy,
  }) async {
    await _client.from('elder_medications').insert({
      'elder_id': elderId,
      'name': name,
      'dosage': dosage,
      'schedule': {'times': times},
      'added_by': addedBy,
    });
  }

  /// Cancels pending future doses and logs a timeline event server-side
  /// via trg_on_medication_discontinued — this call is just the flip.
  Future<void> discontinue(String medicationId) async {
    await _client.from('elder_medications').update({'active': false}).eq('id', medicationId);
  }

  /// Every pending dose for this elder over the next two days, newest last.
  ///
  /// Feeds the on-device alarm scheduler rather than any screen: it needs all
  /// of an elder's doses at once, where the UI asks per medicine. Two days
  /// because the app re-syncs on every open and Android caps how many alarms
  /// one app may hold.
  Future<List<Map<String, dynamic>>> fetchUpcomingDoses(String elderId) async {
    final now = DateTime.now().toUtc();
    return _client
        .from('medication_doses')
        .select('id, status, scheduled_at, elder_medications!inner(elder_id, name, dosage)')
        .eq('elder_medications.elder_id', elderId)
        .eq('status', 'pending')
        .gte('scheduled_at', now.toIso8601String())
        .lt('scheduled_at', now.add(const Duration(days: 2)).toIso8601String())
        .order('scheduled_at');
  }

  Future<List<Map<String, dynamic>>> fetchDosesForToday(String medicationId) async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _client
        .from('medication_doses')
        .select()
        .eq('medication_id', medicationId)
        .gte('scheduled_at', startOfDay.toIso8601String())
        .lt('scheduled_at', endOfDay.toIso8601String())
        .order('scheduled_at');
  }

  Future<void> markDose({
    required String doseId,
    required String status,
    required String markedBy,
    required String markedVia,
  }) async {
    await _client.from('medication_doses').update({
      'status': status,
      'taken_at': status == 'taken' ? DateTime.now().toIso8601String() : null,
      'marked_by': markedBy,
      'marked_via': markedVia,
    }).eq('id', doseId);
  }

  Future<Map<String, dynamic>?> fetchStock(String medicationId) async {
    return _client.from('medication_stock').select().eq('medication_id', medicationId).maybeSingle();
  }

  Future<void> setStock({
    required String medicationId,
    required double quantityOnHand,
    required String unit,
    required double refillThreshold,
  }) async {
    await _client.from('medication_stock').upsert({
      'medication_id': medicationId,
      'quantity_on_hand': quantityOnHand,
      'unit': unit,
      'refill_threshold': refillThreshold,
    }, onConflict: 'medication_id');
  }

  Future<void> markRestocked(String medicationId, double quantity) async {
    await _client.from('medication_stock').update({
      'quantity_on_hand': quantity,
      'last_restocked_at': DateTime.now().toIso8601String(),
    }).eq('medication_id', medicationId);
  }
}
