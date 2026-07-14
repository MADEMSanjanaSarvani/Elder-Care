import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";
import { verifyPayoutAccount } from "@/actions/payoutActions";

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

  const { data: pendingAccounts, error: accountsError } = await supabase
    .from("caregiver_payout_accounts")
    .select("*, caregivers(profiles(display_name))")
    .eq("verified", false)
    .order("created_at", { ascending: true });

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Payout reconciliation</h1>
      <p className="mb-6 text-sm text-muted">
        Every payout row created by otp-end when a visit is verified complete (PRD Part 1 §04).
        The <code>payouts-run</code> Edge Function (triggered by n8n on a schedule, PRD Part 2 §15)
        batches every <code>scheduled</code> row here through RazorpayX — but only against a
        caregiver&apos;s bank/UPI account once it&apos;s verified below, so a typo&apos;d account
        number can&apos;t silently misroute money before a human looks at it.
      </p>

      {error && <p className="text-sos">{error.message}</p>}

      <h2 className="mb-3 text-lg font-medium">Pending bank/UPI verification</h2>
      {accountsError && <p className="mb-4 text-sos">{accountsError.message}</p>}
      {pendingAccounts?.length === 0 && (
        <p className="mb-6 text-sm text-muted">Nothing waiting on verification.</p>
      )}
      {pendingAccounts && pendingAccounts.length > 0 && (
        <div className="mb-8 overflow-x-auto rounded border border-border bg-paper-raised">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs uppercase text-muted">
                <th className="px-4 py-3">Caregiver</th>
                <th className="px-4 py-3">Account holder</th>
                <th className="px-4 py-3">Destination</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {pendingAccounts.map((account) => (
                <tr key={account.id} className="border-b border-border last:border-0">
                  <td className="px-4 py-3">
                    {(account.caregivers as unknown as { profiles: { display_name: string } })?.profiles?.display_name}
                  </td>
                  <td className="px-4 py-3">{account.account_holder_name}</td>
                  <td className="px-4 py-3">
                    {account.upi_id ?? `${account.bank_account_number} · ${account.ifsc}`}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <form action={verifyPayoutAccount}>
                      <input type="hidden" name="account_id" value={account.id} />
                      <button type="submit" className="rounded bg-verified px-3 py-1.5 text-sm font-medium text-white">
                        Verify
                      </button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <h2 className="mb-3 text-lg font-medium">Payouts</h2>
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
