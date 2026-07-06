"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export async function setCaregiverActive(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const caregiverId = formData.get("caregiver_id") as string;
  const active = formData.get("active") === "true";

  const supabase = await createClient();
  const { error } = await supabase.from("caregivers").update({ active }).eq("id", caregiverId);
  if (error) throw new Error(error.message);

  revalidatePath("/caregivers");
}
