/**
 * GET  /api/visibility?slug=  → { slug, visibility, shareUrl? }  (team)
 * POST /api/visibility { slug, visibility } → set vis, mint/revoke share key
 *
 * public | shared | private — mutually exclusive. Keys never in HTML.
 */
import {
  type ForgeEnv,
  type Visibility,
  PUBLIC_ORIGIN,
  SLUG_RE,
  getVisibility,
  isTeamRequest,
  json,
  mintKey,
  setVisibility,
} from "../_lib/access"
import { maybeShortlink } from "../_lib/shlink"

const VIS: Visibility[] = ["private", "shared", "public"]

export const onRequestGet: PagesFunction<ForgeEnv> = async (context) => {
  if (!(await isTeamRequest(context.request, context.env))) {
    return json({ error: "unauthorized" }, 401)
  }
  const slug = new URL(context.request.url).searchParams.get("slug") || ""
  if (!SLUG_RE.test(slug)) return json({ error: "invalid_slug" }, 400)
  const vis = await getVisibility(context.env.SHARES, slug)
  const key = vis === "shared" ? await context.env.SHARES.get(`share:${slug}`) : null
  return json({
    slug,
    visibility: vis,
    shareUrl: key ? `${PUBLIC_ORIGIN}/s/${slug}/${key}/` : null,
  })
}

export const onRequestPost: PagesFunction<ForgeEnv> = async (context) => {
  if (!(await isTeamRequest(context.request, context.env))) {
    return json({ error: "unauthorized" }, 401)
  }
  let body: { slug?: string; visibility?: string } = {}
  try {
    body = (await context.request.json()) as { slug?: string; visibility?: string }
  } catch {
    return json({ error: "invalid_json" }, 400)
  }
  const slug = (body.slug || "").trim()
  const vis = body.visibility as Visibility
  if (!SLUG_RE.test(slug)) return json({ error: "invalid_slug" }, 400)
  if (!VIS.includes(vis)) return json({ error: "invalid_visibility" }, 400)

  await setVisibility(context.env.SHARES, slug, vis)

  let shareUrl: string | null = null
  let shortUrl: string | null = null
  if (vis === "shared") {
    let key = await context.env.SHARES.get(`share:${slug}`)
    if (!key) {
      key = mintKey()
      await context.env.SHARES.put(`share:${slug}`, key)
    }
    shareUrl = `${PUBLIC_ORIGIN}/s/${slug}/${key}/`
    shortUrl = (await maybeShortlink(context.env, shareUrl, slug)) || null
  } else {
    await context.env.SHARES.delete(`share:${slug}`)
  }

  return json({ slug, visibility: vis, shareUrl, shortUrl })
}
