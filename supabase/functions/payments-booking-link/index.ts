// POST /functions/v1/payments-booking-link
// body: { booking_id: uuid }
//
// Creates a Razorpay hosted Payment Link to pay for a booked visit and records
// a `payments` row (status 'created'). Amount is the service price, computed
// server-side. The app opens the returned short_url; payments-booking-confirm
// then verifies with Razorpay before marking the payment captured. Returns 503
// when Razorpay isn't configured so the client can degrade gracefully.
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
    const { booking_id } = await req.json();
    if (!booking_id) return errorResponse("booking_id is required");

    const admin = supabaseAdmin();
    const { data: booking, error } = await admin
      .from("bookings")
      .select("id, requested_by, service_catalog(name, base_price, currency, commission_pct)")
      .eq("id", booking_id)
      .single();
    if (error || !booking) return errorResponse("Booking not found", 404);
    if (booking.requested_by !== user.id) {
      return errorResponse("Not authorized to pay for this booking", 403);
    }
    const svc = booking.service_catalog as unknown as
      { name: string; base_price: number; currency: string; commission_pct: number } | null;
    if (!svc) return errorResponse("Service not found", 404);

    const amountPaise = Math.round(Number(svc.base_price) * 100);
    const auth = btoa(`${keyId}:${keySecret}`);
    const res = await fetch("https://api.razorpay.com/v1/payment_links", {
      method: "POST",
      headers: { "Authorization": `Basic ${auth}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        amount: amountPaise,
        currency: svc.currency ?? "INR",
        description: `SETU visit — ${svc.name}`,
        notes: { purpose: "booking", booking_id, user_id: user.id },
        reminder_enable: false,
      }),
    });
    const link = await res.json();
    if (!res.ok) {
      return errorResponse(link?.error?.description ?? "Payment link failed", 502);
    }

    const commission = Number((Number(svc.base_price) * (svc.commission_pct / 100)).toFixed(2));
    await admin.from("payments").insert({
      booking_id,
      family_user_id: user.id,
      amount: svc.base_price,
      currency: svc.currency ?? "INR",
      commission_amount: commission,
      provider: "razorpay",
      provider_order_ref: link.id,
      status: "created",
    });

    return jsonResponse({
      link_id: link.id,
      short_url: link.short_url,
      amount: amountPaise,
      currency: svc.currency ?? "INR",
    }, 201);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
