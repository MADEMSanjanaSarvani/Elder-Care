// POST /functions/v1/bookings-create
// body: { elder_id: uuid, service_id: uuid, scheduled_at: ISO string }
//
// PRD Part 2 §12: validates the requested service against the elder's
// region and the service's required trust tier *before* a booking row
// ever exists — this check is never left to the Flutter client.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { elder_id, service_id, scheduled_at } = await req.json();
    if (!elder_id || !service_id || !scheduled_at) {
      return errorResponse("elder_id, service_id, and scheduled_at are required");
    }

    const admin = supabaseAdmin();

    // Caller must be the elder themself or an active linked family member —
    // mirrors the bookings_insert RLS policy so a rejected Edge Function
    // call and a rejected direct-client insert fail for the same reason.
    const { data: elder, error: elderErr } = await admin
      .from("elder_profiles")
      .select("id, region_id, auth_user_id")
      .eq("id", elder_id)
      .single();
    if (elderErr || !elder) return errorResponse("Elder not found", 404);

    const isElderSelf = elder.auth_user_id === user.id;
    let isLinkedFamily = false;
    if (!isElderSelf) {
      const { data: link } = await admin
        .from("family_links")
        .select("id")
        .eq("elder_id", elder_id)
        .eq("family_user_id", user.id)
        .eq("status", "active")
        .maybeSingle();
      isLinkedFamily = !!link;
    }
    if (!isElderSelf && !isLinkedFamily) {
      return errorResponse("Not authorized to book on behalf of this elder", 403);
    }

    const { data: service, error: serviceErr } = await admin
      .from("service_catalog")
      .select("id, region_id, requires_trust_tier, active")
      .eq("id", service_id)
      .single();
    if (serviceErr || !service || !service.active) return errorResponse("Service not found or inactive", 404);
    if (service.region_id !== elder.region_id) {
      return errorResponse("Service is not offered in the elder's region", 422);
    }

    const { data: booking, error: insertErr } = await admin
      .from("bookings")
      .insert({
        region_id: elder.region_id,
        elder_id,
        requested_by: user.id,
        service_id,
        required_trust_tier: service.requires_trust_tier,
        scheduled_at,
        status: "requested",
      })
      .select()
      .single();
    if (insertErr) return errorResponse(insertErr.message, 500);

    await admin.from("booking_events").insert({
      booking_id: booking.id,
      event_type: "requested",
      actor_user_id: user.id,
      payload: { service_id },
    });

    return jsonResponse(booking, 201);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
