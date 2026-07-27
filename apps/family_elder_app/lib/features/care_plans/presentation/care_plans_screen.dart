import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../payments/presentation/demo_payment_sheet.dart';
import '../../payments/presentation/payment_flow_screens.dart';
import '../data/care_plans_repository.dart';

final _plansProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, regionId) async {
  final client = ref.watch(supabaseClientProvider);
  return CarePlansRepository(client).fetchPlans(regionId);
});

/// How many real caregivers serve this elder's region. Zero means a plan
/// cannot currently be delivered there — see migration 0042.
final _coverageProvider =
    FutureProvider.family<int, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  final result = await client
      .rpc('region_real_caregiver_count', params: {'p_elder_id': elderId});
  return (result as num?)?.toInt() ?? 0;
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
                Text('Choose the right care for your loved ones',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: SetuSpacing.sm),
                const Text(
                  'Gentle, empathetic technology designed to keep your family '
                  'connected and safe, every step of the way.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SetuColors.mutedLight, height: 1.45),
                ),
                const SizedBox(height: SetuSpacing.lg),
                subAsync.when(
                  data: (sub) => sub == null
                      ? const SizedBox.shrink()
                      : _CurrentSubscriptionBanner(elderId: elderId, subscription: sub),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
                if (ref.watch(_coverageProvider(elderId)).asData?.value == 0)
                  const _NoCoverageNotice(),
                for (final plan in plans)
                  _PlanCard(
                    elderId: elderId,
                    plan: plan,
                    hasActiveSub: subAsync.asData?.value != null,
                    noCoverage:
                        ref.watch(_coverageProvider(elderId)).asData?.value == 0,
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: SetuSpacing.sm),
                  child: Text(
                    'A plan covers its included visits each month. Anything beyond the plan is billed per visit, as usual.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: SetuColors.mutedLight,
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: SetuSpacing.md),
                const _TrustBlock(
                    icon: Icons.lock_outline,
                    tint: SetuColors.peachLight,
                    title: 'Privacy First',
                    body:
                        'Your family\'s health data is encrypted and never shared. You own your data.'),
                const _TrustBlock(
                    icon: Icons.favorite_outline,
                    tint: SetuColors.lavenderLight,
                    title: 'Human Touch',
                    body:
                        'Our AI is backed by a team of certified health caregivers available 24/7.'),
                const _TrustBlock(
                    icon: Icons.accessibility_new_outlined,
                    tint: SetuColors.accentLight,
                    title: 'Elder-Centric',
                    body:
                        'Interfaces designed with high contrast and simple flows for every generation.'),
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

/// A reassurance block below the plans (Privacy First / Human Touch /
/// Elder-Centric), matching the Stitch premium-plans page.
class _TrustBlock extends StatelessWidget {
  const _TrustBlock({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: SetuSpacing.sm),
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        color: SetuColors.mutedLight, height: 1.4)),
              ],
            ),
          ),
        ],
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
  const _PlanCard({
    required this.elderId,
    required this.plan,
    required this.hasActiveSub,
    this.noCoverage = false,
  });

  final String elderId;
  final Map<String, dynamic> plan;
  final bool hasActiveSub;

  /// No real caregiver serves this region yet, so the visits this plan pays
  /// for cannot currently be delivered.
  final bool noCoverage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allocations = (plan['care_plan_allocations'] as List?) ?? [];
    final currency = plan['currency'] as String? ?? 'INR';
    final price = plan['monthly_price'] as num;
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: tint.withValues(alpha: popular ? 0.7 : 0.25),
            width: popular ? 2 : 1),
        boxShadow: popular
            ? [
                BoxShadow(
                    color: tint.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6)),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (popular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: tint,
              child: const Text('MOST POPULAR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ),
          Padding(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['name'] as String,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: SetuSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatMoney(price, currency: currency),
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(color: tint, fontWeight: FontWeight.w900)),
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
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.16),
                              shape: BoxShape.circle),
                          child: Icon(Icons.check, size: 14, color: tint),
                        ),
                        const SizedBox(width: SetuSpacing.sm),
                        Expanded(
                          child: Text(
                              '${alloc['visits_per_period']} × ${(alloc['service_catalog'] as Map<String, dynamic>?)?['name'] ?? ''} / ${alloc['period']}'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: SetuSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: tint,
                        padding: const EdgeInsets.symmetric(
                            vertical: SetuSpacing.md)),
                    onPressed: hasActiveSub
                        ? null
                        : () => _subscribe(context, ref,
                            currencyLabel: formatMoney(price, currency: currency)),
                    child: Text(hasActiveSub
                        ? 'Cancel current plan first'
                        : 'Choose ${plan['name']}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A plan only activates after a verified payment. Tries the real Razorpay
  /// hosted checkout; if payments aren't configured yet (503) it falls back to
  /// the clearly-labelled demo checkout so the flow is still demonstrable.
  Future<void> _subscribe(BuildContext context, WidgetRef ref,
      {required String currencyLabel}) async {
    // Nobody pays a monthly fee for visits that cannot happen without being
    // told first, in a box they have to actively dismiss. The banner above the
    // plans says the same thing, but a banner is scenery by the time somebody
    // has decided to buy.
    if (noCoverage) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No caregivers here yet'),
          content: Text(
            'SETU has not recruited any caregivers in this area yet, so the '
            'visits in this plan cannot be delivered right now. You would be '
            'charged $currencyLabel every month for them.\n\n'
            'Everything else — medicines, reminders, the timeline, check-ins '
            'and SOS — works without a plan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Don't subscribe"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Subscribe anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !context.mounted) return;
    }

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
        if (!context.mounted) return;
        final total = (plan['monthly_price'] as num?)?.toDouble() ?? 0;
        final txn = linkId;
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PaymentResultScreen(
            status: PaymentStatus.success,
            title: '${plan['name']} — monthly plan',
            amountLabel: currencyLabel,
            txnId: txn,
            onViewInvoice: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => InvoiceScreen(
                  invoiceNo: 'INV-${txn.substring(txn.length - 8).toUpperCase()}',
                  title: '${plan['name']} — monthly plan',
                  total: total,
                  method: 'Razorpay',
                  date: DateTime.now(),
                ),
              ),
            ),
          ),
        ));
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


/// Says, before anyone is asked to pay, that the visits a plan buys cannot
/// currently be delivered here.
///
/// Plans run ₹1,999–₹6,999 a month and Choose-plan opens a live Razorpay
/// checkout. What the money buys is caregiver visits, so in a region where no
/// real caregiver has been recruited it buys nothing — and renews anyway. The
/// sample profiles on the marketplace screen made this easy to miss: six
/// smiling cards with five-star ratings look exactly like coverage.
class _NoCoverageNotice extends StatelessWidget {
  const _NoCoverageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: SetuSpacing.md),
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: SetuColors.peachLight.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SetuColors.peachLight.withValues(alpha: 0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: SetuColors.peachLight, size: 22),
          SizedBox(width: SetuSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No caregivers in your area yet',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: SetuColors.peachLight)),
                SizedBox(height: 2),
                Text(
                  'A plan pays for caregiver visits, and SETU has not recruited '
                  'anyone here yet — so a subscription would renew each month '
                  'without visits behind it. Medicines, reminders, the '
                  'timeline, check-ins and SOS all work without a plan.',
                  style: TextStyle(
                      color: SetuColors.mutedLight, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
