enum FamilyLinkStatus {
  pending('pending'),
  active('active'),
  revoked('revoked');

  const FamilyLinkStatus(this.wireValue);

  final String wireValue;

  static FamilyLinkStatus fromWire(String value) {
    return FamilyLinkStatus.values.firstWhere((s) => s.wireValue == value);
  }
}

class FamilyLink {
  const FamilyLink({
    required this.id,
    required this.elderId,
    required this.familyUserId,
    required this.status,
    this.relationship,
  });

  final String id;
  final String elderId;
  final String familyUserId;
  final String? relationship;
  final FamilyLinkStatus status;

  factory FamilyLink.fromJson(Map<String, dynamic> json) {
    return FamilyLink(
      id: json['id'] as String,
      elderId: json['elder_id'] as String,
      familyUserId: json['family_user_id'] as String,
      relationship: json['relationship'] as String?,
      status: FamilyLinkStatus.fromWire(json['status'] as String),
    );
  }
}
