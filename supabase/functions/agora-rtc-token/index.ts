// POST /functions/v1/agora-rtc-token
//
// Mints a short-lived Agora RTC token so a family member (or elder) can join
// the video consult room for a booked consultation. The App Certificate stays
// server-side; the client only ever receives a token scoped to its channel.
//
// Authorization: the caller must be a party to the consultation (elder self,
// linked family, or the doctor) — verified by reading the consult AS the
// caller under RLS. If AGORA_APP_CERTIFICATE isn't configured, we return a
// null token so an Agora project in "testing mode" (App-ID only) still works.
import { supabaseAsUser } from "../_shared/supabaseAsUser.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { buildRtcToken } from "../_shared/agoraToken.ts";

const APP_ID = Deno.env.get("AGORA_APP_ID") ?? "";
const APP_CERTIFICATE = Deno.env.get("AGORA_APP_CERTIFICATE") ?? "";
const TOKEN_TTL_SECONDS = 60 * 60; // 1 hour

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: { consultation_id?: string; uid?: number };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }
  const consultId = body.consultation_id;
  if (!consultId) return errorResponse("consultation_id is required", 400);
  const uid = typeof body.uid === "number" ? body.uid : 0;

  if (!APP_ID) return errorResponse("Video is not configured", 503);

  // Authorize + fetch the channel AS the caller (RLS gates who can read it).
  const asUser = supabaseAsUser(req);
  const { data: consult, error } = await asUser
    .from("doctor_consultations")
    .select("id, agora_channel, mode, status")
    .eq("id", consultId)
    .maybeSingle();
  if (error) return errorResponse(error.message, 500);
  if (!consult) return errorResponse("Not allowed", 403);
  if (consult.mode !== "video" || !consult.agora_channel) {
    return errorResponse("This consultation has no video room", 409);
  }

  const channel = consult.agora_channel as string;

  // No certificate → testing-mode project: join with a null token.
  let token: string | null = null;
  if (APP_CERTIFICATE) {
    token = await buildRtcToken(APP_ID, APP_CERTIFICATE, channel, uid, TOKEN_TTL_SECONDS);
  }

  return jsonResponse({
    app_id: APP_ID,
    channel,
    uid,
    token,
    expires_in: TOKEN_TTL_SECONDS,
  });
});
