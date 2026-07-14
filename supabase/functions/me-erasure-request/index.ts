// POST /functions/v1/me-erasure-request
// body: { reason?: string }
//
// DPDP Act 2023 erasure right (PRD Part 2 §12/§13). This never performs a
// hard delete itself — it queues a request in `erasure_requests` for a
// super_admin to review, because payment records, audit trails, and SOS
// events often carry independent legal retention requirements (tax law,
// safety-incident review) that a blanket delete would violate. See
// `migrations/0004_erasure_requests.sql` for the reasoning behind that
// design.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const body = await req.json().catch(() => ({}));
    const reason = typeof body.reason === "string" ? body.reason : null;

    const admin = supabaseAdmin();

    const { data: request, error: insertErr } = await admin
      .from("erasure_requests")
      .insert({ requested_by: user.id, reason })
      .select()
      .single();
    if (insertErr) return errorResponse(insertErr.message, 500);

    const { data: superAdmins } = await admin
      .from("admin_scopes")
      .select("profile_id")
      .eq("scope", "super_admin");

    if (superAdmins?.length) {
      await admin.from("notifications").insert(
        superAdmins.map((a) => ({
          user_id: a.profile_id,
          type: "erasure_request_submitted",
          payload: { erasure_request_id: request.id, requested_by: user.id },
        })),
      );
    }

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "erasure_request",
      resource_id: request.id,
      metadata: {},
    });

    return jsonResponse(request, 201);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
