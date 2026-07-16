import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";
import { updateCaregiverVerification } from "@/actions/caregiverVerification";

function bgvTone(status: string) {
  if (status === "cleared") return "good" as const;
  if (status === "failed") return "critical" as const;
  return "warning" as const;
}

const DOC_TYPE_LABELS: Record<string, string> = {
  gov_id: "Government ID",
  police_verification: "Police verification",
  council_certificate: "Council certificate",
  insurance: "Insurance",
};

function isImagePath(path: string): boolean {
  return /\.(png|jpe?g|webp|gif|heic)$/i.test(path);
}

interface CaregiverDoc {
  docType: string;
  verified: boolean;
  signedUrl: string | null;
  isImage: boolean;
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

  // Load each caregiver's uploaded documents and mint short-lived signed
  // URLs so the reviewer can actually see the ID/certificate image, not
  // just its verification status. The private-bucket RLS
  // (caregiver_documents_storage_select) already grants read to the
  // verification_agent scope this page requires — so this uses the admin's
  // own authenticated client, no service-role bypass.
  const docsByCaregiver: Record<string, CaregiverDoc[]> = {};
  const caregiverIds = (caregivers ?? []).map((c) => c.id as string);
  if (caregiverIds.length > 0) {
    const { data: docRows } = await supabase
      .from("caregiver_documents")
      .select("caregiver_id, doc_type, storage_path, verified")
      .in("caregiver_id", caregiverIds)
      .order("uploaded_at", { ascending: true });

    const paths = (docRows ?? []).map((d) => d.storage_path as string);
    const signedByPath: Record<string, string> = {};
    if (paths.length > 0) {
      const { data: signed } = await supabase.storage
        .from("caregiver-documents")
        .createSignedUrls(paths, 300); // 5 minutes
      for (const s of signed ?? []) {
        if (s.signedUrl && s.path) signedByPath[s.path] = s.signedUrl;
      }
    }

    for (const d of docRows ?? []) {
      const cid = d.caregiver_id as string;
      const path = d.storage_path as string;
      (docsByCaregiver[cid] ??= []).push({
        docType: d.doc_type as string,
        verified: d.verified as boolean,
        signedUrl: signedByPath[path] ?? null,
        isImage: isImagePath(path),
      });
    }
  }

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

              <div className="mb-4">
                <div className="mb-2 text-xs font-medium uppercase tracking-wide text-muted">
                  Uploaded documents
                </div>
                {(docsByCaregiver[caregiver.id] ?? []).length === 0 ? (
                  <p className="text-sm text-muted">No documents uploaded yet.</p>
                ) : (
                  <div className="flex flex-wrap gap-3">
                    {(docsByCaregiver[caregiver.id] ?? []).map((doc, i) => (
                      <div key={i} className="w-40 rounded border border-border bg-paper p-2">
                        <div className="mb-1 flex items-center justify-between gap-1 text-xs">
                          <span className="font-medium">
                            {DOC_TYPE_LABELS[doc.docType] ?? doc.docType}
                          </span>
                          {doc.verified && (
                            <StatusPill label="verified" tone="good" />
                          )}
                        </div>
                        {doc.signedUrl ? (
                          <a href={doc.signedUrl} target="_blank" rel="noopener noreferrer" className="block">
                            {doc.isImage ? (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img
                                src={doc.signedUrl}
                                alt={`${doc.docType} document`}
                                className="h-24 w-full rounded object-cover"
                              />
                            ) : (
                              <span className="flex h-24 w-full items-center justify-center rounded bg-paper-raised text-sm text-accent underline">
                                Open document
                              </span>
                            )}
                          </a>
                        ) : (
                          <span className="flex h-24 w-full items-center justify-center rounded bg-paper-raised text-xs text-sos">
                            Unavailable
                          </span>
                        )}
                      </div>
                    ))}
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
