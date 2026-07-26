// POST /functions/v1/clinics-import-places
// body: { region_id: uuid, lat: number, lng: number, radius_m?: number,
//         keyword?: string }
//
// Pulls nearby hospitals and clinics from the Google Places API into the
// clinic_imports staging table for a human to review.
//
// Why Places rather than scraping Practo, Justdial or hospital sites:
//
//  * Places is licensed for this. Those sites' terms prohibit scraping and
//    republishing, and their listings are a compiled database somebody else
//    paid to build. A legal notice is not a good use of a pre-revenue
//    startup's month.
//  * Places data is maintained. A scrape is a snapshot that rots silently,
//    and the failure mode here is an 80-year-old taken across Vizag to a
//    clinic that shut last year.
//  * Places returns *facilities* — public businesses. It does not return
//    named doctors, and that distinction is the point: a hospital's address
//    is public information, an individual practitioner's listing is theirs
//    to agree to. Doctors are added by hand, with consent recorded.
//
// So this import seeds the places. The people are still a phone call.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const PLACES_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";

interface PlaceResult {
  place_id: string;
  name: string;
  vicinity?: string;
  formatted_address?: string;
  geometry?: { location?: { lat: number; lng: number } };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);
  if (!PLACES_KEY) {
    return errorResponse(
      "Clinic import isn't configured yet — set GOOGLE_PLACES_API_KEY.",
      503,
    );
  }

  try {
    const user = await requireUser(req);
    const admin = supabaseAdmin();

    // Back-office only: this writes to the directory pipeline. Scopes live
    // in admin_scopes keyed by profile_id, the same table has_admin_scope()
    // reads in RLS.
    const { data: scopes } = await admin
      .from("admin_scopes")
      .select("scope")
      .eq("profile_id", user.id);
    const allowed = (scopes ?? []).some((s: { scope: string }) =>
      s.scope === "verification_agent" || s.scope === "super_admin"
    );
    if (!allowed) return errorResponse("Not authorized", 403);

    const { region_id, lat, lng, radius_m, keyword } = await req.json();
    if (typeof lat !== "number" || typeof lng !== "number") {
      return errorResponse("lat and lng are required");
    }
    // 10km covers a city like Visakhapatnam without pulling in the next
    // district; Places caps at 50km anyway.
    const radius = Math.min(Math.max(radius_m ?? 10000, 500), 50000);

    const url = new URL(
      "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
    );
    url.searchParams.set("location", `${lat},${lng}`);
    url.searchParams.set("radius", String(radius));
    url.searchParams.set("type", "hospital");
    if (keyword) url.searchParams.set("keyword", keyword);
    url.searchParams.set("key", PLACES_KEY);

    const res = await fetch(url);
    if (!res.ok) {
      console.error("places http error", res.status, await res.text());
      return errorResponse("Could not reach the Places API.", 502);
    }
    const body = await res.json();
    if (body.status !== "OK" && body.status !== "ZERO_RESULTS") {
      console.error("places api error", body.status, body.error_message);
      return errorResponse(
        `Places API returned ${body.status}. Check the key and its billing.`,
        502,
      );
    }

    const results: PlaceResult[] = body.results ?? [];
    const rows = results.map((p) => ({
      region_id: region_id ?? null,
      source: "google_places",
      source_ref: p.place_id,
      name: p.name,
      address: p.formatted_address ?? p.vicinity ?? null,
      lat: p.geometry?.location?.lat ?? null,
      lng: p.geometry?.location?.lng ?? null,
      raw: p as unknown as Record<string, unknown>,
      status: "pending",
    }));

    let staged = 0;
    if (rows.length > 0) {
      // Upsert on (source, source_ref) so re-running refreshes a listing
      // rather than duplicating it. Deliberately does NOT reset `status`:
      // something an admin already rejected must stay rejected, otherwise
      // every re-run resurrects the rows they threw out.
      const { error, count } = await admin
        .from("clinic_imports")
        .upsert(rows, {
          onConflict: "source,source_ref",
          ignoreDuplicates: true,
          count: "exact",
        });
      if (error) return errorResponse(error.message, 500);
      staged = count ?? 0;
    }

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "clinic_import",
      resource_id: region_id ?? null,
      metadata: { source: "google_places", found: results.length, staged },
    });

    return jsonResponse({
      found: results.length,
      staged,
      note:
        "Staged for review. Nothing is visible to families until an admin " +
        "promotes it, and named doctors are added separately with consent.",
    }, 200);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
