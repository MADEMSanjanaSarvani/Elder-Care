import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

// Care Analytics Dashboard (PRD Part 9, Batch 6, Module 23). Reads the
// is_admin()-gated wrapper views over the analytics materialized views —
// aggregate/statistical only, no PII, no health content. Refreshed on a
// schedule by the analytics-refresh Edge Function, so these reads are
// cheap and never compete with live transactional traffic.
export default async function AnalyticsPage() {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const supabase = await createClient();

  const [volume, utilization, ratings, suggestions] = await Promise.all([
    supabase.from("analytics_booking_volume").select("*").order("day", { ascending: false }).limit(30),
    supabase.from("analytics_caregiver_utilization").select("*").order("completed_bookings", { ascending: false }).limit(20),
    supabase.from("analytics_rating_trends").select("*").order("month", { ascending: false }).limit(12),
    supabase.from("analytics_suggestion_outcomes").select("*"),
  ]);

  const totalBookings = (volume.data ?? []).reduce((sum, r) => sum + Number(r.bookings ?? 0), 0);
  const completed = (volume.data ?? [])
    .filter((r) => r.status === "completed")
    .reduce((sum, r) => sum + Number(r.bookings ?? 0), 0);
  const cancelled = (volume.data ?? [])
    .filter((r) => r.status === "cancelled")
    .reduce((sum, r) => sum + Number(r.bookings ?? 0), 0);

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Care analytics</h1>
      <p className="mb-6 text-sm text-muted">
        Care-operation metrics from scheduled materialized views — aggregate only, never PII or health
        content. Distinct from product analytics (PostHog). Numbers reflect the last analytics refresh.
      </p>

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Stat label="Bookings (last 30 days by volume rows)" value={totalBookings} />
        <Stat label="Completed" value={completed} />
        <Stat label="Cancelled" value={cancelled} />
      </div>

      <Section title="Caregiver utilization (top 20)">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase text-muted">
              <th className="px-4 py-2">Caregiver</th>
              <th className="px-4 py-2">Completed</th>
              <th className="px-4 py-2">Total</th>
            </tr>
          </thead>
          <tbody>
            {(utilization.data ?? []).map((row, i) => (
              <tr key={i} className="border-b border-border last:border-0">
                <td className="px-4 py-2 font-mono text-xs">{row.caregiver_id}</td>
                <td className="px-4 py-2">{row.completed_bookings}</td>
                <td className="px-4 py-2">{row.total_bookings}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Section>

      <Section title="Rating trends (by month)">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase text-muted">
              <th className="px-4 py-2">Month</th>
              <th className="px-4 py-2">Average stars</th>
              <th className="px-4 py-2">Ratings</th>
            </tr>
          </thead>
          <tbody>
            {(ratings.data ?? []).map((row, i) => (
              <tr key={i} className="border-b border-border last:border-0">
                <td className="px-4 py-2">{row.month}</td>
                <td className="px-4 py-2">{row.average_stars}</td>
                <td className="px-4 py-2">{row.rating_count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Section>

      <Section title="AI suggestion outcomes">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase text-muted">
              <th className="px-4 py-2">Suggestion type</th>
              <th className="px-4 py-2">Status</th>
              <th className="px-4 py-2">Count</th>
            </tr>
          </thead>
          <tbody>
            {(suggestions.data ?? []).map((row, i) => (
              <tr key={i} className="border-b border-border last:border-0">
                <td className="px-4 py-2">{row.suggestion_type}</td>
                <td className="px-4 py-2">{row.status}</td>
                <td className="px-4 py-2">{row.suggestions}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Section>

      <p className="mt-6 text-xs text-muted">
        Scheduled-job health (reminder/check-in/payout/billing sweep success rates) is intentionally not
        shown here yet — there is no job-run-history table to aggregate from. Building it needs a
        job_runs table plus instrumentation in each sweep, flagged as real future work rather than
        faked from unrelated data.
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

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-6 overflow-x-auto rounded border border-border bg-paper-raised">
      <h2 className="border-b border-border px-4 py-3 text-sm font-semibold">{title}</h2>
      {children}
    </div>
  );
}
