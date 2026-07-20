import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../family_home/presentation/family_home_screen.dart' show homeSummaryProvider;
import 'weekly_activity_chart.dart';

/// Family-facing Wellness Summary (Stitch `wellness_summary`): a big wellness
/// ring, an AI daily-insight line, and stat tiles. The score and every tile
/// are derived from the SAME real data the home dashboard uses
/// (medications taken today + the daily check-in) — no invented vitals — so
/// what the family sees here always agrees with the rest of the app.
class WellnessSummaryScreen extends ConsumerWidget {
  const WellnessSummaryScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider(elderId));
    final elderAsync = ref.watch(elderProfileByIdProvider(elderId));
    final first = elderAsync.maybeWhen(
      data: (p) => (p?['display_name'] as String?)?.trim().split(' ').first,
      orElse: () => null,
    );
    final who = first ?? 'Your loved one';

    return Scaffold(
      appBar: AppBar(title: const Text('Wellness Summary')),
      body: summaryAsync.when(
        data: (s) {
          final medsRatio = s.medsTotal > 0 ? s.medsTaken / s.medsTotal : 1.0;
          final checkedIn = s.checkedIn;
          final score =
              (72 + medsRatio * 20 + (checkedIn ? 8 : 0)).round().clamp(0, 100);
          final label = score >= 90
              ? 'Peak Condition'
              : score >= 75
                  ? 'Doing Well'
                  : score >= 60
                      ? 'Needs a Nudge'
                      : 'Check In Soon';

          final insight = _insight(
              who: who,
              score: score,
              medsTaken: s.medsTaken,
              medsTotal: s.medsTotal,
              checkedIn: checkedIn);

          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              _RingCard(score: score, label: label),
              const SizedBox(height: SetuSpacing.lg),
              _InsightCard(insight: insight),
              const SizedBox(height: SetuSpacing.lg),
              WeeklyActivityChart(elderId: elderId),
              const SizedBox(height: SetuSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.medication_rounded,
                      tint: SetuColors.peachLight,
                      value: s.medsTotal == 0
                          ? '—'
                          : '${s.medsTaken}/${s.medsTotal}',
                      label: 'Medicines today',
                    ),
                  ),
                  const SizedBox(width: SetuSpacing.md),
                  Expanded(
                    child: _StatTile(
                      icon: checkedIn
                          ? Icons.check_circle
                          : Icons.pending_outlined,
                      tint: checkedIn
                          ? SetuColors.verifiedLight
                          : SetuColors.peachLight,
                      value: checkedIn ? 'Done' : 'Pending',
                      label: 'Daily check-in',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SetuSpacing.md),
              _StatTile(
                icon: Icons.favorite_rounded,
                tint: SetuColors.accentLight,
                value: '$score%',
                label: 'Overall wellness score',
                wide: true,
              ),
            ],
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }

  String _insight({
    required String who,
    required int score,
    required int medsTaken,
    required int medsTotal,
    required bool checkedIn,
  }) {
    final parts = <String>[];
    if (score >= 90) {
      parts.add("$who's wellness is at a stellar $score% today.");
    } else if (score >= 75) {
      parts.add("$who is doing well at $score% today.");
    } else {
      parts.add("$who is at $score% today — a little attention would help.");
    }
    if (medsTotal > 0) {
      parts.add(medsTaken >= medsTotal
          ? 'All medicines were taken on schedule.'
          : '$medsTaken of $medsTotal medicines taken so far.');
    }
    parts.add(checkedIn
        ? 'The daily check-in is complete.'
        : 'The daily check-in is still pending — a quick call would be lovely.');
    return parts.join(' ');
  }
}

class _RingCard extends StatelessWidget {
  const _RingCard({required this.score, required this.label});
  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.xl),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 168,
            height: 168,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 168,
                  height: 168,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        SetuColors.accentLight.withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation(SetuColors.accentLight),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score%',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                                color: SetuColors.accentLight,
                                fontWeight: FontWeight.w900)),
                    const Text('Wellness',
                        style: TextStyle(color: SetuColors.mutedLight)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 18, color: SetuColors.peachLight),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: SetuColors.peachLight)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final String insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.lavenderLight.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: SetuColors.lavenderLight.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined,
                  color: SetuColors.lavenderLight, size: 20),
              const SizedBox(width: SetuSpacing.sm),
              Text('Daily Insight',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: SetuColors.lavenderLight)),
            ],
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(insight, style: const TextStyle(height: 1.45, fontSize: 15)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    this.wide = false,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment:
            wide ? MainAxisAlignment.start : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: SetuSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tint)),
              Text(label,
                  style: const TextStyle(
                      color: SetuColors.mutedLight, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}
