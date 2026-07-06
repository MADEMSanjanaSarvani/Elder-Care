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
          if (payouts.isEmpty) return const Center(child: Text('No payouts yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: payouts.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final payout = payouts[index];
              return ListTile(
                title: Text('${payout['currency']} ${payout['amount']}'),
                subtitle: Text('Status: ${payout['status']}'),
                trailing: Text(payout['scheduled_for'].toString().split('T').first),
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
