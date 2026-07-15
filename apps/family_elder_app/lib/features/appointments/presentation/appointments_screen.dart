import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/appointments_repository.dart';

final _appointmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return AppointmentsRepository(client).fetchAppointments(elderId);
});

/// Appointment Management (PRD Part 5, Batch 2, Module 7). Plain
/// chronological list, not a calendar grid — the PRD's own accessibility
/// call: a calendar is often harder to parse than a simple ordered list
/// for lower digital literacy or visual impairment.
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(_appointmentsProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAppointmentDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add appointment'),
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          if (appointments.isEmpty) {
            return const Center(child: Text('No appointments tracked yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: appointments.length,
            separatorBuilder: (context, index) => const SizedBox(height: SetuSpacing.sm),
            itemBuilder: (context, index) {
              final appt = appointments[index];
              final scheduledAt = DateTime.parse(appt['scheduled_at'] as String).toLocal();
              final status = appt['status'] as String;
              return Card(
                child: ListTile(
                  leading: Icon(
                    status == 'completed'
                        ? Icons.check_circle_outline
                        : status == 'cancelled'
                            ? Icons.cancel_outlined
                            : Icons.event_outlined,
                    color: status == 'cancelled' ? SetuColors.mutedLight : null,
                  ),
                  title: Text(appt['title'] as String),
                  subtitle: Text([
                    _formatDate(scheduledAt),
                    if (appt['location'] != null) appt['location'] as String,
                  ].join(' · ')),
                  trailing: appt['related_booking_id'] != null
                      ? const Tooltip(message: 'Companion booked', child: Icon(Icons.groups_outlined, size: 18))
                      : null,
                  onTap: status == 'scheduled'
                      ? () => _showOptionsDialog(context, ref, appt)
                      : null,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }

  Future<void> _showOptionsDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> appt) async {
    final repo = AppointmentsRepository(ref.read(supabaseClientProvider));
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(appt['title'] as String),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('companion'),
            child: const Text('Book a companion for this'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('outcome'),
            child: const Text('Log outcome (mark completed)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );

    if (action == 'companion' && context.mounted) {
      context.push('/elder/$elderId/booking');
      return;
    }
    if (action == 'cancel') {
      await repo.cancel(appt['id'] as String);
      ref.invalidate(_appointmentsProvider(elderId));
      return;
    }
    if (action == 'outcome' && context.mounted) {
      final noteController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Outcome note'),
          content: TextField(controller: noteController, maxLines: 3),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      );
      if (confirmed == true) {
        await repo.logOutcome(appt['id'] as String, noteController.text.trim());
        ref.invalidate(_appointmentsProvider(elderId));
      }
    }
  }

  Future<void> _showAddAppointmentDialog(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime scheduledAt = DateTime.now().add(const Duration(days: 1));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Doctor / reason')),
              const SizedBox(height: SetuSpacing.sm),
              TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
              const SizedBox(height: SetuSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_formatDate(scheduledAt)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: scheduledAt,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => scheduledAt = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (result != true || titleController.text.trim().isEmpty) return;

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    try {
      await AppointmentsRepository(ref.read(supabaseClientProvider)).createAppointment(
        elderId: elderId,
        title: titleController.text.trim(),
        location: locationController.text.trim(),
        scheduledAt: scheduledAt,
        createdBy: userId,
      );
      ref.invalidate(_appointmentsProvider(elderId));
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add appointment: $err')));
      }
    }
  }
}

String _formatDate(DateTime dt) {
  return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)}';
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
