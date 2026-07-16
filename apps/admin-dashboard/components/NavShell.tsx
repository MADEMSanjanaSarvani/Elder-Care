import Link from "next/link";

import { hasScope, type CurrentAdmin } from "@/lib/auth";
import { SignOutButton } from "./SignOutButton";

const NAV_ITEMS: { href: string; label: string; scope?: Parameters<typeof hasScope>[1] }[] = [
  { href: "/", label: "Overview" },
  { href: "/verification", label: "Verification queue", scope: "verification_agent" },
  { href: "/sos", label: "Live SOS monitor", scope: "sos_operator" },
  { href: "/bookings", label: "Bookings & disputes", scope: "ops_admin" },
  { href: "/caregivers", label: "Caregiver directory", scope: "ops_admin" },
  { href: "/ai-review", label: "AI review queue", scope: "ops_admin" },
  { href: "/payouts", label: "Payout reconciliation", scope: "finance_ops" },
  { href: "/analytics", label: "Care analytics", scope: "ops_admin" },
  { href: "/services", label: "Service catalog", scope: "super_admin" },
  { href: "/erasure-requests", label: "Erasure requests", scope: "super_admin" },
  { href: "/audit", label: "Audit log", scope: "super_admin" },
];

export function NavShell({ admin, children }: { admin: CurrentAdmin; children: React.ReactNode }) {
  const visibleItems = NAV_ITEMS.filter((item) => !item.scope || hasScope(admin, item.scope));

  return (
    <div className="flex min-h-screen">
      <aside className="w-60 shrink-0 border-r border-border bg-paper-raised px-4 py-6">
        <div className="mb-8 px-2">
          <div className="text-xs font-mono uppercase tracking-wide text-accent">Project Setu</div>
          <div className="text-lg font-semibold">Ops Console</div>
        </div>
        <nav className="flex flex-col gap-0.5">
          {visibleItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded px-2.5 py-2 text-sm text-muted hover:bg-paper hover:text-ink"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="mt-8 border-t border-border pt-4 px-2 text-xs text-muted">
          <div className="mb-2">{admin.displayName ?? "Signed in"}</div>
          <SignOutButton />
        </div>
      </aside>
      <main className="flex-1 bg-paper px-8 py-8">{children}</main>
    </div>
  );
}
