/// How SETU writes money.
///
/// Prices were being rendered three different ways in three different places:
/// "INR 1200" on the care-plans screen, "₹1200.00" on the invoice, and
/// "INR 1200" again on booking. A family that sees a plan priced "INR 1200",
/// then a payment sheet saying "₹1,200.00", has to stop and work out whether
/// those are the same number. At the moment they are being asked to hand over
/// money, that hesitation is expensive.
///
/// Nobody in India writes "INR 1200" to a person. They write ₹1,200.
String formatMoney(num amount, {String currency = 'INR', bool paise = false}) {
  final symbol = _symbols[currency.toUpperCase()];
  // The sign goes outside the symbol: a refund reads "-₹1,200", never
  // "₹-1,200".
  final negative = amount < 0;
  final magnitude = negative ? -amount : amount;
  final value =
      paise ? magnitude.toStringAsFixed(2) : magnitude.round().toString();
  final grouped = _groupIndian(value);
  // An unknown currency keeps its ISO code rather than guessing a symbol —
  // showing ₹ next to a euro amount would be worse than showing "EUR".
  final body = symbol == null ? '$currency $grouped' : '$symbol$grouped';
  return negative ? '-$body' : body;
}

const _symbols = <String, String>{
  'INR': '₹',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
};

/// Indian digit grouping: 12,34,567 rather than 1,234,567.
///
/// Not a stylistic preference. A price grouped the Western way is read wrong
/// by people who group in lakhs — 1,200,000 and 12,00,000 are the same number
/// and only one of them is legible to the audience paying it.
String _groupIndian(String value) {
  final dot = value.indexOf('.');
  var whole = dot == -1 ? value : value.substring(0, dot);
  final fraction = dot == -1 ? '' : value.substring(dot);

  final negative = whole.startsWith('-');
  if (negative) whole = whole.substring(1);

  if (whole.length <= 3) return '${negative ? '-' : ''}$whole$fraction';

  // Last three digits stay together; everything above is grouped in twos.
  final last3 = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);

  return '${negative ? '-' : ''}${parts.join(',')},$last3$fraction';
}
