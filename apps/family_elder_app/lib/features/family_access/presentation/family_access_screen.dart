import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/family_access_repository.dart';

final _familyAccessProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return FamilyAccessRepository(client).fetchFamily(elderId);
});

/// Family Member Management (PRD Part 4, Batch 1, Module 4), matching the
/// Stitch "family_circle_permissions" design: rounded member cards with a
/// relationship badge, and a "Manage Permissions" action that opens the
/// real per-category consent screen (`/elder/:elderId/consent`) — the only
/// place permissions actually get toggled, unchanged. A warm "Grow your
/// care circle" card offers the same real invite flow already wired to the
/// FAB.
///
/// The Stitch mock shows specific per-member permission chips ("Full
/// Report Access", "EOS Alerts", "Medicine Tracking"...) inline on each
/// card. Reproducing those honestly would mean fetching every member's
/// real consent grants here too — out of scope for a visual-only pass — so
/// this card links straight to the real consent screen instead of
/// guessing at (or inventing) what each member can see.
///
/// Coordinator toggling is only offered to the elder themself —
/// `family-invite` itself allows any linked family member to invite,
/// matching the Edge Function's own authorization check, but changing
/// `coordinator` is elder/admin-only regardless of what this screen shows
/// (the database trigger is the real enforcement).
class FamilyAccessScreen extends ConsumerWidget {
  const FamilyAccessScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderAsync = ref.watch(elderProfileByIdProvider(elderId));
    final currentUserId =
        ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final familyAsync = ref.watch(_familyAccessProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Care Circle')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context, ref, elderId),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Invite'),
      ),
      body: elderAsync.when(
        data: (elder) {
          final isElderSelf = elder?['auth_user_id'] == currentUserId;
          return familyAsync.when(
            data: (rows) {
              if (rows.isEmpty) {
                return const SetuEmptyState(
                  icon: Icons.group_outlined,
                  title: 'No family linked yet',
                  message: 'Invite a family member to share care access.',
                );
              }
              return ListView(
                padding: const EdgeInsets.all(SetuSpacing.lg),
                children: [
                  Text('Care Circle',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      'Manage who has access to ${elder?['display_name'] ?? 'this'}\'s '
                      'health data and emergency contacts.',
                      style: const TextStyle(color: SetuColors.mutedLight)),
                  const SizedBox(height: SetuSpacing.lg),
                  for (final row in rows) ...[
                    _FamilyMemberCard(
                      row: row,
                      isElderSelf: isElderSelf,
                      elderId: elderId,
                    ),
                    const SizedBox(height: SetuSpacing.md),
                  ],
                  const SizedBox(height: SetuSpacing.sm),
                  _GrowCircleCard(
                      onInvite: () => _showInviteDialog(context, ref, elderId)),
                  const SizedBox(height: 80),
                ],
              );
            },
            loading: () => const SetuLoading(),
            error: (err, stack) => const SetuErrorState(),
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }

  Future<void> _showInviteDialog(
      BuildContext context, WidgetRef ref, String elderId) async {
    final emailController = TextEditingController();
    final relationshipController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite a family member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: SetuSpacing.sm),
            TextField(
              controller: relationshipController,
              decoration:
                  const InputDecoration(labelText: 'Relationship (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send invite')),
        ],
      ),
    );

    if (result != true || emailController.text.trim().isEmpty) return;

    try {
      await FamilyAccessRepository(ref.read(supabaseClientProvider)).invite(
        elderId: elderId,
        inviteeEmail: emailController.text.trim(),
        relationship: relationshipController.text.trim().isEmpty
            ? null
            : relationshipController.text.trim(),
      );
      ref.invalidate(_familyAccessProvider(elderId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invite sent')));
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send invite: $err')));
      }
    }
  }
}

class _FamilyMemberCard extends ConsumerWidget {
  const _FamilyMemberCard({
    required this.row,
    required this.isElderSelf,
    required this.elderId,
  });

  final Map<String, dynamic> row;
  final bool isElderSelf;
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final isCoordinator = row['coordinator'] as bool? ?? false;
    final name = profile?['display_name'] as String? ?? 'Pending invite';
    final relationship = row['relationship'] as String?;
    final status = row['status'] as String;
    final pending = status != 'active';
    final initials = name.trim().isEmpty || name == 'Pending invite'
        ? '?'
        : name
            .trim()
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join();

    return Container(
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SetuColors.lavenderLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(initials,
                    style: const TextStyle(
                        color: SetuColors.lavenderLight,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (relationship != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: SetuColors.accentLight.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(relationship.toUpperCase(),
                                style: const TextStyle(
                                    color: SetuColors.accentLight,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (pending
                                    ? SetuColors.peachLight
                                    : SetuColors.verifiedLight)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(pending ? 'Invited' : 'Active',
                              style: TextStyle(
                                  color: pending
                                      ? SetuColors.peachLight
                                      : SetuColors.verifiedLight,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isElderSelf)
                Column(
                  children: [
                    Switch(
                      value: isCoordinator,
                      onChanged: (value) => FamilyAccessRepository(
                              ref.read(supabaseClientProvider))
                          .setCoordinator(row['id'] as String, value)
                          .then((_) => ref
                              .invalidate(_familyAccessProvider(elderId))),
                    ),
                    const Text('Coordinator',
                        style: TextStyle(
                            fontSize: 10, color: SetuColors.mutedLight)),
                  ],
                )
              else if (isCoordinator)
                const Padding(
                  padding: EdgeInsets.only(left: SetuSpacing.xs),
                  child: Chip(label: Text('Coordinator')),
                ),
            ],
          ),
          if (!pending) ...[
            const SizedBox(height: SetuSpacing.sm),
            Divider(height: 1, color: SetuColors.borderLight),
            const SizedBox(height: SetuSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/elder/$elderId/consent'),
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: const Text('Manage Permissions'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Grow your care circle" invite CTA (matches the Stitch design's warm
/// invite card), wired to the same real invite dialog as the FAB.
class _GrowCircleCard extends StatelessWidget {
  const _GrowCircleCard({required this.onInvite});
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SetuColors.peachLight.withValues(alpha: 0.22),
            SetuColors.accentLight.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.diversity_1_outlined,
              color: SetuColors.accentLight, size: 26),
          const SizedBox(height: SetuSpacing.sm),
          Text('Grow your care circle',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              'Invite more family members or caregivers to stay in the loop '
              'together.',
              style: TextStyle(color: SetuColors.mutedLight, height: 1.4)),
          const SizedBox(height: SetuSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Invite Family Member'),
            ),
          ),
        ],
      ),
    );
  }
}
