import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the `sos-trigger` Edge Function (PRD Part 2 §12). The function
/// itself refuses to run the notification cascade unless `ack108Shown` is
/// true — this repository exists so that check can never be skipped by a
/// future UI change that forgets to pass the flag.
class SosRepository {
  SosRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> trigger({
    required String elderId,
    required double lat,
    required double lng,
    required bool ack108Shown,
  }) async {
    final response = await _client.functions.invoke(
      'sos-trigger',
      body: {
        'elder_id': elderId,
        'lat': lat,
        'lng': lng,
        'ack_108_shown': ack108Shown
      },
    );
    if (response.status != 201) {
      throw StateError('SOS trigger failed: ${response.data}');
    }
    return response.data as Map<String, dynamic>;
  }
}
