import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';

/// Timeline-first dashboard (PRD Part 3 §17). Consent management is a
/// top-level action here, not buried in a settings submenu — hiding it
/// would undercut the platform's whole trust pitch.
class FamilyHomeScreen extends ConsumerWidget {
  const FamilyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderProfiles = ref.watch(myElderProfilesProvider);

    return elderProfiles.when(
      data: (elders) {
        if (elders.isEmpty) {
          return const Center(child: Text('No linked elders yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          itemCount: elders.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: SetuSpacing.md),
          itemBuilder: (context, index) {
            final elder = elders[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(SetuSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(elder.displayName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: SetuSpacing.sm),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/booking'),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Book help'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/consent'),
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: const Text('What you can see'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Something went wrong: $err')),
    );
  }
}
