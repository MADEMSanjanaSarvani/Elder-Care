import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/timeline_repository.dart';

final _timelineEventsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return TimelineRepository(client).fetchEvents(elderId);
});

/// A real activity feed (PRD Part 4, Batch 1, Module 2), not a stub —
/// what shows here is exactly what `elder_timeline_events_select`'s RLS
/// policy already lets this viewer see, so a family member without
/// consent for a category simply never receives those rows.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_timelineEventsProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline')),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('No activity yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: events.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: SetuSpacing.sm),
            itemBuilder: (context, index) {
              final event = events[index];
              final occurredAt =
                  DateTime.parse(event['occurred_at'] as String).toLocal();
              return Card(
                child: ListTile(
                  leading: Icon(_iconFor(event['event_type'] as String)),
                  title: Text(event['summary'] as String),
                  subtitle: Text(_formatTimestamp(occurredAt)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}

IconData _iconFor(String eventType) {
  switch (eventType) {
    case 'visit_scheduled':
      return Icons.event_available_outlined;
    case 'visit_started':
      return Icons.play_circle_outline;
    case 'visit_completed':
      return Icons.check_circle_outline;
    case 'checkin_completed':
      return Icons.self_improvement_outlined;
    case 'checkin_missed':
      return Icons.warning_amber_outlined;
    case 'sos_triggered':
      return Icons.sos_rounded;
    case 'health_note_added':
      return Icons.notes_outlined;
    default:
      return Icons.circle_outlined;
  }
}

String _formatTimestamp(DateTime dt) {
  return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} '
      '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
