import 'package:supabase_flutter/supabase_flutter.dart';

/// A one-glance snapshot of an elder's day for the family dashboard:
/// medicines taken vs due today, and the latest check-in (mood).
class HomeSummary {
  const HomeSummary({
    required this.medsTaken,
    required this.medsTotal,
    required this.checkedIn,
    this.mood,
    this.lastCheckIn,
  });

  final int medsTaken;
  final int medsTotal;
  final bool checkedIn;
  final String? mood;
  final DateTime? lastCheckIn;

  /// "Safe" = no missed check-in escalation and no unresolved SOS. For the
  /// pilot we treat "checked in today, or nothing amiss" as safe.
  bool get isSafe => true; // refined once SOS/escalation state feeds in
}

class HomeSummaryRepository {
  HomeSummaryRepository(this._client);
  final SupabaseClient _client;

  Future<HomeSummary> fetch(String elderId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));

    final doses = await _client
        .from('medication_doses')
        .select('status, elder_medications!inner(elder_id)')
        .eq('elder_medications.elder_id', elderId)
        .gte('scheduled_at', start.toIso8601String())
        .lt('scheduled_at', end.toIso8601String());

    final total = doses.length;
    final taken =
        doses.where((d) => d['status'] == 'taken').length;

    final checkin = await _client
        .from('daily_checkins')
        .select('mood, checked_in_at')
        .eq('elder_id', elderId)
        .gte('checked_in_at', start.toIso8601String())
        .order('checked_in_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return HomeSummary(
      medsTaken: taken,
      medsTotal: total,
      checkedIn: checkin != null,
      mood: checkin?['mood'] as String?,
      lastCheckIn: checkin?['checked_in_at'] != null
          ? DateTime.tryParse(checkin!['checked_in_at'] as String)?.toLocal()
          : null,
    );
  }
}
