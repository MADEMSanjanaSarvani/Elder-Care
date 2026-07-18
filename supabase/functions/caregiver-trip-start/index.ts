// POST /functions/v1/caregiver-trip-start
//
// The caregiver taps "I'm on my way": this opens (or re-opens) the live trip
// for their assigned booking so the family can watch it in real time. We seed
// the destination from the elder's latest known location (decoded server-side
// from PostGIS) so the caregiver's Start-Navigation button and the family's
// distance readout have a target — without either client touching geography
// types. After this, the caregiver's app streams current_lat/lng and status
// straight to the row under RLS; Realtime does the rest.
//
// Auth: the caller must be the caregiver assigned to the booking. We resolve
// the caller from their JWT and verify assignment from the service role.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { supabaseAsUser } from "../_shared/supabaseAsUser.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: { booking_id?: string; eta_minutes?: number };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }
  const bookingId = body.booking_id;
  if (!bookingId) return errorResponse("booking_id is required", 400);

  // Who is calling?
  const asUser = supabaseAsUser(req);
  const { data: userData } = await asUser.auth.getUser();
  const userId = userData.user?.id;
  if (!userId) return errorResponse("Not authenticated", 401);

  const admin = supabaseAdmin();

  // The booking, with its caregiver's user_id — confirms assignment.
  const { data: booking, error: bErr } = await admin
    .from("bookings")
    .select("id, elder_id, caregiver_id, status, caregivers!inner(user_id)")
    .eq("id", bookingId)
    .maybeSingle();
  if (bErr) return errorResponse(bErr.message, 500);
  if (!booking) return errorResponse("Booking not found", 404);

  const caregiverUserId =
    (booking as { caregivers?: { user_id?: string } }).caregivers?.user_id;
  if (caregiverUserId !== userId) return errorResponse("Not your booking", 403);
  if (booking.caregiver_id == null) return errorResponse("Booking has no caregiver", 409);
  if (booking.status === "completed" || booking.status === "cancelled") {
    return errorResponse("Booking is already closed", 409);
  }

  // Seed the destination from the elder's latest known location, if any.
  let destLat: number | null = null;
  let destLng: number | null = null;
  const { data: loc } = await admin.rpc("latest_elder_location", {
    p_elder_id: booking.elder_id,
  });
  if (Array.isArray(loc) && loc.length > 0) {
    destLat = loc[0].lat as number;
    destLng = loc[0].lng as number;
  }

  const eta = typeof body.eta_minutes === "number" ? body.eta_minutes : null;

  const { data: trip, error: tErr } = await admin
    .from("caregiver_trips")
    .upsert(
      {
        booking_id: bookingId,
        caregiver_id: booking.caregiver_id,
        elder_id: booking.elder_id,
        status: "en_route",
        destination_lat: destLat,
        destination_lng: destLng,
        eta_minutes: eta,
        started_at: new Date().toISOString(),
        arrived_at: null,
        completed_at: null,
      },
      { onConflict: "booking_id" },
    )
    .select()
    .single();
  if (tErr) return errorResponse(tErr.message, 500);

  return jsonResponse({ trip });
});
