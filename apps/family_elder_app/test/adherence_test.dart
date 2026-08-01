// The one piece of logic in CareHive that must not be wrong.
//
// Every number a doctor might act on comes out of buildAdherenceWindow. The
// tests that matter most here are the negative ones: that a dose nobody marked
// is never quietly counted as skipped, and that a percentage is refused
// outright rather than guessed when nothing has come due.

import 'package:flutter_test/flutter_test.dart';
import 'package:family_elder_app/features/medications/presentation/adherence.dart';

/// 2026-08-01 at 12:00 local. Fixed, so a test cannot pass or fail depending
/// on the hour it happens to run at.
final _now = DateTime(2026, 8, 1, 12);

Map<String, dynamic> dose(String status, DateTime at) => {
      'status': status,
      'scheduled_at': at.toUtc().toIso8601String(),
    };

void main() {
  group('buildAdherenceWindow', () {
    test('always returns one bucket per day, including empty days', () {
      final w = buildAdherenceWindow(const [], now: _now, days: 7);

      expect(w.days, hasLength(7));
      expect(w.days.first.day, DateTime(2026, 7, 26));
      expect(w.days.last.day, DateTime(2026, 8, 1));
      expect(w.days.every((d) => d.nothingScheduled), isTrue);
      expect(w.isEmpty, isTrue);
    });

    test('a past pending dose is "no record", never "not taken"', () {
      final w = buildAdherenceWindow(
        [dose('pending', DateTime(2026, 8, 1, 8))],
        now: _now,
        days: 7,
      );

      expect(w.noRecord, 1);
      expect(w.notTaken, 0, reason: 'unmarked is not the same as skipped');
      expect(w.taken, 0);
      expect(w.due, 1);
    });

    test('a future pending dose is upcoming, and is not a gap', () {
      final w = buildAdherenceWindow(
        [dose('pending', DateTime(2026, 8, 1, 20))],
        now: _now,
        days: 7,
      );

      expect(w.days.last.upcoming, 1);
      expect(w.noRecord, 0);
      // Not yet knowable, so it must not drag the denominator down.
      expect(w.due, 0);
      expect(w.takenPercent, isNull);
    });

    test('missed and skipped both count as a recorded "not taken"', () {
      final w = buildAdherenceWindow(
        [
          dose('missed', DateTime(2026, 7, 30, 8)),
          dose('skipped', DateTime(2026, 7, 31, 8)),
        ],
        now: _now,
        days: 7,
      );

      expect(w.notTaken, 2);
      expect(w.noRecord, 0);
      expect(w.due, 2);
    });

    test('a cancelled dose is owed by nobody and counts nowhere', () {
      final w = buildAdherenceWindow(
        [
          dose('cancelled', DateTime(2026, 7, 30, 8)),
          dose('taken', DateTime(2026, 7, 30, 20)),
        ],
        now: _now,
        days: 7,
      );

      expect(w.due, 1);
      expect(w.taken, 1);
      expect(w.takenPercent, 100,
          reason: 'a stopped medicine must not dilute the figure');
    });

    test('percentages are refused, not zeroed, when nothing has come due', () {
      final w = buildAdherenceWindow(
        [dose('pending', DateTime(2026, 8, 1, 20))],
        now: _now,
        days: 7,
      );

      // 0% would read as "took nothing", which is a different claim entirely.
      expect(w.takenPercent, isNull);
      expect(w.recordedPercent, isNull);
    });

    test('takenPercent counts only marked-taken; recordedPercent counts both',
        () {
      final w = buildAdherenceWindow(
        [
          dose('taken', DateTime(2026, 7, 28, 8)),
          dose('taken', DateTime(2026, 7, 29, 8)),
          dose('skipped', DateTime(2026, 7, 30, 8)),
          dose('pending', DateTime(2026, 7, 31, 8)), // past → no record
        ],
        now: _now,
        days: 7,
      );

      expect(w.due, 4);
      expect(w.takenPercent, 50);
      // Three of the four were answered one way or the other.
      expect(w.recordedPercent, 75);
    });

    test('doses outside the window are ignored rather than clamped in', () {
      final w = buildAdherenceWindow(
        [
          dose('taken', DateTime(2026, 7, 1, 8)), // long before
          dose('taken', DateTime(2026, 9, 1, 8)), // after
          dose('taken', DateTime(2026, 7, 31, 8)), // inside
        ],
        now: _now,
        days: 7,
      );

      expect(w.taken, 1);
    });

    test('rows with an unparseable or missing time are dropped, not crashed on',
        () {
      final w = buildAdherenceWindow(
        [
          {'status': 'taken', 'scheduled_at': 'not a date'},
          const {'status': 'taken'},
          dose('taken', DateTime(2026, 7, 31, 8)),
        ],
        now: _now,
        days: 7,
      );

      expect(w.taken, 1);
    });

    test('several doses land on the day they were scheduled, in local time',
        () {
      final w = buildAdherenceWindow(
        [
          dose('taken', DateTime(2026, 7, 30, 8)),
          dose('taken', DateTime(2026, 7, 30, 14)),
          dose('missed', DateTime(2026, 7, 30, 21)),
        ],
        now: _now,
        days: 7,
      );

      final july30 = w.days.firstWhere((d) => d.day == DateTime(2026, 7, 30));
      expect(july30.taken, 2);
      expect(july30.notTaken, 1);
      expect(july30.scheduled, 3);
      expect(july30.nothingScheduled, isFalse);

      // And nothing leaked into its neighbours.
      final july29 = w.days.firstWhere((d) => d.day == DateTime(2026, 7, 29));
      expect(july29.scheduled, 0);
    });

    test('a dose just after local midnight belongs to that new day', () {
      // The bug this guards: computing the day boundary in UTC files an
      // 00:30 IST dose under the previous day, so it vanishes from the day
      // the person is actually looking at.
      final w = buildAdherenceWindow(
        [dose('taken', DateTime(2026, 8, 1, 0, 30))],
        now: _now,
        days: 7,
      );

      expect(w.days.last.day, DateTime(2026, 8, 1));
      expect(w.days.last.taken, 1);
    });
  });
}
