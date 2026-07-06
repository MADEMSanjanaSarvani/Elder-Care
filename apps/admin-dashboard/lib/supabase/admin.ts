import { createClient as createSupabaseClient } from "@supabase/supabase-js";

/**
 * Service-role client. Bypasses RLS entirely — reserve it for the small
 * number of Server Actions that need to call a secret-holding third party
 * (e.g. RazorpayX payout retry). Every caller of this must independently
 * verify the signed-in admin's scope first (see `requireScope` in
 * lib/auth.ts) — the service role key does not know or care who's asking.
 */
export function adminClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}
