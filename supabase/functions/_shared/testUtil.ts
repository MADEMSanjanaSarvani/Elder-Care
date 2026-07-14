// Minimal, dependency-free assertion helpers for the *.test.ts files in
// this directory. Not a general-purpose test framework — just enough to
// avoid depending on jsr:@std/assert, which this environment's network
// policy blocks (jsr.io returns 403). If a real Supabase CLI / CI
// environment has jsr.io access, swapping back to @std/assert is a
// reasonable thing to do there; this exists to make the tests runnable
// without it.

export function assertEquals<T>(actual: T, expected: T, msg?: string): void {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (!ok) {
    throw new Error(msg ?? `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

export function assertStringIncludes(actual: string, expected: string, msg?: string): void {
  if (!actual.includes(expected)) {
    throw new Error(msg ?? `Expected "${actual}" to include "${expected}"`);
  }
}
