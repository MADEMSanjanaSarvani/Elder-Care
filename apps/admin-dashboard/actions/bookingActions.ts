"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { adminClient } from "@/lib/supabase/admin";

export async function setBookingStatus(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const bookingId = formData.get("booking_id") as string;
  const status = formData.get("status") as string;

  const supabase = await createClient();
  const { error } = await supabase.from("bookings").update({ status }).eq("id", bookingId);
  if (error) throw new Error(error.message);

  await supabase.from("booking_events").insert({
    booking_id: bookingId,
    event_type: `admin_set_status_${status}`,
    actor_user_id: admin.id,
    payload: {},
  });

  revalidatePath(`/bookings/${bookingId}`);
  revalidatePath("/bookings");
}

/**
 * Issues a Razorpay refund for a booking's payment. Requires
 * `payments.provider_payment_ref`, which is only ever populated by the
 * payments-webhook Edge Function at capture time — a payment that was
 * never captured (still "created") has no payment id to refund and this
 * will fail loudly rather than silently no-op.
 */
export async function refundBookingPayment(formData: FormData) {
  const currentAdmin = await requireAdmin();
  requireScope(currentAdmin, "finance_ops");

  const bookingId = formData.get("booking_id") as string;

  const supabase = await createClient();
  const { data: payment, error } = await supabase
    .from("payments")
    .select("id, amount, provider_payment_ref, status")
    .eq("booking_id", bookingId)
    .single();
  if (error || !payment) throw new Error(error?.message ?? "No payment found for this booking");
  if (!payment.provider_payment_ref) {
    throw new Error("This payment has no captured Razorpay payment id yet — cannot refund");
  }

  const keyId = process.env.RAZORPAY_KEY_ID!;
  const keySecret = process.env.RAZORPAY_KEY_SECRET!;
  const basicAuth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");

  const refundRes = await fetch(`https://api.razorpay.com/v1/payments/${payment.provider_payment_ref}/refund`, {
    method: "POST",
    headers: { Authorization: `Basic ${basicAuth}`, "Content-Type": "application/json" },
    body: JSON.stringify({ amount: Math.round(payment.amount * 100) }),
  });
  if (!refundRes.ok) {
    throw new Error(`Razorpay refund failed: ${await refundRes.text()}`);
  }

  // Uses the service-role client only for this one write, since "refunded"
  // is a state no ordinary RLS-permitted admin write path covers yet —
  // narrower than adding a whole new column-specific policy for one action.
  const service = adminClient();
  await service.from("payments").update({ status: "refunded" }).eq("id", payment.id);
  await service.from("booking_events").insert({
    booking_id: bookingId,
    event_type: "refund_issued",
    actor_user_id: currentAdmin.id,
    payload: { payment_id: payment.id },
  });

  revalidatePath(`/bookings/${bookingId}`);
}
