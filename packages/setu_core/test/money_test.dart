import 'package:flutter_test/flutter_test.dart';
import 'package:setu_core/setu_core.dart';

/// Indian digit grouping is easy to get subtly wrong and hard to notice — the
/// difference between ₹12,00,000 and ₹1,200,000 only shows up above a lakh,
/// which is exactly where getting it wrong costs the most.
void main() {
  group('formatMoney', () {
    test('uses the rupee symbol, not the ISO code', () {
      expect(formatMoney(1200), '₹1,200');
    });

    test('groups in lakhs, not thousands', () {
      expect(formatMoney(100000), '₹1,00,000');
      expect(formatMoney(1200000), '₹12,00,000');
      expect(formatMoney(10000000), '₹1,00,00,000');
    });

    test('leaves short amounts ungrouped', () {
      expect(formatMoney(0), '₹0');
      expect(formatMoney(99), '₹99');
      expect(formatMoney(999), '₹999');
      expect(formatMoney(1000), '₹1,000');
    });

    test('rounds by default and keeps paise only when asked', () {
      expect(formatMoney(1199.6), '₹1,200');
      expect(formatMoney(1199.6, paise: true), '₹1,199.60');
    });

    test('handles negatives, for refunds and adjustments', () {
      expect(formatMoney(-1200), '-₹1,200');
    });

    test('falls back to the ISO code for a currency with no symbol', () {
      // Showing ₹ next to an amount that is not rupees would be worse than
      // showing the code.
      expect(formatMoney(500, currency: 'AED'), 'AED 500');
    });
  });
}
