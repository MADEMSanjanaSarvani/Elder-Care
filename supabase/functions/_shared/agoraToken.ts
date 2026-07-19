// Agora AccessToken2 (version "007") builder for RTC, implemented for Deno.
// Mirrors Agora's reference RtcTokenBuilder2: big-endian packing, an HMAC-
// SHA256 signing chain, and a zlib-compressed payload. Kept dependency-free
// (Web Crypto + CompressionStream) so it runs as-is in the Edge runtime.
//
// The App Certificate never leaves the server — this is why token minting is
// a function, not something the client does.

const VERSION = "007";

// RTC privileges.
const PRIV_JOIN_CHANNEL = 1;
const PRIV_PUBLISH_AUDIO = 2;
const PRIV_PUBLISH_VIDEO = 3;
const PRIV_PUBLISH_DATA = 4;

const SERVICE_TYPE_RTC = 1;

function u16(n: number): Uint8Array {
  const b = new Uint8Array(2);
  new DataView(b.buffer).setUint16(0, n, false); // big-endian
  return b;
}

function u32(n: number): Uint8Array {
  const b = new Uint8Array(4);
  new DataView(b.buffer).setUint32(0, n >>> 0, false);
  return b;
}

function concat(parts: Uint8Array[]): Uint8Array {
  const len = parts.reduce((a, p) => a + p.length, 0);
  const out = new Uint8Array(len);
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}

const enc = new TextEncoder();

function packString(s: string | Uint8Array): Uint8Array {
  const bytes = typeof s === "string" ? enc.encode(s) : s;
  return concat([u16(bytes.length), bytes]);
}

function packMapU32(m: Map<number, number>): Uint8Array {
  const keys = [...m.keys()].sort((a, b) => a - b);
  const parts: Uint8Array[] = [u16(keys.length)];
  for (const k of keys) parts.push(u16(k), u32(m.get(k)!));
  return concat(parts);
}

// Copy into a fresh ArrayBuffer so the Web Crypto calls get an exact
// ArrayBuffer (not a possibly-shared/offset view), keeping TS + runtime happy.
function toArrayBuffer(u: Uint8Array): ArrayBuffer {
  const out = new ArrayBuffer(u.byteLength);
  new Uint8Array(out).set(u);
  return out;
}

async function hmac(key: Uint8Array, msg: Uint8Array): Promise<Uint8Array> {
  const k = await crypto.subtle.importKey(
    "raw",
    toArrayBuffer(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", k, toArrayBuffer(msg));
  return new Uint8Array(sig);
}

async function zlibCompress(data: Uint8Array): Promise<Uint8Array> {
  const cs = new CompressionStream("deflate"); // zlib-wrapped (RFC 1950)
  const writer = cs.writable.getWriter();
  writer.write(toArrayBuffer(data));
  writer.close();
  const ab = await new Response(cs.readable).arrayBuffer();
  return new Uint8Array(ab);
}

function base64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

/// Builds an RTC token for `channel` and `uid` (0 = any uid), valid for
/// `expireSeconds`. The joiner gets publish (audio/video/data) privileges.
export async function buildRtcToken(
  appId: string,
  appCertificate: string,
  channel: string,
  uid: number,
  expireSeconds: number,
): Promise<string> {
  const issueTs = Math.floor(Date.now() / 1000);
  const salt = Math.floor(Math.random() * 99999999) + 1;

  // signing = HMAC(salt, HMAC(issueTs, appCertificate))
  let signing = await hmac(u32(issueTs), enc.encode(appCertificate));
  signing = await hmac(u32(salt), signing);

  // Service (RTC) with join + publish privileges.
  const privileges = new Map<number, number>([
    [PRIV_JOIN_CHANNEL, expireSeconds],
    [PRIV_PUBLISH_AUDIO, expireSeconds],
    [PRIV_PUBLISH_VIDEO, expireSeconds],
    [PRIV_PUBLISH_DATA, expireSeconds],
  ]);
  const uidStr = uid === 0 ? "" : String(uid);
  const service = concat([
    u16(SERVICE_TYPE_RTC),
    packMapU32(privileges),
    packString(channel),
    packString(uidStr),
  ]);

  const signingInfo = concat([
    packString(appId),
    u32(issueTs),
    u32(expireSeconds),
    u32(salt),
    u16(1), // one service
    service,
  ]);

  const signature = await hmac(signing, signingInfo);

  const content = concat([packString(signature), signingInfo]);
  const compressed = await zlibCompress(content);
  return VERSION + base64(compressed);
}
