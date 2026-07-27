import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';

/// One memory worth offering, or null when there's nothing to say.
final memoryLaneProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, elderId) async {
  ref.watch(authStateProvider);
  final rows = await ref.read(supabaseClientProvider).rpc(
    'memory_lane_pick',
    params: {'p_elder_id': elderId},
  ) as List<dynamic>;
  if (rows.isEmpty) return null;
  return (rows.first as Map).cast<String, dynamic>();
});

/// Memory Lane: reaching back into SETU Memories and *offering* something.
///
/// Not a third photo screen. Memories already holds the material and the
/// Timeline already shows recent days — what makes this different is that
/// somebody asks. Reminiscence prompting is established practice in dementia
/// and low-mood care, and the entire difference between it and a gallery is
/// the question.
///
/// Deliberately one memory, never a list. The moment it becomes scrollable it
/// is the Memories screen again and the thing worth building is gone.
///
/// It also makes no claim about why this memory. The design said "it always
/// makes you smile", which would mean SETU tracked their reaction to a
/// particular photo. It didn't, and saying so would be the kind of small
/// invented intimacy that costs trust when someone notices.
class MemoryLaneCard extends ConsumerWidget {
  const MemoryLaneCard({super.key, required this.elderId});

  final String elderId;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  Future<void> _dismiss(
    BuildContext context,
    WidgetRef ref,
    String memoryId,
    String scope,
  ) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('memory_dismissals').upsert({
        'memory_id': memoryId,
        'profile_id': client.auth.currentUser?.id,
        'scope': scope,
      }, onConflict: 'memory_id,profile_id');
    } catch (_) {
      // A failed dismissal must not trap someone on a memory they asked to
      // put away, so the card goes regardless and the next open re-picks.
    }
    ref.invalidate(memoryLaneProvider(elderId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(memoryLaneProvider(elderId)).asData?.value;
    if (memory == null) return const SizedBox.shrink();

    final id = memory['id'] as String;
    final raw = memory['memory_date'] as String?;
    final date = raw == null ? null : DateTime.tryParse(raw);
    final when = date == null
        ? 'From your memories'
        : '${_months[date.month - 1]} ${date.year}';

    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.lavenderLight.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        boxShadow: SetuSurfaces.of(context).cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_outlined,
                  size: 18, color: SetuColors.lavenderLight),
              const SizedBox(width: 6),
              Text(when.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: SetuColors.lavenderLight)),
            ],
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(
            memory['summary'] as String? ?? '',
            style: const TextStyle(fontSize: 17, height: 1.45),
          ),
          const SizedBox(height: SetuSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/elder/$elderId/memories'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Show me'),
                ),
              ),
              const SizedBox(width: SetuSpacing.sm),
              // "Not now" and "never again" are genuinely different things,
              // and one Dismiss button forces people to over- or under-state
              // what they meant. A memory can be painful — a spouse who has
              // died, a house that was sold — and saying so once should be
              // enough.
              PopupMenuButton<String>(
                tooltip: 'Not now',
                icon: const Icon(Icons.close, color: SetuColors.mutedLight),
                onSelected: (scope) => _dismiss(context, ref, id, scope),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'later', child: Text('Not right now')),
                  PopupMenuItem(
                      value: 'never', child: Text("Don't show this again")),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
