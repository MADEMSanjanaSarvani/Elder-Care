import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";
import { reviewClinicImport } from "@/actions/clinicImports";

function statusTone(status: string) {
  if (status === "promoted") return "good" as const;
  if (status === "rejected") return "critical" as const;
  return "warning" as const;
}

/**
 * Review queue for clinics pulled in by `clinics-import-places`.
 *
 * Nothing an import stages is ever shown to a family. A row sits here until
 * a person decides it is real, in the service area, and somewhere they would
 * send an elderly parent — because the cost of a wrong listing here is not a
 * bad search result, it is an 80-year-old driven across the city to a clinic
 * that closed.
 *
 * Promoting creates the facility record only. The doctors who sit there, and
 * their consent to be listed, still come from a phone call.
 */
export default async function ClinicImportsPage() {
  const admin = await requireAdmin();
  requireScope(admin, "verification_agent");

  const supabase = await createClient();
  const { data: imports, error } = await supabase
    .from("clinic_imports")
    .select("*")
    .order("status", { ascending: true })
    .order("created_at", { ascending: false })
    .limit(200);

  if (error) {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">
        Could not load the import queue: {error.message}
      </div>
    );
  }

  const rows = imports ?? [];
  const pending = rows.filter((r) => r.status === "pending");
  const reviewed = rows.filter((r) => r.status !== "pending");

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Clinic imports</h1>
        <p className="mt-1 max-w-2xl text-sm text-slate-600">
          Hospitals and clinics staged from Google Places. Promote the ones you
          would send someone&apos;s parent to. Promoting adds the facility only —
          the doctors who sit there, and their consent to be listed, come from a
          phone call.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
          Awaiting review ({pending.length})
        </h2>
        {pending.length === 0 ? (
          <p className="rounded-lg border border-dashed border-slate-300 p-6 text-center text-sm text-slate-500">
            Nothing waiting. Run the <code>clinics-import-places</code> function
            for a city to stage more.
          </p>
        ) : (
          <ul className="space-y-3">
            {pending.map((row) => (
              <li
                key={row.id}
                className="rounded-lg border border-slate-200 bg-white p-4"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="font-medium text-slate-900">{row.name}</p>
                    {row.address && (
                      <p className="mt-0.5 text-sm text-slate-600">
                        {row.address}
                      </p>
                    )}
                    <p className="mt-1 text-xs text-slate-500">
                      {row.phone ?? "No phone listed"} · from {row.source}
                    </p>
                  </div>
                  {row.lat && row.lng && (
                    <a
                      className="shrink-0 text-sm font-medium text-sky-700 underline"
                      href={`https://www.google.com/maps/search/?api=1&query=${row.lat},${row.lng}`}
                      target="_blank"
                      rel="noreferrer"
                    >
                      View on map
                    </a>
                  )}
                </div>

                <form action={reviewClinicImport} className="mt-3 flex flex-wrap items-center gap-2">
                  <input type="hidden" name="import_id" value={row.id} />
                  <input
                    type="text"
                    name="review_note"
                    placeholder="Note (optional)"
                    className="min-w-0 flex-1 rounded-md border border-slate-300 px-3 py-1.5 text-sm"
                  />
                  <button
                    type="submit"
                    name="decision"
                    value="promote"
                    className="rounded-md bg-emerald-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-emerald-700"
                  >
                    Promote
                  </button>
                  <button
                    type="submit"
                    name="decision"
                    value="reject"
                    className="rounded-md border border-slate-300 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50"
                  >
                    Reject
                  </button>
                </form>
              </li>
            ))}
          </ul>
        )}
      </section>

      {reviewed.length > 0 && (
        <section>
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
            Already reviewed
          </h2>
          <ul className="divide-y divide-slate-200 rounded-lg border border-slate-200 bg-white">
            {reviewed.map((row) => (
              <li
                key={row.id}
                className="flex flex-wrap items-center justify-between gap-2 px-4 py-3"
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-slate-900">
                    {row.name}
                  </p>
                  {row.review_note && (
                    <p className="truncate text-xs text-slate-500">
                      {row.review_note}
                    </p>
                  )}
                </div>
                <StatusPill label={row.status} tone={statusTone(row.status)} />
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
