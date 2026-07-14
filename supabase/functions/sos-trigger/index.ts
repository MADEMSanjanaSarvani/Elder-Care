// POST /functions/v1/sos-trigger
// body: { elder_id: uuid, lat: number, lng: number, ack_108_shown: boolean }
//
// PRD Part 1 §04 / Part 2 §11,§12: "Call 108 first" is enforced client-side
// as the mandatory primary action on the SOS screen. `ack_108_shown` is the
// client's confirmation that screen was actually displayed before this
// function was called — recorded as `ack_108_shown_at`, which is the audit
// evidence behind the liability boundary described in Part 1. This function
// refuses to fire the notification cascade without it, on the theory that
// a client that skipped the screen shouldn't get the parallel escalation
// either — that path is what's supposed to run *alongside* calling 108,
// not instead of it.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { elder_id, lat, lng, ack_108_shown } = await req.json();
    if (!elder_id || lat === undefined || lng === undefined) {
      return errorResponse("elder_id, lat, and lng are required");
    }
    if (!ack_108_shown) {
      return errorResponse("The 108-first screen must be shown before platform escalation runs", 422);
    }

    const admin = supabaseAdmin();

    const { data: elder, error: elderErr } = await admin
      .from("elder_profiles")
      .select("id, auth_user_id, display_name")
      .eq("id", elder_id)
      .single();
    if (elderErr || !elder) return errorResponse("Elder not found", 404);

    const isElderSelf = elder.auth_user_id === user.id;
    const { data: link } = isElderSelf
      ? { data: null }
      : await admin
          .from("family_links")
          .select("id")
          .eq("elder_id", elder_id)
          .eq("family_user_id", user.id)
          .eq("status", "active")
          .maybeSingle();
    if (!isElderSelf && !link) return errorResponse("Not authorized to raise SOS for this elder", 403);

    const now = new Date().toISOString();
    const { data: sosEvent, error: insertErr } = await admin
      .from("sos_events")
      .insert({
        elder_id,
        triggered_by: user.id,
        location: `SRID=4326;POINT(${lng} ${lat})`,
        status: "triggered",
        ack_108_shown_at: now,
      })
      .select()
      .single();
    if (insertErr) return errorResponse(insertErr.message, 500);

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "sos_event",
      resource_id: sosEvent.id,
      metadata: { elder_id },
    });

    // Fan out to every active family link.
    const { data: familyLinks } = await admin
      .from("family_links")
      .select("family_user_id")
      .eq("elder_id", elder_id)
      .eq("status", "active");

    const notifiedUserIds = (familyLinks ?? []).map((f) => f.family_user_id);
    if (notifiedUserIds.length > 0) {
      await admin.from("notifications").insert(
        notifiedUserIds.map((uid) => ({
          user_id: uid,
          type: "sos_triggered",
          payload: { sos_event_id: sosEvent.id, elder_id, elder_name: elder.display_name, lat, lng },
        }))
      );
    }

    // Notify on-call ops (sos_operator scope) so a human is in the loop
    // immediately, not just family.
    const { data: opsUsers } = await admin
      .from("admin_scopes")
      .select("profile_id")
      .eq("scope", "sos_operator");
    if (opsUsers && opsUsers.length > 0) {
      await admin.from("notifications").insert(
        opsUsers.map((o) => ({
          user_id: o.profile_id,
          type: "sos_ops_alert",
          payload: { sos_event_id: sosEvent.id, elder_id, lat, lng },
        }))
      );
    }

    const { data: updated } = await admin
      .from("sos_events")
      .update({ status: "family_notified", family_notified_at: now })
      .eq("id", sosEvent.id)
      .select()
      .single();

    // TODO(Part 3 deployment): also push via FCM here, not just write to
    // `notifications` — the in-app row alone isn't sufficient for a
    // life-safety alert if the recipient's app is backgrounded.
    return jsonResponse(updated ?? sosEvent, 201);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
