import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../payments/presentation/demo_payment_sheet.dart';
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
            loading: () => const SetuLoading(),
            error: (err, stack) => const SetuErrorState(),
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
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
    final code = plan['code'] as String? ?? '';
    // Middle tier is the "most loved" hero; each tier gets its own tint.
    final popular = code == 'standard';
    final tint = code == 'premium'
        ? SetuColors.lavenderLight
        : code == 'standard'
            ? SetuColors.accentLight
            : SetuColors.peachLight;

    return Container(
      margin: const EdgeInsets.only(bottom: SetuSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: 0.14),
            tint.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
            color: tint.withValues(alpha: popular ? 0.6 : 0.25),
            width: popular ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plan['name'] as String,
                    style: Theme.of(context).textTheme.titleLarge),
                if (popular) ...[
                  const SizedBox(width: SetuSpacing.sm),
                  const SetuStatusPill(
                      label: 'Most loved', color: SetuColors.accentLight),
                ],
              ],
            ),
            const SizedBox(height: SetuSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$currency $price',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: tint, fontWeight: FontWeight.w800)),
                const Text(' / month',
                    style: TextStyle(color: SetuColors.mutedLight)),
              ],
            ),
            if (plan['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: SetuSpacing.xs),
                child: Text(plan['description'] as String,
                    style: const TextStyle(
                        color: SetuColors.mutedLight, height: 1.4)),
              ),
            const SizedBox(height: SetuSpacing.md),
            for (final alloc in allocations)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: tint),
                    const SizedBox(width: SetuSpacing.sm),
                    Expanded(
                      child: Text(
                          '${alloc['visits_per_period']} × ${(alloc['service_catalog'] as Map<String, dynamic>?)?['name'] ?? ''} / ${alloc['period']}'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: SetuSpacing.md),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: tint),
              onPressed: hasActiveSub
                  ? null
                  : () => _subscribe(context, ref,
                      currencyLabel: '$currency $price'),
              child: Text(hasActiveSub
                  ? 'Cancel current plan first'
                  : 'Choose ${plan['name']}'),
            ),
          ],
        ),
      ),
    );
  }

  /// A plan only activates after a verified payment. Tries the real Razorpay
  /// hosted checkout; if payments aren't configured yet (503) it falls back to
  /// the clearly-labelled demo checkout so the flow is still demonstrable.
  Future<void> _subscribe(BuildContext context, WidgetRef ref,
      {required String currencyLabel}) async {
    final repo = CarePlansRepository(ref.read(supabaseClientProvider));
    final planId = plan['id'] as String;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final link = await repo.createPlanPaymentLink(
          elderId: elderId, carePlanId: planId);
      final url = link['short_url'] as String;
      final linkId = link['link_id'] as String;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!context.mounted) return;

      final done = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finish your payment'),
          content: const Text(
              'Complete the payment in your browser, then come back and tap '
              '"I\'ve paid" to activate the plan.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("I've paid")),
          ],
        ),
      );
      if (done != true) return;

      final activated = await repo.confirmPlanPayment(
          linkId: linkId, elderId: elderId, carePlanId: planId);
      if (activated) {
        ref.invalidate(_subscriptionProvider(elderId));
        messenger.showSnackBar(
            SnackBar(content: Text('${plan['name']} is now active.')));
      } else {
        messenger.showSnackBar(const SnackBar(
            content: Text(
                "We couldn't confirm the payment yet. If you paid, try again "
                'in a moment.')));
      }
    } on FunctionException catch (e) {
      if (e.status == 503) {
        // Payments not configured — fall back to the demo checkout.
        if (!context.mounted) return;
        final paid = await DemoPaymentSheet.show(
          context,
          title: '${plan['name']} — monthly plan',
          amountLabel: currencyLabel,
          subtitle: 'Billed every month. Cancel anytime.',
        );
        if (!paid) return;
        try {
          await repo.subscribe(elderId: elderId, carePlanId: planId);
          ref.invalidate(_subscriptionProvider(elderId));
          messenger.showSnackBar(
              SnackBar(content: Text('${plan['name']} is now active.')));
        } catch (err) {
          messenger.showSnackBar(
              SnackBar(content: Text('Could not activate: $err')));
        }
      } else {
        messenger.showSnackBar(
            SnackBar(content: Text('Payment error: ${e.details ?? e.status}')));
      }
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('Could not start payment: $err')));
    }
  }
}
