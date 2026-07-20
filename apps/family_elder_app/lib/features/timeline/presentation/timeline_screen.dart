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

/// A real activity feed (PRD Part 4, Batch 1, Module 2) presented to the
/// redesign's "Daily Peace of Mind" layout: a warm summary header, an AI
/// recommendation card, then the day laid out as a connected timeline.
///
/// What shows here is exactly what the RLS policy lets this viewer see — a
/// family member without consent for a category simply never receives those
/// rows, so the feed stays the source of truth while the chrome is new.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_timelineEventsProvider(elderId));
    final elderAsync = ref.watch(elderProfileByIdProvider(elderId));
    final firstName = elderAsync.maybeWhen(
      data: (p) => ((p?['display_name'] as String?)?.trim().split(' ').first),
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline')),
      body: eventsAsync.when(
        data: (events) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_timelineEventsProvider(elderId));
              await ref.read(_timelineEventsProvider(elderId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              children: [
                _PeaceOfMindHeader(name: firstName, events: events),
                const SizedBox(height: SetuSpacing.md),
                const _AiRecommendationCard(),
                const SizedBox(height: SetuSpacing.lg),
                Row(
                  children: [
                    Text("Today's Timeline",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (events.isNotEmpty)
                      Row(
                        children: [
                          Text('See History',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600)),
                          Icon(Icons.chevron_right,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: SetuSpacing.md),
                if (events.isEmpty)
                  const _EmptyTimeline()
                else
                  for (int i = 0; i < events.length; i++)
                    _TimelineRow(
                      event: events[i],
                      isLast: i == events.length - 1,
                    ),
              ],
            ),
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }
}

/// Warm summary derived from the day's real events, in the redesign's voice.
class _PeaceOfMindHeader extends StatelessWidget {
  const _PeaceOfMindHeader({required this.name, required this.events});

  final String? name;
  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final hasSos =
        events.any((e) => e['event_type'] == 'sos_triggered');
    final missed =
        events.any((e) => e['event_type'] == 'checkin_missed');
    final who = name != null ? name! : 'your loved one';

    final String summary;
    if (hasSos) {
      summary =
          '$greeting. An SOS was raised today — please review the timeline below and check in.';
    } else if (missed) {
      summary =
          '$greeting. Most of the day went smoothly for $who, though a check-in was missed. Details are below.';
    } else if (events.isEmpty) {
      summary =
          "$greeting. No updates yet today — visits, check-ins and health notes for $who will appear here.";
    } else {
      summary =
          '$greeting. $who has had a calm day so far — everything is on track. Here is how the day has unfolded.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.verifiedLight.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: SetuColors.verifiedLight, size: 22),
              const SizedBox(width: SetuSpacing.sm),
              Text('Daily Peace of Mind',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: SetuColors.verifiedLight)),
            ],
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(summary,
              style: const TextStyle(height: 1.4, fontSize: 15)),
        ],
      ),
    );
  }
}

class _AiRecommendationCard extends StatelessWidget {
  const _AiRecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: SetuColors.lavenderLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: SetuColors.lavenderLight.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
                color: SetuColors.lavenderLight, shape: BoxShape.circle),
            child: const Icon(Icons.video_call, color: Colors.white, size: 22),
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Recommendation',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: SetuColors.lavenderLight)),
                const SizedBox(height: 2),
                const Text(
                  'A short video call this evening would brighten their day.',
                  style: TextStyle(height: 1.3),
                ),
              ],
            ),
          ),
        ],
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

/// One event, rendered as a connected timeline node: a coloured icon dot with a
/// dotted rail running to the next node, and a card holding the detail.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final Map<String, dynamic> event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final type = event['event_type'] as String;
    final occurredAt =
        DateTime.parse(event['occurred_at'] as String).toLocal();
    final color = _colorFor(type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail: icon dot + dotted connector down to the next node.
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(SetuSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(_iconFor(type), color: color, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: SetuColors.borderLight,
                  ),
                ),
            ],
          ),
          const SizedBox(width: SetuSpacing.md),
          // Detail card.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : SetuSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(SetuSpacing.md),
                decoration: BoxDecoration(
                  color: SetuColors.paperRaisedLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SetuColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_titleFor(type),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        Text(_friendlyTime(occurredAt),
                            style: const TextStyle(
                                color: SetuColors.mutedLight, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(event['summary'] as String,
                        style: const TextStyle(height: 1.3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _titleFor(String eventType) {
  switch (eventType) {
    case 'visit_scheduled':
      return 'Visit scheduled';
    case 'visit_started':
      return 'Caregiver arrived';
    case 'visit_completed':
      return 'Visit completed';
    case 'checkin_completed':
      return 'Check-in done';
    case 'checkin_missed':
      return 'Check-in missed';
    case 'sos_triggered':
      return 'SOS raised';
    case 'health_note_added':
      return 'Health note';
    default:
      return 'Update';
  }
}

IconData _iconFor(String eventType) {
  switch (eventType) {
    case 'visit_scheduled':
      return Icons.event_available_outlined;
    case 'visit_started':
      return Icons.home_outlined;
    case 'visit_completed':
      return Icons.check_circle_outline;
    case 'checkin_completed':
      return Icons.favorite_outline;
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
      return SetuColors.peachLight; // attention
    case 'sos_triggered':
      return SetuColors.sosLight; // urgent
    default:
      return SetuColors.lavenderLight; // neutral/scheduled
  }
}

String _friendlyTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final time = '${_two(dt.hour == 0 || dt.hour == 12 ? 12 : dt.hour % 12)}:'
      '${_two(dt.minute)} ${dt.hour < 12 ? 'AM' : 'PM'}';
  final days = today.difference(that).inDays;
  if (days == 0) return time;
  if (days == 1) return 'Yesterday';
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
