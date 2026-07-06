import 'caregiver.dart';

class SetuService {
  const SetuService({
    required this.id,
    required this.code,
    required this.name,
    required this.basePrice,
    required this.currency,
    required this.requiresTrustTier,
  });

  final String id;
  final String code;
  final String name;
  final double basePrice;
  final String currency;
  final TrustTier requiresTrustTier;

  factory SetuService.fromJson(Map<String, dynamic> json) {
    return SetuService(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      basePrice: (json['base_price'] as num).toDouble(),
      currency: json['currency'] as String,
      requiresTrustTier: TrustTier.fromWire(json['requires_trust_tier'] as String),
    );
  }
}
