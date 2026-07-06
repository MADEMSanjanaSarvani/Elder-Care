import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";

function statusTone(status: string) {
  if (status === "paid") return "good" as const;
  if (status === "failed") return "critical" as const;
  return "warning" as const;
}

export default async function PayoutsPage() {
  const admin = await requireAdmin();
  requireScope(admin, "finance_ops");

  const supabase = await createClient();
  const { data: payouts, error } = await supabase
    .from("caregiver_payouts")
    .select("*, caregivers(profiles(display_name))")
    .order("scheduled_for", { ascending: false })
    .limit(100);

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Payout reconciliation</h1>
      <p className="mb-2 text-sm text-muted">
        Every payout row created by otp-end when a visit is verified complete (PRD Part 1 §04).
      </p>
      <p className="mb-6 rounded border border-warning/40 bg-warning/5 px-3 py-2 text-sm text-warning">
        Read-only for now: retrying a failed payout via RazorpayX needs a fund_account_id (the caregiver&apos;s
        registered bank/UPI destination) that isn&apos;t modeled anywhere in the schema yet, and payouts-run — the
        job that would actually call RazorpayX — hasn&apos;t been built either (see supabase/README.md). Building a
        retry button here without that would just fail every time, so it&apos;s left out rather than faked.
      </p>

      {error && <p className="text-sos">{error.message}</p>}

      <div className="overflow-x-auto rounded border border-border bg-paper-raised">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase text-muted">
              <th className="px-4 py-3">Caregiver</th>
              <th className="px-4 py-3">Amount</th>
              <th className="px-4 py-3">Scheduled for</th>
              <th className="px-4 py-3">Status</th>
            </tr>
          </thead>
          <tbody>
            {payouts?.map((payout) => (
              <tr key={payout.id} className="border-b border-border last:border-0">
                <td className="px-4 py-3">
                  {(payout.caregivers as unknown as { profiles: { display_name: string } })?.profiles?.display_name}
                </td>
                <td className="px-4 py-3">{payout.currency} {payout.amount}</td>
                <td className="px-4 py-3">{new Date(payout.scheduled_for).toLocaleString()}</td>
                <td className="px-4 py-3">
                  <StatusPill label={payout.status} tone={statusTone(payout.status)} />
                </td>
              </tr>
            ))}
            {payouts?.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-muted">No payouts yet.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
