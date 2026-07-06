"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { createClient } from "@/lib/supabase/client";

export function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const initialError = searchParams.get("error");

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(
    initialError === "not_an_admin" ? "That account is not registered as an admin." : null,
  );

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (signInError) {
      setError(signInError.message);
      return;
    }
    router.push("/");
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="w-full max-w-sm rounded border border-border bg-paper-raised p-8">
      <div className="mb-1 text-xs font-mono uppercase tracking-wide text-accent">Project Setu</div>
      <h1 className="mb-6 text-xl font-semibold">Ops Console</h1>

      {error && <p className="mb-4 rounded bg-sos/10 px-3 py-2 text-sm text-sos">{error}</p>}

      <label className="mb-3 block text-sm">
        <span className="mb-1 block text-muted">Email</span>
        <input
          type="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className="w-full rounded border border-border bg-paper px-3 py-2"
        />
      </label>
      <label className="mb-5 block text-sm">
        <span className="mb-1 block text-muted">Password</span>
        <input
          type="password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          className="w-full rounded border border-border bg-paper px-3 py-2"
        />
      </label>
      <button
        type="submit"
        disabled={busy}
        className="w-full rounded bg-accent py-2 font-medium text-white disabled:opacity-50"
      >
        {busy ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
