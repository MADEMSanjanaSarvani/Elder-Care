import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../checkins/presentation/checkin_button.dart';

/// Big, kind, one-tap (PRD Part 3 §17). The whole home screen for the elder
/// persona — a warm time-of-day greeting and large, calm action tiles, not a
/// shrunken family dashboard.
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
        final greetIcon = hour < 17
            ? Icons.wb_sunny_outlined
            : Icons.nightlight_outlined;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warm greeting
              Row(
                children: [
                  Icon(greetIcon, color: SetuColors.peachLight, size: 30),
                  const SizedBox(width: SetuSpacing.sm),
                  Expanded(
                    child: Text('$greeting,\n${elder.displayName}',
                        style: textTheme.headlineMedium),
                  ),
                ],
              ),
              const SizedBox(height: SetuSpacing.xl),

              // SOS is the tallest, boldest, filled tile.
              _BigActionButton(
                icon: Icons.sos_rounded,
                label: 'Call for Help',
                color: SetuColors.sosLight,
                filled: true,
                onTap: () => context.push('/elder/${elder.id}/sos'),
              ),
              const SizedBox(height: SetuSpacing.md),
              _BigActionButton(
                icon: Icons.add_circle_outline,
                label: 'Book Help',
                color: SetuColors.accentLight,
                onTap: () => context.push('/elder/${elder.id}/booking'),
              ),
              const SizedBox(height: SetuSpacing.md),
              _BigActionButton(
                icon: Icons.event_available_outlined,
                label: "Today's Visit",
                color: SetuColors.verifiedLight,
                onTap: () => context.push('/elder/${elder.id}/booking'),
              ),
              const SizedBox(height: SetuSpacing.md),
              DailyCheckInButton(elderId: elder.id),
              const SizedBox(height: SetuSpacing.md),
              _BigActionButton(
                icon: Icons.chat_bubble_outline,
                label: 'Talk to CareHive',
                color: SetuColors.lavenderLight,
                onTap: () => context.push('/elder/${elder.id}/assistant'),
              ),
            ],
          ),
        );
      },
      loading: () => const SetuLoading(),
      error: (err, stack) => const SetuErrorState(),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      elevation: filled ? 2 : 0,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: filled ? SetuSpacing.xxl : SetuSpacing.xl,
              horizontal: SetuSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: filled ? 46 : 40, color: fg),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: filled ? 26 : 22,
                      fontWeight: FontWeight.w700,
                      color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
