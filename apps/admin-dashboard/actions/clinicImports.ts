"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

/**
 * Promote a staged clinic into the directory, or reject it.
 *
 * Promoting creates a `doctors` row for the *facility* — the clinic name,
 * address and coordinates — with no practitioner attached and
 * `consent_status` left at its default. That row is a placeholder the ops
 * team then fills in by phone: which doctors sit there, on which days, and
 * whether each of them agreed to be listed.
 *
 * It deliberately does not become visible to families on promotion. The app's
 * directory query filters on `consent_status = 'consented'`, so a promoted
 * clinic stays invisible until a human has actually spoken to the doctor.
 * Promotion means "this place is real and in our area", not "publish it".
 */
export async function reviewClinicImport(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "verification_agent");

  const importId = formData.get("import_id") as string;
  const decision = formData.get("decision") as "promote" | "reject";
  const note = ((formData.get("review_note") as string) ?? "").trim();

  const supabase = await createClient();

  const { data: row, error: fetchError } = await supabase
    .from("clinic_imports")
    .select("*")
    .eq("id", importId)
    .single();
  if (fetchError || !row) throw new Error(fetchError?.message ?? "Import not found");
  if (row.status !== "pending") {
    // Two reviewers with the page open shouldn't be able to double-promote.
    throw new Error("This listing has already been reviewed.");
  }

  if (decision === "promote") {
    const { data: existing } = await supabase
      .from("doctors")
      .select("id")
      .eq("source", row.source)
      .eq("source_ref", row.source_ref)
      .maybeSingle();

    if (!existing) {
      // specialty is required by the schema and genuinely unknown until
      // someone rings the clinic, so it is marked as such rather than
      // guessed — "General" would read as a fact nobody established.
      const { error: insertError } = await supabase.from("doctors").insert({
        region_id: row.region_id,
        display_name: row.name,
        specialty: "To be confirmed",
        clinic_name: row.name,
        address: row.address,
        phone: row.phone,
        lat: row.lat,
        lng: row.lng,
        source: row.source,
        source_ref: row.source_ref,
        active: false,
      });
      if (insertError) throw new Error(insertError.message);
    }
  }

  const { error: updateError } = await supabase
    .from("clinic_imports")
    .update({
      status: decision === "promote" ? "promoted" : "rejected",
      reviewed_by: admin.id,
      reviewed_at: new Date().toISOString(),
      review_note: note.length > 0 ? note : null,
    })
    .eq("id", importId)
    .eq("status", "pending");
  if (updateError) throw new Error(updateError.message);

  await supabase.from("audit_log").insert({
    actor_user_id: admin.id,
    action: "write",
    resource_type: "clinic_import",
    resource_id: importId,
    metadata: { decision, source: row.source, name: row.name },
  });

  revalidatePath("/clinic-imports");
}
