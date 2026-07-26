import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

// Where SETU should open next, answered by the families who tried to use it
// there. Every row is someone who went to the trouble of adding a parent and
// then hit "we're not in your city yet" — which is a far better demand signal
// than a survey, because it cost them something to produce.
//
// Deliberately no names, emails or elder details: the operational question is
// "how many, and where", and a page that answers it doesn't need to identify
// anyone. Reaching out to a specific waiting family is a separate, deliberate
// act, not something to make casually browsable.
export default async function ExpansionPage() {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const supabase = await createClient();

  const [regionsRes, interestRes] = await Promise.all([
    supabase.from("regions").select("id, code, display_name, status"),
    supabase.from("region_interest").select("region_id, notified_at, created_at"),
  ]);

  const regions = regionsRes.data ?? [];
  const interest = interestRes.data ?? [];

  const byRegion = new Map<string, { waiting: number; notified: number; latest: string | null }>();
  for (const row of interest) {
    const key = row.region_id as string;
    const entry = byRegion.get(key) ?? { waiting: 0, notified: 0, latest: null };
    if (row.notified_at) entry.notified += 1;
    else entry.waiting += 1;
    const created = row.created_at as string | null;
    if (created && (!entry.latest || created > entry.latest)) entry.latest = created;
    byRegion.set(key, entry);
  }

  const rows = regions
    .map((region) => ({
      ...region,
      ...(byRegion.get(region.id as string) ?? { waiting: 0, notified: 0, latest: null }),
    }))
    // Most wanted first. Regions nobody has asked for still appear, at the
    // bottom, because "nobody asked" is itself the answer to a question ops
    // will otherwise ask again in a month.
    .sort((a, b) => b.waiting - a.waiting || String(a.display_name).localeCompare(String(b.display_name)));

  const totalWaiting = rows.reduce((sum, r) => sum + r.waiting, 0);
  const liveRegions = rows.filter((r) => r.status === "active").length;
  const regionsWithDemand = rows.filter((r) => r.waiting > 0 && r.status !== "active").length;
  const top = rows.find((r) => r.status !== "active" && r.waiting > 0);

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Expansion demand</h1>
      <p className="mb-6 text-sm text-muted">
        Families who added someone in a region SETU has not reached yet. The app promised each of them
        we would tell them when we arrive — <code>activate_region()</code> is what makes that true, and
        it refuses to run until the region has verified caregivers.
      </p>

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Stat label="Families waiting" value={totalWaiting} />
        <Stat label="Regions with demand" value={regionsWithDemand} />
        <Stat label="Regions live" value={liveRegions} />
      </div>

      {top ? (
        <div className="mb-6 rounded border border-border bg-paper-raised p-4 text-sm">
          Most wanted next: <strong>{String(top.display_name)}</strong> — {top.waiting}{" "}
          {top.waiting === 1 ? "family" : "families"} waiting. Onboarding caregivers there is what
          unblocks it; <code>select activate_region(&apos;{String(top.code)}&apos;)</code> refuses
          until at least one has cleared verification.
        </div>
      ) : (
        <div className="mb-6 rounded border border-border bg-paper-raised p-4 text-sm text-muted">
          Nobody is waiting outside the live regions yet. That is expected until the app is in real
          hands — this page fills itself in as families arrive.
        </div>
      )}

      <div className="mb-6 overflow-x-auto rounded border border-border bg-paper-raised">
        <h2 className="border-b border-border px-4 py-3 text-sm font-semibold">All regions</h2>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase text-muted">
              <th className="px-4 py-2">Region</th>
              <th className="px-4 py-2">Status</th>
              <th className="px-4 py-2">Waiting</th>
              <th className="px-4 py-2">Already told</th>
              <th className="px-4 py-2">Most recent</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={String(row.id)} className="border-b border-border last:border-0">
                <td className="px-4 py-2">{String(row.display_name)}</td>
                <td className="px-4 py-2">
                  <span
                    className={
                      row.status === "active"
                        ? "rounded-full bg-accent/15 px-2 py-0.5 text-xs text-accent"
                        : "rounded-full bg-border px-2 py-0.5 text-xs text-muted"
                    }
                  >
                    {String(row.status)}
                  </span>
                </td>
                <td className="px-4 py-2 tabular-nums">{row.waiting || "—"}</td>
                <td className="px-4 py-2 tabular-nums">{row.notified || "—"}</td>
                <td className="px-4 py-2 text-xs text-muted">
                  {row.latest ? new Date(row.latest).toLocaleDateString() : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="text-xs text-muted">
        Counts are one per person per region — adding a second parent in the same city is not a second
        vote, and treating it as one would overstate demand exactly where the decision is most
        expensive. Nobody is marked as told automatically; setting <code>notified_at</code> is a
        deliberate step taken when the announcement actually goes out.
      </p>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded border border-border bg-paper-raised p-4">
      <div className="text-2xl font-semibold tabular-nums">{value}</div>
      <div className="text-xs text-muted">{label}</div>
    </div>
  );
}
