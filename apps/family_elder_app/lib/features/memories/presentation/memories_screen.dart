import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/memories_repository.dart';
import '../../../core/illustrations.dart';

/// SETU Memories — the warm, human story of an elder's days. Newest first;
/// pull-to-refresh (or the top button) asks the server to (re)generate
/// today's memory from the latest data.
final memoriesProvider =
    FutureProvider.family<List<SetuMemory>, String>((ref, elderId) async {
  ref.watch(authStateProvider);
  final repo = MemoriesRepository(ref.watch(supabaseClientProvider));
  // Make sure today's memory reflects the latest data every time the family
  // opens the screen. Deterministic + idempotent, so this is cheap and safe;
  // if it fails (offline, function cold) we still show whatever is stored.
  try {
    await repo.generateToday(elderId);
  } catch (_) {}
  // Fail soft: if the memories backend isn't reachable/provisioned yet, show
  // the friendly empty state instead of a scary "that didn't load" error.
  try {
    return await repo.list(elderId);
  } catch (_) {
    return <SetuMemory>[];
  }
});

/// Maps the small, fixed set of icon names the generator emits to IconData,
/// so the server can stay a plain JSON producer with no Flutter coupling.
IconData _iconFor(String name) {
  switch (name) {
    case 'medication':
      return Icons.medication_rounded;
    case 'sentiment_very_satisfied':
      return Icons.sentiment_very_satisfied_rounded;
    case 'sentiment_satisfied':
      return Icons.sentiment_satisfied_rounded;
    case 'sentiment_neutral':
      return Icons.sentiment_neutral_rounded;
    case 'sentiment_dissatisfied':
      return Icons.sentiment_dissatisfied_rounded;
    case 'sick':
      return Icons.sick_rounded;
    case 'mood':
      return Icons.mood_rounded;
    case 'volunteer_activism':
      return Icons.volunteer_activism_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}

class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memoriesProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('SETU Memories')),
      body: async.when(
        loading: () => const SetuLoading(),
        error: (e, _) => const SetuErrorState(),
        data: (memories) {
          if (memories.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(memoriesProvider(elderId).future),
              child: ListView(
                children: [
                  const SizedBox(height: 120),
                  SetuEmptyState(
                    artwork: SetuArt.emptyMemories(),
                    icon: Icons.auto_awesome_rounded,
                    title: 'Memories are on the way',
                    message:
                        'As medicines, check-ins and visits are logged, warm '
                        'summaries of each day will gather here.',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(memoriesProvider(elderId).future),
            child: ListView.separated(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              itemCount: memories.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: SetuSpacing.md),
              itemBuilder: (context, i) => _MemoryCard(memory: memories[i]),
            ),
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory});
  final SetuMemory memory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SetuColors.lavenderLight.withValues(alpha: 0.14),
            SetuColors.accentLight.withValues(alpha: 0.09),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SetuIconChip(
                  icon: Icons.auto_awesome_rounded,
                  color: SetuColors.lavenderLight),
              const SizedBox(width: SetuSpacing.sm),
              Text(_prettyDate(memory.date),
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: SetuColors.mutedLight)),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          Text(memory.summary,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(height: 1.35)),
          if (memory.highlights.isNotEmpty) ...[
            const SizedBox(height: SetuSpacing.md),
            Wrap(
              spacing: SetuSpacing.sm,
              runSpacing: SetuSpacing.sm,
              children: [
                for (final h in memory.highlights) _HighlightChip(highlight: h),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _prettyDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.highlight});
  final MemoryHighlight highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SetuColors.paperLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(highlight.icon),
              size: 16, color: SetuColors.accentLight),
          const SizedBox(width: 6),
          Text(highlight.text,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
