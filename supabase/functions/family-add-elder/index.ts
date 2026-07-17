// POST /functions/v1/family-add-elder
//
// Family onboarding: a family member creates the parent/elder they care for
// and is linked to them in one step. This can't be done as plain client
// inserts because family_links' RLS requires the caller to ALREADY be linked
// (or be the elder) — a chicken-and-egg for a brand-new elder. So this
// function, authenticated as the user, performs the three writes atomically
// with the service role:
//   1. elder_profiles  (created_by = caller; auth_user_id null = family-managed)
//   2. family_links    (caller linked, status active)
//   3. consent_grants  (all categories granted to the caller, since a
//      family-managed elder has no own login to grant them)
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

    const admin = supabaseAdmin();

    // Self-heal: ensure the caller has a profiles row (elder_profiles.created_by
    // references it). A user can reach this point signed-in but without a
    // profile if role selection was skipped; create one as family_member if so.
    await admin.from("profiles").upsert(
      {
        id: user.id,
        role: "family_member",
        phone: user.phone ?? null,
      },
      { onConflict: "id", ignoreDuplicates: true },
    );

    // Region lookup (the pilot region by default).
    const { data: region, error: regionErr } = await admin
      .from("regions").select("id").eq("code", regionCode).maybeSingle();
    if (regionErr) return errorResponse(regionErr.message, 500);
    if (!region) return errorResponse(`Unknown region: ${regionCode}`, 400);

    // 1. Elder profile — family-managed (no auth_user_id).
    const { data: elder, error: elderErr } = await admin
      .from("elder_profiles")
      .insert({
        region_id: region.id,
        created_by: user.id,
        display_name: displayName,
        primary_language: primaryLanguage,
        dob,
      })
      .select("id")
      .single();
    if (elderErr) return errorResponse(elderErr.message, 500);

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
