import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// A stand-in checkout for the pilot. There is no live payment gateway wired
/// yet (Razorpay/UPI comes with the merchant account + keys), so this sheet
/// makes the *flow* real and honest — you confirm a payment before anything
/// activates — while being explicit that no money is actually charged. When
/// the real gateway lands, only this sheet is swapped; callers stay the same.
///
/// Returns true when the user completes the (simulated) payment, false/null
/// if they dismiss it.
class DemoPaymentSheet {
  const DemoPaymentSheet._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String amountLabel,
    String? subtitle,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: SetuColors.paperRaisedLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PaymentBody(
        title: title,
        amountLabel: amountLabel,
        subtitle: subtitle,
      ),
    );
    return result ?? false;
  }
}

class _PaymentBody extends StatefulWidget {
  const _PaymentBody({
    required this.title,
    required this.amountLabel,
    this.subtitle,
  });

  final String title;
  final String amountLabel;
  final String? subtitle;

  @override
  State<_PaymentBody> createState() => _PaymentBodyState();
}

class _PaymentBodyState extends State<_PaymentBody> {
  bool _processing = false;
  String _method = 'upi';

  Future<void> _pay() async {
    setState(() => _processing = true);
    // Simulate the gateway round-trip so the flow feels real.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _methodTile(String value, IconData icon, String label) {
    final selected = _method == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _processing ? null : () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? SetuColors.accentLight.withValues(alpha: 0.08)
              : null,
          border: Border.all(
            color: selected ? SetuColors.accentLight : SetuColors.borderLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? SetuColors.accentLight
                    : SetuColors.mutedLight),
            const SizedBox(width: SetuSpacing.md),
            Expanded(child: Text(label)),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? SetuColors.accentLight : SetuColors.borderLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: SetuSpacing.lg,
        right: SetuSpacing.lg,
        top: SetuSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + SetuSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!,
                style: const TextStyle(color: SetuColors.mutedLight)),
          ],
          const SizedBox(height: SetuSpacing.md),
          Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              color: SetuColors.accentLight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Subtotal',
                        style: TextStyle(color: SetuColors.mutedLight)),
                    const Spacer(),
                    Text(widget.amountLabel,
                        style: const TextStyle(color: SetuColors.mutedLight)),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Text('Platform fee',
                        style: TextStyle(color: SetuColors.mutedLight)),
                    Spacer(),
                    Text('FREE',
                        style: TextStyle(
                            color: SetuColors.verifiedLight,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const Divider(height: SetuSpacing.lg),
                Row(
                  children: [
                    Text('Total to pay',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(widget.amountLabel,
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: SetuColors.accentLight,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),
          Text('Pay using', style: theme.textTheme.titleMedium),
          const SizedBox(height: SetuSpacing.sm),
          _methodTile('upi', Icons.account_balance_wallet_outlined,
              'UPI (GPay, PhonePe, Paytm)'),
          const SizedBox(height: SetuSpacing.sm),
          _methodTile('card', Icons.credit_card, 'Card'),
          const SizedBox(height: SetuSpacing.sm),
          _methodTile('netbanking', Icons.account_balance_outlined,
              'Net banking'),
          const SizedBox(height: SetuSpacing.lg),
          FilledButton.icon(
            onPressed: _processing ? null : _pay,
            icon: Icon(_processing ? Icons.hourglass_top : Icons.lock_outline),
            label: Text(_processing
                ? 'Processing…'
                : 'Pay Securely · ${widget.amountLabel}'),
          ),
          const SizedBox(height: SetuSpacing.md),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined,
                  size: 15, color: SetuColors.verifiedLight),
              SizedBox(width: 6),
              Text('Secured by SETU · your data is encrypted',
                  style: TextStyle(
                      color: SetuColors.mutedLight, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: SetuSpacing.xs),
          const Center(
            child: Text(
              'Demo checkout — no real payment is charged yet.',
              style: TextStyle(color: SetuColors.mutedLight, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
