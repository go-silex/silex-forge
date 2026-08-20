/**
 * GET /api/catalogue
 * Anonymous → public items only (thumbs included).
 * Team JWT → all items + visibility. Never leak private titles to anonymous.
 */
import {
  type ForgeEnv,
  getVisibility,
  isTeamRequest,
  json,
} from "../_lib/access"

type ManifestItem = {
  f?: string
  t?: string
  d?: string
  cat?: string
  cl?: string
  c?: string
  b?: string[]
  kb?: number
  p?: boolean
  thumb?: string
  desc?: string
  slug?: string
  shared?: boolean
}

export const onRequestGet: PagesFunction<ForgeEnv> = async (context) => {
  const team = await isTeamRequest(context.request, context.env)
  const url = new URL("/manifest.json", context.request.url)
  const res = await context.env.ASSETS.fetch(url.toString())
  if (!res.ok) {
    return json({ team, items: [] })
  }

  let raw: ManifestItem[] = []
  try {
    raw = (await res.json()) as ManifestItem[]
    if (!Array.isArray(raw)) raw = []
  } catch {
    raw = []
  }

  const visBySlug = await Promise.all(
    raw.map(async (it) => {
      const slug = String(it.slug || "")
      if (!slug) return ["", "private"] as const
      return [slug, await getVisibility(context.env.SHARES, slug)] as const
    }),
  )
  const visMap = new Map(visBySlug.filter(([s]) => s))

  const items = []
  for (const it of raw) {
    const slug = String(it.slug || "")
    if (!slug) continue
    const vis = visMap.get(slug) || "private"
    if (!team && vis !== "public") continue

    const badges = Array.isArray(it.b) ? [...it.b] : []
    const filtered = badges.filter((b) => b !== "share" && b !== "public" && b !== "private")
    if (vis === "shared") filtered.push("share")
    if (vis === "public") filtered.push("public")
    if (vis === "private") filtered.push("private")

    items.push({
      f: it.f || `/a/${slug}/`,
      t: it.t || slug,
      d: it.d || "",
      cat: it.cat || "html",
      cl: it.cl || "HTML",
      c: it.c || "gold",
      b: filtered,
      kb: it.kb || 0,
      p: !!it.p,
      // thumbs only for items we already authorised
      thumb: it.p ? `/a/${slug}/og.jpg` : "",
      desc: it.desc || "",
      slug,
      visibility: vis,
      shared: vis === "shared",
    })
  }

  return json({ team, items })
}
