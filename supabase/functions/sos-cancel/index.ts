// POST /functions/v1/sos-cancel
// body: { sos_event_id: uuid, reason?: string }
//
// The undo for sos-trigger. A pocket-press or a mis-tap fans an alert out to
// the whole care circle and the on-call operator, and until now there was no
// way to take it back — so people drove across the city for nothing, and the
// next real alert was believed a little less.
//
// This is an Edge Function rather than a direct table update for one reason:
// cancelling is not a state change, it is a *second message*. Everyone who was
// told the emergency was happening has to be told it isn't, and only the
// service role can write into other people's notification rows. A client that
// merely flipped the status would leave the family still driving.
//
// It deliberately does NOT touch `resolved`. 'cancelled' means nothing
// happened; 'resolved' means something did and was handled. See migration 0040.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { sos_event_id, reason } = await req.json();
    if (!sos_event_id) return errorResponse("sos_event_id is required");

    const admin = supabaseAdmin();

    const { data: sosEvent, error: fetchErr } = await admin
      .from("sos_events")
      .select("id, elder_id, status, triggered_by")
      .eq("id", sos_event_id)
      .maybeSingle();
    if (fetchErr) return errorResponse(fetchErr.message, 500);
    if (!sosEvent) return errorResponse("SOS event not found", 404);

    // Already finished. Returning the row rather than an error means a double
    // tap, or a retry after a dropped connection, is harmless — which matters
    // more here than strictness, because the person pressing this is flustered.
    if (sosEvent.status === "cancelled" || sosEvent.status === "resolved") {
      return jsonResponse(sosEvent, 200);
    }

    const { data: elder, error: elderErr } = await admin
      .from("elder_profiles")
      .select("id, auth_user_id, display_name")
      .eq("id", sosEvent.elder_id)
      .single();
    if (elderErr || !elder) return errorResponse("Elder not found", 404);

    // Same authorization shape as raising one: the elder themselves, or an
    // active family link. Anyone who could have raised this alert can stand it
    // down — a family member who knows it was a false alarm should not have to
    // find the one person who pressed the button.
    const isElderSelf = elder.auth_user_id === user.id;
    const { data: link } = isElderSelf
      ? { data: null }
      : await admin
          .from("family_links")
          .select("id")
          .eq("elder_id", sosEvent.elder_id)
          .eq("family_user_id", user.id)
          .eq("status", "active")
          .maybeSingle();
    if (!isElderSelf && !link) {
      return errorResponse("Not authorized to cancel this SOS", 403);
    }

    const now = new Date().toISOString();
    const note = typeof reason === "string" && reason.trim().length > 0
      ? reason.trim().slice(0, 500)
      : "Cancelled as a false alarm";

    const { data: updated, error: updateErr } = await admin
      .from("sos_events")
      .update({ status: "cancelled", resolved_at: now, notes: note })
      .eq("id", sos_event_id)
      .select()
      .single();
    if (updateErr) return errorResponse(updateErr.message, 500);

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "sos_event",
      resource_id: sos_event_id,
      metadata: { elder_id: sosEvent.elder_id, cancelled: true },
    });

    // Same category and gating as the sos_triggered entry this retracts, so
    // the two sit together on the timeline instead of one being visible to a
    // reader who cannot see the other.
    await admin.from("elder_timeline_events").insert({
      elder_id: sosEvent.elder_id,
      event_type: "sos_cancelled",
      category: "visit_history",
      actor_user_id: user.id,
      summary: "Emergency SOS cancelled — false alarm",
      metadata: { sos_event_id, reason: note },
    });

    // Tell everyone who was told about the emergency. The recipient list is
    // rebuilt from the same queries sos-trigger used rather than stored, so a
    // family member who joined the circle in between still gets the stand-down
    // — being told about a cancellation you never heard raised is a moment of
    // confusion; missing it while driving is worse.
    const { data: familyLinks } = await admin
      .from("family_links")
      .select("family_user_id")
      .eq("elder_id", sosEvent.elder_id)
      .eq("status", "active");

    const familyUserIds = (familyLinks ?? []).map((f) => f.family_user_id);
    if (familyUserIds.length > 0) {
      await admin.from("notifications").insert(
        familyUserIds.map((uid) => ({
          user_id: uid,
          type: "sos_cancelled",
          payload: {
            sos_event_id,
            elder_id: sosEvent.elder_id,
            elder_name: elder.display_name,
            reason: note,
          },
        })),
      );
    }

    const { data: opsUsers } = await admin
      .from("admin_scopes")
      .select("profile_id")
      .eq("scope", "sos_operator");
    if (opsUsers && opsUsers.length > 0) {
      await admin.from("notifications").insert(
        opsUsers.map((o) => ({
          user_id: o.profile_id,
          type: "sos_cancelled",
          payload: {
            sos_event_id,
            elder_id: sosEvent.elder_id,
            elder_name: elder.display_name,
            reason: note,
          },
        })),
      );
    }

    return jsonResponse(updated, 200);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
