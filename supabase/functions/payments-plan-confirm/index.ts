// POST /functions/v1/payments-plan-confirm
// body: { link_id: string, elder_id: uuid, care_plan_id: uuid }
//
// Verifies with Razorpay that the payment link was actually PAID, then
// activates the care-plan subscription. Verification is server-to-server
// against Razorpay's API (not the client's word), so a plan can never be
// activated without a real, confirmed payment. Idempotent: if a subscription
// already exists it just reports active.
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
    const { link_id, elder_id, care_plan_id } = await req.json();
    if (!link_id || !elder_id || !care_plan_id) {
      return errorResponse("link_id, elder_id and care_plan_id are required");
    }

    const admin = supabaseAdmin();

    // Ask Razorpay whether this link is paid.
    const auth = btoa(`${keyId}:${keySecret}`);
    const res = await fetch(`https://api.razorpay.com/v1/payment_links/${link_id}`, {
      headers: { "Authorization": `Basic ${auth}` },
    });
    const link = await res.json();
    if (!res.ok) {
      return errorResponse(link?.error?.description ?? "Could not verify payment", 502);
    }

    // Confirm the link is ours (matches the notes we set) and is paid.
    const notes = link.notes ?? {};
    if (notes.user_id !== user.id || notes.care_plan_id !== care_plan_id ||
        notes.elder_id !== elder_id) {
      return errorResponse("Payment does not match this request", 403);
    }
    if (link.status !== "paid") {
      return jsonResponse({ activated: false, status: link.status }, 200);
    }

    // Activate (idempotently).
    const { data: existing } = await admin
      .from("elder_care_plan_subscriptions")
      .select("id, status")
      .eq("elder_id", elder_id)
      .in("status", ["active", "paused"])
      .maybeSingle();

    if (!existing) {
      const { error: insErr } = await admin
        .from("elder_care_plan_subscriptions")
        .insert({ elder_id, care_plan_id, subscribed_by: user.id });
      if (insErr) return errorResponse(insErr.message, 500);
    }

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "care_plan_subscription",
      resource_id: elder_id,
      metadata: { event: "activated_via_payment", link_id },
    });

    return jsonResponse({ activated: true }, 200);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
