import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';

/// Elder home rebuilt to the redesign `home_screen_elderly`: a warm greeting,
/// the unmissable red SOS card at the very top, a green daily-wellness card,
/// today's medicines, and a big terracotta "Ask SETU" voice card.
class ElderHomeScreen extends ConsumerWidget {
  const ElderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderProfiles = ref.watch(myElderProfilesProvider);
    final t = Theme.of(context).textTheme.scaledForElderMode();

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
        final first = elder.displayName.trim().split(' ').first;
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : 'Good evening';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome back',
                  style: t.bodyMedium?.copyWith(color: SetuColors.mutedLight)),
              Text('$greeting, $first',
                  style: t.headlineMedium?.copyWith(
                      color: SetuColors.accentLight,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: SetuSpacing.lg),

              // The hero: a big red SOS card.
              _SosCard(
                  onTap: () => context.push('/elder/${elder.id}/sos'), t: t),
              const SizedBox(height: SetuSpacing.lg),

              // Daily wellness (green).
              _WellnessCard(
                  name: first,
                  onTap: () => context.push('/elder/${elder.id}/wellness'),
                  t: t),
              const SizedBox(height: SetuSpacing.lg),

              Row(
                children: [
                  Text('Medicines Today',
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        context.push('/elder/${elder.id}/medications'),
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: SetuSpacing.sm),
              _MedRow(
                  icon: Icons.medication_rounded,
                  tint: SetuColors.peachLight,
                  name: 'Your medicines',
                  detail: 'Tap "See All" for today\'s schedule',
                  t: t,
                  onTap: () => context.push('/elder/${elder.id}/medications')),
              const SizedBox(height: SetuSpacing.lg),

              // Ask SETU (terracotta).
              _AskSetuCard(
                  onTap: () => context.push('/elder/${elder.id}/assistant'),
                  t: t),
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

class _SosCard extends StatelessWidget {
  const _SosCard({required this.onTap, required this.t});
  final VoidCallback onTap;
  final TextTheme t;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: SetuColors.sosLight,
      borderRadius: BorderRadius.circular(24),
      elevation: 3,
      shadowColor: SetuColors.sosLight.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: SetuSpacing.xl, horizontal: SetuSpacing.lg),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.priority_high,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(height: SetuSpacing.md),
              Text('SOS HELP',
                  style: t.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              Text('Press for immediate assistance',
                  style: t.bodyMedium?.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WellnessCard extends StatelessWidget {
  const _WellnessCard(
      {required this.name, required this.onTap, required this.t});
  final String name;
  final VoidCallback onTap;
  final TextTheme t;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: SetuColors.verifiedLight.withValues(alpha: 0.18),
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
                    color: SetuColors.paperRaisedLight,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.directions_walk,
                    color: SetuColors.verifiedLight, size: 28),
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Wellness',
                        style:
                            t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text('A short walk each day keeps you strong, $name.',
                        style: t.bodyMedium
                            ?.copyWith(color: SetuColors.mutedLight)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedRow extends StatelessWidget {
  const _MedRow({
    required this.icon,
    required this.tint,
    required this.name,
    required this.detail,
    required this.t,
    required this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String name;
  final String detail;
  final TextTheme t;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: SetuColors.paperRaisedLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.18),
                    shape: BoxShape.circle),
                child: Icon(icon, color: tint, size: 24),
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(detail,
                        style: t.bodyMedium
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

class _AskSetuCard extends StatelessWidget {
  const _AskSetuCard({required this.onTap, required this.t});
  final VoidCallback onTap;
  final TextTheme t;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.xl),
      decoration: BoxDecoration(
        color: SetuColors.accentLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Need help? Just ask.',
              style: t.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: SetuSpacing.sm),
          Text('"Hey SETU, what time is my doctor\'s appointment?"',
              style: t.bodyMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: SetuSpacing.lg),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SetuSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ask SETU',
                        style: t.titleLarge?.copyWith(
                            color: SetuColors.accentLight,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: SetuSpacing.sm),
                    const Icon(Icons.mic, color: SetuColors.accentLight),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
