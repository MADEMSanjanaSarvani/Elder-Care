import 'consent_category.dart';

enum ConsentGrantSource {
  elderApp('elder_app'),
  documentedGuardianProcess('documented_guardian_process');

  const ConsentGrantSource(this.wireValue);

  final String wireValue;

  static ConsentGrantSource fromWire(String value) {
    return ConsentGrantSource.values.firstWhere((s) => s.wireValue == value);
  }
}

/// A single row from `consent_grants` — one elder, one family member, one
/// category, revocable independently of the others (PRD Part 1 §04).
class ConsentGrant {
  const ConsentGrant({
    required this.elderId,
    required this.familyUserId,
    required this.category,
    required this.granted,
    required this.grantedVia,
    this.grantedAt,
    this.revokedAt,
  });

  final String elderId;
  final String familyUserId;
  final ConsentCategory category;
  final bool granted;
  final ConsentGrantSource grantedVia;
  final DateTime? grantedAt;
  final DateTime? revokedAt;

  bool get isActive => granted && revokedAt == null;

  factory ConsentGrant.fromJson(Map<String, dynamic> json) {
    return ConsentGrant(
      elderId: json['elder_id'] as String,
      familyUserId: json['family_user_id'] as String,
      category: ConsentCategory.fromWire(json['category'] as String),
      granted: json['granted'] as bool,
      grantedVia: ConsentGrantSource.fromWire(json['granted_via'] as String),
      grantedAt: json['granted_at'] == null
          ? null
          : DateTime.parse(json['granted_at'] as String),
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.parse(json['revoked_at'] as String),
    );
  }
}
