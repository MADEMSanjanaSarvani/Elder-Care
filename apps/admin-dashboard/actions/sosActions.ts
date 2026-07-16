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

/**
 * Post-resolution QA (PRD Part 10, Batch 7, Module 25). Files the one
 * incident report per sos_event. `filed_by` is stamped server-side from the
 * authenticated operator — the RLS write policy on sos_incident_reports
 * independently requires filed_by = auth.uid() and the sos_operator scope,
 * so a spoofed value can never land. The unique constraint on sos_event_id
 * means a second submission for the same event is rejected by the database.
 */
export async function fileIncidentReport(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "sos_operator");

  const sosEventId = formData.get("sos_event_id") as string;
  const outcomeSummary = (formData.get("outcome_summary") as string)?.trim();
  const lessonsNotes = (formData.get("lessons_notes") as string)?.trim() || null;
  const emergencyServicesEngaged = formData.get("emergency_services_engaged") === "on";

  if (!outcomeSummary) throw new Error("An outcome summary is required.");

  const supabase = await createClient();
  const { error } = await supabase.from("sos_incident_reports").insert({
    sos_event_id: sosEventId,
    emergency_services_engaged: emergencyServicesEngaged,
    outcome_summary: outcomeSummary,
    lessons_notes: lessonsNotes,
    filed_by: admin.id,
  });
  if (error) throw new Error(error.message);

  revalidatePath("/sos");
}
