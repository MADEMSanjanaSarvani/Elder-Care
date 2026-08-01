import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/hospital_stays_repository.dart';

final _staysProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return HospitalStaysRepository(client).fetchStays(elderId);
});

/// A record of hospital admissions.
///
/// This screen used to be a scheduling board for paid companion shifts — book
/// a sitter, link the booking, watch the roster. None of that exists now. What
/// is left is the part a doctor actually asks about: was this person in
/// hospital, which one, and when. It sits alongside the medicine record for
/// the same reason the medicine record exists — because somebody will be asked
/// the question months later and will not remember.
class HospitalStaysScreen extends ConsumerWidget {
  const HospitalStaysScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staysAsync = ref.watch(_staysProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Hospital stays')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateStayDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New stay'),
      ),
      body: staysAsync.when(
        data: (stays) {
          if (stays.isEmpty) {
            return const SetuEmptyState(
              icon: Icons.local_hospital_outlined,
              title: 'No hospital stays',
              message: 'If a hospital admission comes up, note it here so it '
                  'is on the record later.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: stays.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: SetuSpacing.md),
            itemBuilder: (context, index) =>
                _StayCard(elderId: elderId, stay: stays[index]),
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }

  Future<void> _showCreateStayDialog(BuildContext context, WidgetRef ref) async {
    final hospitalController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New hospital stay'),
        content: TextField(
          controller: hospitalController,
          decoration: const InputDecoration(labelText: 'Hospital name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create')),
        ],
      ),
    );
    if (result != true || hospitalController.text.trim().isEmpty) return;

    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await HospitalStaysRepository(client).createStay(
        elderId: elderId,
        hospitalName: hospitalController.text.trim(),
        createdBy: userId,
      );
      ref.invalidate(_staysProvider(elderId));
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create stay: $err')));
      }
    }
  }
}

class _StayCard extends ConsumerWidget {
  const _StayCard({required this.elderId, required this.stay});

  final String elderId;
  final Map<String, dynamic> stay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stayId = stay['id'] as String;
    final status = stay['status'] as String;
    final active = status == 'active';
    final admissionAt = DateTime.parse(stay['admission_at'] as String).toLocal();
    final dischargeAt = stay['actual_discharge_at'] != null
        ? DateTime.parse(stay['actual_discharge_at'] as String).toLocal()
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_hospital_outlined,
                    color:
                        active ? SetuColors.accentLight : SetuColors.mutedLight),
                const SizedBox(width: SetuSpacing.sm),
                Expanded(
                  child: Text(stay['hospital_name'] as String,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(label: Text(status)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: SetuSpacing.xs),
              child: Text(
                dischargeAt == null
                    ? 'Admitted ${_formatDate(admissionAt)}'
                    : 'Admitted ${_formatDate(admissionAt)} · discharged '
                        '${_formatDate(dischargeAt)}',
                style: const TextStyle(color: SetuColors.mutedLight),
              ),
            ),
            if (active) ...[
              const SizedBox(height: SetuSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _discharge(context, ref, stayId),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Mark discharged'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _discharge(
      BuildContext context, WidgetRef ref, String stayId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark discharged?'),
        content: const Text('This closes the stay and stamps today as the '
            'discharge date.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Mark discharged')),
        ],
      ),
    );
    if (confirmed != true) return;
    final client = ref.read(supabaseClientProvider);
    await HospitalStaysRepository(client).markDischarged(stayId);
    ref.invalidate(_staysProvider(elderId));
  }
}

String _formatDate(DateTime dt) {
  return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)}';
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
