// PRD Part 7, Batch 4, Module 13 (AI Care Assistant): the one place in
// this codebase where an Edge Function deliberately executes queries AS
// THE CALLER, under RLS, rather than as the service role.
//
// Every other function uses supabaseAdmin() (service role, RLS bypassed)
// plus hand-written re-checks of the exact authorization it needs — the
// right pattern when a function has a fixed, enumerable set of call sites.
// It would be actively wrong for the AI assistant: an LLM's tool
// selection is not a fixed set of call sites, so hand-re-implementing
// every consent check the model might trigger, correctly, for every tool,
// is far more error-prone than letting Postgres RLS (already exhaustively
// tested by every other module) do it. So the assistant's tool calls run
// through this client, scoped to exactly what the requesting user could
// already see through the app — never a new access path.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// Builds a client that carries the caller's JWT on every request, so
// Postgres evaluates RLS as that user. Requires SUPABASE_ANON_KEY to be
// configured (the publishable key — safe to hold server-side; RLS is the
// real boundary either way).
export function supabaseAsUser(req: Request): SupabaseClient {
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
