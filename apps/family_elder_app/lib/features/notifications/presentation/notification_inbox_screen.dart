import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/notifications_repository.dart';

final notificationInboxProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  return NotificationsRepository(client).fetchInbox(userId);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return 0;
  return NotificationsRepository(client).unreadCount(userId);
});

/// Notification categories used purely to group the real inbox into the
/// sections the Stitch "notification_center" design shows (Emergency
/// Alerts / Health Updates / Family & Wellness) — derived from the same
/// real `type` field the old flat list used, nothing invented.
enum _Category { emergency, health, family, other }

_Category _categoryFor(String type) {
  switch (type) {
    case 'sos_triggered':
    case 'sos_ops_alert':
    // The stand-down sits in Emergency alongside the alert it retracts. In
    // any other section it would be found after the drive across town.
    case 'sos_cancelled':
    case 'checkin_missed_escalation':
    case 'reminder_hospital_stay_gap':
      return _Category.emergency;
    case 'reminder_medication_dose':
    case 'reminder_appointment':
      return _Category.health;
    case 'family_invite_sent':
      return _Category.family;
    default:
      return _Category.other;
  }
}

/// Family Notification Center inbox (PRD Part 6, Batch 3, Module 9):
/// grouped by category (matching the Stitch "notification_center" design),
/// read/unread, mark-all-read, deep link to the source screen where one
/// exists. A notification whose source is gone shows a graceful message,
/// not a crash (PRD §13). Empty state matches the "no_notifications" design.
class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(notificationInboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              final userId = client.auth.currentUser?.id;
              if (userId == null) return;
              await NotificationsRepository(client).markAllRead(userId);
              ref.invalidate(notificationInboxProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('Mark all read'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification preferences',
            onPressed: () => context.push('/notifications/preferences'),
          ),
        ],
      ),
      body: inboxAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _NoNotifications(
              onRefresh: () => ref.invalidate(notificationInboxProvider),
            );
          }

          final groups = <_Category, List<Map<String, dynamic>>>{};
          for (final n in notifications) {
            groups
                .putIfAbsent(_categoryFor(n['type'] as String), () => [])
                .add(n);
          }

          Widget markReadAndOpen(Map<String, dynamic> n) {
            return _NotificationCard(notification: n, onTap: () async {
              final client = ref.read(supabaseClientProvider);
              await NotificationsRepository(client).markRead(n['id'] as String);
              ref.invalidate(notificationInboxProvider);
              ref.invalidate(unreadCountProvider);
              if (!context.mounted) return;
              final route = _deepLinkFor(
                  n['type'] as String, n['payload'] as Map<String, dynamic>?);
              if (route != null) {
                context.push(route);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('This is no longer available.')));
              }
            });
          }

          const sections = [
            (_Category.emergency, 'EMERGENCY ALERTS', Icons.emergency_outlined,
                SetuColors.sosLight),
            (_Category.health, 'HEALTH UPDATES', Icons.medical_services_outlined,
                SetuColors.accentLight),
            (_Category.family, 'FAMILY & WELLNESS', Icons.diversity_1_outlined,
                SetuColors.lavenderLight),
            (_Category.other, 'OTHER', Icons.notifications_outlined,
                SetuColors.mutedLight),
          ];

          final children = <Widget>[];
          for (final section in sections) {
            final items = groups[section.$1];
            if (items == null || items.isEmpty) continue;
            children.add(Row(
              children: [
                Icon(section.$3, size: 18, color: section.$4),
                const SizedBox(width: SetuSpacing.sm),
                Text(section.$2,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: section.$4)),
              ],
            ));
            children.add(const SizedBox(height: SetuSpacing.sm));
            for (final n in items) {
              children.add(markReadAndOpen(n));
              children.add(const SizedBox(height: SetuSpacing.sm));
            }
            children.add(const SizedBox(height: SetuSpacing.sm));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationInboxProvider);
              await ref.read(notificationInboxProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              children: children,
            ),
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }
}

