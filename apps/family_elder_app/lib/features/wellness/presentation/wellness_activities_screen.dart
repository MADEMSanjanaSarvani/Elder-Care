import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

/// Elder Wellness Activities — a warm daily engagement hub (matched to the
/// Stitch "Elder Wellness Activities" design): a health-score ring, a daily
/// brain-game challenge, meditation, a walking goal, and story listening.
/// Content is gentle and encouraging by design; the deeper data hooks (real
/// step counts, AI story picks) layer in later without changing this layout.
class WellnessActivitiesScreen extends StatelessWidget {
  const WellnessActivitiesScreen({required this.elderId, super.key});
  final String elderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wellness')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          _healthScore(context),
          const SizedBox(height: SetuSpacing.lg),
          _challengeCard(context),
          const SizedBox(height: SetuSpacing.md),
          _meditationCard(context),
          const SizedBox(height: SetuSpacing.md),
          _walkingCard(context),
          const SizedBox(height: SetuSpacing.md),
          _storyCard(context),
          const SizedBox(height: SetuSpacing.md),
          _aiPromptCard(context),
        ],
      ),
    );
  }

  Widget _healthScore(BuildContext context) {
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
                    value: 0.95,
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
                    Text('95%',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: SetuColors.accentLight,
                            fontWeight: FontWeight.w800)),
                    const Text('OPTIMAL',
                        style: TextStyle(
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
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: SetuSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: SetuColors.lavenderLight.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome,
                    size: 16, color: SetuColors.lavenderLight),
                SizedBox(width: 6),
                Text('Everything looks great today.',
                    style: TextStyle(
                        color: SetuColors.lavenderLight,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.sm),
          const Text(
            "Your vitals are stable, and you've had a restful sleep. It's a "
            'perfect day for a light walk!',
            textAlign: TextAlign.center,
            style: TextStyle(color: SetuColors.mutedLight, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _challengeCard(BuildContext context) {
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
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              'Keep your mind sharp with fun visual puzzles designed just for you.',
              style: TextStyle(color: SetuColors.mutedLight, height: 1.4)),
          const SizedBox(height: SetuSpacing.md),
          FilledButton.icon(
            onPressed: () => _soon(context),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Play Now'),
          ),
        ],
      ),
    );
  }

  Widget _meditationCard(BuildContext context) => _simpleCard(
        context,
        tint: SetuColors.lavenderLight,
        icon: Icons.self_improvement,
        title: 'Meditation',
        subtitle: 'Calm your mind for 10 minutes.',
      );

  Widget _walkingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.peachDark.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('WALKING\nGOAL',
                  style: TextStyle(
                      color: SetuColors.mutedLight,
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      height: 1.2)),
              const SizedBox(width: SetuSpacing.md),
              Text('1,240 / 3k steps',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: SetuSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 1240 / 3000,
              minHeight: 8,
              backgroundColor: SetuColors.paperLight,
              valueColor:
                  const AlwaysStoppedAnimation(SetuColors.accentLight),
            ),
          ),
          const SizedBox(height: SetuSpacing.md),
          Text('Morning Stroll',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const Text('Track your progress and enjoy the fresh air.',
              style: TextStyle(color: SetuColors.mutedLight)),
        ],
      ),
    );
  }

  Widget _storyCard(BuildContext context) {
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Text('Traditional Folklore',
                    style: TextStyle(color: SetuColors.mutedLight)),
              ],
            ),
          ]),
          const SizedBox(height: SetuSpacing.md),
          Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
                color: SetuColors.paperLight,
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.play_circle_outline,
                  color: SetuColors.accentLight),
              const SizedBox(width: SetuSpacing.sm),
              const Expanded(child: Text('The Golden River')),
              const Text('15 min',
                  style: TextStyle(
                      color: SetuColors.mutedLight, fontSize: 12.5)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _aiPromptCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.lavenderLight.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: SetuColors.paperLight.withValues(alpha: 0.7),
                shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined,
                color: SetuColors.lavenderLight),
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    '"Would you like to hear your favourite story from yesterday?"',
                    style: TextStyle(height: 1.4, fontWeight: FontWeight.w600)),
                const SizedBox(height: SetuSpacing.sm),
                Row(children: [
                  FilledButton(
                      onPressed: () => _soon(context),
                      child: const Text('Yes, please')),
                  const SizedBox(width: SetuSpacing.sm),
                  OutlinedButton(
                      onPressed: () => _soon(context),
                      child: const Text('Not now')),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _simpleCard(BuildContext context,
      {required Color tint,
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(subtitle,
                  style: const TextStyle(color: SetuColors.mutedLight)),
            ],
          ),
        ),
      ]),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon in your next update.')),
    );
  }
}
