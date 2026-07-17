import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../checkins/data/checkin_repository.dart';
import '../../suggestions/presentation/suggestions_card.dart';

/// Timeline-first dashboard (PRD Part 3 §17). Redesigned to the CareHive
/// design system: an avatar header, a friendly "Today" status card, a clean
/// grid of the primary actions, and everything secondary tucked under
/// "More" — clarity over density. Consent/privacy stay one tap away (trust
/// is a feature, not a buried setting).
class FamilyHomeScreen extends ConsumerWidget {
  const FamilyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderProfiles = ref.watch(myElderProfilesProvider);

    return elderProfiles.when(
      data: (elders) {
        if (elders.isEmpty) return const _NoElders();
        return ListView(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          children: [
            for (final elder in elders) ...[
              _ElderCard(elder: elder),
              const SizedBox(height: SetuSpacing.lg),
            ],
            OutlinedButton.icon(
              onPressed: () => showAddElderDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add another person'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Something went wrong: $err')),
    );
  }
}

/// Family onboarding: create the elder you care for and link yourself, via
/// the family-add-elder function (RLS blocks the direct client path).
Future<void> showAddElderDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final relationshipController = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add someone you care for'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
                labelText: 'Their name', hintText: 'e.g. Lakshmi'),
          ),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: relationshipController,
            decoration: const InputDecoration(
                labelText: 'Relationship (optional)',
                hintText: 'e.g. Mother'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add')),
      ],
    ),
  );

  if (submitted != true || nameController.text.trim().isEmpty) return;

  try {
    final client = ref.read(supabaseClientProvider);
    final response = await client.functions.invoke('family-add-elder', body: {
      'display_name': nameController.text.trim(),
      'relationship': relationshipController.text.trim(),
    });
    if (response.status != 201) {
      throw StateError('${response.data}');
    }
    ref.invalidate(myElderProfilesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${nameController.text.trim()} added.')),
      );
    }
  } catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add: $err')),
      );
    }
  }
}

class _NoElders extends ConsumerWidget {
  const _NoElders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.family_restroom,
                size: 56, color: SetuColors.mutedLight),
            const SizedBox(height: SetuSpacing.md),
            Text('No one added yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SetuSpacing.xs),
            const Text(
              'Add the parent or elder you care for to see their day at a glance.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SetuSpacing.lg),
            FilledButton.icon(
              onPressed: () => showAddElderDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add someone you care for'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElderCard extends ConsumerStatefulWidget {
  const _ElderCard({required this.elder});

  final ElderProfile elder;

  @override
  ConsumerState<_ElderCard> createState() => _ElderCardState();
}

class _ElderCardState extends ConsumerState<_ElderCard> {
  bool _showMore = false;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final elder = widget.elder;
    final id = elder.id;

    const primary = <_Action>[
      _Action(Icons.add_circle_outline, 'Book help', 'booking'),
      _Action(Icons.timeline_outlined, 'Timeline', 'timeline'),
      _Action(Icons.medication_outlined, 'Medicines', 'medications'),
      _Action(Icons.event_outlined, 'Appointments', 'appointments'),
      _Action(Icons.card_membership_outlined, 'Care plans', 'care-plans'),
      _Action(Icons.chat_bubble_outline, 'Ask assistant', 'assistant'),
    ];
    const more = <_Action>[
      _Action(Icons.notifications_outlined, 'Reminders', 'reminders'),
      _Action(Icons.local_hospital_outlined, 'Hospital stays', 'hospital-stays'),
      _Action(Icons.favorite_outline, 'Health profile', 'health-profile'),
      _Action(Icons.diversity_1_outlined, 'Companion', 'companion-preferences'),
      _Action(Icons.summarize_outlined, 'Weekly reports', 'reports'),
      _Action(Icons.star_outline, 'Rate a visit', 'rate'),
      _Action(Icons.group_outlined, 'Family access', 'family'),
      _Action(Icons.privacy_tip_outlined, 'What you can see', 'consent'),
      _Action(Icons.shield_outlined, 'Privacy centre', 'privacy'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      SetuColors.accentLight.withValues(alpha: 0.15),
                  child: Text(_initials(elder.displayName),
                      style: const TextStyle(
                          color: SetuColors.accentLight,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: SetuSpacing.md),
                Expanded(
                  child: Text(elder.displayName,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: SetuSpacing.md),
            // Today card: check-in status
            FutureBuilder<DateTime?>(
              future: CheckInRepository(ref.read(supabaseClientProvider))
                  .lastCheckInToday(id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 4);
                }
                final checkedIn = snapshot.data != null;
                final color = checkedIn
                    ? SetuColors.verifiedLight
                    : SetuColors.accentLight;
                return Container(
                  padding: const EdgeInsets.all(SetuSpacing.md),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          checkedIn
                              ? Icons.check_circle
                              : Icons.wb_sunny_outlined,
                          color: color),
                      const SizedBox(width: SetuSpacing.sm),
                      Expanded(
                        child: Text(
                          checkedIn
                              ? 'Checked in today — all good.'
                              : "Hasn't checked in today yet.",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: SetuSpacing.md),
            SuggestionsCard(elderId: id),
            const SizedBox(height: SetuSpacing.md),
            // Primary actions grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: SetuSpacing.sm,
              crossAxisSpacing: SetuSpacing.sm,
              childAspectRatio: 0.92,
              children: [
                for (final a in primary)
                  _ActionTile(action: a, elderId: id),
              ],
            ),
            // More (collapsed)
            const SizedBox(height: SetuSpacing.xs),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _showMore = !_showMore),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SetuSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_showMore ? 'Show less' : 'More',
                        style: const TextStyle(
                            color: SetuColors.accentLight,
                            fontWeight: FontWeight.w600)),
                    Icon(
                        _showMore
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: SetuColors.accentLight),
                  ],
                ),
              ),
            ),
            if (_showMore)
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: SetuSpacing.sm,
                crossAxisSpacing: SetuSpacing.sm,
                childAspectRatio: 0.92,
                children: [
                  for (final a in more) _ActionTile(action: a, elderId: id),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Action {
  const _Action(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.elderId});

  final _Action action;
  final String elderId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/elder/$elderId/${action.route}'),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SetuColors.borderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(SetuSpacing.sm),
              decoration: BoxDecoration(
                color: SetuColors.accentLight.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: SetuColors.accentLight, size: 22),
            ),
            const SizedBox(height: SetuSpacing.xs),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}
