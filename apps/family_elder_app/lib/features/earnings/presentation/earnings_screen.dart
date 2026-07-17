import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';

final _payoutsProvider = FutureProvider((ref) async {
  final caregiver = await ref.watch(myCaregiverProvider.future);
  if (caregiver == null) return <Map<String, dynamic>>[];
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('caregiver_payouts')
      .select()
      .eq('caregiver_id', caregiver.id)
      .order('scheduled_for', ascending: false);
});

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(_payoutsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: payoutsAsync.when(
        data: (payouts) {
          if (payouts.isEmpty) {
            return const SetuEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No earnings yet',
              message: 'Payouts appear here after your visits are verified.',
            );
          }
          final currency = payouts.first['currency'] ?? 'INR';
          final paidTotal = payouts
              .where((p) => p['status'] == 'paid')
              .fold<double>(
                  0, (sum, p) => sum + (p['amount'] as num).toDouble());
          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SetuSpacing.lg),
                decoration: BoxDecoration(
                  color: SetuColors.verifiedLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total paid out',
                        style: TextStyle(color: SetuColors.mutedLight)),
                    const SizedBox(height: 4),
                    Text('$currency ${paidTotal.toStringAsFixed(0)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: SetuColors.verifiedLight)),
                  ],
                ),
              ),
              const SizedBox(height: SetuSpacing.lg),
              Text('Payouts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: SetuSpacing.sm),
              for (final payout in payouts) _PayoutCard(payout: payout),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout});

  final Map<String, dynamic> payout;

  @override
  Widget build(BuildContext context) {
    final status = payout['status'] as String;
    final color = status == 'paid'
        ? SetuColors.verifiedLight
        : status == 'failed'
            ? SetuColors.sosLight
            : SetuColors.accentLight;
    final when = DateTime.tryParse(payout['scheduled_for']?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: Card(
        child: ListTile(
          leading: SetuIconChip(
              icon: Icons.account_balance_wallet_outlined, color: color),
          title: Text('${payout['currency']} ${payout['amount']}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle:
              when == null ? null : Text(SetuFormat.friendlyDate(when)),
          trailing: SetuStatusPill(label: status, color: color),
        ),
      ),
    );
  }
}
