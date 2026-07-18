enum CaregiverType {
  clinical('clinical'),
  nonClinical('non_clinical');

  const CaregiverType(this.wireValue);

  final String wireValue;

  static CaregiverType fromWire(String value) {
    return CaregiverType.values.firstWhere((t) => t.wireValue == value);
  }
}

/// Mirrors the Postgres `trust_tier` enum (PRD Part 1 §04, Part 2 §11).
/// Order matters: index reflects rank, used for "does this caregiver
/// qualify for this job" comparisons on the client side (the server-side
/// `meetsRequiredTier` in the Edge Functions is the actual enforcement).
enum TrustTier {
  probationary('probationary'),
  standard('standard'),
  clinicalVerified('clinical_verified');

  const TrustTier(this.wireValue);

  final String wireValue;

  bool meets(TrustTier required) => index >= required.index;

  static TrustTier fromWire(String value) {
    return TrustTier.values.firstWhere((t) => t.wireValue == value);
  }
}

class Caregiver {
  const Caregiver({
    required this.id,
    required this.caregiverType,
    required this.trustTier,
    this.active = true,
    this.displayName,
  });

  final String id;
  final CaregiverType caregiverType;
  final TrustTier trustTier;

  /// Whether the caregiver has been activated by an admin. A freshly
  /// self-registered caregiver is inactive until verification completes.
  final bool active;
  final String? displayName;

  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      id: json['id'] as String,
      caregiverType: CaregiverType.fromWire(json['caregiver_type'] as String),
      trustTier: TrustTier.fromWire(json['trust_tier'] as String),
      active: json['active'] as bool? ?? true,
      displayName: json['display_name'] as String?,
    );
  }
}
