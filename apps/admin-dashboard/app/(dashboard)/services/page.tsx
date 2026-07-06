import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { updateService } from "@/actions/serviceCatalogActions";

export default async function ServiceCatalogPage() {
  const admin = await requireAdmin();
  requireScope(admin, "super_admin");

  const supabase = await createClient();
  const { data: services, error } = await supabase
    .from("service_catalog")
    .select("*, regions(display_name)")
    .order("code");

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Service catalog</h1>
      <p className="mb-6 text-sm text-muted">
        Per-region pricing and trust-tier requirements (PRD Part 2 §11 addendum) — adding a new region for Phase 2+
        is a new set of rows here, not a code change.
      </p>

      {error && <p className="text-sos">{error.message}</p>}

      <div className="flex flex-col gap-3">
        {services?.map((service) => (
          <form
            key={service.id}
            action={updateService}
            className="flex flex-wrap items-end gap-4 rounded border border-border bg-paper-raised p-4"
          >
            <input type="hidden" name="service_id" value={service.id} />
            <div className="min-w-[180px]">
              <div className="font-medium">{service.name}</div>
              <div className="text-xs text-muted">
                {service.code} · {(service.regions as unknown as { display_name: string } | null)?.display_name}
              </div>
            </div>
            <label className="text-sm">
              <span className="mb-1 block text-muted">Base price ({service.currency})</span>
              <input
                type="number"
                step="0.01"
                name="base_price"
                defaultValue={service.base_price}
                className="w-28 rounded border border-border bg-paper px-2 py-1"
              />
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-muted">Commission %</span>
              <input
                type="number"
                step="0.01"
                name="commission_pct"
                defaultValue={service.commission_pct}
                className="w-20 rounded border border-border bg-paper px-2 py-1"
              />
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-muted">Requires trust tier</span>
              <select
                name="requires_trust_tier"
                defaultValue={service.requires_trust_tier}
                className="rounded border border-border bg-paper px-2 py-1"
              >
                <option value="probationary">Probationary</option>
                <option value="standard">Standard</option>
                <option value="clinical_verified">Clinical verified</option>
              </select>
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="active" defaultChecked={service.active} />
              Active
            </label>
            <button type="submit" className="rounded bg-accent px-4 py-1.5 text-sm font-medium text-white">
              Save
            </button>
          </form>
        ))}
      </div>
    </div>
  );
}
