// GET /functions/v1/me-access-history
//
// PRD Part 10, Batch 7, Module 24. Returns a human-readable "who accessed
// what" history for the caller's own elder record — the previously-
// deferred read that 0002_rls.sql's own comment anticipated needing a
// dedicated Edge Function for, since audit_log has no direct elder_id
// column and RLS alone can't express the per-resource-type mapping back
// to an elder.
//
// requireUser(); resolves the caller's own elder_id (as themselves, or as
// a linked family member), then queries audit_log for entries whose
// resource traces back to that elder. Read-only; no consent-model change.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET" && req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const url = new URL(req.url);
    const elderIdParam = url.searchParams.get("elder_id");

    const admin = supabaseAdmin();

    // The caller must be entitled to this elder's history: the elder
    // themselves, or a linked family member. (An admin's own access
    // auditing is a separate ops concern, not this self-service endpoint.)
    let elderId = elderIdParam;
    if (!elderId) {
      const { data: self } = await admin
        .from("elder_profiles").select("id").eq("auth_user_id", user.id).maybeSingle();
      elderId = self?.id ?? null;
    }
    if (!elderId) return errorResponse("No elder record resolved for this caller", 404);

    const { data: elder } = await admin
      .from("elder_profiles").select("id, auth_user_id").eq("id", elderId).single();
    if (!elder) return errorResponse("Elder not found", 404);

    const isSelf = elder.auth_user_id === user.id;
    let isLinked = false;
    if (!isSelf) {
      const { data: link } = await admin
        .from("family_links").select("id")
        .eq("elder_id", elderId).eq("family_user_id", user.id).eq("status", "active").maybeSingle();
      isLinked = !!link;
    }
    if (!isSelf && !isLinked) return errorResponse("Not authorized to view this elder's access history", 403);

    // audit_log has no elder_id column, so map back via metadata.elder_id.
    // Write-path entries (sos-trigger, bookings-*) stamp it, and the admin
    // dashboard's read-path logging (logAdminRead: action 'admin_read' on
    // booking / ai_interaction) stamps it too — so this now surfaces both
    // "who changed my data" and "who looked at my data". A fuller mapping
    // (payments, more resource types) extends the same metadata-driven
    // approach as those paths start stamping elder_id.
    const { data: entries } = await admin
      .from("audit_log")
      .select("action, resource_type, resource_id, metadata, created_at, actor_user_id")
      .contains("metadata", { elder_id: elderId })
      .order("created_at", { ascending: false })
      .limit(200);

    const readable = (entries ?? []).map((e) => ({
      when: e.created_at,
      action: e.action,
      resource: e.resource_type,
      detail: e.metadata,
    }));

    return jsonResponse({ elder_id: elderId, entries: readable });
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
