"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export async function setCaregiverActive(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const caregiverId = formData.get("caregiver_id") as string;
  const active = formData.get("active") === "true";
  // PRD Part 8, Batch 5, cross-cutting: deactivation history is only
  // accountable if the one code path that flips `active` records WHY.
  // Required — there is no other place to build this history from.
  const reason = ((formData.get("reason") as string) ?? "").trim();
  if (!reason) throw new Error("A reason is required to change a caregiver's active status.");

  const supabase = await createClient();

  // Read the current value first so the history row's previous_active is
  // truthful, not assumed.
  const { data: current, error: readErr } = await supabase
    .from("caregivers").select("active").eq("id", caregiverId).single();
  if (readErr) throw new Error(readErr.message);

  const { error } = await supabase.from("caregivers").update({ active }).eq("id", caregiverId);
  if (error) throw new Error(error.message);

  // Additive: append to caregiver_status_history (new in 0017). A failure
  // here shouldn't silently swallow the successful status change, so it
  // surfaces as an error the ops admin sees.
  const { error: historyErr } = await supabase.from("caregiver_status_history").insert({
    caregiver_id: caregiverId,
    previous_active: current.active,
    new_active: active,
    reason,
    changed_by: admin.id,
  });
  if (historyErr) throw new Error(historyErr.message);

  revalidatePath("/caregivers");
}
