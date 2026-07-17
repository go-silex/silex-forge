/**
 * GET /s/<slug>/<key>/… — share public.
 * Valide KV puis sert /a/<slug>/… via ASSETS.
 */
interface Env {
  SHARES: KVNamespace
  ASSETS: Fetcher
}

export const onRequest: PagesFunction<Env> = async (context) => {
  const url = new URL(context.request.url)
  const parts = url.pathname.replace(/^\/s\/?/, "").split("/").filter(Boolean)

  if (parts.length < 2) {
    return new Response("Not found", { status: 404, headers: { "content-type": "text/plain" } })
  }

  const slug = parts[0]
  const key = parts[1]
  const rest = parts.slice(2)

  const stored = await context.env.SHARES.get(`share:${slug}`)
  if (!stored || stored !== key) {
    return new Response("Not found", {
      status: 404,
      headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" },
    })
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
    return new Response("Not found", { status: 404, headers: { "cache-control": "no-store" } })
  }

  const headers = new Headers(res.headers)
  headers.set("cache-control", "no-store")
  headers.set("x-robots-tag", "noindex, nofollow, noarchive")
  headers.set("x-forge-share", "1")
  return new Response(res.body, { status: res.status, headers })
}
