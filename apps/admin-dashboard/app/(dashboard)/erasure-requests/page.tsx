import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";
import { resolveErasureRequest } from "@/actions/erasureRequestActions";

function statusTone(status: string) {
  if (status === "completed") return "good" as const;
  if (status === "denied") return "critical" as const;
  return "warning" as const;
}

export default async function ErasureRequestsPage() {
  const admin = await requireAdmin();
  requireScope(admin, "super_admin");

  const supabase = await createClient();
  const { data: rows, error } = await supabase
    .from("erasure_requests")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(200);

  // No PostgREST embed here — erasure_requests has two FKs into profiles
  // (requested_by, reviewed_by), which makes an embedded select ambiguous
  // without pinning an exact constraint name. A second, keyed-by-id query
  // is simpler and avoids depending on an auto-generated constraint name.
  const requesterIds = Array.from(new Set((rows ?? []).map((r) => r.requested_by)));
  const { data: requesters } = requesterIds.length
    ? await supabase.from("profiles").select("id, display_name, phone").in("id", requesterIds)
    : { data: [] };
  const requesterById = new Map((requesters ?? []).map((p) => [p.id, p]));

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">DPDP erasure requests</h1>
      <p className="mb-6 text-sm text-muted">
        Filed via <code>POST /functions/v1/me-erasure-request</code> (PRD Part 2 §12/§13). Resolving
        a request here never triggers an automatic delete — payment records, audit trails, and SOS
        events often carry independent legal retention requirements that a blanket delete would
        violate, so any actual data removal is a manual step taken outside this form, documented in
        the notes below.
      </p>

      {error && <p className="text-sos">{error.message}</p>}
      {rows?.length === 0 && <p className="text-sm text-muted">No erasure requests filed.</p>}

      <div className="flex flex-col gap-4">
        {rows?.map((row) => {
          const requester = requesterById.get(row.requested_by);
          const isOpen = row.status === "pending" || row.status === "in_review";
          return (
            <div key={row.id} className="rounded border border-border bg-paper-raised p-5">
              <div className="mb-2 flex items-center justify-between text-sm">
                <span className="font-medium">
                  {requester?.display_name ?? row.requested_by} {requester?.phone ? `· ${requester.phone}` : ""}
                </span>
                <div className="flex items-center gap-3">
                  <span className="text-muted">{new Date(row.created_at).toLocaleString()}</span>
                  <StatusPill label={row.status} tone={statusTone(row.status)} />
                </div>
              </div>
              {row.reason && (
                <div className="mb-3 whitespace-pre-wrap rounded bg-paper p-3 text-sm">{row.reason}</div>
              )}
              {row.admin_notes && (
                <div className="mb-3 text-sm text-muted">
                  <span className="font-medium text-ink">Admin notes: </span>
                  {row.admin_notes}
                </div>
              )}

              {isOpen && (
                <form action={resolveErasureRequest} className="flex flex-col gap-2 sm:flex-row sm:items-end">
                  <input type="hidden" name="request_id" value={row.id} />
                  <div className="flex-1">
                    <label className="mb-1 block text-xs uppercase text-muted">Admin notes</label>
                    <textarea
                      name="admin_notes"
                      rows={2}
                      className="w-full rounded border border-border bg-paper px-2 py-1.5 text-sm"
                      placeholder="What was checked / why this outcome"
                    />
                  </div>
                  <div className="flex gap-2">
                    <button
                      type="submit"
                      name="status"
                      value="in_review"
                      className="rounded border border-border px-3 py-1.5 text-sm font-medium"
                    >
                      Mark in review
                    </button>
                    <button
                      type="submit"
                      name="status"
                      value="completed"
                      className="rounded bg-verified px-3 py-1.5 text-sm font-medium text-white"
                    >
                      Mark completed
                    </button>
                    <button
                      type="submit"
                      name="status"
                      value="denied"
                      className="rounded border border-sos px-3 py-1.5 text-sm font-medium text-sos"
                    >
                      Deny
                    </button>
                  </div>
                </form>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
