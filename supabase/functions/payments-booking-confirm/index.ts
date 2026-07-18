// POST /functions/v1/payments-booking-confirm
// body: { link_id: string, booking_id: uuid }
//
// Verifies server-to-server with Razorpay that the booking's payment link was
// actually PAID (and belongs to this user/booking), then marks the payments
// row captured. Idempotent. The webhook path (payments-webhook) still handles
// captures too; this gives the app an immediate, poll-based confirmation.
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
    const { link_id, booking_id } = await req.json();
    if (!link_id || !booking_id) {
      return errorResponse("link_id and booking_id are required");
    }

    const admin = supabaseAdmin();
    const auth = btoa(`${keyId}:${keySecret}`);
    const res = await fetch(`https://api.razorpay.com/v1/payment_links/${link_id}`, {
      headers: { "Authorization": `Basic ${auth}` },
    });
    const link = await res.json();
    if (!res.ok) {
      return errorResponse(link?.error?.description ?? "Could not verify payment", 502);
    }

    const notes = link.notes ?? {};
    if (notes.user_id !== user.id || notes.booking_id !== booking_id) {
      return errorResponse("Payment does not match this request", 403);
    }
    if (link.status !== "paid") {
      return jsonResponse({ paid: false, status: link.status }, 200);
    }

    // The link's paid amount references a Razorpay payment id we can store.
    const paymentId = Array.isArray(link.payments) && link.payments.length > 0
      ? link.payments[0].payment_id
      : null;

    await admin.from("payments")
      .update({
        status: "captured",
        captured_at: new Date().toISOString(),
        provider_payment_ref: paymentId,
      })
      .eq("provider_order_ref", link_id);

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "payment",
      resource_id: booking_id,
      metadata: { event: "captured_via_link", link_id },
    });

    return jsonResponse({ paid: true }, 200);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
