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
      await admin
        .from("payments")
        .update({ status: "captured", captured_at: new Date().toISOString(), provider_payment_ref: paymentId })
        .eq("provider_order_ref", orderId);
    }
  } else if (event.event === "payment.failed") {
    const orderId = event.payload?.payment?.entity?.order_id;
    if (orderId) {
      await admin.from("payments").update({ status: "failed" }).eq("provider_order_ref", orderId);
    }
  }
  // Other event types are intentionally ignored rather than erroring, per
  // Razorpay's own recommendation to acknowledge webhooks you don't handle.

  return jsonResponse({ received: true });
});
