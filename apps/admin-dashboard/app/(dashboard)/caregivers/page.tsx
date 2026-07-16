import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";
import { setCaregiverActive } from "@/actions/caregiverDirectory";
import { markRatingReviewed } from "@/actions/ratingReviewActions";

export default async function CaregiverDirectoryPage() {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const supabase = await createClient();
  const { data: caregivers, error } = await supabase
    .from("caregivers")
    .select("*, profiles(display_name, phone)")
    .order("created_at", { ascending: false });

  // Low-rating review queue (PRD Part 8, Batch 5, Module 18): ratings the
  // DB trigger auto-flagged (<= 2 stars) that no admin has cleared yet.
  const { data: flaggedRatings } = await supabase
    .from("caregiver_ratings")
    .select("id, caregiver_id, stars, review_text, created_at, caregivers(profiles(display_name))")
    .eq("flagged_for_review", true)
    .eq("admin_reviewed", false)
    .order("created_at", { ascending: false });

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Caregiver directory</h1>
      <p className="mb-6 text-sm text-muted">
        Every onboarded caregiver, active or not. Deactivating one now requires a reason, recorded to the
        caregiver&apos;s status history; low ratings surface in the review queue below.
      </p>

      {error && <p className="text-sos">{error.message}</p>}

      {flaggedRatings && flaggedRatings.length > 0 && (
        <div className="mb-6 rounded border border-sos/40 bg-sos/5 p-4">
          <h2 className="mb-3 text-sm font-semibold text-sos">Low ratings needing review</h2>
          <ul className="space-y-3">
            {flaggedRatings.map((rating) => {
              const cg = rating.caregivers as unknown as { profiles: { display_name: string | null } | null } | null;
              return (
                <li key={rating.id} className="flex items-start justify-between gap-4 text-sm">
                  <div>
                    <div className="font-medium">
                      {cg?.profiles?.display_name ?? "Caregiver"} — {rating.stars}★
                    </div>
                    {rating.review_text && <div className="text-muted">{rating.review_text}</div>}
                  </div>
                  <form action={markRatingReviewed}>
                    <input type="hidden" name="rating_id" value={rating.id} />
                    <button type="submit" className="text-xs underline text-muted hover:text-ink">
                      Mark reviewed
                    </button>
                  </form>
                </li>
              );
            })}
          </ul>
        </div>
      )}

      <div className="overflow-x-auto rounded border border-border bg-paper-raised">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase text-muted">
              <th className="px-4 py-3">Name</th>
              <th className="px-4 py-3">Role</th>
              <th className="px-4 py-3">Trust tier</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {caregivers?.map((caregiver) => {
              const profile = caregiver.profiles as unknown as { display_name: string | null; phone: string | null } | null;
              return (
                <tr key={caregiver.id} className="border-b border-border last:border-0">
                  <td className="px-4 py-3">
                    <div>{profile?.display_name ?? "Unnamed"}</div>
                    <div className="text-xs text-muted">{profile?.phone}</div>
                  </td>
                  <td className="px-4 py-3">{caregiver.sub_role}</td>
                  <td className="px-4 py-3">
                    <StatusPill
                      label={caregiver.trust_tier}
                      tone={caregiver.trust_tier === "clinical_verified" ? "good" : caregiver.trust_tier === "standard" ? "good" : "warning"}
                    />
                  </td>
                  <td className="px-4 py-3">
                    <StatusPill label={caregiver.active ? "Active" : "Deactivated"} tone={caregiver.active ? "good" : "critical"} />
                  </td>
                  <td className="px-4 py-3">
                    <form action={setCaregiverActive} className="flex items-center gap-2">
                      <input type="hidden" name="caregiver_id" value={caregiver.id} />
                      <input type="hidden" name="active" value={(!caregiver.active).toString()} />
                      <input
                        type="text"
                        name="reason"
                        required
                        placeholder="Reason (required)"
                        className="w-40 rounded border border-border bg-paper px-2 py-1 text-xs"
                      />
                      <button type="submit" className="text-xs underline text-muted hover:text-ink">
                        {caregiver.active ? "Deactivate" : "Reactivate"}
                      </button>
                    </form>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
