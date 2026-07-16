import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/care_plans_repository.dart';

final _plansProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, regionId) async {
  final client = ref.watch(supabaseClientProvider);
  return CarePlansRepository(client).fetchPlans(regionId);
});

final _subscriptionProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return CarePlansRepository(client).fetchActiveSubscription(elderId);
});

/// Care Plans (PRD Part 9, Batch 6, Module 21): the three-tier ladder,
/// each card showing what's included, with a current-subscription banner
/// and pause/resume when one is active. Subscribing shows a plan covers
/// its allocated visits; anything beyond is billed per-visit through the
/// normal flow (stated on the screen so the hybrid is never a surprise).
class CarePlansScreen extends ConsumerWidget {
  const CarePlansScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderAsync = ref.watch(elderProfileByIdProvider(elderId));
    final subAsync = ref.watch(_subscriptionProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Care plans')),
      body: elderAsync.when(
        data: (elder) {
          if (elder == null) return const Center(child: Text('Elder not found'));
          final regionId = elder['region_id'] as String;
          final plansAsync = ref.watch(_plansProvider(regionId));

          return plansAsync.when(
            data: (plans) => ListView(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              children: [
                subAsync.when(
                  data: (sub) => sub == null
                      ? const SizedBox.shrink()
                      : _CurrentSubscriptionBanner(elderId: elderId, subscription: sub),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: SetuSpacing.sm),
                  child: Text(
                    'A plan covers its included visits each month. Anything beyond the plan is billed per visit, as usual.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
                for (final plan in plans)
                  _PlanCard(
                    elderId: elderId,
                    plan: plan,
                    hasActiveSub: subAsync.asData?.value != null,
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Something went wrong: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}

class _CurrentSubscriptionBanner extends ConsumerWidget {
  const _CurrentSubscriptionBanner({required this.elderId, required this.subscription});

  final String elderId;
  final Map<String, dynamic> subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = subscription['care_plans'] as Map<String, dynamic>?;
    final status = subscription['status'] as String;
    final paused = status == 'paused';

    return Card(
      color: SetuColors.verifiedLight.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current plan: ${plan?['name'] ?? ''} ($status)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: SetuSpacing.sm),
            Wrap(spacing: SetuSpacing.sm, children: [
              TextButton(
                onPressed: () async {
                  await CarePlansRepository(ref.read(supabaseClientProvider))
                      .setStatus(subscription['id'] as String, paused ? 'active' : 'paused');
                  ref.invalidate(_subscriptionProvider(elderId));
                },
                child: Text(paused ? 'Resume' : 'Pause'),
              ),
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Cancel plan?'),
                      content: const Text('This ends the subscription. You can resubscribe anytime.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep')),
                        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel plan')),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await CarePlansRepository(ref.read(supabaseClientProvider))
                      .setStatus(subscription['id'] as String, 'cancelled');
                  ref.invalidate(_subscriptionProvider(elderId));
                },
                child: const Text('Cancel'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.elderId, required this.plan, required this.hasActiveSub});

  final String elderId;
  final Map<String, dynamic> plan;
  final bool hasActiveSub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allocations = (plan['care_plan_allocations'] as List?) ?? [];
    final currency = plan['currency'] as String? ?? 'INR';
    final price = (plan['monthly_price'] as num).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(plan['name'] as String, style: Theme.of(context).textTheme.titleLarge),
                Text('$currency $price/mo', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            if (plan['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: SetuSpacing.xs),
                child: Text(plan['description'] as String),
              ),
            const SizedBox(height: SetuSpacing.sm),
            for (final alloc in allocations)
              Row(
                children: [
                  const Icon(Icons.check, size: 16, color: SetuColors.verifiedLight),
                  const SizedBox(width: SetuSpacing.xs),
                  Expanded(
                    child: Text(
                        '${alloc['visits_per_period']} × ${(alloc['service_catalog'] as Map<String, dynamic>?)?['name'] ?? ''} per ${alloc['period']}'),
                  ),
                ],
              ),
            const SizedBox(height: SetuSpacing.sm),
            FilledButton(
              onPressed: hasActiveSub
                  ? null
                  : () async {
                      try {
                        await CarePlansRepository(ref.read(supabaseClientProvider))
                            .subscribe(elderId: elderId, carePlanId: plan['id'] as String);
                        ref.invalidate(_subscriptionProvider(elderId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Subscribed to ${plan['name']}')));
                        }
                      } catch (err) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Could not subscribe: $err')));
                        }
                      }
                    },
              child: Text(hasActiveSub ? 'Cancel current plan first' : 'Choose ${plan['name']}'),
            ),
          ],
        ),
      ),
    );
  }
}
