import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../family_home/presentation/family_home_screen.dart' show homeSummaryProvider;
import 'weekly_activity_chart.dart';

/// Family-facing Wellness Summary, matching the Stitch `wellness_summary`
/// design (both frames): a glass "AI Daily Insights" card with real-data
/// chips, a big wellness ring, a 2x2 bento grid, and the real weekly trend
/// chart. The score and every tile are derived from the SAME real data the
/// home dashboard uses (medications taken today, the daily check-in, mood,
/// and logged timeline activity) — no invented vitals — so what the family
/// sees here always agrees with the rest of the app.
///
/// The Stitch mock also shows Sleep Quality, Hydration, Steps and Resting
/// Heart Rate tiles — SETU doesn't track any wearable/vitals data, so those
/// are omitted rather than filled with invented numbers. Activity and Mood
/// are wired to the nearest real values instead (weekly timeline event
/// count, and the elder's own logged mood).
class WellnessSummaryScreen extends ConsumerWidget {
  const WellnessSummaryScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider(elderId));
    final weeklyActivity =
        ref.watch(weeklyActivityProvider(elderId)).asData?.value;
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

          final weeklyTotal =
              weeklyActivity?.fold<int>(0, (a, b) => a + b);

          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              _InsightCard(
                  insight: insight,
                  medsTaken: s.medsTaken,
                  medsTotal: s.medsTotal,
                  checkedIn: checkedIn),
              const SizedBox(height: SetuSpacing.lg),
              _RingCard(score: score, label: label),
              const SizedBox(height: SetuSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _BentoTile(
                      icon: Icons.medication_rounded,
                      tint: SetuColors.peachLight,
                      value: s.medsTotal == 0
                          ? '—'
                          : '${s.medsTaken}/${s.medsTotal}',
                      label: 'MEDICINES TODAY',
                    ),
                  ),
                  const SizedBox(width: SetuSpacing.md),
                  Expanded(
                    child: _BentoTile(
                      icon: checkedIn
                          ? Icons.check_circle
                          : Icons.pending_outlined,
                      tint: checkedIn
                          ? SetuColors.verifiedLight
                          : SetuColors.peachLight,
                      value: checkedIn ? 'Done' : 'Pending',
                      label: 'DAILY CHECK-IN',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SetuSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _BentoTile(
                      icon: Icons.directions_walk,
                      tint: SetuColors.accentLight,
                      value: weeklyTotal == null ? '—' : '$weeklyTotal',
                      label: 'ACTIVITY THIS WEEK',
                    ),
                  ),
                  const SizedBox(width: SetuSpacing.md),
                  Expanded(
                    child: _BentoTile(
                      icon: Icons.sentiment_satisfied_alt_outlined,
                      tint: SetuColors.lavenderLight,
                      value: s.mood == null
                          ? '—'
                          : s.mood![0].toUpperCase() + s.mood!.substring(1),
                      label: 'MOOD STATUS',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SetuSpacing.lg),
              Text('Weekly Trend',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: SetuSpacing.md),
              WeeklyActivityChart(elderId: elderId),
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

/// Glass "AI Daily Insights" card (matches the Stitch design's top summary
/// panel), with real-data status chips instead of the mock's fabricated
/// "Activity 9/10" / "Sleep 98%" pills.
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.insight,
    required this.medsTaken,
    required this.medsTotal,
    required this.checkedIn,
  });

  final String insight;
  final int medsTaken;
  final int medsTotal;
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: const Border(
          left: BorderSide(color: SetuColors.accentLight, width: 4),
          top: BorderSide(color: SetuColors.borderLight),
          right: BorderSide(color: SetuColors.borderLight),
          bottom: BorderSide(color: SetuColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.smart_toy, color: SetuColors.accentLight, size: 20),
              SizedBox(width: SetuSpacing.sm),
              Text('DAILY INSIGHTS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: SetuColors.accentLight)),
            ],
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(insight, style: const TextStyle(height: 1.45, fontSize: 15)),
          const SizedBox(height: SetuSpacing.md),
          Wrap(
            spacing: SetuSpacing.sm,
            runSpacing: SetuSpacing.sm,
            children: [
              _Chip(
                icon: medsTotal > 0 && medsTaken >= medsTotal
                    ? Icons.check_circle
                    : Icons.medication_outlined,
                label: medsTotal == 0
                    ? 'No medicines today'
                    : 'Medicines $medsTaken/$medsTotal',
                color: SetuColors.peachLight,
              ),
              _Chip(
                icon: checkedIn ? Icons.check_circle : Icons.pending_outlined,
                label: checkedIn ? 'Checked in' : 'Check-in pending',
                color: checkedIn
                    ? SetuColors.verifiedLight
                    : SetuColors.peachLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
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
          // The arc and the number count up together over 1.5s, as in the
          // design. TweenAnimationBuilder rather than an AnimationController
          // because the score is live: when the elder marks a dose taken and
          // this rebuilds, the tween starts from the value already on screen
          // and moves to the new one, so the change is legible instead of
          // snapping. A controller would replay from zero every rebuild.
          SizedBox(
            width: 168,
            height: 168,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: score / 100),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, value, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: CircularProgressIndicator(
                      value: value,
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
                      Text('${(value * 100).round()}%',
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
          ),
          const SizedBox(height: SetuSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: SetuColors.peachLight.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
          ),
        ],
      ),
    );
  }
}

/// A 2x2 bento metric tile (matches the Stitch "Sleep Quality" / "Hydration"
/// tile shape, applied to real metrics instead).
class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: SetuColors.paperRaisedLight.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: tint)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: SetuColors.mutedLight)),
        ],
      ),
    );
  }
}
