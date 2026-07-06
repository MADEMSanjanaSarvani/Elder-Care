import Link from "next/link";

import { requireAdmin, hasScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export default async function OverviewPage() {
  const admin = await requireAdmin();
  const supabase = await createClient();

  const [pendingVerification, activeSos, flaggedAi, disputedBookings] = await Promise.all([
    hasScope(admin, "verification_agent")
      ? supabase.from("caregivers").select("id", { count: "exact", head: true }).eq("trust_tier", "probationary")
      : Promise.resolve({ count: 0 }),
    hasScope(admin, "sos_operator")
      ? supabase.from("sos_events").select("id", { count: "exact", head: true }).neq("status", "resolved")
      : Promise.resolve({ count: 0 }),
    hasScope(admin, "ops_admin")
      ? supabase.from("ai_interactions").select("id", { count: "exact", head: true }).eq("flagged", true).eq("human_reviewed", false)
      : Promise.resolve({ count: 0 }),
    hasScope(admin, "ops_admin")
      ? supabase.from("bookings").select("id", { count: "exact", head: true }).eq("status", "disputed")
      : Promise.resolve({ count: 0 }),
  ]);

  const cards = [
    { href: "/verification", label: "Caregivers awaiting full verification", value: pendingVerification.count, scope: "verification_agent" as const },
    { href: "/sos", label: "Active SOS events", value: activeSos.count, scope: "sos_operator" as const },
    { href: "/ai-review", label: "AI outputs pending review", value: flaggedAi.count, scope: "ops_admin" as const },
    { href: "/bookings", label: "Disputed bookings", value: disputedBookings.count, scope: "ops_admin" as const },
  ].filter((card) => hasScope(admin, card.scope));

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">Overview</h1>
      <p className="mb-8 text-sm text-muted">Signed in as {admin.displayName ?? admin.id}</p>

      {cards.length === 0 ? (
        <p className="text-sm text-muted">Your account has no admin scopes assigned yet — ask a super_admin to grant one.</p>
      ) : (
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
          {cards.map((card) => (
            <Link
              key={card.href}
              href={card.href}
              className="rounded border border-border bg-paper-raised p-5 hover:border-accent"
            >
              <div className="text-3xl font-semibold tabular-nums">{card.value}</div>
              <div className="mt-1 text-sm text-muted">{card.label}</div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
