import { notFound } from "next/navigation";

import { requireAdmin, requireScope, hasScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { logAdminRead } from "@/lib/audit";
import { StatusPill } from "@/components/StatusPill";
import { setBookingStatus, refundBookingPayment } from "@/actions/bookingActions";

export default async function BookingDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");
  const { id } = await params;

  const supabase = await createClient();
  const [{ data: booking }, { data: events }, { data: payment }] = await Promise.all([
    supabase.from("bookings").select("*, elder_profiles(display_name), service_catalog(name)").eq("id", id).single(),
    supabase.from("booking_events").select("*").eq("booking_id", id).order("created_at", { ascending: true }),
    supabase.from("payments").select("*").eq("booking_id", id).maybeSingle(),
  ]);

  if (!booking) notFound();

  // Read-path audit: an admin opened this elder's booking detail (which
  // exposes their name, service, and payment). Surfaces in the elder's
  // Privacy Centre via me-access-history's metadata.elder_id match.
  await logAdminRead({
    actorUserId: admin.id,
    resourceType: "booking",
    resourceId: booking.id,
    elderId: booking.elder_id,
  });

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">
        {(booking.elder_profiles as unknown as { display_name: string } | null)?.display_name} —{" "}
        {(booking.service_catalog as unknown as { name: string } | null)?.name}
      </h1>
      <p className="mb-6 text-sm text-muted">Scheduled {new Date(booking.scheduled_at).toLocaleString()}</p>

      <div className="mb-6 flex flex-wrap items-center gap-4">
        <StatusPill label={booking.status} tone={booking.status === "disputed" ? "critical" : "good"} />

        <form action={setBookingStatus} className="flex items-center gap-2">
          <input type="hidden" name="booking_id" value={booking.id} />
          <select name="status" defaultValue={booking.status} className="rounded border border-border bg-paper px-2 py-1 text-sm">
            <option value="requested">Requested</option>
            <option value="matched">Matched</option>
            <option value="confirmed">Confirmed</option>
            <option value="in_progress">In progress</option>
            <option value="completed">Completed</option>
            <option value="cancelled">Cancelled</option>
            <option value="disputed">Disputed</option>
          </select>
          <button type="submit" className="rounded bg-accent px-3 py-1 text-sm font-medium text-white">
            Update status
          </button>
        </form>

        {payment && hasScope(admin, "finance_ops") && payment.status === "captured" && (
          <form action={refundBookingPayment}>
            <input type="hidden" name="booking_id" value={booking.id} />
            <button type="submit" className="rounded border border-sos px-3 py-1 text-sm font-medium text-sos">
              Issue refund
            </button>
          </form>
        )}
      </div>

      {payment && (
        <div className="mb-6 rounded border border-border bg-paper-raised p-4 text-sm">
          <div className="mb-1 font-medium">Payment</div>
          <div className="text-muted">
            {payment.currency} {payment.amount} · <StatusPill label={payment.status} tone={payment.status === "captured" ? "good" : payment.status === "refunded" ? "neutral" : "warning"} />
          </div>
        </div>
      )}

      <h2 className="mb-3 text-sm font-medium uppercase tracking-wide text-muted">Event log</h2>
      <div className="flex flex-col gap-2">
        {events?.map((event) => (
          <div key={event.id} className="rounded border border-border bg-paper-raised p-3 text-sm">
            <span className="font-medium">{event.event_type}</span>{" "}
            <span className="text-muted">— {new Date(event.created_at).toLocaleString()}</span>
          </div>
        ))}
        {events?.length === 0 && <p className="text-sm text-muted">No events logged.</p>}
      </div>
    </div>
  );
}
