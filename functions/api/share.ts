/**
 * POST /api/share  { slug, rotate? }  → mint or return share URL (équipe)
 * GET  /api/share?slug=…             → état share (active only — pas de clé)
 * DELETE /api/share { slug }         → révoque
 *
 * Binding: SHARES (KV) — clé `share:<slug>` = token path
 * Contenu servi depuis /a/<slug>/ via ASSETS (pas de copie /s/ statique).
 *
 * Auth équipe (fail-closed) :
 *  1. JWT Cloudflare Access vérifié (JWKS team + aud)
 *  2. OU X-Forge-Share-Secret === env.FORGE_SHARE_SECRET (constant-time, CLI/ops)
 */

interface Env {
  SHARES: KVNamespace
  ASSETS: Fetcher
  SHLINK_API_KEY?: string
  SHLINK_BASE?: string
  /** Ops/CLI secret — never length-check alone */
  FORGE_SHARE_SECRET?: string
  /** e.g. gosilex.cloudflareaccess.com */
  CF_ACCESS_TEAM_DOMAIN?: string
  /** Comma-separated Access application AUDs (forge + pages.dev) */
  CF_ACCESS_AUD?: string
}

/** Canonical public origin for share URLs / shortlinks (never request host). */
const PUBLIC_ORIGIN = "https://forge.gosilex.com"

const SLUG_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/
const DEFAULT_TEAM = "gosilex.cloudflareaccess.com"

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  })
}

function mintKey(): string {
  const bytes = new Uint8Array(18)
  crypto.getRandomValues(bytes)
  let s = ""
  const alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  for (let i = 0; i < bytes.length; i++) s += alphabet[bytes[i] % 64]
  return s
}

function timingSafeEqualStr(a: string, b: string): boolean {
  const enc = new TextEncoder()
  const ab = enc.encode(a)
  const bb = enc.encode(b)
  if (ab.byteLength !== bb.byteLength) {
    // still compare to reduce trivial timing on length (best-effort)
    let diff = ab.byteLength ^ bb.byteLength
    const n = Math.max(ab.byteLength, bb.byteLength)
    for (let i = 0; i < n; i++) {
      diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0)
    }
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

function parseJwt(token: string): { header: Record<string, unknown>; payload: Record<string, unknown>; data: string; sig: Uint8Array } | null {
  const parts = token.split(".")
  if (parts.length !== 3) return null
  try {
    const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[0]))) as Record<string, unknown>
    const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[1]))) as Record<string, unknown>
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

/**
 * Verify Cloudflare Access JWT (RS256 + aud + exp + iss).
 * Fail closed on any error.
 */
async function verifyAccessJwt(token: string, env: Env): Promise<boolean> {
  const team = (env.CF_ACCESS_TEAM_DOMAIN || DEFAULT_TEAM).replace(/^https?:\/\//, "").replace(/\/$/, "")
  const auds = (env.CF_ACCESS_AUD || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
  if (auds.length === 0) return false

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
      /* try next key */
    }
  }
  return false
}

async function isTeamRequest(request: Request, env: Env): Promise<boolean> {
  // 1) Ops/CLI shared secret (must match env binding — never length alone)
  const provided = request.headers.get("X-Forge-Share-Secret")
  const expected = env.FORGE_SHARE_SECRET
  if (provided && expected && timingSafeEqualStr(provided, expected)) {
    return true
  }

  // 2) Verified Access JWT (not mere header presence)
  const jwt = request.headers.get("Cf-Access-Jwt-Assertion")
  if (!jwt) return false
  return verifyAccessJwt(jwt, env)
}

async function assetExists(env: Env, request: Request, slug: string): Promise<boolean> {
  const url = new URL(`/a/${slug}/index.html`, request.url)
  const res = await env.ASSETS.fetch(new Request(url.toString()))
  return res.ok
}

async function maybeShortlink(
  env: Env,
  longUrl: string,
  slug: string,
): Promise<string | undefined> {
  const apiKey = env.SHLINK_API_KEY
  if (!apiKey) return undefined
  const base = (env.SHLINK_BASE || "https://s.gosilex.com").replace(/\/$/, "")
  const customSlug = `f-${slug}`.slice(0, 50)
  try {
    const res = await fetch(`${base}/rest/v3/short-urls`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Api-Key": apiKey,
      },
      body: JSON.stringify({
        longUrl,
        customSlug,
        findIfExists: true,
      }),
    })
    if (!res.ok) return undefined
    const data = (await res.json()) as { shortUrl?: string }
    return data.shortUrl
  } catch {
    return undefined
  }
}

export const onRequestGet: PagesFunction<Env> = async (context) => {
  const url = new URL(context.request.url)
  const slug = url.searchParams.get("slug") || ""
  if (!SLUG_RE.test(slug)) return json({ error: "invalid_slug" }, 400)
  if (!(await isTeamRequest(context.request, context.env))) {
    return json({ error: "unauthorized" }, 401)
  }

  const key = await context.env.SHARES.get(`share:${slug}`)
  // Never return raw key — catalogue / badge only need active
  if (!key) return json({ slug, active: false })
  return json({ slug, active: true })
}

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const request = context.request
  if (!(await isTeamRequest(request, context.env))) {
    return json({ error: "unauthorized" }, 401)
  }

  let body: { slug?: string; rotate?: boolean } = {}
  try {
    body = (await request.json()) as { slug?: string; rotate?: boolean }
  } catch {
    return json({ error: "invalid_json" }, 400)
  }

  const slug = (body.slug || "").trim()
  if (!SLUG_RE.test(slug)) return json({ error: "invalid_slug" }, 400)

  const exists = await assetExists(context.env, request, slug)
  if (!exists) return json({ error: "not_found", slug }, 404)

  let key = await context.env.SHARES.get(`share:${slug}`)
  if (!key || body.rotate) {
    key = mintKey()
    await context.env.SHARES.put(`share:${slug}`, key)
  }

  // Always forge.gosilex.com — never pages.dev origin from the request
  const shareUrl = `${PUBLIC_ORIGIN}/s/${slug}/${key}/`
  const shortUrl = await maybeShortlink(context.env, shareUrl, slug)

  return json({
    slug,
    shareUrl,
    shortUrl: shortUrl || null,
    rotated: Boolean(body.rotate),
    // key omitted intentionally — shareUrl is enough for clipboard
  })
}

export const onRequestDelete: PagesFunction<Env> = async (context) => {
  const request = context.request
  if (!(await isTeamRequest(request, context.env))) {
    return json({ error: "unauthorized" }, 401)
  }

  let body: { slug?: string } = {}
  try {
    body = (await request.json()) as { slug?: string }
  } catch {
    return json({ error: "invalid_json" }, 400)
  }
  const slug = (body.slug || "").trim()
  if (!SLUG_RE.test(slug)) return json({ error: "invalid_slug" }, 400)

  await context.env.SHARES.delete(`share:${slug}`)
  return json({ slug, active: false })
}
