import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/notifications_repository.dart';

final _typesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return NotificationsRepository(client).fetchTypes();
});

final _preferencesProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return {};
  final rows = await NotificationsRepository(client).fetchPreferences(userId);
  return {for (final row in rows) row['type'] as String: row};
});

/// Per-type channel preference (PRD Part 6, Batch 3, Module 9). Types
/// with can_disable=false show no off switch at all — and the database
/// trigger enforces it regardless of what any client shows.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(_typesProvider);
    final prefsAsync = ref.watch(_preferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: typesAsync.when(
        data: (types) => prefsAsync.when(
          data: (prefs) => ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: types.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: SetuSpacing.sm),
            itemBuilder: (context, index) {
              final type = types[index];
              final typeName = type['type'] as String;
              final canDisable = type['can_disable'] as bool? ?? true;
              final pref = prefs[typeName];
              final enabled = pref?['enabled'] as bool? ?? true;
              return Card(
                child: SwitchListTile(
                  title: Text(type['description'] as String? ?? typeName),
                  subtitle: canDisable
                      ? null
                      : const Text('Always delivered — safety notifications cannot be turned off'),
                  value: enabled,
                  onChanged: canDisable
                      ? (value) async {
                          final client = ref.read(supabaseClientProvider);
                          final userId = client.auth.currentUser?.id;
                          if (userId == null) return;
                          await NotificationsRepository(client).setPreference(
                            userId: userId,
                            type: typeName,
                            channel: type['default_channel'] as String? ?? 'push',
                            enabled: value,
                          );
                          ref.invalidate(_preferencesProvider);
                        }
                      : null,
                ),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Something went wrong: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}
