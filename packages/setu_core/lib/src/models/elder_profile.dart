class ElderProfile {
  const ElderProfile({
    required this.id,
    required this.regionId,
    required this.displayName,
    required this.primaryLanguage,
    this.authUserId,
    this.dob,
  });

  final String id;
  final String regionId;
  final String? authUserId;
  final String displayName;
  final DateTime? dob;
  final String primaryLanguage;

  factory ElderProfile.fromJson(Map<String, dynamic> json) {
    return ElderProfile(
      id: json['id'] as String,
      regionId: json['region_id'] as String,
      authUserId: json['auth_user_id'] as String?,
      displayName: json['display_name'] as String,
      dob: json['dob'] == null ? null : DateTime.parse(json['dob'] as String),
      primaryLanguage: json['primary_language'] as String? ?? 'en',
    );
  }
}
