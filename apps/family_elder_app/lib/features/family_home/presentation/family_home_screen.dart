import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../checkins/data/checkin_repository.dart';
import '../../suggestions/presentation/suggestions_card.dart';

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
                    SuggestionsCard(elderId: elder.id),
                    FutureBuilder<DateTime?>(
                      future: CheckInRepository(ref.read(supabaseClientProvider))
                          .lastCheckInToday(elder.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final checkedIn = snapshot.data != null;
                        return Row(
                          children: [
                            Icon(
                              checkedIn
                                  ? Icons.check_circle
                                  : Icons.warning_amber_outlined,
                              size: 18,
                              color: checkedIn
                                  ? SetuColors.verifiedLight
                                  : SetuColors.accentLight,
                            ),
                            const SizedBox(width: SetuSpacing.xs),
                            Text(checkedIn
                                ? 'Checked in today'
                                : 'Not checked in today'),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: SetuSpacing.sm),
                    Wrap(
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/booking'),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Book help'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/timeline'),
                          icon: const Icon(Icons.timeline_outlined),
                          label: const Text('Timeline'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/family'),
                          icon: const Icon(Icons.group_outlined),
                          label: const Text('Family'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/medications'),
                          icon: const Icon(Icons.medication_outlined),
                          label: const Text('Medications'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/appointments'),
                          icon: const Icon(Icons.event_outlined),
                          label: const Text('Appointments'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/reminders'),
                          icon: const Icon(Icons.notifications_outlined),
                          label: const Text('Reminders'),
                        ),
                        TextButton.icon(
                          onPressed: () => context
                              .push('/elder/${elder.id}/hospital-stays'),
                          icon: const Icon(Icons.local_hospital_outlined),
                          label: const Text('Hospital stays'),
                        ),
                        TextButton.icon(
                          onPressed: () => context
                              .push('/elder/${elder.id}/health-profile'),
                          icon: const Icon(Icons.favorite_outline),
                          label: const Text('Health profile'),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push(
                              '/elder/${elder.id}/companion-preferences'),
                          icon: const Icon(Icons.diversity_1_outlined),
                          label: const Text('Companion'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/assistant'),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Ask assistant'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/elder/${elder.id}/reports'),
                          icon: const Icon(Icons.summarize_outlined),
                          label: const Text('Weekly reports'),
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
