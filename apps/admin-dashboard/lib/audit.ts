import { adminClient } from "./supabase/admin";

/**
 * Read-path audit logging for the admin dashboard (PRD Part 3/4; completes
 * the Privacy Centre's "who has seen this data" story — Batch 7, Module 24).
 *
 * The audit_log table has no INSERT policy for `authenticated`, by design:
 * audit rows are written by trusted server code, never by a client session.
 * So this uses the service-role client — which means every caller must have
 * already verified the admin's scope (requireScope) before reading the data
 * it's logging access to.
 *
 * The `elder_id` is stamped into `metadata` on purpose: the me-access-history
 * Edge Function surfaces an entry to an elder/family by matching
 * `metadata @> { elder_id }`. Without it here, an admin's read would never
 * appear in the elder's Privacy Centre — which is the whole point of this
 * function.
 *
 * It never throws. An audit-write failure must not 500 the page the admin is
 * trying to view; we log to the server console and move on. (A dropped audit
 * row is a monitoring concern, not a reason to deny the operator the screen.)
 */
export async function logAdminRead(params: {
  actorUserId: string;
  resourceType: string;
  resourceId: string;
  elderId: string;
  metadata?: Record<string, unknown>;
}): Promise<void> {
  try {
    await adminClient()
      .from("audit_log")
      .insert({
        actor_user_id: params.actorUserId,
        action: "admin_read",
        resource_type: params.resourceType,
        resource_id: params.resourceId,
        metadata: { elder_id: params.elderId, ...params.metadata },
      });
  } catch (err) {
    console.error("logAdminRead failed", err);
  }
}

/** Batch variant — one insert for several rows read in the same page load. */
export async function logAdminReads(
  rows: Array<{
    actorUserId: string;
    resourceType: string;
    resourceId: string;
    elderId: string;
    metadata?: Record<string, unknown>;
  }>,
): Promise<void> {
  if (rows.length === 0) return;
  try {
    await adminClient()
      .from("audit_log")
      .insert(
        rows.map((r) => ({
          actor_user_id: r.actorUserId,
          action: "admin_read",
          resource_type: r.resourceType,
          resource_id: r.resourceId,
          metadata: { elder_id: r.elderId, ...r.metadata },
        })),
      );
  } catch (err) {
    console.error("logAdminReads failed", err);
  }
}
