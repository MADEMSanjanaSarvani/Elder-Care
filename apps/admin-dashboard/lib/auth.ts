import { redirect } from "next/navigation";

import { createClient } from "./supabase/server";
import type { AdminScope } from "./types";

export interface CurrentAdmin {
  id: string;
  displayName: string | null;
  scopes: AdminScope[];
}

/**
 * Server-side gate used at the top of every dashboard page. Redirects
 * anyone who isn't `profiles.role = 'admin'` — this mirrors what RLS
 * already enforces on every table underneath (a non-admin session would
 * just get empty results from these queries), but failing fast with a
 * clear redirect is better UX than a dashboard silently rendering nothing.
 */
export async function requireAdmin(): Promise<CurrentAdmin> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("role, display_name")
    .eq("id", user.id)
    .single();

  if (!profile || profile.role !== "admin") {
    redirect("/login?error=not_an_admin");
  }

  const { data: scopeRows } = await supabase
    .from("admin_scopes")
    .select("scope")
    .eq("profile_id", user.id);

  return {
    id: user.id,
    displayName: profile.display_name,
    scopes: (scopeRows ?? []).map((row) => row.scope as AdminScope),
  };
}

export function hasScope(admin: CurrentAdmin, scope: AdminScope): boolean {
  return admin.scopes.includes(scope) || admin.scopes.includes("super_admin");
}

/** Use inside a page/Server Action that requires a specific scope beyond plain admin. */
export function requireScope(admin: CurrentAdmin, scope: AdminScope): void {
  if (!hasScope(admin, scope)) {
    redirect("/?error=insufficient_scope");
  }
}
