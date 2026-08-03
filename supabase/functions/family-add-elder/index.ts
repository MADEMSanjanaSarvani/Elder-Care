// POST /functions/v1/family-add-elder
//
// Creates the person whose medicines are being tracked. Two shapes:
//
// **Family-managed** (default) — a family member creates the parent they care
// for and is linked to them in one step. Three writes:
//   1. elder_profiles  (created_by = caller; auth_user_id null = family-managed)
//   2. family_links    (caller linked, status active)
//   3. consent_grants  (all categories granted to the caller, since a
//      family-managed elder has no own login to grant them)
//
// **Self** (`{ self: true }`) — the person sets themselves up, and owns the
// record: `auth_user_id = caller`. No family_link and no consent_grants,
// because there is nobody to link or to grant to; family are added later from
// Family access, which is where consent belongs.
//
// The self path is not a nicety. Without it an elder who installs CareHive
// alone lands on "Ask your family to add you, then sign in again" and can do
// nothing at all — `myElderProfilesProvider` looks for
// `elder_profiles.auth_user_id = me`, and until now literally nothing in the
// system ever set that column. CareHive's whole premise is that it works with
// no second person involved, so a dead end that requires one was the single
// worst bug in the app.
//
// Either path needs the service role: family_links' RLS requires the caller to
// ALREADY be linked (or be the elder), a chicken-and-egg for a brand-new row.
//
// requireUser(); returns { elder_id }.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const CONSENT_CATEGORIES = [
  "location_live",
  "location_history",
  "health_notes",
  "medication_list",
  "visit_history",
  "billing",
  "wellbeing_checkins",
];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const body = await req.json().catch(() => ({}));
    const displayName = (body.display_name ?? "").toString().trim();
    if (!displayName) return errorResponse("A name is required", 400);

    const relationship = (body.relationship ?? "").toString().trim() || null;
    const primaryLanguage = (body.primary_language ?? "en").toString();
    const regionCode = (body.region_code ?? "vizag-ap-in").toString();
    const dob = body.dob ? body.dob.toString() : null;
    const isSelf = body.self === true;

    const admin = supabaseAdmin();

    // Self-heal: ensure the caller has a profiles row (elder_profiles.created_by
    // references it). A user can reach this point signed-in but without a
    // profile if role selection was skipped.
    await admin.from("profiles").upsert(
      {
        id: user.id,
        role: isSelf ? "elder" : "family_member",
        // Email accounts have no phone; store null (not "") — profiles.phone
        // is UNIQUE and Postgres allows many nulls but only one empty string.
        phone: user.phone ? user.phone : null,
      },
      { onConflict: "id", ignoreDuplicates: true },
    );

    // One self-record per account. Without this, tapping the setup button
    // twice — or once on a slow connection — leaves somebody with two copies
    // of themselves and their medicines split across both.
    if (isSelf) {
      const { data: existing } = await admin
        .from("elder_profiles")
        .select("id")
        .eq("auth_user_id", user.id)
        .maybeSingle();
      if (existing) return jsonResponse({ elder_id: existing.id }, 200);
    }

    // Region lookup (the pilot region by default).
    const { data: region, error: regionErr } = await admin
      .from("regions").select("id").eq("code", regionCode).maybeSingle();
    if (regionErr) return errorResponse(regionErr.message, 500);
    if (!region) return errorResponse(`Unknown region: ${regionCode}`, 400);

    // 1. The elder profile. `auth_user_id` is what makes it self-owned: it is
    //    the column elder_profiles' RLS checks first, and the one the app
    //    reads to find "the person that is me".
    const { data: elder, error: elderErr } = await admin
      .from("elder_profiles")
      .insert({
        region_id: region.id,
        created_by: user.id,
        auth_user_id: isSelf ? user.id : null,
        display_name: displayName,
        primary_language: primaryLanguage,
        dob,
      })
      .select("id")
      .single();
    if (elderErr) return errorResponse(elderErr.message, 500);

    // A self-managed record stops here. There is no family member to link and
    // nobody to grant consent to — the person owns their own row, and RLS
    // already lets them read and write it. Family are added afterwards from
    // Family access, which is where the consent decisions belong: granting
    // them here would silently hand out access nobody had asked for.
    if (isSelf) return jsonResponse({ elder_id: elder.id }, 201);

    // 2. Link the family member, active immediately.
    const { error: linkErr } = await admin.from("family_links").insert({
      elder_id: elder.id,
      family_user_id: user.id,
      invited_by: user.id,
      relationship,
      status: "active",
    });
    if (linkErr) return errorResponse(linkErr.message, 500);

    // 3. Grant the creator full visibility (the elder has no own login).
    const now = new Date().toISOString();
    const { error: consentErr } = await admin.from("consent_grants").insert(
      CONSENT_CATEGORIES.map((category) => ({
        elder_id: elder.id,
        family_user_id: user.id,
        category,
        granted: true,
        granted_via: "elder_app",
        granted_at: now,
      })),
    );
    if (consentErr) return errorResponse(consentErr.message, 500);

    return jsonResponse({ elder_id: elder.id }, 201);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
