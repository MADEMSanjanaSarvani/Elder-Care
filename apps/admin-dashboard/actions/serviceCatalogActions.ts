"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export async function updateService(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "super_admin");

  const serviceId = formData.get("service_id") as string;
  const basePrice = Number(formData.get("base_price"));
  const commissionPct = Number(formData.get("commission_pct"));
  const requiresTrustTier = formData.get("requires_trust_tier") as string;
  const active = formData.get("active") === "on";

  const supabase = await createClient();
  const { error } = await supabase
    .from("service_catalog")
    .update({ base_price: basePrice, commission_pct: commissionPct, requires_trust_tier: requiresTrustTier, active })
    .eq("id", serviceId);
  if (error) throw new Error(error.message);

  revalidatePath("/services");
}
