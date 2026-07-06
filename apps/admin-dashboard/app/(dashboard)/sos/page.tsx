import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { SosMonitor, type SosEventRow } from "@/components/SosMonitor";

export default async function SosMonitorPage() {
  const admin = await requireAdmin();
  requireScope(admin, "sos_operator");

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("sos_events")
    .select("*, elder_profiles(display_name)")
    .order("created_at", { ascending: false })
    .limit(100);

  const initialEvents: SosEventRow[] = (data ?? []).map((row) => ({
    id: row.id,
    elder_id: row.elder_id,
    elder_name: (row.elder_profiles as unknown as { display_name: string } | null)?.display_name ?? null,
    status: row.status,
    ack_108_shown_at: row.ack_108_shown_at,
    family_notified_at: row.family_notified_at,
    created_at: row.created_at,
    notes: row.notes,
  }));

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Live SOS monitor</h1>
      <p className="mb-6 text-sm text-muted">
        Updates in real time — no refresh needed. &quot;108 screen not confirmed shown&quot; would indicate the
        client bypassed the mandatory emergency-services-first flow (PRD Part 1 §04); that shouldn&apos;t be
        possible given how sos-trigger is implemented, so treat its appearance as a bug to investigate, not routine.
      </p>
      {error && <p className="text-sos">{error.message}</p>}
      <SosMonitor initialEvents={initialEvents} />
    </div>
  );
}
