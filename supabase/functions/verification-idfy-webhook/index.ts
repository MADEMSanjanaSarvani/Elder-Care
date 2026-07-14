// POST /functions/v1/verification-idfy-webhook
//
// Receives background-verification status callbacks from IDfy (PRD Part 1
// §04 decision) and recomputes the caregiver's trust tier.
//
// IMPORTANT: the shared-secret header check and payload shape below are a
// reasonable *placeholder* contract, not a confirmed IDfy integration —
// verify IDfy's actual webhook authentication scheme (signature vs. shared
// secret vs. IP allowlist) and exact payload fields against their current
// API docs / integration contract before this goes live. Do not treat the
// field names here as settled.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { computeTrustTier } from "../_shared/trustTier.ts";

const IDFY_WEBHOOK_SHARED_SECRET = Deno.env.get("IDFY_WEBHOOK_SHARED_SECRET")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-webhook-secret");
  if (providedSecret !== IDFY_WEBHOOK_SHARED_SECRET) {
    return errorResponse("Invalid webhook credentials", 401);
  }

  const body = await req.json();
  // Placeholder field names — confirm against IDfy's real callback schema.
  const { bgv_provider_ref, status } = body as { bgv_provider_ref: string; status: string };
  if (!bgv_provider_ref || !status) return errorResponse("bgv_provider_ref and status are required");

  const admin = supabaseAdmin();
  const { data: caregiver, error } = await admin
    .from("caregivers")
    .select("id, caregiver_type, police_verification_status, professional_council_reg_no, credential_verified_at, insurance_on_file")
    .eq("bgv_provider_ref", bgv_provider_ref)
    .single();
  if (error || !caregiver) return errorResponse("Caregiver not found for this bgv_provider_ref", 404);

  const bgvStatus = status === "completed" ? "cleared" : status === "failed" ? "failed" : "in_progress";
  const newTier = computeTrustTier({ ...caregiver, bgv_status: bgvStatus });

  await admin
    .from("caregivers")
    .update({ bgv_status: bgvStatus, trust_tier: newTier })
    .eq("id", caregiver.id);

  await admin.from("audit_log").insert({
    actor_user_id: null,
    action: "write",
    resource_type: "caregiver",
    resource_id: caregiver.id,
    metadata: { via: "verification-idfy-webhook", bgv_status: bgvStatus, trust_tier: newTier },
  });

  return jsonResponse({ received: true });
});
