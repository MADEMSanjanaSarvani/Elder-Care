/// The record of what was actually taken.
///
/// This is the thing the whole app exists to produce. Everything else —
/// the alarms, the Taken button, the family view — is machinery for filling
/// this in honestly.
///
/// ## The distinction that matters
///
/// A dose row that is still `pending` after its time has passed does **not**
/// mean the medicine was skipped. It means nobody told us. Those are different
/// facts and the app must never quietly merge them:
///
/// * **taken** — somebody marked it. A fact.
/// * **not taken** — somebody marked it `missed` or `skipped`. Also a fact.
/// * **no record** — the time passed and nothing was marked. *Not* a fact
///   about the medicine, only about the record.
///
/// Counting "no record" as a missed dose would produce an adherence figure
/// that reads as medical information and isn't. A doctor shown "62% adherence"
/// may change a prescription; the same doctor shown "62% recorded taken, 30%
/// no record" asks a question instead. The second is the truth, so it is what
/// gets drawn.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/motion.dart';
import '../../../core/providers.dart';

/// One day's worth of doses, split by what is actually known about them.
@immutable
class DoseDay {
  const DoseDay({
    required this.day,
    this.taken = 0,
    this.notTaken = 0,
    this.noRecord = 0,
    this.upcoming = 0,
  });

  /// Local midnight of the day described.
  final DateTime day;

  /// Marked taken.
  final int taken;

  /// Marked missed or skipped — a deliberate record that it was not taken.
  final int notTaken;

  /// Due, in the past, and never marked either way.
  final int noRecord;

  /// Due later today or in future. Not yet knowable, so never counted as a gap.
  final int upcoming;

  /// Doses that have come due, and therefore could have been recorded.
  int get due => taken + notTaken + noRecord;

  int get scheduled => due + upcoming;

  /// True when nothing was scheduled at all — draws as an empty slot, not a
  /// zero-adherence day.
  bool get nothingScheduled => scheduled == 0;

  DoseDay _plus({int taken = 0, int notTaken = 0, int noRecord = 0, int upcoming = 0}) =>
      DoseDay(
        day: day,
        taken: this.taken + taken,
        notTaken: this.notTaken + notTaken,
        noRecord: this.noRecord + noRecord,
        upcoming: this.upcoming + upcoming,
      );
}

/// A window of days, newest last, with no gaps — days on which nothing was
/// scheduled are present and empty rather than absent, so the chart keeps a
/// steady one-column-per-day rhythm.
@immutable
class AdherenceWindow {
  const AdherenceWindow(this.days);

  final List<DoseDay> days;

  int get taken => days.fold(0, (s, d) => s + d.taken);
  int get notTaken => days.fold(0, (s, d) => s + d.notTaken);
  int get noRecord => days.fold(0, (s, d) => s + d.noRecord);
  int get due => days.fold(0, (s, d) => s + d.due);

  /// Share of *due* doses that were marked taken, 0–100. Null when nothing has
  /// come due yet: a percentage of zero doses is not 0%, it is unanswerable,
  /// and showing "0%" for a medicine started this morning is a lie that makes
  /// people distrust the number for good.
  int? get takenPercent => due == 0 ? null : ((taken / due) * 100).round();

  /// How complete the record itself is. The number to look at before believing
  /// [takenPercent].
  int? get recordedPercent =>
      due == 0 ? null : (((taken + notTaken) / due) * 100).round();

  bool get isEmpty => days.every((d) => d.nothingScheduled);
}

/// Sorts dose rows into days and states. Pure, and separated from the query
/// deliberately: this is the function that decides whether an unmarked tablet
/// is reported as skipped or as unknown, so it is the one thing here that has
/// to be testable without a database. See test/adherence_test.dart.
///
/// [days] is the window length ending on [now]'s local day.
AdherenceWindow buildAdherenceWindow(
  List<Map<String, dynamic>> rows, {
  required DateTime now,
  required int days,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: days - 1));

  final buckets = <DoseDay>[
    for (var i = 0; i < days; i++) DoseDay(day: start.add(Duration(days: i))),
  ];

  for (final row in rows) {
    final at = DateTime.tryParse(row['scheduled_at'] as String? ?? '')?.toLocal();
    if (at == null) continue;
    final index = DateTime(at.year, at.month, at.day).difference(start).inDays;
    if (index < 0 || index >= buckets.length) continue;

    switch (row['status'] as String?) {
      case 'taken':
        buckets[index] = buckets[index]._plus(taken: 1);
      case 'missed':
      case 'skipped':
        buckets[index] = buckets[index]._plus(notTaken: 1);
      case 'cancelled':
        // The medicine was stopped before this dose was due. It was never
        // owed, so it is neither a gap nor an achievement.
        break;
      default:
        // 'pending'. Which side of now it falls on is the whole distinction:
        // still to come, or come and gone with nobody saying what happened.
        buckets[index] = at.isAfter(now)
            ? buckets[index]._plus(upcoming: 1)
            : buckets[index]._plus(noRecord: 1);
    }
  }

  return AdherenceWindow(buckets);
}

