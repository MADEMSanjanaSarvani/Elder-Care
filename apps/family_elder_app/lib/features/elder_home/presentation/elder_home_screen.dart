import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';

/// Three buttons, not a menu (PRD Part 3 §17). Deliberately not a smaller
/// version of the family dashboard — this is the whole home screen for
/// the elder persona.
class ElderHomeScreen extends ConsumerWidget {
  const ElderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderProfiles = ref.watch(myElderProfilesProvider);
    final textTheme = Theme.of(context).textTheme.scaledForElderMode();

    return elderProfiles.when(
      data: (elders) {
        if (elders.isEmpty) {
          return const Center(child: Text('No elder profile found for this account.'));
        }
        final elder = elders.first; // an elder-mode login always maps to exactly one profile
        return Padding(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hello, ${elder.displayName}', style: textTheme.headlineMedium),
              const SizedBox(height: SetuSpacing.xl),
              _BigActionButton(
                icon: Icons.sos_rounded,
                label: 'Call for Help',
                color: SetuColors.sosLight,
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
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Something went wrong: $err')),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SetuSpacing.xl, horizontal: SetuSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
