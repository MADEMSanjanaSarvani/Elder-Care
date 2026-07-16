import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/suggestions_repository.dart';

final suggestionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return SuggestionsRepository(client).fetchPending(elderId);
});

/// Care suggestions surfaced inline on the family dashboard (PRD Part 7,
/// Batch 4, Module 15). Deliberately gentle and dismissible — these are
/// operational nudges, never alerts, and every one can be acted on (deep
/// link to the relevant screen) or dismissed. Renders nothing when there
/// are no pending suggestions, so it never adds noise to a quiet home.
class SuggestionsCard extends ConsumerWidget {
  const SuggestionsCard({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestionsProvider(elderId));
    return suggestionsAsync.maybeWhen(
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Card(
          color: SetuColors.accentLight.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(SetuSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: SetuColors.accentLight),
                    const SizedBox(width: SetuSpacing.xs),
                    Text('Suggestions',
                        style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: SetuSpacing.sm),
                for (final s in suggestions)
                  _SuggestionRow(elderId: elderId, suggestion: s),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SuggestionRow extends ConsumerWidget {
  const _SuggestionRow({required this.elderId, required this.suggestion});

  final String elderId;
  final Map<String, dynamic> suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = suggestion['id'] as String;
    final type = suggestion['suggestion_type'] as String;
    final route = _actionRouteFor(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(suggestion['suggestion_text'] as String)),
          if (route != null)
            TextButton(
              onPressed: () async {
                await SuggestionsRepository(ref.read(supabaseClientProvider)).markActedOn(id);
                ref.invalidate(suggestionsProvider(elderId));
                if (context.mounted) context.push(route);
              },
              child: const Text('Do it'),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
            onPressed: () async {
              await SuggestionsRepository(ref.read(supabaseClientProvider)).dismiss(id);
              ref.invalidate(suggestionsProvider(elderId));
            },
          ),
        ],
      ),
    );
  }

  String? _actionRouteFor(String type) {
    switch (type) {
      case 'no_recent_visit':
      case 'appointment_without_companion':
        return '/elder/$elderId/booking';
      case 'refill_due_soon':
        return '/elder/$elderId/medications';
      case 'checkin_streak_broken':
        return '/elder/$elderId/timeline';
      default:
        return null;
    }
  }
}
