// POST /functions/v1/payouts-run
//
// PRD Part 2 §15: batches every due caregiver_payouts row through
// RazorpayX. No user JWT here — this is meant to be triggered by n8n on a
// schedule, authenticated with a shared secret header instead of
// requireUser(), the same pattern as verification-idfy-webhook.
//
// A payout is only ever attempted against a caregiver_payout_accounts row
// that's been marked `verified` by finance_ops (migrations/0005) — an
// unverified account is skipped, not paid, so a typo'd bank/UPI detail
// can't silently misroute real money before a human has looked at it.
//
// One caregiver's failure never blocks the rest of the batch: each payout
// is processed and recorded independently, and a failure just leaves that
// row `failed` (visible on the Admin Dashboard payouts page) rather than
// throwing and abandoning everything still queued behind it.
//
// RazorpayX field/endpoint names below (contacts -> fund_accounts ->
// payouts) are per Razorpay's public X Payouts API docs as of this
// writing — like the IDfy webhook, confirm against Razorpay's current docs
// before relying on this in production; API surfaces do shift.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const RAZORPAYX_KEY_ID = Deno.env.get("RAZORPAYX_KEY_ID")!;
const RAZORPAYX_KEY_SECRET = Deno.env.get("RAZORPAYX_KEY_SECRET")!;
const RAZORPAYX_ACCOUNT_NUMBER = Deno.env.get("RAZORPAYX_ACCOUNT_NUMBER")!; // the platform's own RazorpayX current account: source of every payout
const PAYOUTS_RUN_SHARED_SECRET = Deno.env.get("PAYOUTS_RUN_SHARED_SECRET")!;

type PayoutAccount = {
  id: string;
  caregiver_id: string;
  account_holder_name: string;
  bank_account_number: string | null;
  ifsc: string | null;
  upi_id: string | null;
  razorpayx_contact_id: string | null;
  razorpayx_fund_account_id: string | null;
  verified: boolean;
};

function razorpayxHeaders(): HeadersInit {
  return {
    Authorization: `Basic ${btoa(`${RAZORPAYX_KEY_ID}:${RAZORPAYX_KEY_SECRET}`)}`,
    "Content-Type": "application/json",
  };
}

async function ensureFundAccount(
  admin: ReturnType<typeof supabaseAdmin>,
  account: PayoutAccount,
): Promise<string> {
  if (account.razorpayx_fund_account_id) return account.razorpayx_fund_account_id;

  let contactId = account.razorpayx_contact_id;
  if (!contactId) {
    const contactRes = await fetch("https://api.razorpay.com/v1/contacts", {
      method: "POST",
      headers: razorpayxHeaders(),
      body: JSON.stringify({
        name: account.account_holder_name,
        type: "employee",
        reference_id: account.caregiver_id,
      }),
    });
    if (!contactRes.ok) throw new Error(`RazorpayX contact creation failed: ${await contactRes.text()}`);
    contactId = (await contactRes.json()).id;
    await admin.from("caregiver_payout_accounts").update({ razorpayx_contact_id: contactId }).eq("id", account.id);
  }

  const fundAccountBody = account.upi_id
    ? { contact_id: contactId, account_type: "vpa", vpa: { address: account.upi_id } }
    : {
        contact_id: contactId,
        account_type: "bank_account",
        bank_account: {
          name: account.account_holder_name,
          ifsc: account.ifsc,
          account_number: account.bank_account_number,
        },
      };

  const fundRes = await fetch("https://api.razorpay.com/v1/fund_accounts", {
    method: "POST",
    headers: razorpayxHeaders(),
    body: JSON.stringify(fundAccountBody),
  });
  if (!fundRes.ok) throw new Error(`RazorpayX fund account creation failed: ${await fundRes.text()}`);
  const fundAccountId = (await fundRes.json()).id;
  await admin.from("caregiver_payout_accounts").update({ razorpayx_fund_account_id: fundAccountId }).eq("id", account.id);
  return fundAccountId;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-payouts-run-secret");
  if (providedSecret !== PAYOUTS_RUN_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const nowIso = new Date().toISOString();

  const { data: duePayouts, error } = await admin
    .from("caregiver_payouts")
    .select("id, caregiver_id, amount, currency")
    .eq("status", "scheduled")
    .lte("scheduled_for", nowIso);
  if (error) return errorResponse(error.message, 500);

  const results: Array<{ payout_id: string; outcome: "paid" | "processing" | "failed"; detail?: string }> = [];

  for (const payout of duePayouts ?? []) {
    try {
      const { data: account, error: acctErr } = await admin
        .from("caregiver_payout_accounts")
        .select("*")
        .eq("caregiver_id", payout.caregiver_id)
        .maybeSingle();
      if (acctErr) throw new Error(acctErr.message);
      if (!account) throw new Error("No payout account on file for this caregiver");
      if (!account.verified) throw new Error("Payout account not yet verified by finance_ops");

      const fundAccountId = await ensureFundAccount(admin, account as PayoutAccount);

      const payoutRes = await fetch("https://api.razorpay.com/v1/payouts", {
        method: "POST",
        headers: razorpayxHeaders(),
        body: JSON.stringify({
          account_number: RAZORPAYX_ACCOUNT_NUMBER,
          fund_account_id: fundAccountId,
          amount: Math.round(payout.amount * 100), // RazorpayX expects paise, not rupees
          currency: payout.currency,
          mode: account.upi_id ? "UPI" : "IMPS",
          purpose: "payout",
          queue_if_low_balance: true,
          reference_id: payout.id,
          narration: "Setu caregiver payout",
        }),
      });
      if (!payoutRes.ok) throw new Error(await payoutRes.text());
      const payoutData = await payoutRes.json();

      const paid = payoutData.status === "processed";
      await admin
        .from("caregiver_payouts")
        .update({
          status: paid ? "paid" : "processing",
          provider_ref: payoutData.id,
          paid_at: paid ? new Date().toISOString() : null,
        })
        .eq("id", payout.id);

      await admin.from("audit_log").insert({
        actor_user_id: null,
        action: "write",
        resource_type: "caregiver_payout",
        resource_id: payout.id,
        metadata: { via: "payouts-run", razorpayx_status: payoutData.status },
      });

      results.push({ payout_id: payout.id, outcome: paid ? "paid" : "processing" });
    } catch (err) {
      await admin.from("caregiver_payouts").update({ status: "failed" }).eq("id", payout.id);
      await admin.from("audit_log").insert({
        actor_user_id: null,
        action: "write",
        resource_type: "caregiver_payout",
        resource_id: payout.id,
        metadata: { via: "payouts-run", error: (err as Error).message },
      });
      results.push({ payout_id: payout.id, outcome: "failed", detail: (err as Error).message });
    }
  }

  return jsonResponse({ processed: results.length, results });
});
