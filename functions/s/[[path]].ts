/**
 * GET /s/<slug>/<key>/…  — share public (clé dans le path)
 * GET /s/<slug>/?k=<key> — même secret en query (alias type 1page)
 *
 * Valide KV `share:<slug>` puis sert /a/<slug>/… via ASSETS.
 */
interface Env {
  SHARES: KVNamespace
  ASSETS: Fetcher
}

function timingSafeEqualStr(a: string, b: string): boolean {
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

export const onRequest: PagesFunction<Env> = async (context) => {
  const url = new URL(context.request.url)
  const parts = url.pathname.replace(/^\/s\/?/, "").split("/").filter(Boolean)
  const qk = url.searchParams.get("k") || ""

  let slug = ""
  let key = ""
  let rest: string[] = []

  if (parts.length >= 2 && !qk) {
    // /s/slug/key/...
    slug = parts[0]
    key = parts[1]
    rest = parts.slice(2)
  } else if (parts.length >= 1 && qk) {
    // /s/slug/?k=key  or /s/slug/assets/x?k=key
    slug = parts[0]
    key = qk
    rest = parts.slice(1)
  } else {
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

function plain404(): Response {
  return new Response("Not found", {
    status: 404,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  })
}
