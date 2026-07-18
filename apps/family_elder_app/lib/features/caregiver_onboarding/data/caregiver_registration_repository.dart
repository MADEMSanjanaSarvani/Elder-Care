import 'package:supabase_flutter/supabase_flutter.dart';

/// Files a caregiver's professional application via the caregiver-register
/// Edge Function (which creates the inactive caregiver row and queues it for
/// admin verification).
class CaregiverRegistrationRepository {
  CaregiverRegistrationRepository(this._client);

  final SupabaseClient _client;

  Future<void> submit(Map<String, dynamic> application) async {
    final res =
        await _client.functions.invoke('caregiver-register', body: application);
    if (res.status != 201) {
      throw StateError('${res.data}');
    }
  }
}
