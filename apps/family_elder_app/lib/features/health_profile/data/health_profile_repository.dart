import 'package:supabase_flutter/supabase_flutter.dart';

/// Health Records Management (PRD Part 6, Batch 3, Module 12): the
/// two-tier split is the whole design — elder_health_profile is
/// emergency-relevant and caregiver-visible during an active booking/SOS,
/// elder_administrative_profile is never caregiver-visible. Both are
/// plain RLS-guarded reads/writes; the split is enforced by the two
/// tables' separate policies, not by this repository.
class HealthProfileRepository {
  HealthProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchHealthProfile(String elderId) async {
    return _client.from('elder_health_profile').select().eq('elder_id', elderId).maybeSingle();
  }

  Future<Map<String, dynamic>?> fetchAdministrativeProfile(String elderId) async {
    return _client
        .from('elder_administrative_profile')
        .select()
        .eq('elder_id', elderId)
        .maybeSingle();
  }

  Future<void> saveHealthProfile({
    required String elderId,
    required String updatedBy,
    String? bloodType,
    required List<String> allergies,
    required List<String> chronicConditions,
    String? emergencyMedicalNotes,
  }) async {
    await _client.from('elder_health_profile').upsert({
      'elder_id': elderId,
      'blood_type': bloodType,
      'allergies': allergies,
      'chronic_conditions': chronicConditions,
      'emergency_medical_notes': emergencyMedicalNotes,
      'updated_by': updatedBy,
    }, onConflict: 'elder_id');
  }

  Future<void> saveAdministrativeProfile({
    required String elderId,
    required String updatedBy,
    String? physicianName,
    String? physicianContact,
    String? insuranceProvider,
    String? insurancePolicyNumber,
  }) async {
    await _client.from('elder_administrative_profile').upsert({
      'elder_id': elderId,
      'primary_physician_name': physicianName,
      'primary_physician_contact': physicianContact,
      'insurance_provider': insuranceProvider,
      'insurance_policy_number': insurancePolicyNumber,
      'updated_by': updatedBy,
    }, onConflict: 'elder_id');
  }
}
