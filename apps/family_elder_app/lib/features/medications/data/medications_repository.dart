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

  /// Returns the new medication's id so the caller can attach stock to it.
  Future<String> addMedication({
    required String elderId,
    required String name,
    required String dosage,
    required List<String> times,
    required String addedBy,
  }) async {
    final row = await _client.from('elder_medications').insert({
      'elder_id': elderId,
      'name': name,
      'dosage': dosage,
      'schedule': {'times': times},
      'added_by': addedBy,
    }).select('id').single();
    return row['id'] as String;
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

  /// Midnight-to-midnight *where the person is standing*.
  ///
  /// This used to be built with `DateTime.utc(now.year, now.month, now.day)`,
  /// which is a different day. At IST (+5:30) that window runs 05:30 today to
  /// 05:30 tomorrow, so a 6am tablet showed up under "today" correctly but a
  /// 4am one was filed under yesterday and vanished from the screen the person
  /// was looking at. Local midnight, converted to UTC for the query, is the
  /// boundary a human means by "today".
  static ({String start, String end}) _todayBounds() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return (
      start: start.toUtc().toIso8601String(),
      end: start.add(const Duration(days: 1)).toUtc().toIso8601String(),
    );
  }

  Future<List<Map<String, dynamic>>> fetchDosesForToday(String medicationId) async {
    final bounds = _todayBounds();
    return _client
        .from('medication_doses')
        .select()
        .eq('medication_id', medicationId)
        .gte('scheduled_at', bounds.start)
        .lt('scheduled_at', bounds.end)
        .order('scheduled_at');
  }

  /// Everything due today across *all* of an elder's medicines, with the
  /// medicine's name and dosage attached.
  ///
  /// The per-medicine query above answers "how is this tablet going", which is
  /// the wrong question first thing in the morning. This one answers "what do
  /// I take now", which is the question the Today screen exists for — one list,
  /// in time order, regardless of which medicine each dose belongs to.
  Future<List<Map<String, dynamic>>> fetchTodayForElder(String elderId) async {
    final bounds = _todayBounds();
    return _client
        .from('medication_doses')
        .select(
            'id, status, scheduled_at, taken_at, elder_medications!inner(id, elder_id, name, dosage)')
        .eq('elder_medications.elder_id', elderId)
        .neq('status', 'cancelled')
        .gte('scheduled_at', bounds.start)
        .lt('scheduled_at', bounds.end)
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
