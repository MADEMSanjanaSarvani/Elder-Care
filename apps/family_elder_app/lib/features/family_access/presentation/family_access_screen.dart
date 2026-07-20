import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/family_access_repository.dart';

final _familyAccessProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return FamilyAccessRepository(client).fetchFamily(elderId);
});

/// Family Member Management (PRD Part 4, Batch 1, Module 4). Coordinator
/// toggling is only offered to the elder themself — `family-invite` itself
/// allows any linked family member to invite, matching the Edge
/// Function's own authorization check, but changing `coordinator` is
/// elder/admin-only regardless of what this screen shows (the database
/// trigger is the real enforcement).
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
      appBar: AppBar(title: const Text('Family')),
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
              return ListView.separated(
                padding: const EdgeInsets.all(SetuSpacing.lg),
                itemCount: rows.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: SetuSpacing.sm),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final profile = row['profiles'] as Map<String, dynamic>?;
                  final isCoordinator = row['coordinator'] as bool? ?? false;
                  final name =
                      profile?['display_name'] as String? ?? 'Pending invite';
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
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: SetuColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                SetuColors.lavenderLight.withValues(alpha: 0.15),
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
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (relationship != null) ...[
                                    Text(relationship,
                                        style: const TextStyle(
                                            color: SetuColors.mutedLight,
                                            fontSize: 13)),
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
                                    .then((_) => ref.invalidate(
                                        _familyAccessProvider(elderId))),
                              ),
                              const Text('Coordinator',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: SetuColors.mutedLight)),
                            ],
                          )
                        else if (isCoordinator)
                          const Chip(label: Text('Coordinator')),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const SetuLoading(),
            error: (err, stack) =>
                const SetuErrorState(),
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
