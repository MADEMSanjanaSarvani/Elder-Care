// GET /functions/v1/me-data-export
//
// DPDP Act 2023 data-portability right (PRD Part 2 §12/§13). Returns every
// record the caller is the *data principal* for — deliberately narrower
// than what RLS would let them read. A family member's consent grants let
// them *view* an elder's health notes; that's the elder's data, not
// theirs, so it's excluded here even though `elder_health_notes_select`
// would return it. Role-scoped, explicit queries via the service-role
// client rather than "select through the caller's own session" for
// exactly that reason — RLS answers "can they see it," not "is it theirs."
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const admin = supabaseAdmin();

    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select("id, role, phone, preferred_language, display_name, created_at")
      .eq("id", user.id)
      .single();
    if (profileErr || !profile) return errorResponse("Profile not found", 404);

    const { data: notifications } = await admin
      .from("notifications")
      .select("*")
      .eq("user_id", user.id);

    const exportBody: Record<string, unknown> = { profile, notifications: notifications ?? [] };

    if (profile.role === "elder") {
      const { data: elderProfiles } = await admin
        .from("elder_profiles")
        .select("*")
        .eq("auth_user_id", user.id);
      const elderIds = (elderProfiles ?? []).map((e) => e.id);

      const [healthNotes, medications, locations, bookings, sosEvents, aiInteractions, consentGrants, familyLinks] =
        await Promise.all([
          elderIds.length ? admin.from("elder_health_notes").select("*").in("elder_id", elderIds) : { data: [] },
          elderIds.length ? admin.from("elder_medications").select("*").in("elder_id", elderIds) : { data: [] },
          elderIds.length ? admin.from("elder_locations").select("*").in("elder_id", elderIds) : { data: [] },
          elderIds.length ? admin.from("bookings").select("*").in("elder_id", elderIds) : { data: [] },
          elderIds.length ? admin.from("sos_events").select("*").in("elder_id", elderIds) : { data: [] },
          elderIds.length ? admin.from("ai_interactions").select("*").in("elder_id", elderIds) : { data: [] },
          elderIds.length ? admin.from("consent_grants").select("*").in("elder_id", elderIds) : { data: [] },
          elderIds.length ? admin.from("family_links").select("*").in("elder_id", elderIds) : { data: [] },
        ]);

      const bookingIds = (bookings.data ?? []).map((b: { id: string }) => b.id);
      const { data: payments } = bookingIds.length
        ? await admin.from("payments").select("*").in("booking_id", bookingIds)
        : { data: [] };

      Object.assign(exportBody, {
        elder_profiles: elderProfiles ?? [],
        elder_health_notes: healthNotes.data ?? [],
        elder_medications: medications.data ?? [],
        elder_locations: locations.data ?? [],
        bookings: bookings.data ?? [],
        sos_events: sosEvents.data ?? [],
        ai_interactions: aiInteractions.data ?? [],
        consent_grants: consentGrants.data ?? [],
        family_links: familyLinks.data ?? [],
        payments: payments ?? [],
      });
    } else if (profile.role === "family_member") {
      const [familyLinks, consentGrants, bookings, payments] = await Promise.all([
        admin.from("family_links").select("*").eq("family_user_id", user.id),
        admin.from("consent_grants").select("*").eq("family_user_id", user.id),
        admin.from("bookings").select("*").eq("requested_by", user.id),
        admin.from("payments").select("*").eq("family_user_id", user.id),
      ]);
      Object.assign(exportBody, {
        family_links: familyLinks.data ?? [],
        consent_grants: consentGrants.data ?? [],
        bookings: bookings.data ?? [],
        payments: payments.data ?? [],
      });
    } else if (profile.role === "caregiver") {
      const { data: caregiver } = await admin.from("caregivers").select("*").eq("user_id", user.id).maybeSingle();
      const caregiverId = caregiver?.id;

      const [documents, bookings, payouts] = await Promise.all([
        caregiverId ? admin.from("caregiver_documents").select("*").eq("caregiver_id", caregiverId) : { data: [] },
        caregiverId ? admin.from("bookings").select("*").eq("caregiver_id", caregiverId) : { data: [] },
        caregiverId ? admin.from("caregiver_payouts").select("*").eq("caregiver_id", caregiverId) : { data: [] },
      ]);
      Object.assign(exportBody, {
        caregiver: caregiver ?? null,
        caregiver_documents: documents.data ?? [],
        bookings: bookings.data ?? [],
        caregiver_payouts: payouts.data ?? [],
      });
    } else {
      const { data: adminScopes } = await admin.from("admin_scopes").select("*").eq("profile_id", user.id);
      Object.assign(exportBody, { admin_scopes: adminScopes ?? [] });
    }

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "read",
      resource_type: "data_export",
      resource_id: user.id,
      metadata: { via: "me-data-export" },
    });

    return jsonResponse(exportBody);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
