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

/// Great-circle distance in km between two lat/lng points.
function haversineKm(
  lat1: number, lng1: number, lat2: number, lng2: number,
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { elder_id, service_id, lat, lng } = await req.json();
    if (!elder_id || !service_id) {
      return errorResponse("elder_id and service_id are required");
    }
    const originLat = typeof lat === "number" ? lat : null;
    const originLng = typeof lng === "number" ? lng : null;

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
      .select("id, user_id, caregiver_type, sub_role, trust_tier, created_at, demo")
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
          .select("caregiver_id, bio, photo_storage_path, latitude, longitude, years_experience, certifications, languages, available_days, available_from, available_to")
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
      // Distance from the family's current location, when shared.
      let distanceKm: number | null = null;
      if (originLat != null && originLng != null &&
          detail?.latitude != null && detail?.longitude != null) {
        distanceKm = haversineKm(
          originLat, originLng,
          Number(detail.latitude), Number(detail.longitude));
      }
      return {
        id: c.id,
        name: nameById.get(c.user_id) ?? "SETU caregiver",
        caregiver_type: c.caregiver_type,
        sub_role: c.sub_role,
        trust_tier: c.trust_tier,
        // A seeded sample profile, not a real person. Carried all the way to
        // the card so the app can say so plainly — see migration 0041.
        demo: c.demo === true,
        bio: detail?.bio ?? null,
        photo_url: photoUrl,
        average_stars: rating ? Number(rating.average_stars) : 0,
        rating_count: rating ? rating.rating_count : 0,
        distance_km: distanceKm,
        member_since: c.created_at,
        // Self-declared profile content. Anything SETU has actually checked
        // is reflected in trust_tier instead, and the app labels these as
        // the caregiver's own claims.
        years_experience: detail?.years_experience ?? null,
        certifications: detail?.certifications ?? [],
        languages: detail?.languages ?? [],
        available_days: detail?.available_days ?? [],
        available_from: detail?.available_from ?? null,
        available_to: detail?.available_to ?? null,
      };
    }));

    // When a location was shared, nearest first; otherwise best-presented
    // first (trust tier, then rating, then review count).
    const haveDistances = cards.some((c) => c.distance_km != null);
    cards.sort((a, b) => {
      if (haveDistances) {
        const da = a.distance_km ?? Number.MAX_VALUE;
        const db = b.distance_km ?? Number.MAX_VALUE;
        if (da !== db) return da - db;
      }
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
