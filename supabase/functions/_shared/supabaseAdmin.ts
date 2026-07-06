// Service-role client for Edge Functions.
//
// PRD Part 2 §12/§13: Edge Functions own every path that touches a secret
// or a cross-table rule (bookings, payments, payouts, SOS, AI, verification
// webhooks). The service-role key bypasses RLS by design — every function
// in this directory is responsible for re-checking the authorization it
// needs (see `requireUser` below) instead of relying on Postgres to do it.
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

export function supabaseAdmin(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// Verifies the caller's JWT (passed through from the Flutter client's
// Supabase session) and returns the authenticated user, without granting
// the function any of the client's RLS-scoped permissions — those checks
// are done explicitly, table by table, in each function below.
export async function requireUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Missing Authorization header");
  }
  const jwt = authHeader.replace("Bearer ", "");
  const { data, error } = await supabaseAdmin().auth.getUser(jwt);
  if (error || !data.user) {
    throw new Error("Invalid or expired session");
  }
  return data.user;
}
