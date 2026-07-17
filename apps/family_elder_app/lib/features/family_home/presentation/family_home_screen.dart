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

/// First-run welcome. Rather than a bare empty state, this explains what
/// CareHive is for a brand-new family member and invites them to begin — so
/// the very first screen after sign-in teaches the idea and feels warm.
class _NoElders extends ConsumerWidget {
  const _NoElders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const features = <List<dynamic>>[
      [Icons.volunteer_activism_outlined, SetuColors.accentLight, 'Trusted caregivers',
        'Book background-verified helpers for visits, nursing and companionship.'],
      [Icons.medication_outlined, SetuColors.peachLight, 'Medicines & refills',
        'Track every dose and get a nudge before medicines run low.'],
      [Icons.favorite_outline, SetuColors.lavenderLight, 'Daily check-ins',
        'A gentle "I\'m okay today" from your parent, so you never wonder.'],
      [Icons.chat_bubble_outline, SetuColors.lavenderLight, 'AI companion',
        'Someone for them to talk to, plus warm weekly wellbeing updates.'],
      [Icons.sos_outlined, SetuColors.sosLight, 'Emergency SOS',
        'One tap calls for help and alerts your whole family at once.'],
      [Icons.timeline_outlined, SetuColors.accentLight, 'Health & timeline',
        'Every visit, appointment and update gathered in one calm place.'],
    ];

    return ListView(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      children: [
        const SizedBox(height: SetuSpacing.sm),
        Center(
          child: Container(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            decoration: BoxDecoration(
              color: SetuColors.accentLight.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.holiday_village_outlined,
                size: 44, color: SetuColors.accentLight),
          ),
        ),
        const SizedBox(height: SetuSpacing.md),
        Text('Welcome to CareHive',
            textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        const SizedBox(height: SetuSpacing.xs),
        Text(
          'A warm, simple way to look after your parents — together, from '
          'anywhere. Here\'s everything CareHive does for your family.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: SetuColors.mutedLight, height: 1.5),
        ),
        const SizedBox(height: SetuSpacing.lg),

        // Start-here card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Let\'s begin', style: theme.textTheme.titleLarge),
                const SizedBox(height: SetuSpacing.xs),
                Text(
                  'Add the parent or elder you care for to unlock their '
                  'dashboard — bookings, medicines, check-ins and more.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: SetuColors.mutedLight),
                ),
                const SizedBox(height: SetuSpacing.md),
                FilledButton.icon(
                  onPressed: () => showAddElderDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add someone you care for'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SetuSpacing.xl),

        Text('What you can do', style: theme.textTheme.titleLarge),
        const SizedBox(height: SetuSpacing.sm),
        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(SetuSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SetuIconChip(icon: f[0] as IconData, color: f[1] as Color),
                    const SizedBox(width: SetuSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f[2] as String,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(f[3] as String,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: SetuColors.mutedLight, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: SetuSpacing.lg),
      ],
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
