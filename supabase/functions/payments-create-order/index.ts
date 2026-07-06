// POST /functions/v1/payments-create-order
// body: { booking_id: uuid }
//
// PRD Part 1 decision: merchant-of-record — the family pays Setu directly
// via Razorpay's standard Orders API (not Route/marketplace), and Setu
// pays caregivers separately via RazorpayX Payouts (see otp-end). The
// Razorpay key secret lives only in this function's environment — the
// Flutter client never sees it (PRD Part 2 §13).
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID")!;
const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { booking_id } = await req.json();
    if (!booking_id) return errorResponse("booking_id is required");

    const admin = supabaseAdmin();
    const { data: booking, error } = await admin
      .from("bookings")
      .select("id, requested_by, service_catalog(base_price, currency, commission_pct)")
      .eq("id", booking_id)
      .single();
    if (error || !booking) return errorResponse("Booking not found", 404);
    if (booking.requested_by !== user.id) return errorResponse("Not authorized to pay for this booking", 403);

    const service = (booking as unknown as { service_catalog: { base_price: number; currency: string; commission_pct: number } }).service_catalog;
    const amountInSubunits = Math.round(service.base_price * 100); // Razorpay expects paise, not rupees

    const basicAuth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
    const orderRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: { Authorization: `Basic ${basicAuth}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        amount: amountInSubunits,
        currency: service.currency,
        receipt: booking_id,
        notes: { booking_id },
      }),
    });
    if (!orderRes.ok) {
      const text = await orderRes.text();
      return errorResponse(`Razorpay order creation failed: ${text}`, 502);
    }
    const order = await orderRes.json();

    const commissionAmount = Number((service.base_price * (service.commission_pct / 100)).toFixed(2));
    const { data: payment, error: insertErr } = await admin
      .from("payments")
      .insert({
        booking_id,
        family_user_id: user.id,
        amount: service.base_price,
        currency: service.currency,
        commission_amount: commissionAmount,
        provider: "razorpay",
        provider_ref: order.id,
        status: "created",
      })
      .select()
      .single();
    if (insertErr) return errorResponse(insertErr.message, 500);

    // razorpay_order_id + razorpay_key_id are what the Flutter client needs
    // to open Razorpay's checkout; the key *secret* never leaves this function.
    return jsonResponse({ payment, razorpay_order_id: order.id, razorpay_key_id: RAZORPAY_KEY_ID });
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
