import { requireAdmin } from "@/lib/auth";
import { NavShell } from "@/components/NavShell";

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const admin = await requireAdmin();
  return <NavShell admin={admin}>{children}</NavShell>;
}
