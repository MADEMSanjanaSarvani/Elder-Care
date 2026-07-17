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

/// Family Notification Center inbox (PRD Part 6, Batch 3, Module 9):
/// chronological, read/unread, mark-all-read, deep link to the source
/// screen where one exists. A notification whose source is gone shows a
/// graceful message, not a crash (PRD §13).
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
            return const SetuEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications',
              message: 'Updates about visits, medicines and check-ins land here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: notifications.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: SetuSpacing.sm),
            itemBuilder: (context, index) {
              final n = notifications[index];
              final unread = n['read_at'] == null;
              final createdAt = DateTime.parse(n['created_at'] as String).toLocal();
              return Card(
                child: ListTile(
                  leading: SetuIconChip(
                    icon: _iconFor(n['type'] as String),
                    color: unread
                        ? SetuColors.accentLight
                        : SetuColors.mutedLight,
                  ),
                  title: Text(
                    _labelFor(n['type'] as String),
                    style: unread
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                  subtitle: Text(SetuFormat.friendlyTime(createdAt)),
                  trailing: unread
                      ? const Icon(Icons.circle, size: 10, color: SetuColors.accentLight)
                      : null,
                  onTap: () async {
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
                  },
                ),
              );
            },
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }
}

IconData _iconFor(String type) {
  switch (type) {
    case 'sos_triggered':
    case 'sos_ops_alert':
      return Icons.sos_rounded;
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
