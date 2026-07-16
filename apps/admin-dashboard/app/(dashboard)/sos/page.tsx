import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { SosMonitor, type SosEventRow, type IncidentReport } from "@/components/SosMonitor";

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

  // Which resolved events already have a post-resolution incident report on
  // file, so the monitor can hide the form for those and show the summary.
  const { data: reportRows } = await supabase
    .from("sos_incident_reports")
    .select("sos_event_id, emergency_services_engaged, outcome_summary, lessons_notes, filed_at");
  const reports: Record<string, IncidentReport> = {};
  for (const r of reportRows ?? []) {
    reports[r.sos_event_id as string] = {
      emergency_services_engaged: r.emergency_services_engaged as boolean,
      outcome_summary: r.outcome_summary as string,
      lessons_notes: r.lessons_notes as string | null,
      filed_at: r.filed_at as string,
    };
  }

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Live SOS monitor</h1>
      <p className="mb-6 text-sm text-muted">
        Updates in real time — no refresh needed. &quot;108 screen not confirmed shown&quot; would indicate the
        client bypassed the mandatory emergency-services-first flow (PRD Part 1 §04); that shouldn&apos;t be
        possible given how sos-trigger is implemented, so treat its appearance as a bug to investigate, not routine.
      </p>
      {error && <p className="text-sos">{error.message}</p>}
      <SosMonitor initialEvents={initialEvents} reports={reports} />
    </div>
  );
}
