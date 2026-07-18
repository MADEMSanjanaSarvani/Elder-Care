// POST /functions/v1/payments-plan-link
// body: { elder_id: uuid, care_plan_id: uuid }
//
// Creates a Razorpay hosted Payment Link for a care-plan subscription and
// returns its short_url. The app opens that URL in the browser; after paying,
// the app calls payments-plan-confirm which verifies with Razorpay before
// activating the plan. Amount is derived server-side from the plan (never the
// client). Returns 503 if Razorpay keys aren't configured so the app can fall
// back to the demo checkout.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!keyId || !keySecret) return errorResponse("Payments are not configured yet", 503);

  try {
    const user = await requireUser(req);
    const { elder_id, care_plan_id } = await req.json();
    if (!elder_id || !care_plan_id) {
      return errorResponse("elder_id and care_plan_id are required");
    }

    const admin = supabaseAdmin();

    // Authorize: caller is the elder or an active linked family member.
    const { data: elder } = await admin
      .from("elder_profiles").select("id, auth_user_id").eq("id", elder_id).single();
    if (!elder) return errorResponse("Elder not found", 404);
    if (elder.auth_user_id !== user.id) {
      const { data: link } = await admin
        .from("family_links").select("id")
        .eq("elder_id", elder_id).eq("family_user_id", user.id)
        .eq("status", "active").maybeSingle();
      if (!link) return errorResponse("Not authorized for this elder", 403);
    }

    const { data: plan } = await admin
      .from("care_plans").select("name, monthly_price, currency").eq("id", care_plan_id).single();
    if (!plan) return errorResponse("Plan not found", 404);

    const amountPaise = Math.round(Number(plan.monthly_price) * 100);
    const auth = btoa(`${keyId}:${keySecret}`);
    const res = await fetch("https://api.razorpay.com/v1/payment_links", {
      method: "POST",
      headers: { "Authorization": `Basic ${auth}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        amount: amountPaise,
        currency: plan.currency ?? "INR",
        description: `CareHive — ${plan.name} (monthly)`,
        notes: { purpose: "care_plan", elder_id, care_plan_id, user_id: user.id },
        reminder_enable: false,
      }),
    });
    const link = await res.json();
    if (!res.ok) {
      return errorResponse(link?.error?.description ?? "Payment link failed", 502);
    }

    return jsonResponse({
      link_id: link.id,
      short_url: link.short_url,
      amount: amountPaise,
      currency: plan.currency ?? "INR",
    }, 201);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
