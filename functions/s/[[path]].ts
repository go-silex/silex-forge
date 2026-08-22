/**
 * GET /s/<slug>/<key>/…  — share public (key in path)
 * GET /s/<slug>/?k=<key> — same secret in query (alias)
 *
 * Requires vis:shared + valid KV share:<slug> key, then serves /a/<slug>/… via ASSETS.
 */
import {
  type ForgeEnv,
  getVisibility,
  timingSafeEqualStr,
} from "../_lib/access"

async function plain404(): Promise<Response> {
  return new Response("Not found", {
    status: 404,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  })
}

export const onRequest: PagesFunction<ForgeEnv> = async (context) => {
  const url = new URL(context.request.url)
  const parts = url.pathname.replace(/^\/s\/?/, "").split("/").filter(Boolean)
  const qk = url.searchParams.get("k") || ""

  let slug = ""
  let key = ""
  let rest: string[] = []

  if (parts.length >= 2 && !qk) {
    slug = parts[0]
    key = parts[1]
    rest = parts.slice(2)
  } else if (parts.length >= 1 && qk) {
    slug = parts[0]
    key = qk
    rest = parts.slice(1)
  } else {
    return plain404()
  }

  const vis = await getVisibility(context.env.SHARES, slug)
  if (vis !== "shared") {
    return plain404()
  }

  const stored = await context.env.SHARES.get(`share:${slug}`)
  if (!stored || !key || !timingSafeEqualStr(stored, key)) {
    return plain404()
  }

  let assetPath: string
  if (rest.length === 0) {
    assetPath = `/a/${slug}/index.html`
  } else if (rest[rest.length - 1].includes(".")) {
    assetPath = `/a/${slug}/${rest.join("/")}`
  } else {
    assetPath = `/a/${slug}/${rest.join("/")}/index.html`
  }

  const assetUrl = new URL(assetPath, url.origin)
  const res = await context.env.ASSETS.fetch(assetUrl.toString())

  if (res.status === 404) {
    return plain404()
  }

  const headers = new Headers(res.headers)
  headers.set("cache-control", "no-store")
  headers.set("x-robots-tag", "noindex, nofollow, noarchive")
  headers.set("x-forge-share", "1")
  return new Response(res.body, { status: res.status, headers })
}
