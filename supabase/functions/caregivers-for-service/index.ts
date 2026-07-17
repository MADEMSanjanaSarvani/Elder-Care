// POST /functions/v1/caregivers-for-service
// body: { elder_id: uuid, service_id: uuid }
//
// Returns the curated, privacy-safe list of caregivers a family can CHOOSE
// from for a given service — so booking is "pick the person you trust", not
// a blind auto-match. RLS deliberately hides the caregiver pool from families
// until a booking exists (chicken-and-egg), so this runs with the service
// role and returns only non-sensitive, family-facing fields: name, role,
// trust tier, bio, photo and the public rating aggregate. Verification
// documents and identifiers never leave the server.
//
// Only active, background-verified (bgv 'cleared') caregivers in the elder's
// region whose trust tier meets the service's requirement are listed.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const TIER_RANK: Record<string, number> = {
  probationary: 0,
  standard: 1,
  clinical_verified: 2,
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { elder_id, service_id } = await req.json();
    if (!elder_id || !service_id) {
      return errorResponse("elder_id and service_id are required");
    }

    const admin = supabaseAdmin();

    // Authorize: caller must be the elder or an active linked family member.
    const { data: elder, error: elderErr } = await admin
      .from("elder_profiles")
      .select("id, region_id, auth_user_id")
      .eq("id", elder_id)
      .single();
    if (elderErr || !elder) return errorResponse("Elder not found", 404);

    const isElderSelf = elder.auth_user_id === user.id;
    if (!isElderSelf) {
      const { data: link } = await admin
        .from("family_links")
        .select("id")
        .eq("elder_id", elder_id)
        .eq("family_user_id", user.id)
        .eq("status", "active")
        .maybeSingle();
      if (!link) return errorResponse("Not authorized for this elder", 403);
    }

    const { data: service, error: serviceErr } = await admin
      .from("service_catalog")
      .select("id, region_id, requires_trust_tier, name")
      .eq("id", service_id)
      .single();
    if (serviceErr || !service) return errorResponse("Service not found", 404);

    const minRank = TIER_RANK[service.requires_trust_tier] ?? 0;

    // Verified, active caregivers in the elder's region.
    const { data: caregivers, error: cgErr } = await admin
      .from("caregivers")
      .select("id, user_id, caregiver_type, sub_role, trust_tier, created_at")
      .eq("region_id", elder.region_id)
      .eq("active", true)
      .eq("bgv_status", "cleared");
    if (cgErr) return errorResponse(cgErr.message, 500);

    const eligible = (caregivers ?? []).filter(
      (c) => (TIER_RANK[c.trust_tier] ?? 0) >= minRank,
    );
    if (eligible.length === 0) return jsonResponse({ caregivers: [] }, 200);

    const ids = eligible.map((c) => c.id);
    const userIds = eligible.map((c) => c.user_id);

    // Enrich: names, bio/photo, and the public rating aggregate.
    const [{ data: profiles }, { data: details }, { data: ratings }] =
      await Promise.all([
        admin.from("profiles").select("id, display_name").in("id", userIds),
        admin
          .from("caregiver_profile_details")
          .select("caregiver_id, bio, photo_storage_path")
          .in("caregiver_id", ids),
        admin
          .from("caregiver_rating_summary")
          .select("caregiver_id, average_stars, rating_count")
          .in("caregiver_id", ids),
      ]);

    const nameById = new Map((profiles ?? []).map((p) => [p.id, p.display_name]));
    const detailById = new Map((details ?? []).map((d) => [d.caregiver_id, d]));
    const ratingById = new Map((ratings ?? []).map((r) => [r.caregiver_id, r]));

    const cards = await Promise.all(eligible.map(async (c) => {
      const detail = detailById.get(c.id);
      const rating = ratingById.get(c.id);
      let photoUrl: string | null = null;
      const path = detail?.photo_storage_path as string | undefined;
      if (path) {
        const { data: signed } = await admin.storage
          .from("caregiver-profile-photos")
          .createSignedUrl(path, 60 * 60);
        photoUrl = signed?.signedUrl ?? null;
      }
      return {
        id: c.id,
        name: nameById.get(c.user_id) ?? "CareHive caregiver",
        caregiver_type: c.caregiver_type,
        sub_role: c.sub_role,
        trust_tier: c.trust_tier,
        bio: detail?.bio ?? null,
        photo_url: photoUrl,
        average_stars: rating ? Number(rating.average_stars) : 0,
        rating_count: rating ? rating.rating_count : 0,
        member_since: c.created_at,
      };
    }));

    // Best-presented first: higher trust tier, then higher rating, then more
    // reviews.
    cards.sort((a, b) => {
      const t = (TIER_RANK[b.trust_tier] ?? 0) - (TIER_RANK[a.trust_tier] ?? 0);
      if (t !== 0) return t;
      if (b.average_stars !== a.average_stars) {
        return b.average_stars - a.average_stars;
      }
      return b.rating_count - a.rating_count;
    });

    return jsonResponse({ caregivers: cards }, 200);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
