import 'package:supabase_flutter/supabase_flutter.dart';

import 'region.dart';

/// Reads the active region's config once at startup (PRD Part 2 §12).
///
/// Backed by the `regions-config` Edge Function rather than a raw table
/// select, so the contract can evolve independently of RLS as more
/// per-region fields are added across Phases 2-6.
class RegionConfigClient {
  RegionConfigClient(this._supabase);

  final SupabaseClient _supabase;

  Future<Region> fetch(String regionCode) async {
    final response = await _supabase.functions.invoke(
      'regions-config',
      queryParameters: {'code': regionCode},
      method: HttpMethod.get,
    );
    if (response.status != 200) {
      throw StateError(
          'Failed to load region config for $regionCode: ${response.status}');
    }
    return Region.fromJson(response.data as Map<String, dynamic>);
  }
}
