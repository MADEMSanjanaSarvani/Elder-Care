import { createBrowserClient } from "@supabase/ssr";

/**
 * Browser-side client used by Client Components. Carries the signed-in
 * admin's own session — every query still goes through RLS
 * (supabase/migrations/0002_rls.sql), so this client can never see more
 * than that admin's `admin_scopes` rows permit, regardless of anything
 * the UI does or doesn't render.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
