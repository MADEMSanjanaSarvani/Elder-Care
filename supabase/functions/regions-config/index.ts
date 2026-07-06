// GET /functions/v1/regions-config?code=vizag-ap-in
//
// PRD Part 2 §12: clients read a region's currency, tax profile, and
// provider config once at startup instead of hardcoding India/INR anywhere.
// (Note: `regions` is world-readable to any authenticated user under RLS,
// so a direct client select would also work — this function exists to
// give the config a stable, versionable contract as more fields are added
// per-region across Phases 2-6.)
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  try {
    await requireUser(req); // any authenticated user may read region config

    const code = new URL(req.url).searchParams.get("code");
    if (!code) return errorResponse("Missing 'code' query parameter");

    const { data, error } = await supabaseAdmin()
      .from("regions")
      .select("code, display_name, country_code, currency, tax_profile, payment_provider, bgv_provider, compliance_profile, status")
      .eq("code", code)
      .single();

    if (error || !data) return errorResponse("Region not found", 404);
    return jsonResponse(data);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
