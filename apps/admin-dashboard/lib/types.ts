// Mirrors the Postgres enums in supabase/migrations/0001_schema.sql —
// kept in sync by hand for now; consider generating this from the schema
// once the schema stabilizes past MVP.

export type AdminScope = "verification_agent" | "sos_operator" | "ops_admin" | "finance_ops" | "super_admin";

export type TrustTier = "probationary" | "standard" | "clinical_verified";

export type CaregiverType = "clinical" | "non_clinical";

export type BgvStatus = "not_started" | "submitted" | "in_progress" | "cleared" | "failed";

export type PoliceVerificationStatus = "not_started" | "submitted" | "in_progress" | "cleared" | "flagged";

export type BookingStatus =
  | "requested"
  | "matched"
  | "confirmed"
  | "in_progress"
  | "completed"
  | "cancelled"
  | "disputed";

export type SosStatus = "triggered" | "family_notified" | "responder_dispatched" | "resolved";

export type PayoutStatus = "scheduled" | "processing" | "paid" | "failed";

export interface Caregiver {
  id: string;
  region_id: string;
  user_id: string;
  caregiver_type: CaregiverType;
  sub_role: string;
  bgv_status: BgvStatus;
  bgv_provider_ref: string | null;
  police_verification_status: PoliceVerificationStatus;
  professional_council_reg_no: string | null;
  credential_verified_at: string | null;
  insurance_on_file: boolean;
  trust_tier: TrustTier;
  active: boolean;
  created_at: string;
}
