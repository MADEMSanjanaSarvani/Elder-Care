import 'package:supabase_flutter/supabase_flutter.dart';

/// A one-glance snapshot of an elder's day for the family dashboard:
/// medicines taken vs due today, and the latest check-in (mood).
/// What CareHive actually knows about how the day is going.
///
/// Three states rather than a boolean, because "nothing has been flagged" and
/// "we have not heard from them" are different facts, and a family deserves to
/// be told which one it is looking at.
enum SafetyState {
  /// Nothing amiss has been recorded.
  allWell,

  /// The check-in sweep logged a miss today. Not an emergency — a reason to
  /// ring them.
  needsAttention,

  /// An SOS is open and has been neither resolved nor cancelled.
  emergency,
}

class HomeSummary {
  const HomeSummary({
    required this.medsTaken,
    required this.medsTotal,
    required this.checkedIn,
    required this.safety,
    this.mood,
    this.lastCheckIn,
    this.nextDoseAt,
    this.nextDoseName,
  });

  final int medsTaken;
  final int medsTotal;
  final bool checkedIn;
  final String? mood;
  final DateTime? lastCheckIn;

  /// The next dose still due today, if any. An elder glancing at their home
  /// screen should be able to see when the next tablet is due without tapping
  /// into anything — "tap to see today's schedule" makes them do work to learn
  /// the one fact they opened the app for.
  final DateTime? nextDoseAt;
  final String? nextDoseName;

  /// Read from real rows — an open `sos_events` row, and today's
  /// `checkin_missed` timeline entry written by the escalation sweep.
  ///
  /// This used to be `bool get isSafe => true;`. The dashboard said "Ramesh is
  /// safe", in green, with a status dot, no matter what had happened — an SOS
  /// ten minutes earlier did not change it. That is exactly the fabricated
  /// status this app has refused from every mock it was handed, shipped in our
  /// own code, on the line an anxious family reads first.
  final SafetyState safety;

  bool get isSafe => safety == SafetyState.allWell;
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
        .select('status, scheduled_at, elder_medications!inner(elder_id, name)')
        .eq('elder_medications.elder_id', elderId)
        .gte('scheduled_at', start.toIso8601String())
        .lt('scheduled_at', end.toIso8601String())
        .order('scheduled_at');

    final total = doses.length;
    final taken =
        doses.where((d) => d['status'] == 'taken').length;

    // The earliest dose still outstanding. Anything already taken or skipped
    // is behind us; a missed one still in the past is deliberately not shown
    // as "next", because calling an overdue dose "next" would hide the fact
    // that it was missed.
    DateTime? nextAt;
    String? nextName;
    for (final dose in doses) {
      if (dose['status'] != 'pending') continue;
      final at = DateTime.tryParse(dose['scheduled_at'] as String)?.toLocal();
      if (at == null || at.isBefore(now)) continue;
      if (nextAt == null || at.isBefore(nextAt)) {
        nextAt = at;
        final med = dose['elder_medications'];
        nextName = med is Map ? med['name'] as String? : null;
      }
    }

    final checkin = await _client
        .from('daily_checkins')
        .select('mood, checked_in_at')
        .eq('elder_id', elderId)
        .gte('checked_in_at', start.toIso8601String())
        .order('checked_in_at', ascending: false)
        .limit(1)
        .maybeSingle();

    // An SOS that nobody has resolved or cancelled. Not date-bounded: an
    // emergency raised at 11pm is still an emergency at 1am, and scoping this
    // to "today" would clear the dashboard at midnight while the ambulance was
    // still on its way.
    final openSos = await _client
        .from('sos_events')
        .select('id')
        .eq('elder_id', elderId)
        .not('status', 'in', '(resolved,cancelled)')
        .limit(1)
        .maybeSingle();

    // The escalation sweep's own judgement, rather than a threshold invented
    // here. If the server has not called it a miss, this screen does not.
    final missed = openSos != null
        ? null
        : await _client
            .from('elder_timeline_events')
            .select('id')
            .eq('elder_id', elderId)
            .eq('event_type', 'checkin_missed')
            .gte('occurred_at', start.toIso8601String())
            .limit(1)
            .maybeSingle();

    final safety = openSos != null
        ? SafetyState.emergency
        : missed != null
            ? SafetyState.needsAttention
            : SafetyState.allWell;

    return HomeSummary(
      medsTaken: taken,
      medsTotal: total,
      checkedIn: checkin != null,
      safety: safety,
      mood: checkin?['mood'] as String?,
      lastCheckIn: checkin?['checked_in_at'] != null
          ? DateTime.tryParse(checkin!['checked_in_at'] as String)?.toLocal()
          : null,
      nextDoseAt: nextAt,
      nextDoseName: nextName,
    );
  }
}
