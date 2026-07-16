// POST /functions/v1/care-plans-billing-run
//
// PRD Part 9, Batch 6, Module 21. Monthly scheduled sweep: charge each
// active subscription for the coming period and record it in
// care_plan_charges — NEVER in `payments`. Recurring subscription billing
// is a different Razorpay product surface (Subscriptions/recurring charge)
// than the Orders API payments-create-order uses, and lives in its own
// parallel table precisely to avoid blurring what `payments` means.
//
// No user JWT — shared-secret header.
//
// Not built: the actual Razorpay Subscriptions API call. Like payouts-run's
// RazorpayX calls, that needs real Razorpay subscription credentials this
// project doesn't have configured yet (a business item — the Subscriptions
// product must be enabled on the Razorpay account, distinct from the Orders
// product). So this sweep records a `pending` charge row per active
// subscription per period (idempotent on subscription_id + period_start);
// wiring the real recurring-charge API call and reconciling its webhook to
// flip pending -> paid/failed is the remaining integration step, flagged
// here rather than faked.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const CAREPLAN_BILLING_SWEEP_SHARED_SECRET = Deno.env.get("CAREPLAN_BILLING_SWEEP_SHARED_SECRET")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-careplan-billing-sweep-secret");
  if (providedSecret !== CAREPLAN_BILLING_SWEEP_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const now = new Date();
  const periodStart = now.toISOString().slice(0, 10);
  const periodEnd = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

  const { data: subs, error } = await admin
    .from("elder_care_plan_subscriptions")
    .select("id, care_plan_id, care_plans(monthly_price, currency)")
    .eq("status", "active");
  if (error) return errorResponse(error.message, 500);

  let charged = 0;
  const results: Array<{ subscription_id: string; outcome: "charged" | "already_charged" }> = [];

  for (const sub of subs ?? []) {
    // Idempotent: one charge per subscription per period_start.
    const { data: existing } = await admin
      .from("care_plan_charges")
      .select("id").eq("subscription_id", sub.id).eq("period_start", periodStart).maybeSingle();
    if (existing) {
      results.push({ subscription_id: sub.id, outcome: "already_charged" });
      continue;
    }

    const plan = (sub as unknown as { care_plans: { monthly_price: number; currency: string } }).care_plans;
    const { error: insErr } = await admin.from("care_plan_charges").insert({
      subscription_id: sub.id,
      period_start: periodStart,
      period_end: periodEnd,
      amount: plan.monthly_price,
      currency: plan.currency,
      status: "pending", // flips to paid/failed when the real Razorpay Subscriptions charge + webhook are wired
    });
    if (!insErr) {
      charged++;
      results.push({ subscription_id: sub.id, outcome: "charged" });
    }
  }

  return jsonResponse({ charged, results });
});
