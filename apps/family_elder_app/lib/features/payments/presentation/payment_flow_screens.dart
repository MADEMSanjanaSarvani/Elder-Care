import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setu_core/setu_core.dart';

/// Production payment-flow screens the functional audit called out: a result
/// screen (success / failed / pending), a GST invoice, and the cancellation &
/// refund policy. These are gateway-agnostic — they render whatever the
/// checkout produced, so wiring a real Razorpay result in later is a data
/// change, not a rewrite.
///
/// Restyled to match the Stitch "secure_payment" design's warm, trustworthy
/// card language. The mock itself shows an in-app "choose payment method +
/// enter card number" checkout form — SETU never collects card details
/// in-app; `createPlanPaymentLink` hands off to Razorpay's own PCI-compliant
/// hosted checkout page in the external browser (see care_plans_screen.dart
/// `_subscribe`). Building a look-alike in-app card form here would either
/// go nowhere (misleading) or imply we handle card data ourselves (we
/// don't), so it's intentionally not replicated — only the trust-badge
/// styling and summary-panel visual language carry over.

enum PaymentStatus { success, failed, pending }

class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({
    required this.status,
    required this.title,
    required this.amountLabel,
    this.txnId,
    this.onViewInvoice,
    this.onRetry,
    super.key,
  });

  final PaymentStatus status;
  final String title;
  final String amountLabel;
  final String? txnId;
  final VoidCallback? onViewInvoice;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (color, icon, heading, message) = switch (status) {
      PaymentStatus.success => (
          SetuColors.verifiedLight,
          Icons.check_rounded,
          'Payment successful',
          'Your payment for $title is complete.'
        ),
      PaymentStatus.failed => (
          SetuColors.sosLight,
          Icons.close_rounded,
          'Payment failed',
          "We couldn't complete your payment. You have not been charged."
        ),
      PaymentStatus.pending => (
          SetuColors.peachLight,
          Icons.hourglass_top_rounded,
          'Payment pending',
          'Your payment is being confirmed. This can take a moment.'
        ),
    };

    return Scaffold(
      backgroundColor: SetuColors.paperLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    color.withValues(alpha: 0.22),
                    color.withValues(alpha: 0.06),
                  ]),
                ),
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 42),
                  ),
                ),
              ),
              const SizedBox(height: SetuSpacing.xl),
              Text(heading,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: SetuSpacing.sm),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: SetuColors.mutedLight, height: 1.45, fontSize: 16)),
              const SizedBox(height: SetuSpacing.md),
              Text(amountLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color, fontWeight: FontWeight.w900)),
              if (txnId != null) ...[
                const SizedBox(height: 4),
                Text('Ref: $txnId',
                    style: const TextStyle(
                        color: SetuColors.mutedLight, fontSize: 12.5)),
              ],
              const Spacer(flex: 3),
              if (status == PaymentStatus.success && onViewInvoice != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onViewInvoice,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View invoice'),
                  ),
                ),
              if (status == PaymentStatus.failed && onRetry != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ),
              const SizedBox(height: SetuSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(height: SetuSpacing.md),
              const _SecuredBySetuBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small trust footer matching the Stitch "secure_payment" design's
/// "SECURED BY SETU" badge. The claim is true for SETU's real flow: card
/// details are entered on Razorpay's own hosted checkout page in the
/// external browser, never captured by this app.
class _SecuredBySetuBadge extends StatelessWidget {
  const _SecuredBySetuBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 14, color: SetuColors.mutedLight),
        const SizedBox(width: 6),
        Text('SECURED BY SETU',
            style: TextStyle(
                color: SetuColors.mutedLight,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// A simple GST-style invoice. Amounts are computed from the paid total; the
/// GST split (18%) is shown for transparency and can be tuned per service tax
/// treatment when the real gateway + tax config land.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({
    required this.invoiceNo,
    required this.title,
    required this.total,
    required this.method,
    required this.date,
    super.key,
  });

  final String invoiceNo;
  final String title;
  final double total;
  final String method;
  final DateTime date;

  String _r(double v) => formatMoney(v, paise: true);

  @override
  Widget build(BuildContext context) {
    final base = total / 1.18; // total is GST-inclusive
    final gst = total - base;
    final body = 'SETU — Tax Invoice\n'
        'Invoice: $invoiceNo\n'
        'Date: ${date.day}/${date.month}/${date.year}\n'
        'Item: $title\n'
        'Taxable value: ${_r(base)}\n'
        'GST (18%): ${_r(gst)}\n'
        'Total paid: ${_r(total)}\n'
        'Method: $method';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy invoice',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: body));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Invoice copied to clipboard.')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          Row(
            children: [
              Image.asset('assets/icon/icon.png', width: 40, height: 40),
              const SizedBox(width: SetuSpacing.sm),
              Text('SETU',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: SetuColors.accentLight,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('TAX INVOICE',
                  style: TextStyle(
                      color: SetuColors.mutedLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: SetuSpacing.lg),
          Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              color: SetuColors.paperRaisedLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SetuColors.borderLight),
            ),
            child: Column(
              children: [
                _row('Invoice no.', invoiceNo),
                _row('Date', '${date.day}/${date.month}/${date.year}'),
                _row('Payment method', method),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),
          Text('SUMMARY',
              style: TextStyle(
                  color: SetuColors.mutedLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(height: SetuSpacing.sm),
          Container(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            decoration: BoxDecoration(
              color: SetuColors.accentLight.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SetuColors.accentLight.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: SetuSpacing.md),
                _row('Taxable value', _r(base)),
                _row('GST (18%)', _r(gst)),
                Divider(height: SetuSpacing.lg, color: SetuColors.borderLight),
                Row(
                  children: [
                    const Text('Total paid',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const Spacer(),
                    Text(_r(total),
                        style: const TextStyle(
                            color: SetuColors.accentLight,
                            fontWeight: FontWeight.w900,
                            fontSize: 20)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.xl),
          const Center(
            child: Text('Thank you for trusting SETU with your family’s care.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SetuColors.mutedLight)),
          ),
          const SizedBox(height: SetuSpacing.md),
          const _SecuredBySetuBadge(),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: SetuColors.mutedLight)),
            const Spacer(),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class CancellationPolicyScreen extends StatelessWidget {
  const CancellationPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = <(String, String)>[
      (
        'Free cancellation window',
        'Cancel a caregiver visit more than 2 hours before the scheduled time for a full refund to your original payment method or SETU credit.'
      ),
      (
        'Late cancellation',
        'Cancelling within 2 hours may retain a portion to cover the caregiver’s committed time. The exact amount is shown before you confirm.'
      ),
      (
        'Caregiver no-show',
        'If a caregiver does not arrive, you receive a full refund plus a goodwill credit — automatically, no request needed.'
      ),
      (
        'Subscriptions',
        'Monthly plans can be cancelled anytime and stay active until the end of the paid period. No partial-month refunds unless required by law.'
      ),
      (
        'Refund timelines',
        'Approved refunds reach your original payment method within 5–7 business days; SETU credit is instant.'
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Cancellation & Refund Policy')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          for (final (t, b) in items) ...[
            Container(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              decoration: BoxDecoration(
                color: SetuColors.paperRaisedLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SetuColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(b,
                      style: const TextStyle(
                          color: SetuColors.mutedLight, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: SetuSpacing.md),
          ],
        ],
      ),
    );
  }
}
