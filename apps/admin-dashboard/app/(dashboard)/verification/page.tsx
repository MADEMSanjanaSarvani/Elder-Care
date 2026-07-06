import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";
import { updateCaregiverVerification } from "@/actions/caregiverVerification";

function bgvTone(status: string) {
  if (status === "cleared") return "good" as const;
  if (status === "failed") return "critical" as const;
  return "warning" as const;
}

export default async function VerificationQueuePage() {
  const admin = await requireAdmin();
  requireScope(admin, "verification_agent");

  const supabase = await createClient();
  const { data: caregivers, error } = await supabase
    .from("caregivers")
    .select("*, profiles(display_name, phone)")
    .neq("trust_tier", "clinical_verified")
    .order("created_at", { ascending: true });

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Verification queue</h1>
      <p className="mb-6 text-sm text-muted">
        Caregivers not yet at their maximum trust tier. Police verification and clinical credential review are
        recorded here manually — there is no automated feed for either (PRD Part 1 §04).
      </p>

      {error && <p className="text-sos">{error.message}</p>}
      {caregivers?.length === 0 && <p className="text-sm text-muted">Nobody in the queue right now.</p>}

      <div className="flex flex-col gap-4">
        {caregivers?.map((caregiver) => {
          const profile = caregiver.profiles as unknown as { display_name: string | null; phone: string | null } | null;
          return (
            <form
              key={caregiver.id}
              action={updateCaregiverVerification}
              className="rounded border border-border bg-paper-raised p-5"
            >
              <input type="hidden" name="caregiver_id" value={caregiver.id} />

              <div className="mb-3 flex items-center justify-between">
                <div>
                  <div className="font-medium">{profile?.display_name ?? "Unnamed caregiver"}</div>
                  <div className="text-xs text-muted">{profile?.phone} · {caregiver.sub_role} · {caregiver.caregiver_type}</div>
                </div>
                <StatusPill
                  label={`Trust tier: ${caregiver.trust_tier}`}
                  tone={caregiver.trust_tier === "probationary" ? "warning" : "good"}
                />
              </div>

              <div className="mb-4 flex flex-wrap gap-4 text-sm">
                <div>
                  <span className="text-muted">BGV (IDfy): </span>
                  <StatusPill label={caregiver.bgv_status} tone={bgvTone(caregiver.bgv_status)} />
                </div>
                {caregiver.caregiver_type === "clinical" && (
                  <div className="text-muted">
                    Council reg. no: {caregiver.professional_council_reg_no ?? "not on file"}
                  </div>
                )}
              </div>

              <div className="flex flex-wrap items-end gap-4">
                <label className="text-sm">
                  <span className="mb-1 block text-muted">Police verification</span>
                  <select
                    name="police_verification_status"
                    defaultValue={caregiver.police_verification_status}
                    className="rounded border border-border bg-paper px-2 py-1.5"
                  >
                    <option value="not_started">Not started</option>
                    <option value="submitted">Submitted</option>
                    <option value="in_progress">In progress</option>
                    <option value="cleared">Cleared</option>
                    <option value="flagged">Flagged</option>
                  </select>
                </label>

                {caregiver.caregiver_type === "clinical" && (
                  <>
                    <label className="flex items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        name="credential_verified"
                        defaultChecked={!!caregiver.credential_verified_at}
                      />
                      Council credential verified
                    </label>
                    <label className="flex items-center gap-2 text-sm">
                      <input type="checkbox" name="insurance_on_file" defaultChecked={caregiver.insurance_on_file} />
                      Insurance on file
                    </label>
                  </>
                )}

                <button type="submit" className="rounded bg-accent px-4 py-1.5 text-sm font-medium text-white">
                  Save
                </button>
              </div>
            </form>
          );
        })}
      </div>
    </div>
  );
}
