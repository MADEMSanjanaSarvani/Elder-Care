// POST /functions/v1/doctor-consultation-book
//
// A family (or the elder) books a consultation with a listed doctor. We
// confirm the caller may act for the elder, take the fee from the doctor's
// listing (never trusting a client-supplied amount), and for a video consult
// mint a unique Agora channel name the two ends will join. Payment is tracked
// as 'created' here and settled through the existing Razorpay flow.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { supabaseAsUser } from "../_shared/supabaseAsUser.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const MODES = new Set(["video", "audio", "in_person"]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: {
    elder_id?: string;
    doctor_id?: string;
    mode?: string;
    scheduled_at?: string;
    reason?: string;
  };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  const { elder_id: elderId, doctor_id: doctorId } = body;
  const mode = body.mode ?? "video";
  if (!elderId || !doctorId) return errorResponse("elder_id and doctor_id are required", 400);
  if (!MODES.has(mode)) return errorResponse("Invalid mode", 400);
  if (!body.scheduled_at || Number.isNaN(Date.parse(body.scheduled_at))) {
    return errorResponse("A valid scheduled_at is required", 400);
  }

  const asUser = supabaseAsUser(req);
  const { data: userData } = await asUser.auth.getUser();
  const userId = userData.user?.id;
  if (!userId) return errorResponse("Not authenticated", 401);

  // Can the caller act for this elder? RLS on elder_profiles answers
  // self / linked-family in one read.
  const { data: elder } = await asUser
    .from("elder_profiles")
    .select("id")
    .eq("id", elderId)
    .maybeSingle();
  if (!elder) return errorResponse("Not allowed for this member", 403);

  const admin = supabaseAdmin();
  const { data: doctor, error: dErr } = await admin
    .from("doctors")
    .select("id, consult_fee, active")
    .eq("id", doctorId)
    .maybeSingle();
  if (dErr) return errorResponse(dErr.message, 500);
  if (!doctor || !doctor.active) return errorResponse("Doctor is not available", 409);

  const channel = mode === "video"
    ? `setu-consult-${crypto.randomUUID().replace(/-/g, "").slice(0, 20)}`
    : null;

  const { data: consult, error: cErr } = await admin
    .from("doctor_consultations")
    .insert({
      elder_id: elderId,
      doctor_id: doctorId,
      requested_by: userId,
      mode,
      status: "confirmed",
      scheduled_at: body.scheduled_at,
      reason: body.reason ?? null,
      agora_channel: channel,
      fee: doctor.consult_fee,
      payment_status: doctor.consult_fee > 0 ? "created" : "captured",
    })
    .select()
    .single();
  if (cErr) return errorResponse(cErr.message, 500);

  return jsonResponse({ consultation: consult });
});
