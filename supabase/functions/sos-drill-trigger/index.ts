// POST /functions/v1/sos-drill-trigger
// body: { elder_id?: uuid }
//
// PRD Part 10, Batch 7, Module 25. A practice run of the SOS flow —
// DELIBERATELY SEPARATE from sos-trigger, sharing no code path with the
// real emergency trigger. This eliminates any risk that a bug in shared
// logic could make a drill fan out real notifications, or vice versa.
//
// A drill gives feedback ONLY to the practicing user, on their own device
// (this response). It writes a sos_drills row and NOTHING else — no
// family push, no ops alert, no notifications row, no sos_events row. The
// two tables and two functions are kept apart on purpose (see 0020's
// comment on why drills are not an is_drill flag on sos_events).
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const DRILL_FEEDBACK =
  "Practice complete. In a real emergency: press and hold SOS, then the app shows the 108 number " +
  "first — call it. Your family and our on-call team are alerted at the same time. Calling 108 is " +
  "always the fastest way to get medical help; the app does not replace it.";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { elder_id } = await req.json().catch(() => ({ elder_id: null }));

    const admin = supabaseAdmin();
    // Record the drill for the practicing user's own history and for
    // aggregate drill-completion tracking. This is the ONLY write.
    const { data: drill, error } = await admin
      .from("sos_drills")
      .insert({ triggered_by: user.id, elder_id: elder_id ?? null, feedback: DRILL_FEEDBACK })
      .select()
      .single();
    if (error) return errorResponse(error.message, 500);

    return jsonResponse({ drill_id: drill.id, feedback: DRILL_FEEDBACK, is_drill: true });
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
