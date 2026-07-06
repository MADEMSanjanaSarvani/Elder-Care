// TypeScript port of supabase/functions/_shared/trustTier.ts — kept as a
// deliberate duplicate rather than a shared package, since one lives in
// Deno (Edge Functions) and the other in Node/Next.js; the two runtimes
// don't share a module system here. If this logic changes, change it in
// both places.
import type { BgvStatus, PoliceVerificationStatus, TrustTier } from "./types";

const RANK: Record<TrustTier, number> = {
  probationary: 0,
  standard: 1,
  clinical_verified: 2,
};

export function meetsRequiredTier(caregiverTier: TrustTier, requiredTier: TrustTier): boolean {
  return RANK[caregiverTier] >= RANK[requiredTier];
}

export function computeTrustTier(caregiver: {
  caregiver_type: "clinical" | "non_clinical";
  bgv_status: BgvStatus;
  police_verification_status: PoliceVerificationStatus;
  professional_council_reg_no: string | null;
  credential_verified_at: string | null;
  insurance_on_file: boolean;
}): TrustTier {
  const bgvCleared = caregiver.bgv_status === "cleared";
  const policeCleared = caregiver.police_verification_status === "cleared";

  if (
    caregiver.caregiver_type === "clinical" &&
    bgvCleared &&
    policeCleared &&
    caregiver.professional_council_reg_no &&
    caregiver.credential_verified_at &&
    caregiver.insurance_on_file
  ) {
    return "clinical_verified";
  }
  if (bgvCleared && policeCleared) {
    return "standard";
  }
  return "probationary";
}
