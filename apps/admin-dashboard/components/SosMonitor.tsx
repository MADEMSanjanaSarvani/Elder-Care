"use client";

import { useEffect, useState } from "react";

import { createClient } from "@/lib/supabase/client";
import { resolveSosEvent } from "@/actions/sosActions";
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

function statusTone(status: SosStatus) {
  if (status === "resolved") return "good" as const;
  if (status === "triggered") return "critical" as const;
  return "warning" as const;
}

/**
 * Live feed via Supabase Realtime (PRD Part 2 §15). New rows and status
 * changes on sos_events push straight into this list — an ops operator
 * should never need to refresh the page to see a new emergency.
 */
export function SosMonitor({ initialEvents }: { initialEvents: SosEventRow[] }) {
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
        <div className="flex flex-col gap-2">
          {resolved.slice(0, 20).map((event) => (
            <div key={event.id} className="rounded border border-border bg-paper-raised p-3 text-sm">
              <span className="font-medium">{event.elder_name ?? event.elder_id}</span>{" "}
              <span className="text-muted">— {new Date(event.created_at).toLocaleString()}</span>
              {event.notes && <div className="mt-1 text-xs text-muted">{event.notes}</div>}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
