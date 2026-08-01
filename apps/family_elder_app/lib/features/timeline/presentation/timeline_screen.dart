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

/// A real activity feed (PRD Part 4, Batch 1, Module 2) presented to match
/// the Stitch "daily_timeline_peace_of_mind" design: a glass AI summary
/// card, then the day laid out as a connected, dashed-rail timeline with
/// status pills.
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

/// Warm summary derived from the day's real events, in the redesign's voice
/// — a glass card with an AI Recommendation nested inside, matching the
/// Stitch "Daily Peace of Mind" / "Peace of Mind AI" panel.
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

    // A cancelled SOS stands the banner down. Leaving "an SOS was raised
    // today — please check in" at the top of the day, after the family has
    // already established it was a pocket-press, is how an app teaches people
    // to ignore it.
    final sosCancelled =
        events.any((e) => e['event_type'] == 'sos_cancelled');
    final hasSos = !sosCancelled &&
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
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: const Border(
          left: BorderSide(color: SetuColors.accentLight, width: 4),
          top: BorderSide(color: SetuColors.borderLight),
          right: BorderSide(color: SetuColors.borderLight),
          bottom: BorderSide(color: SetuColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: SetuColors.accentLight, size: 20),
              SizedBox(width: SetuSpacing.sm),
              Text('DAILY PEACE OF MIND',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: SetuColors.accentLight)),
            ],
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(summary,
              style: const TextStyle(height: 1.45, fontSize: 15.5)),
          const SizedBox(height: SetuSpacing.md),
          const _AiRecommendationCard(),
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
        color: SetuColors.lavenderLight.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: SetuColors.lavenderLight.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
                color: SetuColors.lavenderLight, shape: BoxShape.circle),
            child: const Icon(Icons.video_call, color: Colors.white, size: 22),
          ),
          const SizedBox(width: SetuSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Recommendation',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: SetuColors.lavenderLight)),
                SizedBox(height: 2),
                Text(
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

/// One event, rendered as a connected timeline node: a big coloured icon
/// medallion with a dashed rail running to the next node, and a card
/// holding the detail plus a status pill (matches the Stitch dashboard's
/// timeline nodes). The pill reflects only real event_type categories —
/// nothing here is invented per-event data (no fabricated vitals/names).
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
    final pill = _pillFor(type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail: icon medallion + the connector down to the next node.
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                  // Lifted off the rail so the medallions read as nodes on a
                  // line rather than as holes punched through it.
                  boxShadow: SetuSurfaces.of(context).cardShadow,
                ),
                child: Icon(_iconFor(type), color: color, size: 26),
              ),
              if (!isLast)
                // A gradient rather than the dashes it used to draw. The
                // design fades peach into sand down the page, which reads as
                // the day passing — dashes read as a form field. It is also
                // one Container instead of a CustomPaint that re-rasterised
                // on every scroll frame.
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.55),
                          SetuColors.borderLight,
                        ],
                      ),
                    ),
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
                    if (pill != null) ...[
                      const SizedBox(height: SetuSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(pill.$1, size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(pill.$2,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: color)),
                          ],
                        ),
                      ),
                    ],
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
      return 'Visit started';
    case 'visit_completed':
      return 'Visit completed';
    case 'checkin_completed':
      return 'Check-in done';
    case 'checkin_missed':
      return 'Check-in missed';
    case 'sos_triggered':
      return 'SOS raised';
    case 'sos_cancelled':
      return 'SOS cancelled';
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
    case 'sos_cancelled':
      return Icons.check_circle_outline;
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
    case 'sos_cancelled':
      return SetuColors.verifiedLight; // stood down
    default:
      return SetuColors.lavenderLight; // neutral/scheduled
  }
}

/// A small status pill for the handful of event types with a clear
/// real-world status (icon, label). Returns null for neutral/scheduled
/// events so we never invent a status that isn't actually known.
(IconData, String)? _pillFor(String eventType) {
  switch (eventType) {
    case 'visit_completed':
    case 'checkin_completed':
      return (Icons.check_circle, 'Completed');
    case 'checkin_missed':
      return (Icons.warning_amber_rounded, 'Missed');
    case 'sos_triggered':
      return (Icons.priority_high_rounded, 'Urgent');
    case 'sos_cancelled':
      return (Icons.check_circle, 'False alarm');
    default:
      return null;
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
