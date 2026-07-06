import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/**
 * Server Component / Server Action client — still built from the
 * signed-in admin's cookies, not the service role key, so RLS remains the
 * enforcement layer even for server-rendered pages. Use `adminClient()`
 * (lib/supabase/admin.ts) only for the narrow set of actions that
 * genuinely need to bypass RLS to call a secret-holding third party.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, options);
            });
          } catch {
            // Called from a Server Component during render — the
            // middleware below is what actually persists session refresh
            // in that case, so this is safe to swallow.
          }
        },
      },
    },
  );
}
