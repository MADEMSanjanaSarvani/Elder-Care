import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../family_home/data/home_summary_repository.dart' show HomeSummary;
import '../../family_home/presentation/family_home_screen.dart' show homeSummaryProvider;
import 'memory_game_screen.dart';
import 'stories_screen.dart';

/// Elder Wellness Activities — a warm daily engagement hub matching the
/// Stitch "elder_wellness_activities" design: a real health-score ring, a
/// daily brain-game challenge, meditation, a walking encouragement card, and
/// story listening. Reachable from both the elder's own Home tab and the
/// family dashboard, so text stays large and high-contrast throughout.
///
/// The Stitch mock's health score, "restful sleep" line, and "1,240/3k
/// steps" walking goal are all fabricated vitals/step data SETU doesn't
/// track. The ring is wired to the same real score (medicines + check-in)
/// used everywhere else in the app, the insight line is derived from that
/// same real data, and the walking card dropped its invented step count in
/// favour of a plain encouragement message. Memory Games opens a real,
/// playable card-matching game; Meditation and Story Listening remain static
/// engagement content. The mock's "would you like to hear yesterday's story"
/// prompt was dropped — both its buttons only raised a "coming soon"
/// snackbar, and a card that pretends to converse is worse than no card.
class WellnessActivitiesScreen extends ConsumerWidget {
  const WellnessActivitiesScreen({required this.elderId, super.key});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme.scaledForElderMode();
    final summary = ref.watch(homeSummaryProvider(elderId)).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Wellness')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          _healthScore(context, t, summary),
          const SizedBox(height: SetuSpacing.lg),
          _challengeCard(context, t),
          const SizedBox(height: SetuSpacing.md),
          _meditationCard(context, t),
          const SizedBox(height: SetuSpacing.md),
          _walkingCard(context, t),
          const SizedBox(height: SetuSpacing.md),
          _storyCard(context, t),
        ],
      ),
    );
  }

  Widget _healthScore(BuildContext context, TextTheme t, HomeSummary? s) {
    final medsRatio = (s != null && s.medsTotal > 0)
        ? s.medsTaken / s.medsTotal
        : 1.0;
    final checkedIn = s?.checkedIn ?? false;
    final score =
        (72 + medsRatio * 20 + (checkedIn ? 8 : 0)).round().clamp(0, 100);
    final tag = score >= 90
        ? 'OPTIMAL'
        : score >= 75
            ? 'GOOD'
            : 'STEADY';

    final parts = <String>[];
    if (s == null) {
      parts.add('Loading how your day is going...');
    } else {
      if (s.medsTotal > 0) {
        parts.add(s.medsTaken >= s.medsTotal
            ? "You've taken all your medicines today."
            : '${s.medsTaken} of ${s.medsTotal} medicines taken so far.');
      }
      parts.add(checkedIn
          ? "You've checked in today — thank you!"
          : "Don't forget to check in today.");
      parts.add("It's a perfect day for a light walk!");
    }

    return Container(
      padding: const EdgeInsets.all(SetuSpacing.xl),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 128,
                  height: 128,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor:
                        SetuColors.accentLight.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(
                        SetuColors.accentLight),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score%',
                        style: t.headlineMedium?.copyWith(
                            color: SetuColors.accentLight,
                            fontWeight: FontWeight.w800)),
                    Text(tag,
                        style: const TextStyle(
                            color: SetuColors.mutedLight,
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),
          Text("Today's Health Score",
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: SetuSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: SetuColors.lavenderLight.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome,
                    size: 16, color: SetuColors.lavenderLight),
                const SizedBox(width: 6),
                Text(
                    score >= 75
                        ? 'Everything looks great today.'
                        : 'A little attention would help today.',
                    style: const TextStyle(
                        color: SetuColors.lavenderLight,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(
            parts.join(' '),
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: SetuColors.mutedLight, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _challengeCard(BuildContext context, TextTheme t) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.peachLight.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SetuIconChip(
                icon: Icons.extension_outlined, color: SetuColors.accentLight),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: SetuColors.inkLight,
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('DAILY CHALLENGE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
          ]),
          const SizedBox(height: SetuSpacing.sm),
          Text('Memory Games',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              'Keep your mind sharp with fun visual puzzles designed just for you.',
              style: t.bodyMedium?.copyWith(color: SetuColors.mutedLight, height: 1.4)),
          const SizedBox(height: SetuSpacing.md),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const MemoryGameScreen()),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Play Now'),
          ),
        ],
      ),
    );
  }

  Widget _meditationCard(BuildContext context, TextTheme t) => _simpleCard(
        context,
        t: t,
        tint: SetuColors.lavenderLight,
        icon: Icons.self_improvement,
        title: 'Meditation',
        subtitle: 'Calm your mind for 10 minutes.',
      );

  Widget _walkingCard(BuildContext context, TextTheme t) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.peachDark.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SetuIconChip(
              icon: Icons.directions_walk, color: SetuColors.accentLight, size: 26),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WALKING GOAL',
                    style: TextStyle(
                        color: SetuColors.mutedLight,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Morning Stroll',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('A short walk each day keeps you strong and steady.',
                    style: t.bodyMedium?.copyWith(color: SetuColors.mutedLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyCard(BuildContext context, TextTheme t) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SetuIconChip(
                icon: Icons.menu_book_outlined,
                color: SetuColors.accentLight),
            const SizedBox(width: SetuSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Story Listening',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('Panchatantra, Jataka and more',
                    style: t.bodyMedium?.copyWith(color: SetuColors.mutedLight)),
              ],
            ),
          ]),
          const SizedBox(height: SetuSpacing.md),
          // This used to be "The Golden River · 15 min" behind a play triangle.
          // There was no Golden River and nothing happened when you pressed it.
          // An elder who presses play on a story that does not exist learns
          // that this app is decoration, and that lesson carries straight over
          // to the buttons that matter.
          //
          // It reads rather than plays because no narrator has been recorded
          // yet, and the label says so — a book icon, not a play triangle.
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const StoriesScreen(),
            )),
            child: Container(
              padding: const EdgeInsets.all(SetuSpacing.md),
              decoration: BoxDecoration(
                  color: SetuColors.paperLight,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.auto_stories_outlined,
                    color: SetuColors.accentLight),
                const SizedBox(width: SetuSpacing.sm),
                Expanded(
                    child: Text('Read a folk tale', style: t.bodyMedium)),
                const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simpleCard(BuildContext context,
      {required TextTheme t,
      required Color tint,
      required IconData icon,
      required String title,
      required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        SetuIconChip(icon: icon, color: tint),
        const SizedBox(width: SetuSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(subtitle,
                  style: t.bodyMedium?.copyWith(color: SetuColors.mutedLight)),
            ],
          ),
        ),
      ]),
    );
  }
}
