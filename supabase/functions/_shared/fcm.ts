// Firebase Cloud Messaging — the actual sending half.
//
// Until now the app collected an FCM token into `user_devices` and nothing
// ever sent to it. Reminders were written into the `notifications` table and
// surfaced over Realtime, which means they only ever appeared **while the app
// was open**. For a medicine reminder that is the same as not existing: the
// phone is in a pocket at 8am and nothing happens.
//
// This talks to FCM HTTP v1, which needs an OAuth2 access token minted from a
// service account rather than the old static server key. The whole dance is
// here — sign a JWT with the service account's private key, swap it for an
// access token, cache it until it expires — so callers just say sendPush().
//
// Fail-soft on purpose, like the client side: if FIREBASE_SERVICE_ACCOUNT is
// not set, sendPush() logs once and returns. A missing push config must never
// take down the sweep that also writes the in-app notification rows.

import { type SupabaseClient } from "npm:@supabase/supabase-js@2";

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

let cachedAccount: ServiceAccount | null | undefined;
let cachedToken: { value: string; expiresAt: number } | null = null;
let warned = false;

function serviceAccount(): ServiceAccount | null {
  if (cachedAccount !== undefined) return cachedAccount;
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
  if (!raw.trim()) {
    cachedAccount = null;
    return null;
  }
  try {
    const parsed = JSON.parse(raw) as ServiceAccount;
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      console.error("[fcm] FIREBASE_SERVICE_ACCOUNT is missing required fields");
      cachedAccount = null;
      return null;
    }
    cachedAccount = parsed;
    return parsed;
  } catch (err) {
    console.error("[fcm] FIREBASE_SERVICE_ACCOUNT is not valid JSON:", err);
    cachedAccount = null;
    return null;
  }
}

function base64url(bytes: Uint8Array): string {
  // Chunked rather than String.fromCharCode(...bytes): a spread of a large
  // array overflows the call stack, and signatures are 256 bytes.
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlText(text: string): string {
  return base64url(new TextEncoder().encode(text));
}

/// Turns the PEM private key from the service account JSON into a signing key.
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    // The JSON carries the newlines as literal \n once it has been through an
    // environment variable, so both forms have to go.
    .replace(/\\n/g, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der.buffer as ArrayBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function accessToken(account: ServiceAccount): Promise<string | null> {
  // 30s of slack so a token never expires mid-request.
  if (cachedToken && cachedToken.expiresAt > Date.now() + 30_000) {
    return cachedToken.value;
  }

  const tokenUri = account.token_uri ?? "https://oauth2.googleapis.com/token";
  const now = Math.floor(Date.now() / 1000);
  const header = base64urlText(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64urlText(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));

  try {
    const key = await importPrivateKey(account.private_key);
    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(`${header}.${claims}`),
    );
    const jwt = `${header}.${claims}.${base64url(new Uint8Array(signature))}`;

    const res = await fetch(tokenUri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });
    if (!res.ok) {
      console.error("[fcm] token exchange failed", res.status, await res.text());
      return null;
    }
    const body = await res.json() as { access_token: string; expires_in: number };
    cachedToken = {
      value: body.access_token,
      expiresAt: Date.now() + (body.expires_in ?? 3600) * 1000,
    };
    return cachedToken.value;
  } catch (err) {
    console.error("[fcm] could not mint an access token:", err);
    return null;
  }
}

export interface PushMessage {
  title: string;
  body: string;
  /// Extra values the app reads when the notification is opened. FCM requires
  /// every data value to be a string, so numbers and ids are stringified here
  /// rather than at each call site.
  data?: Record<string, string | number | null | undefined>;
  /// Android channel. Dose reminders and emergencies must not share one — a
  /// person who silences reminders must not thereby silence an SOS.
  channelId?: string;
  /// Emergencies bypass battery-saver batching; reminders do not need to.
  highPriority?: boolean;
}

export interface PushResult {
  sent: number;
  failed: number;
  pruned: number;
}

/// Sends to every registered device of every listed user.
///
/// Returns counts rather than throwing: a push that fails must never fail the
/// operation it was announcing. The dose was still due; the SOS still happened.
export async function sendPush(
  // The real service-role client. Typed as SupabaseClient rather than a
  // hand-written structural shape: the generated query-builder types are deep
  // enough that a lookalike interface sends the compiler into TS2589.
  admin: SupabaseClient,
  userIds: string[],
  message: PushMessage,
): Promise<PushResult> {
  const empty: PushResult = { sent: 0, failed: 0, pruned: 0 };
  if (userIds.length === 0) return empty;

  const account = serviceAccount();
  if (!account) {
    if (!warned) {
      warned = true;
      console.warn(
        "[fcm] FIREBASE_SERVICE_ACCOUNT not set — no push will be delivered. " +
          "In-app notification rows are still written.",
      );
    }
    return empty;
  }

  const token = await accessToken(account);
  if (!token) return empty;

  const { data: devices, error } = await admin
    .from("user_devices")
    .select("fcm_token")
    .in("user_id", userIds);
  if (error) {
    console.error("[fcm] could not read user_devices:", error);
    return empty;
  }

  const tokens = [
    ...new Set(
      ((devices ?? []) as { fcm_token: string | null }[])
        .map((d) => d.fcm_token)
        .filter((t): t is string => !!t && t.length > 0),
    ),
  ];
  if (tokens.length === 0) return empty;

  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries(message.data ?? {})) {
    if (v !== null && v !== undefined) data[k] = String(v);
  }

  const url =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;
  const dead: string[] = [];
  let sent = 0;
  let failed = 0;

  // Sequential rather than Promise.all: this runs against at most a handful of
  // devices per user, and a burst of parallel requests is how you meet FCM's
  // rate limiter on a free project.
  for (const fcmToken of tokens) {
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: { title: message.title, body: message.body },
            data,
            android: {
              priority: message.highPriority ? "HIGH" : "NORMAL",
              notification: {
                channel_id: message.channelId ?? "carehive_reminders",
                // Lets the app replace an earlier notification for the same
                // dose instead of stacking three copies of "time for your
                // tablet" by lunchtime.
                tag: data.dose_id ?? data.sos_event_id ?? undefined,
              },
            },
          },
        }),
      });

      if (res.ok) {
        sent++;
        continue;
      }

      failed++;
      const text = await res.text();
      // 404 UNREGISTERED / 400 INVALID_ARGUMENT mean the token is dead — the
      // app was uninstalled or the token rotated. Keeping it means retrying a
      // guaranteed failure on every sweep, forever.
      if (res.status === 404 || text.includes("UNREGISTERED") ||
          text.includes("INVALID_ARGUMENT")) {
        dead.push(fcmToken);
      } else {
        console.error("[fcm] send failed", res.status, text.slice(0, 300));
      }
    } catch (err) {
      failed++;
      console.error("[fcm] send threw:", err);
    }
  }

  if (dead.length > 0) {
    try {
      await admin.from("user_devices").delete().in("fcm_token", dead);
    } catch (err) {
      console.error("[fcm] could not prune dead tokens:", err);
    }
  }

  return { sent, failed, pruned: dead.length };
}
