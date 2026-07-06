import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { StatusPill } from "@/components/StatusPill";
import { setCaregiverActive } from "@/actions/caregiverDirectory";

export default async function CaregiverDirectoryPage() {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const supabase = await createClient();
  const { data: caregivers, error } = await supabase
    .from("caregivers")
    .select("*, profiles(display_name, phone)")
    .order("created_at", { ascending: false });

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Caregiver directory</h1>
      <p className="mb-6 text-sm text-muted">
        Every onboarded caregiver, active or not. Performance/complaint history isn&apos;t modeled in the schema yet
        — this is identity, trust tier, and active status only.
      </p>

      {error && <p className="text-sos">{error.message}</p>}

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
                    <form action={setCaregiverActive}>
                      <input type="hidden" name="caregiver_id" value={caregiver.id} />
                      <input type="hidden" name="active" value={(!caregiver.active).toString()} />
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
