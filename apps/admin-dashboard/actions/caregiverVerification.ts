"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { computeTrustTier } from "@/lib/trustTier";
import type { BgvStatus, PoliceVerificationStatus } from "@/lib/types";

/**
 * Updates the manual/ops-reviewed parts of a caregiver's verification —
 * police verification (state-administered, no webhook exists for it),
 * clinical credential review, and insurance-on-file — then recomputes
 * trust_tier from the full picture (PRD Part 1 §04). Goes through the
 * request-scoped Supabase client, not the service-role one: the
 * caregivers_update_self RLS policy already permits a verification_agent
 * to update any caregiver row, so this stays consistent with "RLS is the
 * enforcement layer, not the Flutter/Next client."
 */
export async function updateCaregiverVerification(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "verification_agent");

  const caregiverId = formData.get("caregiver_id") as string;
  const policeVerificationStatus = formData.get("police_verification_status") as PoliceVerificationStatus;
  const credentialVerified = formData.get("credential_verified") === "on";
  const insuranceOnFile = formData.get("insurance_on_file") === "on";
  // Background-verification status is recorded manually here for
  // self-registered caregivers (no automated BGV feed). `active` is the
  // switch that makes a caregiver visible and bookable by families.
  const bgvStatus = formData.get("bgv_status") as BgvStatus | null;
  const active = formData.get("active") === "on";

  const supabase = await createClient();
  const { data: caregiver, error: fetchError } = await supabase
    .from("caregivers")
    .select("caregiver_type, bgv_status, professional_council_reg_no, credential_verified_at")
    .eq("id", caregiverId)
    .single();
  if (fetchError || !caregiver) throw new Error(fetchError?.message ?? "Caregiver not found");

  const effectiveBgv = bgvStatus ?? caregiver.bgv_status;

  const credentialVerifiedAt = credentialVerified
    ? caregiver.credential_verified_at ?? new Date().toISOString()
    : null;

  const trustTier = computeTrustTier({
    caregiver_type: caregiver.caregiver_type,
    bgv_status: effectiveBgv,
    police_verification_status: policeVerificationStatus,
    professional_council_reg_no: caregiver.professional_council_reg_no,
    credential_verified_at: credentialVerifiedAt,
    insurance_on_file: insuranceOnFile,
  });

  const { error: updateError } = await supabase
    .from("caregivers")
    .update({
      police_verification_status: policeVerificationStatus,
      credential_verified_at: credentialVerifiedAt,
      insurance_on_file: insuranceOnFile,
      bgv_status: effectiveBgv,
      active,
      trust_tier: trustTier,
    })
    .eq("id", caregiverId);
  if (updateError) throw new Error(updateError.message);

  revalidatePath("/verification");
  revalidatePath("/caregivers");
}
