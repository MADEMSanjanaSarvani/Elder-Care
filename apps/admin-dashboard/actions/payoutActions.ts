"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

/**
 * Marks a caregiver's bank/UPI details as reviewed and safe to pay
 * (PRD Part 2 §15). `payouts-run` refuses to touch an unverified account —
 * this is the human step that unblocks it, so a typo'd account number
 * can't silently misroute real money before someone has looked at it.
 */
export async function verifyPayoutAccount(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "finance_ops");

  const accountId = formData.get("account_id") as string;
  const supabase = await createClient();

  const { error } = await supabase
    .from("caregiver_payout_accounts")
    .update({ verified: true, verified_by: admin.id })
    .eq("id", accountId);
  if (error) throw new Error(error.message);

  revalidatePath("/payouts");
}
