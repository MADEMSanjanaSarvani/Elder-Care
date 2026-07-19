import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../checkins/presentation/checkin_button.dart';

/// Big, kind, one-tap (PRD Part 3 §17), matched to the Stitch "Elder Home"
/// design: a warm peach greeting, a prominent lavender AI companion card, a
/// gentle medicines reminder, and the unmissable red SOS button.
class ElderHomeScreen extends ConsumerWidget {
  const ElderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderProfiles = ref.watch(myElderProfilesProvider);
    final textTheme = Theme.of(context).textTheme.scaledForElderMode();

    return elderProfiles.when(
      data: (elders) {
        if (elders.isEmpty) {
          return const SetuEmptyState(
            icon: Icons.elderly,
            title: 'Setting up your profile',
            message: 'Ask your family to add you, then sign in again.',
          );
        }
        final elder = elders.first;
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : 'Good evening';
        final firstName = elder.displayName.trim().split(' ').first;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warm peach greeting card.
              Container(
                padding: const EdgeInsets.all(SetuSpacing.xl),
                decoration: BoxDecoration(
                  color: SetuColors.peachLight.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting,\n$firstName.',
                        style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800, height: 1.15)),
                    const SizedBox(height: SetuSpacing.sm),
                    Text("It's a beautiful day.",
                        style: textTheme.titleMedium
                            ?.copyWith(color: SetuColors.mutedLight)),
                  ],
                ),
              ),
              const SizedBox(height: SetuSpacing.lg),

              // Big lavender "Talk to AI Assistant" card.
              _AiCompanionCard(
                onTap: () => context.push('/elder/${elder.id}/assistant'),
                textTheme: textTheme,
              ),
              const SizedBox(height: SetuSpacing.lg),

              // Gentle daily check-in.
              DailyCheckInButton(elderId: elder.id),
              const SizedBox(height: SetuSpacing.md),

              // Medicines reminder card.
              _TileCard(
                icon: Icons.medication_rounded,
                tint: SetuColors.accentLight,
                title: 'My medicines',
                subtitle: 'See what to take and when',
                textTheme: textTheme,
                onTap: () => context.push('/elder/${elder.id}/medications'),
              ),
              const SizedBox(height: SetuSpacing.md),
              _TileCard(
                icon: Icons.event_available_outlined,
                tint: SetuColors.verifiedLight,
                title: "Today's visit",
                subtitle: 'Your caregiver and appointments',
                textTheme: textTheme,
                onTap: () => context.push('/elder/${elder.id}/booking'),
              ),
              const SizedBox(height: SetuSpacing.md),
              _TileCard(
                icon: Icons.spa_outlined,
                tint: SetuColors.lavenderLight,
                title: 'Wellness & activities',
                subtitle: 'Games, meditation, stories and your day',
                textTheme: textTheme,
                onTap: () => context.push('/elder/${elder.id}/wellness'),
              ),
              const SizedBox(height: SetuSpacing.xl),

              // The unmissable SOS pill.
              _SosButton(
                onTap: () => context.push('/elder/${elder.id}/sos'),
                textTheme: textTheme,
              ),
              const SizedBox(height: SetuSpacing.md),
            ],
          ),
        );
      },
      loading: () => const SetuLoading(),
      error: (err, stack) => const SetuErrorState(),
    );
  }
}

class _AiCompanionCard extends StatelessWidget {
  const _AiCompanionCard({required this.onTap, required this.textTheme});
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SetuColors.lavenderLight.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SetuColors.paperLight.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_none_rounded,
                      color: SetuColors.lavenderLight, size: 26),
                ),
              ),
              const SizedBox(height: SetuSpacing.lg),
              Text('Talk to AI Assistant',
                  style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: SetuColors.inkLight)),
              const SizedBox(height: 4),
              Text('"How are you feeling today?"',
                  style: textTheme.titleMedium
                      ?.copyWith(color: SetuColors.mutedLight)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileCard extends StatelessWidget {
  const _TileCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.textTheme,
    required this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SetuColors.paperRaisedLight,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    shape: BoxShape.circle),
                child: Icon(icon, color: tint, size: 30),
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: SetuColors.mutedLight)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap, required this.textTheme});
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SetuColors.sosLight,
      borderRadius: BorderRadius.circular(999),
      elevation: 3,
      shadowColor: SetuColors.sosLight.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SetuSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sos_rounded, color: Colors.white, size: 36),
              const SizedBox(width: SetuSpacing.md),
              Text('SOS',
                  style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
