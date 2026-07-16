"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

/**
 * PRD Part 8, Batch 5, Module 18: ratings of 2 stars or fewer auto-flag
 * for admin review (the DB trigger sets flagged_for_review). This action
 * marks a flagged rating as reviewed, clearing it from the low-rating
 * queue — the same shape as the AI review queue, in the spirit of the
 * existing verification queue.
 */
export async function markRatingReviewed(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const ratingId = formData.get("rating_id") as string;
  const supabase = await createClient();

  const { error } = await supabase
    .from("caregiver_ratings")
    .update({ admin_reviewed: true })
    .eq("id", ratingId);
  if (error) throw new Error(error.message);

  revalidatePath("/caregivers");
}
