/** Cloudflare Access JWT + forge visibility (KV). Fail-closed. */

export interface ForgeEnv {
  SHARES: KVNamespace
  ASSETS: Fetcher
  SHLINK_API_KEY?: string
  /** Full Shlink create URL, e.g. https://s.gosilex.com/rest/v3/short-urls — no default */
  SHLINK_API_URL?: string
  FORGE_SHARE_SECRET?: string
  CF_ACCESS_TEAM_DOMAIN?: string
  CF_ACCESS_AUD?: string
}

export type Visibility = "private" | "shared" | "public"

export const SLUG_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/
export const PUBLIC_ORIGIN = "https://forge.gosilex.com"

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  })
}

export function timingSafeEqualStr(a: string, b: string): boolean {
  const enc = new TextEncoder()
  const ab = enc.encode(a)
  const bb = enc.encode(b)
  if (ab.byteLength !== bb.byteLength) {
    let diff = ab.byteLength ^ bb.byteLength
    const n = Math.max(ab.byteLength, bb.byteLength)
    for (let i = 0; i < n; i++) diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0)
    return false
  }
  let out = 0
  for (let i = 0; i < ab.byteLength; i++) out |= ab[i] ^ bb[i]
  return out === 0
}

type Jwks = {
  keys: Array<{
    kid?: string
    kty: string
    alg?: string
    n?: string
    e?: string
    use?: string
  }>
}

let jwksCache: { at: number; keys: Jwks["keys"] } | null = null

async function fetchAccessJwks(teamDomain: string): Promise<Jwks["keys"]> {
  const now = Date.now()
  if (jwksCache && now - jwksCache.at < 3600_000) return jwksCache.keys
  const res = await fetch(`https://${teamDomain}/cdn-cgi/access/certs`)
  if (!res.ok) throw new Error(`jwks_http_${res.status}`)
  const data = (await res.json()) as Jwks
  jwksCache = { at: now, keys: data.keys || [] }
  return jwksCache.keys
}

function b64urlToBytes(s: string): Uint8Array {
  const pad = "=".repeat((4 - (s.length % 4)) % 4)
  const b64 = (s + pad).replace(/-/g, "+").replace(/_/g, "/")
  const bin = atob(b64)
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

function parseJwt(token: string): {
  header: Record<string, unknown>
  payload: Record<string, unknown>
  data: string
  sig: Uint8Array
} | null {
  const parts = token.split(".")
  if (parts.length !== 3) return null
  try {
    const header = JSON.parse(
      new TextDecoder().decode(b64urlToBytes(parts[0])),
    ) as Record<string, unknown>
    const payload = JSON.parse(
      new TextDecoder().decode(b64urlToBytes(parts[1])),
    ) as Record<string, unknown>
    return {
      header,
      payload,
      data: `${parts[0]}.${parts[1]}`,
      sig: b64urlToBytes(parts[2]),
    }
  } catch {
    return null
  }
}

async function importRsaJwk(jwk: Jwks["keys"][0]): Promise<CryptoKey | null> {
  if (jwk.kty !== "RSA" || !jwk.n || !jwk.e) return null
  try {
    return await crypto.subtle.importKey(
      "jwk",
      { kty: "RSA", n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    )
  } catch {
    return null
  }
}

export async function verifyAccessJwt(
  token: string,
  env: ForgeEnv,
): Promise<boolean> {
  const team = (env.CF_ACCESS_TEAM_DOMAIN || "")
    .replace(/^https?:\/\//, "")
    .replace(/\/$/, "")
  const auds = (env.CF_ACCESS_AUD || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
  // Fail-closed: both must come from Pages env (no hardcoded defaults)
  if (!team || auds.length === 0) return false

  const parsed = parseJwt(token)
  if (!parsed) return false
  if (parsed.header.alg !== "RS256") return false

  const { payload } = parsed
  const exp = Number(payload.exp)
  if (!Number.isFinite(exp) || exp * 1000 < Date.now() - 30_000) return false

  const iss = String(payload.iss || "")
  const expectedIss = `https://${team}`
  if (iss !== expectedIss && iss !== `${expectedIss}/`) return false

  const aud = payload.aud
  const audList = Array.isArray(aud) ? aud.map(String) : [String(aud || "")]
  if (!audList.some((a) => auds.includes(a))) return false

  let keys: Jwks["keys"]
  try {
    keys = await fetchAccessJwks(team)
  } catch {
    return false
  }

  const kid = parsed.header.kid as string | undefined
  const candidates = kid ? keys.filter((k) => k.kid === kid) : keys
  const enc = new TextEncoder()
  const data = enc.encode(parsed.data)

  for (const jwk of candidates) {
    const key = await importRsaJwk(jwk)
    if (!key) continue
    try {
      const ok = await crypto.subtle.verify(
        "RSASSA-PKCS1-v1_5",
        key,
        parsed.sig as BufferSource,
        data,
      )
      if (ok) return true
    } catch {
      /* next */
    }
  }
  return false
}

function jwtFromCookie(request: Request): string {
  const raw = request.headers.get("Cookie") || ""
  const m = raw.match(/(?:^|;\s*)CF_Authorization=([^;]+)/)
  if (!m) return ""
  try {
    return decodeURIComponent(m[1])
  } catch {
    return m[1]
  }
}

/** Team = verified Access JWT (header or CF_Authorization cookie) or ops secret. */
export async function isTeamRequest(
  request: Request,
  env: ForgeEnv,
): Promise<boolean> {
  const provided = request.headers.get("X-Forge-Share-Secret")
  const expected = env.FORGE_SHARE_SECRET
  if (provided && expected && timingSafeEqualStr(provided, expected)) {
    return true
  }

  const headerJwt = request.headers.get("Cf-Access-Jwt-Assertion") || ""
  const cookieJwt = jwtFromCookie(request)
  for (const jwt of [headerJwt, cookieJwt]) {
    if (!jwt) continue
    if (await verifyAccessJwt(jwt, env)) return true
  }
  return false
}

export async function getVisibility(
  kv: KVNamespace,
  slug: string,
): Promise<Visibility> {
  const v = await kv.get(`vis:${slug}`)
  if (v === "public" || v === "shared" || v === "private") return v
  const share = await kv.get(`share:${slug}`)
  if (share) return "shared"
  return "private"
}

export async function setVisibility(
  kv: KVNamespace,
  slug: string,
  vis: Visibility,
): Promise<void> {
  await kv.put(`vis:${slug}`, vis)
}

export function mintKey(): string {
  const bytes = new Uint8Array(18)
  crypto.getRandomValues(bytes)
  let s = ""
  const alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  for (let i = 0; i < bytes.length; i++) s += alphabet[bytes[i] % 64]
  return s
}

export function extractSlugFromAPath(pathname: string): string {
  const m = pathname.match(/^\/a\/([a-z0-9]+(?:-[a-z0-9]+)*)(?:\/|$)/)
  return m ? m[1] : ""
}
