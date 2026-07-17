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

/// A real activity feed (PRD Part 4, Batch 1, Module 2). What shows here is
/// exactly what the RLS policy lets this viewer see — a family member without
/// consent for a category simply never receives those rows. Presented as a
/// colour-coded feed so "all good" and "needs attention" read at a glance.
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
            return const _EmptyTimeline();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_timelineEventsProvider(elderId));
              await ref.read(_timelineEventsProvider(elderId).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              itemCount: events.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: SetuSpacing.sm),
              itemBuilder: (context, index) =>
                  _TimelineRow(event: events[index]),
            ),
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) =>
            const SetuErrorState(),
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timeline_outlined,
                size: 56, color: SetuColors.mutedLight),
            const SizedBox(height: SetuSpacing.md),
            Text('Nothing here yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SetuSpacing.xs),
            const Text('Visits, check-ins and updates will appear here.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final type = event['event_type'] as String;
    final occurredAt =
        DateTime.parse(event['occurred_at'] as String).toLocal();
    final color = _colorFor(type);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(SetuSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(type), color: color, size: 20),
            ),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event['summary'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, height: 1.25)),
                  const SizedBox(height: 2),
                  Text(_friendlyTime(occurredAt),
                      style: const TextStyle(
                          color: SetuColors.mutedLight, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
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

Color _colorFor(String eventType) {
  switch (eventType) {
    case 'visit_completed':
    case 'checkin_completed':
      return SetuColors.verifiedLight; // positive / all-good
    case 'checkin_missed':
      return SetuColors.accentLight; // attention
    case 'sos_triggered':
      return SetuColors.sosLight; // urgent
    default:
      return SetuColors.accentLight; // neutral/scheduled
  }
}

String _friendlyTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final time = '${_two(dt.hour == 0 || dt.hour == 12 ? 12 : dt.hour % 12)}:'
      '${_two(dt.minute)} ${dt.hour < 12 ? 'AM' : 'PM'}';
  final days = today.difference(that).inDays;
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Yesterday, $time';
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}, $time';
}

String _two(int n) => n.toString().padLeft(2, '0');
