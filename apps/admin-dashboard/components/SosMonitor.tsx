"use client";

import { useEffect, useState } from "react";

import { createClient } from "@/lib/supabase/client";
import { resolveSosEvent, fileIncidentReport } from "@/actions/sosActions";
import { StatusPill } from "./StatusPill";
import type { SosStatus } from "@/lib/types";

export interface SosEventRow {
  id: string;
  elder_id: string;
  elder_name: string | null;
  status: SosStatus;
  ack_108_shown_at: string | null;
  family_notified_at: string | null;
  created_at: string;
  notes: string | null;
}

export interface IncidentReport {
  emergency_services_engaged: boolean;
  outcome_summary: string;
  lessons_notes: string | null;
  filed_at: string;
}

function statusTone(status: SosStatus) {
  if (status === "resolved") return "good" as const;
  // Neutral, not "good": a cancelled alert is off the queue but it is not an
  // outcome anyone achieved, and an operator scanning for wins should not
  // read false alarms as them.
  if (status === "cancelled") return "neutral" as const;
  if (status === "triggered") return "critical" as const;
  return "warning" as const;
}

/**
 * Live feed via Supabase Realtime (PRD Part 2 §15). New rows and status
 * changes on sos_events push straight into this list — an ops operator
 * should never need to refresh the page to see a new emergency.
 */
export function SosMonitor({
  initialEvents,
  reports,
}: {
  initialEvents: SosEventRow[];
  reports: Record<string, IncidentReport>;
}) {
  const [events, setEvents] = useState(initialEvents);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel("sos-events-live")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "sos_events" },
        (payload) => {
          setEvents((current) => {
            const incoming = payload.new as Record<string, unknown>;
            if (payload.eventType === "DELETE") {
              return current.filter((event) => event.id !== (payload.old as { id: string }).id);
            }
            const existingIndex = current.findIndex((event) => event.id === incoming.id);
            const updated: SosEventRow = {
              id: incoming.id as string,
              elder_id: incoming.elder_id as string,
              elder_name: existingIndex >= 0 ? current[existingIndex].elder_name : null,
              status: incoming.status as SosStatus,
              ack_108_shown_at: incoming.ack_108_shown_at as string | null,
              family_notified_at: incoming.family_notified_at as string | null,
              created_at: incoming.created_at as string,
              notes: incoming.notes as string | null,
            };
            if (existingIndex >= 0) {
              const next = [...current];
              next[existingIndex] = updated;
              return next;
            }
            return [updated, ...current];
          });
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const active = events.filter((event) => event.status !== "resolved");
  const resolved = events.filter((event) => event.status === "resolved");

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="mb-3 text-sm font-medium uppercase tracking-wide text-muted">Active ({active.length})</h2>
        {active.length === 0 && <p className="text-sm text-muted">No active SOS events.</p>}
        <div className="flex flex-col gap-3">
          {active.map((event) => (
            <div key={event.id} className="rounded border border-sos/40 bg-sos/5 p-4">
              <div className="mb-2 flex items-center justify-between">
                <div className="font-medium">{event.elder_name ?? event.elder_id}</div>
                <StatusPill label={event.status.replace("_", " ")} tone={statusTone(event.status)} />
              </div>
              <div className="mb-3 text-xs text-muted">
                Triggered {new Date(event.created_at).toLocaleString()}
                {event.ack_108_shown_at ? " · 108 screen shown" : " · ⚠ 108 screen NOT confirmed shown"}
              </div>
              <form action={resolveSosEvent} className="flex items-center gap-2">
                <input type="hidden" name="sos_event_id" value={event.id} />
                <input
                  name="notes"
                  placeholder="Resolution notes"
                  className="flex-1 rounded border border-border bg-paper px-2 py-1 text-sm"
                />
                <button type="submit" className="rounded bg-verified px-3 py-1 text-sm font-medium text-white">
                  Mark resolved
                </button>
              </form>
            </div>
          ))}
        </div>
      </div>

      <div>
        <h2 className="mb-3 text-sm font-medium uppercase tracking-wide text-muted">Resolved ({resolved.length})</h2>
        <p className="-mt-2 mb-3 text-xs text-muted">
          Every resolved event needs one post-resolution incident report — the after-action record used
          for QA and drills (PRD Part 10, Module 25).
        </p>
        <div className="flex flex-col gap-2">
          {resolved.slice(0, 20).map((event) => (
            <div key={event.id} className="rounded border border-border bg-paper-raised p-3 text-sm">
              <span className="font-medium">{event.elder_name ?? event.elder_id}</span>{" "}
              <span className="text-muted">— {new Date(event.created_at).toLocaleString()}</span>
              {event.notes && <div className="mt-1 text-xs text-muted">{event.notes}</div>}
              <IncidentReportBlock eventId={event.id} report={reports[event.id]} />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/**
 * The one incident report per resolved event. Once filed it's read-only
 * here (the DB's unique constraint on sos_event_id is the real guarantee);
 * until then it shows the filing form. `filed_by` and the sos_operator
 * scope are enforced server-side, so this form carries no identity fields.
 */
function IncidentReportBlock({ eventId, report }: { eventId: string; report?: IncidentReport }) {
  if (report) {
    return (
      <div className="mt-2 rounded border border-verified/40 bg-verified/5 p-2 text-xs">
        <div className="font-medium text-verified">
          Incident report filed {new Date(report.filed_at).toLocaleString()}
        </div>
        <div className="mt-1">
          Emergency services {report.emergency_services_engaged ? "engaged" : "not engaged"}.
        </div>
        <div className="mt-1">{report.outcome_summary}</div>
        {report.lessons_notes && <div className="mt-1 text-muted">Lessons: {report.lessons_notes}</div>}
      </div>
    );
  }

  return (
    <form action={fileIncidentReport} className="mt-2 flex flex-col gap-2 rounded border border-border p-2">
      <input type="hidden" name="sos_event_id" value={eventId} />
      <label className="flex items-center gap-2 text-xs">
        <input type="checkbox" name="emergency_services_engaged" />
        Emergency services (108/EMS) were engaged
      </label>
      <textarea
        name="outcome_summary"
        required
        placeholder="What happened and how it was resolved"
        className="rounded border border-border bg-paper px-2 py-1 text-sm"
        rows={2}
      />
      <input
        name="lessons_notes"
        placeholder="Lessons / follow-ups (optional)"
        className="rounded border border-border bg-paper px-2 py-1 text-sm"
      />
      <button type="submit" className="self-start rounded bg-verified px-3 py-1 text-sm font-medium text-white">
        File incident report
      </button>
    </form>
  );
}
