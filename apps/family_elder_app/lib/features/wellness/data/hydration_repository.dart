import 'package:supabase_flutter/supabase_flutter.dart';

class HydrationToday {
  const HydrationToday({required this.glasses, required this.target});

  final int glasses;
  final int target;

  double get progress => target == 0 ? 0 : (glasses / target).clamp(0, 1);
  bool get metTarget => glasses >= target;
}

/// Glasses of water, self-reported.
///
/// The only one of the design's four wellness metrics that needs no hardware,
/// and the one that matters most here: thirst sensation declines with age, so
/// the person least likely to notice they are dehydrated is exactly the person
/// this app is for.
class HydrationRepository {
  HydrationRepository(this._client);

  final SupabaseClient _client;

  /// Eight is the familiar number, not a clinical one. Overridden per elder,
  /// because someone on fluid restriction must not be nudged upward.
  static const defaultTarget = 8;

  Future<HydrationToday> today(String elderId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();

    final rows = await _client
        .from('hydration_logs')
        .select('id')
        .eq('elder_id', elderId)
        .gte('logged_at', start.toIso8601String());

    final profile = await _client
        .from('elder_health_profile')
        .select('daily_water_glasses')
        .eq('elder_id', elderId)
        .maybeSingle();

    return HydrationToday(
      glasses: (rows as List).length,
      target: (profile?['daily_water_glasses'] as num?)?.toInt() ?? defaultTarget,
    );
  }

  Future<void> logGlass(String elderId) async {
    await _client.from('hydration_logs').insert({
      'elder_id': elderId,
      'logged_by': _client.auth.currentUser?.id,
    });
  }

  /// Removes the most recent glass logged today.
  ///
  /// Exists because the commonest interaction on this card is a mis-tap by
  /// someone with unsteady hands, and a counter that only goes up quietly
  /// stops being true.
  Future<void> undoLastGlass(String elderId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final rows = await _client
        .from('hydration_logs')
        .select('id')
        .eq('elder_id', elderId)
        .gte('logged_at', start.toIso8601String())
        .order('logged_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return;
    await _client
        .from('hydration_logs')
        .delete()
        .eq('id', (list.first as Map)['id'] as String);
  }
}
