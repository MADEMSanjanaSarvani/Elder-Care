import 'package:supabase_flutter/supabase_flutter.dart';

/// Care Plans & Subscriptions (PRD Part 9, Batch 6, Module 21). Plans are
/// a public catalog; subscribing/pausing are plain RLS-guarded writes.
/// Billing charges are read-only (written by the billing-run sweep) and
/// billing-consent-gated for family, so a family member without billing
/// consent simply gets nothing back.
class CarePlansRepository {
  CarePlansRepository(this._client);

  final SupabaseClient _client;

  /// The tier ladder with each plan's allocations, so the UI can show
  /// "what's included" per tier.
  Future<List<Map<String, dynamic>>> fetchPlans(String regionId) async {
    return _client
        .from('care_plans')
        .select('id, code, name, description, monthly_price, currency, '
            'care_plan_allocations(visits_per_period, period, service_catalog(name))')
        .eq('region_id', regionId)
        .eq('active', true)
        .order('monthly_price');
  }

  Future<Map<String, dynamic>?> fetchActiveSubscription(String elderId) async {
    return _client
        .from('elder_care_plan_subscriptions')
        .select('id, status, started_at, paused_until, care_plans(name, monthly_price, currency)')
        .eq('elder_id', elderId)
        .inFilter('status', ['active', 'paused'])
        .maybeSingle();
  }

  Future<void> subscribe({required String elderId, required String carePlanId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    await _client.from('elder_care_plan_subscriptions').insert({
      'elder_id': elderId,
      'care_plan_id': carePlanId,
      'subscribed_by': userId,
    });
  }

  Future<void> setStatus(String subscriptionId, String status) async {
    await _client.from('elder_care_plan_subscriptions').update({
      'status': status,
      if (status == 'cancelled') 'cancelled_at': DateTime.now().toIso8601String(),
    }).eq('id', subscriptionId);
  }

  /// Creates a Razorpay hosted payment link for a plan. Throws a
  /// FunctionException with status 503 when payments aren't configured yet
  /// (the UI then falls back to the demo checkout).
  Future<Map<String, dynamic>> createPlanPaymentLink({
    required String elderId,
    required String carePlanId,
  }) async {
    final res = await _client.functions.invoke('payments-plan-link',
        body: {'elder_id': elderId, 'care_plan_id': carePlanId});
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Verifies the payment with Razorpay server-side and activates the plan.
  /// Returns true once activated, false if the payment isn't confirmed yet.
  Future<bool> confirmPlanPayment({
    required String linkId,
    required String elderId,
    required String carePlanId,
  }) async {
    final res = await _client.functions.invoke('payments-plan-confirm', body: {
      'link_id': linkId,
      'elder_id': elderId,
      'care_plan_id': carePlanId,
    });
    return (res.data as Map)['activated'] == true;
  }

  Future<List<Map<String, dynamic>>> fetchCharges(String subscriptionId) async {
    return _client
        .from('care_plan_charges')
        .select('period_start, period_end, amount, currency, status')
        .eq('subscription_id', subscriptionId)
        .order('period_start', ascending: false);
  }
}
