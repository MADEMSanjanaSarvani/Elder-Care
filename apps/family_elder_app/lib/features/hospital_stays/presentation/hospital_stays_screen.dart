import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/hospital_stays_repository.dart';

final _staysProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return HospitalStaysRepository(client).fetchStays(elderId);
});

final _shiftsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, stayId) async {
  final client = ref.watch(supabaseClientProvider);
  return HospitalStaysRepository(client).fetchShifts(stayId);
});

/// Hospital Companion Services (PRD Part 6, Batch 3, Module 11): a stay
/// is a grouping lens over individual hospital_companion bookings, which
/// still appear in the normal bookings flow too. Booking a new shift
/// deep-links into the existing, unmodified booking screen.
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
              message: 'If a stay comes up, track it here to arrange companions.',
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong: $err')),
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
    final shiftsAsync = ref.watch(_shiftsProvider(stayId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_hospital_outlined,
                    color: active ? SetuColors.accentLight : SetuColors.mutedLight),
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
              child: Text('Admitted ${_formatDate(admissionAt)}'),
            ),
            const SizedBox(height: SetuSpacing.sm),
            shiftsAsync.when(
              data: (shifts) {
                if (shifts.isEmpty) {
                  return const Text('No shifts linked yet.',
                      style: TextStyle(fontStyle: FontStyle.italic));
                }
                final sorted = [...shifts]..sort((a, b) {
                    final aAt = (a['bookings'] as Map<String, dynamic>?)?['scheduled_at'] as String? ?? '';
                    final bAt = (b['bookings'] as Map<String, dynamic>?)?['scheduled_at'] as String? ?? '';
                    return aAt.compareTo(bAt);
                  });
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sorted.map((shift) {
                    final booking = shift['bookings'] as Map<String, dynamic>?;
                    final scheduledAt = booking?['scheduled_at'] != null
                        ? DateTime.parse(booking!['scheduled_at'] as String).toLocal()
                        : null;
                    final note = shift['shift_note'] as String?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: SetuSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.schedule_outlined, size: 16),
                          const SizedBox(width: SetuSpacing.xs),
                          Expanded(
                            child: Text([
                              if (scheduledAt != null) _formatDate(scheduledAt),
                              booking?['status'] as String? ?? '',
                              if (note != null && note.isNotEmpty) '— $note',
                            ].join(' ')),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, stack) => Text('Could not load shifts: $err'),
            ),
            if (active) ...[
              const SizedBox(height: SetuSpacing.sm),
              Wrap(
                spacing: SetuSpacing.sm,
                children: [
                  TextButton.icon(
                    onPressed: () => context.push('/elder/$elderId/booking'),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Book a shift'),
                  ),
                  TextButton.icon(
                    onPressed: () => _linkShift(context, ref, stayId),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Link a booking'),
                  ),
                  TextButton.icon(
                    onPressed: () => _discharge(context, ref, stayId),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Mark discharged'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _linkShift(BuildContext context, WidgetRef ref, String stayId) async {
    final client = ref.read(supabaseClientProvider);
    final repo = HospitalStaysRepository(client);
    final linkable = await repo.fetchLinkableBookings(elderId);
    if (!context.mounted) return;
    if (linkable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No unlinked hospital companion bookings — book a shift first.')));
      return;
    }
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Link a booking to this stay'),
        children: linkable.map((b) {
          final scheduledAt = DateTime.parse(b['scheduled_at'] as String).toLocal();
          return SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(b['id'] as String),
            child: Text('${_formatDate(scheduledAt)} · ${b['status']}'),
          );
        }).toList(),
      ),
    );
    if (chosen == null) return;
    await repo.linkBooking(stayId, chosen);
    ref.invalidate(_shiftsProvider(stayId));
  }

  Future<void> _discharge(BuildContext context, WidgetRef ref, String stayId) async {
    final client = ref.read(supabaseClientProvider);
    final repo = HospitalStaysRepository(client);

    // PRD §13: a still-scheduled shift prompts confirmation, never an
    // automatic cancel — the shift bookings themselves are left alone.
    final shifts = await repo.fetchShifts(stayId);
    final upcoming = shifts.where((s) {
      final status = (s['bookings'] as Map<String, dynamic>?)?['status'] as String?;
      return status != null && ['requested', 'matched', 'confirmed'].contains(status);
    }).length;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark discharged?'),
        content: Text(upcoming > 0
            ? '$upcoming shift(s) are still scheduled. They will NOT be cancelled automatically — cancel them separately if no longer needed.'
            : 'This closes the stay.'),
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
    await repo.markDischarged(stayId);
    ref.invalidate(_staysProvider(elderId));
  }
}

String _formatDate(DateTime dt) {
  return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)}';
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
