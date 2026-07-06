"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

/**
 * Clears a flagged AI output for delivery (PRD Part 2 §14: "a flagged
 * output is held for human review, never delivered" — this is that
 * review). Approving a visit_summary writes it to elder_health_notes now,
 * exactly where it would have landed automatically if it hadn't been
 * flagged.
 */
export async function approveAiInteraction(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const interactionId = formData.get("interaction_id") as string;
  const supabase = await createClient();

  const { data: interaction, error } = await supabase
    .from("ai_interactions")
    .select("*")
    .eq("id", interactionId)
    .single();
  if (error || !interaction) throw new Error(error?.message ?? "Interaction not found");

  if (interaction.interaction_type === "visit_summary") {
    const { error: insertError } = await supabase.from("elder_health_notes").insert({
      elder_id: interaction.elder_id,
      booking_id: interaction.booking_id,
      note: interaction.output_text,
      source: "ai_summary",
      created_by: admin.id,
    });
    if (insertError) throw new Error(insertError.message);
  }

  const { error: updateError } = await supabase
    .from("ai_interactions")
    .update({ human_reviewed: true })
    .eq("id", interactionId);
  if (updateError) throw new Error(updateError.message);

  revalidatePath("/ai-review");
}

export async function rejectAiInteraction(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const interactionId = formData.get("interaction_id") as string;
  const supabase = await createClient();

  const { error } = await supabase
    .from("ai_interactions")
    .update({ human_reviewed: true })
    .eq("id", interactionId);
  if (error) throw new Error(error.message);

  revalidatePath("/ai-review");
}
