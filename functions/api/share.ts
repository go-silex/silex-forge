/**
 * POST /api/share  { slug, rotate? }  → mint share URL (sets visibility=shared)
 * GET  /api/share?slug=…             → { active } only
 * DELETE /api/share { slug }         → révoque + visibility=private
 */
import {
  type ForgeEnv,
  PUBLIC_ORIGIN,
  SLUG_RE,
  isTeamRequest,
  json,
  mintKey,
  setVisibility,
} from "../_lib/access"
import { maybeShortlink } from "../_lib/shlink"

type Env = ForgeEnv

async function assetExists(env: Env, request: Request, slug: string): Promise<boolean> {
  const url = new URL(`/a/${slug}/index.html`, request.url)
  const res = await env.ASSETS.fetch(new Request(url.toString()))
  return res.ok
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
  await setVisibility(context.env.SHARES, slug, "shared")

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
  await setVisibility(context.env.SHARES, slug, "private")
  return json({ slug, active: false })
}