/// Adherence over the last [days] days, ending today.
///
/// Keyed by a record so the 7-day card and the 30-day history are separate
/// cached entries rather than one fighting the other.
final adherenceProvider = FutureProvider.family<AdherenceWindow,
    ({String elderId, int days})>((ref, key) async {
  final client = ref.watch(supabaseClientProvider);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: key.days - 1));

  final rows = await client
      .from('medication_doses')
      .select('status, scheduled_at, elder_medications!inner(elder_id)')
      .eq('elder_medications.elder_id', key.elderId)
      .gte('scheduled_at', start.toUtc().toIso8601String());

  return buildAdherenceWindow(
    List<Map<String, dynamic>>.from(rows as List),
    now: now,
    days: key.days,
  );
});

// ---------------------------------------------------------------------------
// Colours
//
// Three states, three colours, used identically in the chart, the legend and
// the history list, so the eye learns them once.
// ---------------------------------------------------------------------------
const _takenColor = SetuColors.verifiedLight;
const _notTakenColor = SetuColors.sosLight;
/// "No record" is the distinction this whole app is built on, so it has to be
/// *visible* — it is a bar segment and a pip carrying meaning, which WCAG asks
/// to clear 3:1 against its background. The old #CFC7BE managed 1.67 on a
/// white card: the one state that says "we do not know" was the one you could
/// not see. This reads 3.96 on card and 3.13 on the page, and still says
/// absent rather than alarming.
const _noRecordColor = Color(0xFF8A7E70);

/// Seven days of doses, stacked by what is known. Tapping opens the full
/// thirty-day record.
class MedicationAdherenceChart extends ConsumerWidget {
  const MedicationAdherenceChart({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adherenceProvider((elderId: elderId, days: 7)));
    final window = async.asData?.value;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdherenceHistoryScreen(elderId: elderId),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        decoration: BoxDecoration(
          color: SetuColors.paperRaisedLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SetuColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication_rounded,
                    color: SetuColors.accentLight, size: 20),
                const SizedBox(width: SetuSpacing.sm),
                Expanded(
                  child: Text('This week',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: SetuColors.mutedLight),
              ],
            ),
            const SizedBox(height: SetuSpacing.xs),
            Text(
              _headline(window),
              style: const TextStyle(
                  color: SetuColors.mutedLight, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: SetuSpacing.lg),
            SizedBox(
              height: 132,
              child: window == null
                  ? const SizedBox.shrink()
                  : _StackedDayChart(window: window),
            ),
            const SizedBox(height: SetuSpacing.md),
            const _Legend(),
          ],
        ),
      ),
    );
  }

  static String _headline(AdherenceWindow? window) {
    if (window == null) return 'Loading the last seven days…';
    if (window.due == 0) {
      return 'No doses have come due yet this week.';
    }
    final buffer = StringBuffer('${window.taken} of ${window.due} doses marked taken');
    if (window.noRecord > 0) {
      buffer.write(' · ${window.noRecord} with no record');
    }
    return buffer.toString();
  }
}

class _StackedDayChart extends StatelessWidget {
  const _StackedDayChart({required this.window});

  final AdherenceWindow window;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final days = window.days;
    final maxScheduled =
        days.fold<int>(0, (m, d) => d.scheduled > m ? d.scheduled : m);
    final maxY = (maxScheduled < 3 ? 3 : maxScheduled + 1).toDouble();

    return BarChart(
      // The bars grow from zero when the card first appears, and re-grow when
      // a dose is marked — so the chart visibly answers the tap you just made
      // two cards down instead of quietly being different.
      duration: Motion.of(context, Motion.slow),
      curve: Curves.easeOutCubic,
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, __, ___) {
              final d = days[group.x];
              return BarTooltipItem(
                _describeDay(d),
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (v) => FlLine(
              color: SetuColors.borderLight.withValues(alpha: 0.6),
              strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_dayLabels[days[i].day.weekday - 1],
                      style: const TextStyle(
                          color: SetuColors.mutedLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [_rodFor(days[i])],
            ),
        ],
      ),
    );
  }

  /// One rod per day, stacked bottom-up: taken, then explicitly not taken,
  /// then the unknown. Reading upward tells you how the day went in the order
  /// you would want to hear it.
  static BarChartRodData _rodFor(DoseDay d) {
    if (d.due == 0) {
      // Nothing has come due. A zero-height rod, not a grey one — an empty
      // column reads as "nothing to say", which is correct.
      return BarChartRodData(toY: 0, width: 16);
    }
    var cursor = 0.0;
    final stack = <BarChartRodStackItem>[];
    void add(int count, Color color) {
      if (count == 0) return;
      stack.add(BarChartRodStackItem(cursor, cursor + count, color));
      cursor += count;
    }

    add(d.taken, _takenColor);
    add(d.notTaken, _notTakenColor);
    add(d.noRecord, _noRecordColor);

    return BarChartRodData(
      toY: cursor,
      width: 16,
      rodStackItems: stack,
      color: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
    );
  }
}

