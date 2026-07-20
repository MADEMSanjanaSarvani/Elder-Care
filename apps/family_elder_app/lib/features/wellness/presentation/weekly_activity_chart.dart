import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';

/// Real 7-day activity: counts timeline events per day for the last week, so
/// the bars reflect actual logged activity (visits, check-ins, doses, notes)
/// — never invented numbers. Empty days simply read as 0.
final weeklyActivityProvider =
    FutureProvider.family<List<int>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final startDay = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
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

/// A warm bar chart of the last 7 days of activity. Fails soft: on any error
/// or while loading it shows a slim placeholder instead of a red error, so it
/// never breaks the screen it sits on.
class WeeklyActivityChart extends ConsumerWidget {
  const WeeklyActivityChart({required this.elderId, super.key});

  final String elderId;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyActivityProvider(elderId));
    final counts = async.asData?.value ?? const [0, 0, 0, 0, 0, 0, 0];
    final maxV = counts.fold<int>(0, (m, v) => v > m ? v : m);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

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
              const Icon(Icons.insights_rounded,
                  color: SetuColors.accentLight, size: 20),
              const SizedBox(width: SetuSpacing.sm),
              Text("This week's activity",
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
          if (maxV == 0) ...[
            const SizedBox(height: SetuSpacing.sm),
            const Text(
              'Activity will appear here as visits, check-ins and doses are logged.',
              style: TextStyle(color: SetuColors.mutedLight, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
