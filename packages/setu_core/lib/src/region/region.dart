/// A region config row (PRD Part 2 §11 addendum, Part 3 §22).
///
/// Every client reads this once at startup instead of hardcoding
/// India/INR anywhere — see `RegionConfigClient`.
class Region {
  const Region({
    required this.code,
    required this.displayName,
    required this.countryCode,
    required this.currency,
    required this.taxProfile,
    required this.paymentProvider,
    required this.bgvProvider,
    required this.complianceProfile,
    required this.status,
  });

  final String code;
  final String displayName;
  final String countryCode;
  final String currency;
  final Map<String, dynamic> taxProfile;
  final String paymentProvider;
  final String bgvProvider;
  final String complianceProfile;
  final String status;

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      code: json['code'] as String,
      displayName: json['display_name'] as String,
      countryCode: json['country_code'] as String,
      currency: json['currency'] as String,
      taxProfile: Map<String, dynamic>.from(json['tax_profile'] as Map),
      paymentProvider: json['payment_provider'] as String,
      bgvProvider: json['bgv_provider'] as String,
      complianceProfile: json['compliance_profile'] as String,
      status: json['status'] as String,
    );
  }
}
