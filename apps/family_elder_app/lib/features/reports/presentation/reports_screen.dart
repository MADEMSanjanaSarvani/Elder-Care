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
/// digests, newest first, presented to the Stitch "AI Reports" look — a
/// lavender AI-branded header, then each week as its own soft card. What
/// appears here has already cleared the guardrail (RLS withholds
/// flagged/held reports), so there's no review state to show — just the report.
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
          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              const _AiReportsHeader(),
              const SizedBox(height: SetuSpacing.lg),
              for (int i = 0; i < reports.length; i++) ...[
                _ReportCard(report: reports[i], latest: i == 0),
                if (i != reports.length - 1)
                  const SizedBox(height: SetuSpacing.md),
              ],
            ],
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }
}

class _AiReportsHeader extends StatelessWidget {
  const _AiReportsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.lavenderLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: SetuColors.lavenderLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: SetuColors.lavenderLight, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Weekly Reports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: SetuColors.lavenderLight)),
                const SizedBox(height: 2),
                const Text(
                  'Gentle, plain-language summaries of your loved one\'s week.',
                  style: TextStyle(color: SetuColors.mutedLight, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.latest});

  final Map<String, dynamic> report;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(report['period_start'] as String);
    final end = DateTime.parse(report['period_end'] as String);
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SetuIconChip(
                  icon: Icons.summarize_outlined,
                  color: SetuColors.lavenderLight,
                  size: 16),
              const SizedBox(width: SetuSpacing.sm),
              Expanded(
                child: Text(
                    '${SetuFormat.friendlyDate(start)} – ${SetuFormat.friendlyDate(end)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (latest)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: SetuColors.verifiedLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Latest',
                      style: TextStyle(
                          color: SetuColors.verifiedLight,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          Text(report['report_text'] as String,
              style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}
