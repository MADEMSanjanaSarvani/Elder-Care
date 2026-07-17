import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/reports_repository.dart';

final _reportsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return ReportsRepository(client).fetchReports(elderId);
});

/// AI Visit Reports viewer (PRD Part 7, Batch 4, Module 14): the weekly
/// digests, newest first. What appears here has already cleared the
/// guardrail (RLS withholds flagged/held reports), so there's no review
/// state to show the family — just the report.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(_reportsProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly reports')),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return const SetuEmptyState(
              icon: Icons.summarize_outlined,
              title: 'No reports yet',
              message: 'A gentle weekly summary of care will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const SizedBox(height: SetuSpacing.md),
            itemBuilder: (context, index) {
              final report = reports[index];
              final start = DateTime.parse(report['period_start'] as String);
              final end = DateTime.parse(report['period_end'] as String);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(SetuSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SetuIconChip(
                              icon: Icons.summarize_outlined, size: 16),
                          const SizedBox(width: SetuSpacing.sm),
                          Text(
                              '${SetuFormat.friendlyDate(start)} – ${SetuFormat.friendlyDate(end)}',
                              style: Theme.of(context).textTheme.labelMedium),
                        ],
                      ),
                      const SizedBox(height: SetuSpacing.sm),
                      Text(report['report_text'] as String),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}
