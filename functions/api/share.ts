/**
 * POST /api/share  { slug, rotate? }  → mint or return share URL (équipe, derrière Access)
 * GET  /api/share?slug=…             → état share
 * DELETE /api/share { slug }         → révoque
 *
 * Binding: SHARES (KV) — clé `share:<slug>` = token path
 * Contenu servi depuis /a/<slug>/ via ASSETS (pas de copie /s/ statique).
 */

interface Env {
  SHARES: KVNamespace
  ASSETS: Fetcher
  SHLINK_API_KEY?: string
  SHLINK_BASE?: string
}

const SLUG_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/

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

/** Access JWT present when user passed Cloudflare Access (custom domain). */
function isTeamRequest(request: Request): boolean {
  if (request.headers.get("Cf-Access-Jwt-Assertion")) return true
  // local / pages.dev testing with shared secret
  const secret = request.headers.get("X-Forge-Share-Secret")
  return Boolean(secret && secret.length > 8)
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
  if (!isTeamRequest(context.request)) return json({ error: "unauthorized" }, 401)

  const key = await context.env.SHARES.get(`share:${slug}`)
  if (!key) return json({ slug, active: false })
  const origin = url.origin
  const shareUrl = `${origin}/s/${slug}/${key}/`
  return json({ slug, active: true, shareUrl, key })
}

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const request = context.request
  if (!isTeamRequest(request)) return json({ error: "unauthorized" }, 401)

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

  const origin = new URL(request.url).origin
  const shareUrl = `${origin}/s/${slug}/${key}/`
  const shortUrl = await maybeShortlink(context.env, shareUrl, slug)

  const shareUrlQuery = `${origin}/s/${slug}/?k=${key}`
  return json({
    slug,
    shareUrl,
    shareUrlQuery,
    shortUrl: shortUrl || null,
    key,
    rotated: Boolean(body.rotate),
  })
}

export const onRequestDelete: PagesFunction<Env> = async (context) => {
  const request = context.request
  if (!isTeamRequest(request)) return json({ error: "unauthorized" }, 401)

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
