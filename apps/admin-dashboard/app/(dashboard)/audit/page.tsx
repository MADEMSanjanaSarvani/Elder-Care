import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export default async function AuditLogPage() {
  const admin = await requireAdmin();
  requireScope(admin, "super_admin");

  const supabase = await createClient();
  const { data: rows, error } = await supabase
    .from("audit_log")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(200);

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Audit log</h1>
      <p className="mb-2 text-sm text-muted">
        Metadata only by design (PRD Part 2 §16) — health content itself is never shown here, even to super_admin.
      </p>
      <p className="mb-6 rounded border border-warning/40 bg-warning/5 px-3 py-2 text-sm text-warning">
        Known gap: nothing currently writes to this table. Postgres has no native SELECT-trigger auditing, so
        logging &quot;who read what&quot; needs explicit instrumentation added at each sensitive read path — in the
        consumer apps&apos; repositories and in the Edge Functions alike. That instrumentation hasn&apos;t been
        built yet; this page is a real, working viewer over a table nothing populates.
      </p>

      {error && <p className="text-sos">{error.message}</p>}

      <div className="overflow-x-auto rounded border border-border bg-paper-raised">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase text-muted">
              <th className="px-4 py-3">When</th>
              <th className="px-4 py-3">Actor</th>
              <th className="px-4 py-3">Action</th>
              <th className="px-4 py-3">Resource</th>
            </tr>
          </thead>
          <tbody>
            {rows?.map((row) => (
              <tr key={row.id} className="border-b border-border last:border-0">
                <td className="px-4 py-3">{new Date(row.created_at).toLocaleString()}</td>
                <td className="px-4 py-3">{row.actor_user_id}</td>
                <td className="px-4 py-3">{row.action}</td>
                <td className="px-4 py-3">{row.resource_type} {row.resource_id}</td>
              </tr>
            ))}
            {rows?.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-muted">No entries.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
