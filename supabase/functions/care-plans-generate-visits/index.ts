// POST /functions/v1/care-plans-generate-visits
//
// PRD Part 9, Batch 6, Module 21. Weekly scheduled sweep: for each active
// subscription, generate that period's booking drafts against the plan's
// allocations. No user JWT — shared-secret header, same pattern as every
// other sweep.
//
// Deviation from the PRD's literal "invokes the existing bookings-create
// function": bookings-create requires a real user session (requireUser),
// which a scheduled job doesn't have. Rather than add a system-auth bypass
// to the user-facing booking function (a change to it, which this batch's
// cross-cutting section explicitly forbids), this sweep performs the same
// two validations bookings-create does — service belongs to the elder's
// region, and required_trust_tier comes from the service, never the
// client — and inserts the booking via the service-role client,
// attributing requested_by to the subscriber. The validation is reused in
// spirit (identical checks), just not over HTTP; reimplementing two lines
// is cleaner and safer than punching a hole in bookings-create's auth.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const CAREPLAN_VISITS_SWEEP_SHARED_SECRET = Deno.env.get("CAREPLAN_VISITS_SWEEP_SHARED_SECRET")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-careplan-visits-sweep-secret");
  if (providedSecret !== CAREPLAN_VISITS_SWEEP_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const now = new Date();

  const { data: subs, error } = await admin
    .from("elder_care_plan_subscriptions")
    .select("id, elder_id, care_plan_id, subscribed_by, elder_profiles(region_id)")
    .eq("status", "active");
  if (error) return errorResponse(error.message, 500);

  let created = 0;
  const results: Array<{ subscription_id: string; drafts: number }> = [];

  for (const sub of subs ?? []) {
    const elderRegion = (sub as unknown as { elder_profiles: { region_id: string } }).elder_profiles.region_id;

    const { data: allocations } = await admin
      .from("care_plan_allocations")
      .select("service_id, visits_per_period, period, service_catalog(region_id, requires_trust_tier, active)")
      .eq("care_plan_id", sub.care_plan_id);

    let draftsForSub = 0;
    for (const alloc of allocations ?? []) {
      // This sweep runs weekly; generate a week's worth. A 'month' period
      // allocation is spread by generating ceil(visits/4) each weekly run —
      // a simple, documented approximation, not a calendar-exact scheduler
      // (a per-elder-timezone, holiday-aware scheduler is named Phase 2+
      // work, consistent with the other sweeps' MVP simplifications).
      const svc = (alloc as unknown as { service_catalog: { region_id: string; requires_trust_tier: string; active: boolean } }).service_catalog;
      if (!svc?.active) continue;
      if (svc.region_id !== elderRegion) continue; // same region check bookings-create makes

      const perWeek = alloc.period === "week" ? alloc.visits_per_period : Math.ceil(alloc.visits_per_period / 4);
      for (let i = 0; i < perWeek; i++) {
        // Spread across the coming week; a human still confirms/reschedules
        // via the normal booking flow — these are 'requested' drafts.
        const scheduledAt = new Date(now.getTime() + (i + 1) * 24 * 60 * 60 * 1000).toISOString();
        const { error: insErr } = await admin.from("bookings").insert({
          region_id: elderRegion,
          elder_id: sub.elder_id,
          requested_by: sub.subscribed_by,
          service_id: alloc.service_id,
          required_trust_tier: svc.requires_trust_tier,
          scheduled_at: scheduledAt,
          status: "requested",
        });
        if (!insErr) {
          created++;
          draftsForSub++;
        }
      }
    }
    results.push({ subscription_id: sub.id, drafts: draftsForSub });
  }

  return jsonResponse({ created, subscriptions: results.length, results });
});
