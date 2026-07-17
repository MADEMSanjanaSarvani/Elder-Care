import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/reminders_repository.dart';

final _remindersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return RemindersRepository(client).fetchPending(elderId);
});

/// Smart Reminder System's one destination screen (PRD Part 5, Batch 2,
/// Module 8 §05: "mostly infrastructure, not a destination screen...a
/// simple in-app list aggregating every pending reminder regardless of
/// which module generated it"). Copy is deliberately plain and
/// non-alarming — a reminder is not an emergency.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(_remindersProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return const SetuEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'Nothing pending',
              message: 'Medicine and appointment reminders will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: reminders.length,
            separatorBuilder: (context, index) => const SizedBox(height: SetuSpacing.sm),
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              final remindAt = DateTime.parse(reminder['remind_at'] as String).toLocal();
              return Card(
                child: ListTile(
                  leading: SetuIconChip(
                      icon: _iconFor(reminder['source_type'] as String)),
                  title: Text(_labelFor(reminder['source_type'] as String)),
                  subtitle: Text(SetuFormat.friendlyTime(remindAt)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.snooze_outlined),
                        tooltip: 'Snooze 1 hour',
                        onPressed: () async {
                          await RemindersRepository(ref.read(supabaseClientProvider))
                              .snooze(reminder['id'] as String, const Duration(hours: 1));
                          ref.invalidate(_remindersProvider(elderId));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Dismiss',
                        onPressed: () async {
                          await RemindersRepository(ref.read(supabaseClientProvider))
                              .dismiss(reminder['id'] as String);
                          ref.invalidate(_remindersProvider(elderId));
                        },
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
      ),
    );
  }
}

IconData _iconFor(String sourceType) {
  switch (sourceType) {
    case 'medication_dose':
      return Icons.medication_outlined;
    case 'appointment':
      return Icons.event_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

String _labelFor(String sourceType) {
  switch (sourceType) {
    case 'medication_dose':
      return 'Time for a dose';
    case 'appointment':
      return 'Upcoming appointment';
    default:
      return 'Reminder';
  }
}

