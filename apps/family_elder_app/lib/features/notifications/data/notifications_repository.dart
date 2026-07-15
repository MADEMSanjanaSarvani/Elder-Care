import 'package:supabase_flutter/supabase_flutter.dart';

/// Family Notification Center (PRD Part 6, Batch 3, Module 9). All plain
/// RLS-guarded operations — the notifications table's own policy already
/// scopes rows to user_id = auth.uid(); delivery dispatch stays owned by
/// whichever module generates a given notification.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchInbox(String userId, {int limit = 100}) async {
    return _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<int> unreadCount(String userId) async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .isFilter('read_at', null);
    return rows.length;
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()}).eq('id', notificationId);
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }

  Future<List<Map<String, dynamic>>> fetchTypes() async {
    return _client.from('notification_types').select().order('type');
  }

  Future<List<Map<String, dynamic>>> fetchPreferences(String userId) async {
    return _client.from('notification_preferences').select().eq('user_id', userId);
  }

  /// The must-deliver trigger raises if a can_disable=false type is
  /// disabled — the UI shouldn't offer that switch, but the database is
  /// the enforcement either way.
  Future<void> setPreference({
    required String userId,
    required String type,
    required String channel,
    required bool enabled,
  }) async {
    await _client.from('notification_preferences').upsert({
      'user_id': userId,
      'type': type,
      'channel': channel,
      'enabled': enabled,
    }, onConflict: 'user_id, type');
  }
}
