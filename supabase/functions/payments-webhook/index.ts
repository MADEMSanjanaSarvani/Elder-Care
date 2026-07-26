// POST /functions/v1/payments-webhook
// Razorpay webhook receiver — no user JWT here, this is server-to-server.
// Every request's signature is verified against RAZORPAY_WEBHOOK_SECRET
// before anything in the payload is trusted (PRD Part 2 §13).
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const RAZORPAY_WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET")!;

async function verifySignature(rawBody: string, signatureHeader: string | null): Promise<boolean> {
  if (!signatureHeader) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(RAZORPAY_WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signatureBuffer = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const computedHex = Array.from(new Uint8Array(signatureBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return computedHex === signatureHeader;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  // Signature verification requires the exact raw request body — read it
  // as text first, and only parse JSON after the signature check passes.
  const rawBody = await req.text();
  const signature = req.headers.get("x-razorpay-signature");
  const isValid = await verifySignature(rawBody, signature);
  if (!isValid) return errorResponse("Invalid webhook signature", 401);

  const event = JSON.parse(rawBody);
  const admin = supabaseAdmin();

  if (event.event === "payment.captured") {
    const orderId = event.payload?.payment?.entity?.order_id;
    const paymentId = event.payload?.payment?.entity?.id;
    if (orderId) {
      // provider_payment_ref (the actual Razorpay payment id, distinct
      // from the order id) is what a refund action needs later — capture
      // it here since this is the only point that ever sees it.
      const { data: updated } = await admin
        .from("payments")
        .update({ status: "captured", captured_at: new Date().toISOString(), provider_payment_ref: paymentId })
        .eq("provider_order_ref", orderId)
        .select("id")
        .maybeSingle();
      if (updated) {
        await admin.from("audit_log").insert({
          actor_user_id: null,
          action: "write",
          resource_type: "payment",
          resource_id: updated.id,
          metadata: { via: "payments-webhook", event: "payment.captured" },
        });
      }
    }

    // Marking the payment captured is not enough on its own — until this
    // block existed, nothing was actually delivered by the webhook. A family
    // that paid and closed the browser got a captured payment row and an
    // unconfirmed visit or an inactive plan, and the purchase only completed
    // if they happened to return and tap "I've paid". Razorpay carries the
    // intent in the payment link's notes, so honour it here too. Both
    // branches are idempotent, because a webhook can and will be redelivered.
    const notes = event.payload?.payment?.entity?.notes ?? {};

    if (notes.purpose === "care_plan" && notes.elder_id && notes.care_plan_id) {
      const { data: existing } = await admin
        .from("elder_care_plan_subscriptions")
        .select("id")
        .eq("elder_id", notes.elder_id)
        .in("status", ["active", "paused"])
        .maybeSingle();
      if (!existing) {
        await admin.from("elder_care_plan_subscriptions").insert({
          elder_id: notes.elder_id,
          care_plan_id: notes.care_plan_id,
          subscribed_by: notes.user_id ?? null,
        });
        await admin.from("audit_log").insert({
          actor_user_id: notes.user_id ?? null,
          action: "write",
          resource_type: "care_plan_subscription",
          resource_id: notes.elder_id,
          metadata: { via: "payments-webhook", event: "plan_activated" },
        });
      }
    }

    if (notes.purpose === "booking" && notes.booking_id) {
      // Only advance from the pre-confirmation states, so a redelivered
      // webhook can never resurrect a completed or cancelled visit.
      await admin
        .from("bookings")
        .update({ status: "confirmed" })
        .eq("id", notes.booking_id)
        .in("status", ["requested", "matched"]);
      await admin.from("audit_log").insert({
        actor_user_id: notes.user_id ?? null,
        action: "write",
        resource_type: "booking",
        resource_id: notes.booking_id,
        metadata: { via: "payments-webhook", event: "booking_confirmed" },
      });
    }
  } else if (event.event === "payment.failed") {
    const orderId = event.payload?.payment?.entity?.order_id;
    if (orderId) {
      const { data: updated } = await admin
        .from("payments")
        .update({ status: "failed" })
        .eq("provider_order_ref", orderId)
        .select("id")
        .maybeSingle();
      if (updated) {
        await admin.from("audit_log").insert({
          actor_user_id: null,
          action: "write",
          resource_type: "payment",
          resource_id: updated.id,
          metadata: { via: "payments-webhook", event: "payment.failed" },
        });
      }
    }
  }
  // Other event types are intentionally ignored rather than erroring, per
  // Razorpay's own recommendation to acknowledge webhooks you don't handle.

  return jsonResponse({ received: true });
});
