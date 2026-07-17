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
                  return Card(
                    child: ListTile(
                      title: Text(
                          profile?['display_name'] as String? ?? 'Pending invite'),
                      subtitle: Text([
                        if (row['relationship'] != null) row['relationship'] as String,
                        row['status'] as String,
                      ].join(' · ')),
                      trailing: isElderSelf
                          ? Switch(
                              value: isCoordinator,
                              onChanged: (value) => FamilyAccessRepository(
                                      ref.read(supabaseClientProvider))
                                  .setCoordinator(row['id'] as String, value)
                                  .then((_) => ref.invalidate(
                                      _familyAccessProvider(elderId))),
                            )
                          : isCoordinator
                              ? const Chip(label: Text('Coordinator'))
                              : null,
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
