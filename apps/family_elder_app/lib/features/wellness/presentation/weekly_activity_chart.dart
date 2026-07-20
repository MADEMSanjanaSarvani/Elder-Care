import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';

DateTime _weekStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
}

/// Real 7-day activity: counts timeline events per day for the last week.
final weeklyActivityProvider =
    FutureProvider.family<List<int>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  final startDay = _weekStart();
  final rows = await client
      .from('elder_timeline_events')
      .select('occurred_at')
      .eq('elder_id', elderId)
      .gte('occurred_at', startDay.toIso8601String());
  final counts = List<int>.filled(7, 0);
  for (final r in (rows as List)) {
    final d = DateTime.parse(r['occurred_at'] as String).toLocal();
    final idx = DateTime(d.year, d.month, d.day).difference(startDay).inDays;
    if (idx >= 0 && idx < 7) counts[idx]++;
  }
  return counts;
});

/// Real 7-day medication adherence: doses marked 'taken' per day, joined to the
/// elder's medications. Reflects actual logged doses, never invented numbers.
final medicationAdherenceProvider =
    FutureProvider.family<List<int>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  final startDay = _weekStart();
  final rows = await client
      .from('medication_doses')
      .select('status, scheduled_at, elder_medications!inner(elder_id)')
      .eq('elder_medications.elder_id', elderId)
      .gte('scheduled_at', startDay.toIso8601String());
  final counts = List<int>.filled(7, 0);
  for (final r in (rows as List)) {
    if (r['status'] != 'taken') continue;
    final d = DateTime.parse(r['scheduled_at'] as String).toLocal();
    final idx = DateTime(d.year, d.month, d.day).difference(startDay).inDays;
    if (idx >= 0 && idx < 7) counts[idx]++;
  }
  return counts;
});

/// Reusable warm 7-day bar chart. Fails soft: while loading or on error it
/// shows a slim placeholder, never a red error, so it never breaks its host.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    required this.counts,
    required this.title,
    required this.icon,
    this.emptyHint,
    super.key,
  });

  final List<int> counts;
  final String title;
  final IconData icon;
  final String? emptyHint;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final maxV = counts.fold<int>(0, (m, v) => v > m ? v : m);
    final start = _weekStart();

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
          Row(
            children: [
              Icon(icon, color: SetuColors.accentLight, size: 20),
              const SizedBox(width: SetuSpacing.sm),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: SetuSpacing.lg),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxV < 4 ? 4 : maxV + 1).toDouble(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                      color: SetuColors.borderLight.withValues(alpha: 0.6),
                      strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        final label = i >= 0 && i < 7
                            ? _dayLabels[
                                start.add(Duration(days: i)).weekday - 1]
                            : '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label,
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
                  for (int i = 0; i < counts.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[i].toDouble(),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              SetuColors.peachLight,
                              SetuColors.accentLight,
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (maxV == 0 && emptyHint != null) ...[
            const SizedBox(height: SetuSpacing.sm),
            Text(emptyHint!,
                style: const TextStyle(
                    color: SetuColors.mutedLight, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

/// Dashboard/wellness: 7-day activity from timeline events.
class WeeklyActivityChart extends ConsumerWidget {
  const WeeklyActivityChart({required this.elderId, super.key});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(weeklyActivityProvider(elderId)).asData?.value ??
        const [0, 0, 0, 0, 0, 0, 0];
    return WeeklyBarChart(
      counts: counts,
      title: "This week's activity",
      icon: Icons.insights_rounded,
      emptyHint:
          'Activity appears here as visits, check-ins and doses are logged.',
    );
  }
}

/// Medications: 7-day adherence (doses taken per day).
class MedicationAdherenceChart extends ConsumerWidget {
  const MedicationAdherenceChart({required this.elderId, super.key});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts =
        ref.watch(medicationAdherenceProvider(elderId)).asData?.value ??
            const [0, 0, 0, 0, 0, 0, 0];
    return WeeklyBarChart(
      counts: counts,
      title: 'Doses taken this week',
      icon: Icons.medication_rounded,
      emptyHint: 'Adherence appears here as doses are marked taken.',
    );
  }
}
