import Link from "next/link";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";

function statusTone(status: string) {
  if (status === "completed") return "good" as const;
  if (status === "disputed" || status === "cancelled") return "critical" as const;
  return "warning" as const;
}

export default async function BookingsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");
  const { status } = await searchParams;

  const supabase = await createClient();
  let query = supabase
    .from("bookings")
    .select("*, elder_profiles(display_name), service_catalog(name)")
    .order("scheduled_at", { ascending: false })
    .limit(50);
  if (status) query = query.eq("status", status);
  const { data: bookings, error } = await query;

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Bookings & disputes</h1>
      <div className="mb-6 flex gap-3 text-sm">
        <Link href="/bookings" className={!status ? "font-medium" : "text-muted"}>All</Link>
        <Link href="/bookings?status=disputed" className={status === "disputed" ? "font-medium text-sos" : "text-muted"}>
          Disputed
        </Link>
        <Link href="/bookings?status=completed" className={status === "completed" ? "font-medium" : "text-muted"}>
          Completed
        </Link>
      </div>

      {error && <p className="text-sos">{error.message}</p>}

      <div className="overflow-x-auto rounded border border-border bg-paper-raised">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase text-muted">
              <th className="px-4 py-3">Elder</th>
              <th className="px-4 py-3">Service</th>
              <th className="px-4 py-3">Scheduled</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {bookings?.map((booking) => (
              <tr key={booking.id} className="border-b border-border last:border-0">
                <td className="px-4 py-3">
                  {(booking.elder_profiles as unknown as { display_name: string } | null)?.display_name}
                </td>
                <td className="px-4 py-3">
                  {(booking.service_catalog as unknown as { name: string } | null)?.name}
                </td>
                <td className="px-4 py-3">{new Date(booking.scheduled_at).toLocaleString()}</td>
                <td className="px-4 py-3">
                  <StatusPill label={booking.status} tone={statusTone(booking.status)} />
                </td>
                <td className="px-4 py-3">
                  <Link href={`/bookings/${booking.id}`} className="text-xs underline text-muted hover:text-ink">
                    View
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
