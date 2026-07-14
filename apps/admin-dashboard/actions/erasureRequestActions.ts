"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

const RESOLVED_STATUSES = new Set(["completed", "denied"]);

/**
 * Resolves a DPDP erasure request (PRD Part 2 §12/§13). This never
 * triggers a hard delete itself — that decision, and any actual data
 * removal it implies, is a human judgment call recorded here as
 * status/admin_notes, because payment records, audit trails, and SOS
 * events often carry independent legal retention requirements that a
 * blanket delete would violate (see migrations/0004_erasure_requests.sql).
 */
export async function resolveErasureRequest(formData: FormData) {
  const admin = await requireAdmin();
  requireScope(admin, "super_admin");

  const requestId = formData.get("request_id") as string;
  const status = formData.get("status") as string;
  const adminNotes = formData.get("admin_notes") as string;

  const supabase = await createClient();
  const { error } = await supabase
    .from("erasure_requests")
    .update({
      status,
      admin_notes: adminNotes || null,
      reviewed_by: admin.id,
      resolved_at: RESOLVED_STATUSES.has(status) ? new Date().toISOString() : null,
    })
    .eq("id", requestId);
  if (error) throw new Error(error.message);

  revalidatePath("/erasure-requests");
}
