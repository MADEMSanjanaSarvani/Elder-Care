// POST /functions/v1/analytics-refresh
//
// PRD Part 9, Batch 6, Module 23. Refreshes the care-analytics
// materialized views on a schedule so dashboard reads stay cheap and never
// compete with live transactional traffic. No user JWT — shared-secret
// header. Delegates to the refresh_analytics_views() database function
// (security definer), which owns the refresh of all four matviews.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const ANALYTICS_REFRESH_SHARED_SECRET = Deno.env.get("ANALYTICS_REFRESH_SHARED_SECRET")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-analytics-refresh-secret");
  if (providedSecret !== ANALYTICS_REFRESH_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const { error } = await admin.rpc("refresh_analytics_views");
  if (error) return errorResponse(error.message, 500);

  return jsonResponse({ refreshed: true });
});
