"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export async function resolveSosEvent(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "sos_operator");

  const sosEventId = formData.get("sos_event_id") as string;
  const notes = formData.get("notes") as string;

  const supabase = await createClient();
  const { error } = await supabase
    .from("sos_events")
    .update({ status: "resolved", resolved_at: new Date().toISOString(), notes })
    .eq("id", sosEventId);
  if (error) throw new Error(error.message);

  revalidatePath("/sos");
}