/// A single notification card. Emergency-category notifications get bold,
/// urgent styling (solid icon medallion, thick red rail); everything else
/// keeps the calmer left-border card.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = notification['type'] as String;
    final unread = notification['read_at'] == null;
    final createdAt =
        DateTime.parse(notification['created_at'] as String).toLocal();
    final tint = _categoryColor(type);
    final urgent = _categoryFor(type) == _Category.emergency;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: urgent
              ? tint.withValues(alpha: 0.10)
              : unread
                  ? tint.withValues(alpha: 0.08)
                  : SetuColors.paperRaisedLight,
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: tint, width: urgent ? 5 : 4)),
        ),
        padding: const EdgeInsets.all(SetuSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            urgent
                ? Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                    child: Icon(_iconFor(type), color: Colors.white, size: 24),
                  )
                : SetuIconChip(icon: _iconFor(type), color: tint),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_labelFor(type),
                      style: TextStyle(
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(SetuFormat.friendlyTime(createdAt),
                      style: const TextStyle(
                          color: SetuColors.mutedLight, fontSize: 12.5)),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty inbox, matching the Stitch "no_notifications" design: a soft
/// pulsing badge, "All quiet here", and a real "Check for updates" refresh
/// action (no illustration asset bundled, so a plain icon badge stands in).
class _NoNotifications extends StatefulWidget {
  const _NoNotifications({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  State<_NoNotifications> createState() => _NoNotificationsState();
}

class _NoNotificationsState extends State<_NoNotifications>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setuSyncBreathing(context, _controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.06).animate(
                        CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: SetuColors.peachLight.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: const BoxDecoration(
                      color: SetuColors.paperRaisedLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x14FF9F66),
                            blurRadius: 20,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.notifications_none_rounded,
                        size: 56, color: SetuColors.accentLight),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                          color: SetuColors.peachLight, shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_off,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SetuSpacing.lg),
            Text('All quiet here',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: SetuSpacing.sm),
            const Text(
              "You'll see updates about your loved one's health and care here when they happen.",
              textAlign: TextAlign.center,
              style: TextStyle(color: SetuColors.mutedLight, height: 1.4),
            ),
            const SizedBox(height: SetuSpacing.lg),
            FilledButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Check for updates'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category tint for a notification's left border (matches the Stitch
/// notification-center grouping: emergency red, health, family/wellness).
Color _categoryColor(String type) {
  switch (type) {
    case 'sos_triggered':
    case 'sos_ops_alert':
    case 'checkin_missed_escalation':
    case 'reminder_hospital_stay_gap':
      return SetuColors.sosLight;
    // Green, though it is an emergency-category row: a red stripe on a
    // stand-down is read as another alarm at a glance.
    case 'sos_cancelled':
      return SetuColors.verifiedLight;
    case 'reminder_medication_dose':
    case 'reminder_appointment':
      return SetuColors.peachLight;
    case 'family_invite_sent':
      return SetuColors.lavenderLight;
    default:
      return SetuColors.accentLight;
  }
}

IconData _iconFor(String type) {
  switch (type) {
    case 'sos_triggered':
    case 'sos_ops_alert':
      return Icons.sos_rounded;
    case 'sos_cancelled':
      return Icons.check_circle_outline;
    case 'checkin_missed_escalation':
      return Icons.warning_amber_outlined;
    case 'family_invite_sent':
      return Icons.group_add_outlined;
    case 'reminder_medication_dose':
      return Icons.medication_outlined;
    case 'reminder_appointment':
      return Icons.event_outlined;
    case 'reminder_hospital_stay_gap':
      return Icons.local_hospital_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

String _labelFor(String type) {
  switch (type) {
    case 'sos_triggered':
      return 'SOS triggered';
    case 'sos_cancelled':
      return 'False alarm — SOS cancelled';
    case 'sos_ops_alert':
      return 'SOS ops alert';
    case 'checkin_missed_escalation':
      return 'Missed daily check-in';
    case 'family_invite_sent':
      return 'Family invitation';
    case 'reminder_medication_dose':
      return 'Medication reminder';
    case 'reminder_appointment':
      return 'Appointment reminder';
    case 'reminder_hospital_stay_gap':
      return 'Hospital stay has a coverage gap';
    case 'erasure_request_submitted':
      return 'Data erasure request filed';
    default:
      return type;
  }
}

String? _deepLinkFor(String type, Map<String, dynamic>? payload) {
  final elderId = payload?['elder_id'] as String?;
  if (elderId == null) return null;
  switch (type) {
    case 'sos_triggered':
    case 'sos_cancelled':
      return '/elder/$elderId/sos';
    case 'checkin_missed_escalation':
      return '/elder/$elderId/timeline';
    case 'reminder_medication_dose':
      return '/elder/$elderId/medications';
    case 'reminder_appointment':
      return '/elder/$elderId/appointments';
    case 'reminder_hospital_stay_gap':
      return '/elder/$elderId/hospital-stays';
    case 'family_invite_sent':
      return '/elder/$elderId/family';
    default:
      return null;
  }
}
