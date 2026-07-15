// POST /functions/v1/family-invite
// body: { elder_id: uuid, invitee_email: string, invitee_phone?: string, relationship?: string }
//
// PRD Part 4, Batch 1, Module 4 (Family Member Management). Creates a
// real account for the invitee via the Auth Admin API before creating the
// family_links row — family_links.family_user_id is a NOT NULL fk to
// profiles, so a pending invite needs a real profile id to point to, not
// a bare phone number the PRD's own text implied could stand in for one.
// Supabase's built-in invite-by-email flow gives us exactly that (an
// auth.users row plus a real id to build on) without needing a separate
// phone-keyed pending-invite table or a third-party SMS integration for
// MVP — a deliberate simplification versus the PRD's SMS-first framing,
// since this primitive already satisfies "the invitee doesn't need the
// app installed to accept." SMS as an additional channel for phone-
// primary families remains a reasonable Phase 2+ addition, not built here.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

// No more than 5 invites per elder in a rolling 24h window — the PRD's
// own non-functional requirement, preventing spam-inviting strangers.
const MAX_INVITES_PER_DAY = 5;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { elder_id, invitee_email, invitee_phone, relationship } = await req.json();
    if (!elder_id || !invitee_email) return errorResponse("elder_id and invitee_email are required");

    const admin = supabaseAdmin();

    const { data: elder, error: elderErr } = await admin
      .from("elder_profiles")
      .select("id, auth_user_id")
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
      return errorResponse("Not authorized to invite family for this elder", 403);
    }

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { count } = await admin
      .from("family_links")
      .select("id", { count: "exact", head: true })
      .eq("elder_id", elder_id)
      .gte("created_at", since);
    if ((count ?? 0) >= MAX_INVITES_PER_DAY) {
      return errorResponse("Too many invites sent for this elder in the last 24 hours", 429);
    }

    // Inviting someone who already has an account links them, rather than
    // creating a duplicate — email is the natural lookup key here.
    const { data: existingUsers } = await admin.auth.admin.listUsers();
    let inviteeId = existingUsers?.users.find((u) => u.email === invitee_email)?.id;

    if (!inviteeId) {
      const { data: created, error: createErr } = await admin.auth.admin.inviteUserByEmail(invitee_email);
      if (createErr || !created.user) {
        return errorResponse(createErr?.message ?? "Could not create an account for the invitee", 500);
      }
      inviteeId = created.user.id;

      const { error: profileErr } = await admin.from("profiles").insert({
        id: inviteeId,
        role: "family_member",
        phone: invitee_phone ?? null,
      });
      if (profileErr) return errorResponse(profileErr.message, 500);
    }

    const { data: familyLink, error: linkErr } = await admin
      .from("family_links")
      .insert({
        elder_id,
        family_user_id: inviteeId,
        relationship: relationship ?? null,
        status: "pending",
        invited_by: user.id,
      })
      .select()
      .single();
    if (linkErr) return errorResponse(linkErr.message, 500);

    await admin.from("notifications").insert({
      user_id: inviteeId,
      type: "family_invite_sent",
      payload: { elder_id, family_link_id: familyLink.id, invited_by: user.id },
    });

    return jsonResponse(familyLink, 201);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