String _describeDay(DoseDay d) {
  if (d.scheduled == 0) return 'Nothing scheduled';
  final parts = <String>[
    if (d.taken > 0) '${d.taken} taken',
    if (d.notTaken > 0) '${d.notTaken} not taken',
    if (d.noRecord > 0) '${d.noRecord} no record',
    if (d.upcoming > 0) '${d.upcoming} still to come',
  ];
  return parts.join('\n');
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: SetuSpacing.md,
      runSpacing: 6,
      children: [
        _LegendDot(color: _takenColor, label: 'Taken'),
        _LegendDot(color: _notTakenColor, label: 'Not taken'),
        _LegendDot(color: _noRecordColor, label: 'No record'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: SetuColors.mutedLight,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The thirty-day record
// ---------------------------------------------------------------------------

/// The screen you hand to a doctor.
///
/// Deliberately plain: a headline sentence in words, then one row per day. No
/// score, no grade, no encouragement. Somebody reading this is making a
/// clinical decision, and a cheerful "great streak!" banner above a month with
/// eleven unrecorded doses would be actively misleading.
class AdherenceHistoryScreen extends ConsumerWidget {
  const AdherenceHistoryScreen({required this.elderId, super.key});

  final String elderId;

  static const _window = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adherenceProvider((elderId: elderId, days: _window)));

    return Scaffold(
      appBar: AppBar(title: const Text('Last 30 days')),
      body: async.when(
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
        data: (window) {
          if (window.isEmpty) {
            return const SetuEmptyState(
              icon: Icons.event_note_outlined,
              title: 'Nothing recorded yet',
              message:
                  'Once medicines have dose times, every day shows up here — '
                  'including the days nothing was marked.',
            );
          }

          // Newest first: the question is almost always "how has it been
          // lately", not "how did it start".
          final days = window.days.reversed.toList();

          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              _SummaryCard(window: window),
              const SizedBox(height: SetuSpacing.lg),
              const _Legend(),
              const SizedBox(height: SetuSpacing.md),
              for (final day in days)
                if (!day.nothingScheduled) _DayRow(day: day),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.window});

  final AdherenceWindow window;

  @override
  Widget build(BuildContext context) {
    final takenPercent = window.takenPercent;

    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            takenPercent == null
                ? 'No doses have come due in the last 30 days.'
                : '$takenPercent% of doses marked taken',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(
            _sentence(window),
            style: const TextStyle(
                color: SetuColors.mutedLight, fontSize: 13.5, height: 1.45),
          ),
          if (window.noRecord > 0) ...[
            const SizedBox(height: SetuSpacing.md),
            Container(
              padding: const EdgeInsets.all(SetuSpacing.md),
              decoration: BoxDecoration(
                color: _noRecordColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 18, color: SetuColors.mutedLight),
                  SizedBox(width: SetuSpacing.sm),
                  Expanded(
                    child: Text(
                      'A dose with no record was not necessarily missed — it '
                      'means nobody marked it either way. It is left as '
                      'unknown rather than counted as skipped.',
                      style: TextStyle(
                          color: SetuColors.mutedLight,
                          fontSize: 12.5,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _sentence(AdherenceWindow w) {
    if (w.due == 0) return 'Nothing has come due yet.';
    final parts = <String>['${w.taken} taken'];
    if (w.notTaken > 0) parts.add('${w.notTaken} recorded as not taken');
    if (w.noRecord > 0) parts.add('${w.noRecord} with no record');
    return '${parts.join(', ')} — out of ${w.due} doses due.';
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final DoseDay day;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = day.day.year == now.year &&
        day.day.month == now.month &&
        day.day.day == now.day;

    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday
                      ? 'Today'
                      : '${_weekdays[day.day.weekday - 1]} ${day.day.day}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: isToday
                          ? SetuColors.accentLight
                          : SetuColors.inkLight),
                ),
                Text(_months[day.day.month - 1],
                    style: const TextStyle(
                        color: SetuColors.mutedLight, fontSize: 11.5)),
              ],
            ),
          ),
          // One pip per dose, in the order taken → not taken → no record →
          // upcoming. At a glance the row is a small honest picture of the day.
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (var i = 0; i < day.taken; i++)
                  const _Pip(color: _takenColor),
                for (var i = 0; i < day.notTaken; i++)
                  const _Pip(color: _notTakenColor),
                for (var i = 0; i < day.noRecord; i++)
                  const _Pip(color: _noRecordColor),
                for (var i = 0; i < day.upcoming; i++)
                  const _Pip(color: Colors.transparent, outlined: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({required this.color, this.outlined = false});

  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: outlined
            ? Border.all(color: SetuColors.borderLight, width: 1.5)
            : null,
      ),
    );
  }
}
