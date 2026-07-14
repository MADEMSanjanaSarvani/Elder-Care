// Unit tests for the trust-tier logic (PRD Part 1 §04). Pure functions,
// no network/database/secrets needed — run with `deno test`. This is the
// TypeScript twin of apps/admin-dashboard/lib/trustTier.ts; if one changes,
// check whether the other needs to.
//
// Deliberately dependency-free (no jsr:@std/assert) — this environment's
// network policy blocks jsr.io, and a two-line assertion helper is a
// perfectly reasonable thing to own outright rather than fight that.
import { assertEquals } from "./testUtil.ts";
import { computeTrustTier, meetsRequiredTier } from "./trustTier.ts";

const nonClinicalBase = {
  caregiver_type: "non_clinical" as const,
  bgv_status: "not_started",
  police_verification_status: "not_started",
  professional_council_reg_no: null,
  credential_verified_at: null,
  insurance_on_file: false,
};

const clinicalBase = { ...nonClinicalBase, caregiver_type: "clinical" as const };

Deno.test("meetsRequiredTier: higher tiers satisfy lower requirements", () => {
  assertEquals(meetsRequiredTier("clinical_verified", "probationary"), true);
  assertEquals(meetsRequiredTier("clinical_verified", "standard"), true);
  assertEquals(meetsRequiredTier("standard", "clinical_verified"), false);
  assertEquals(meetsRequiredTier("probationary", "standard"), false);
  assertEquals(meetsRequiredTier("standard", "standard"), true);
});

Deno.test("computeTrustTier: brand new caregiver is probationary", () => {
  assertEquals(computeTrustTier(nonClinicalBase), "probationary");
});

Deno.test("computeTrustTier: non-clinical caregiver reaches standard once BGV + police clear", () => {
  const caregiver = { ...nonClinicalBase, bgv_status: "cleared", police_verification_status: "cleared" };
  assertEquals(computeTrustTier(caregiver), "standard");
});

Deno.test("computeTrustTier: non-clinical caregiver CANNOT reach clinical_verified regardless of other fields", () => {
  const caregiver = {
    ...nonClinicalBase,
    bgv_status: "cleared",
    police_verification_status: "cleared",
    professional_council_reg_no: "RN-12345",
    credential_verified_at: new Date().toISOString(),
    insurance_on_file: true,
  };
  assertEquals(computeTrustTier(caregiver), "standard");
});

Deno.test("computeTrustTier: clinical caregiver stuck at standard until council credential + insurance are both present", () => {
  const bgvAndPoliceOnly = { ...clinicalBase, bgv_status: "cleared", police_verification_status: "cleared" };
  assertEquals(computeTrustTier(bgvAndPoliceOnly), "standard");

  const missingInsurance = {
    ...bgvAndPoliceOnly,
    professional_council_reg_no: "RN-12345",
    credential_verified_at: new Date().toISOString(),
    insurance_on_file: false,
  };
  assertEquals(computeTrustTier(missingInsurance), "standard");
});

Deno.test("computeTrustTier: clinical caregiver reaches clinical_verified only with every requirement met", () => {
  const fullyVerified = {
    ...clinicalBase,
    bgv_status: "cleared",
    police_verification_status: "cleared",
    professional_council_reg_no: "RN-12345",
    credential_verified_at: new Date().toISOString(),
    insurance_on_file: true,
  };
  assertEquals(computeTrustTier(fullyVerified), "clinical_verified");
});

Deno.test("computeTrustTier: a failed BGV never advances past probationary, even with everything else cleared", () => {
  const failedBgv = {
    ...clinicalBase,
    bgv_status: "failed",
    police_verification_status: "cleared",
    professional_council_reg_no: "RN-12345",
    credential_verified_at: new Date().toISOString(),
    insurance_on_file: true,
  };
  assertEquals(computeTrustTier(failedBgv), "probationary");
});
