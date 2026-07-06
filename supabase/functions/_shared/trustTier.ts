// Trust-tier ordering (PRD Part 1 §04, Part 2 §11): probationary is the
// instant-BGV-only tier; standard adds cleared police verification;
// clinical_verified additionally requires a validated professional-council
// registration and insurance on file. Higher tiers satisfy lower
// requirements — a clinical_verified caregiver can take a probationary-tier
// job, not the reverse.
export type TrustTier = "probationary" | "standard" | "clinical_verified";

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
  bgv_status: string;
  police_verification_status: string;
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
  return "probationary"; // even if bgv is not yet cleared — gates the job list, not the login
}
