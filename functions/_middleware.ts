/**
 * ACL + pages.dev lock.
 *
 * forge.gosilex.com (after Access Bypass on / and /a):
 *   /                    catalogue shell (no private titles in HTML)
 *   /api/catalogue       public OK (filtered)
 *   /a/<slug>/*          vis KV: public | shared | private  (+ JWT cookie)
 *   /s/*                 KV key (existing Function)
 *   /manifest.json       never to clients (worker reads via ASSETS)
 *
 * Fail-closed: unknown vis = private.
 * pages.dev: 403 except /s/* .
 */
import {
  type ForgeEnv,
  extractSlugFromAPath,
  getVisibility,
  isTeamRequest,
} from "./_lib/access"

const SHARE_PREFIX = "/s/"

function isPagesDev(host: string): boolean {
  return host === "pages.dev" || host.endsWith(".pages.dev")
}

function plain404(): Response {
  return new Response("Not found", {
    status: 404,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
      "x-robots-tag": "noindex, nofollow",
    },
  })
}

function loginRedirect(): Response {
  return new Response(null, {
    status: 302,
    headers: {
      location: "/login",
      "cache-control": "no-store",
    },
  })
}

function isPublicShell(pathname: string): boolean {
  return (
    pathname === "/" ||
    pathname === "/index.html" ||
    pathname === "/login" ||
    pathname === "/login.html" ||
    pathname === "/robots.txt" ||
    pathname === "/favicon.ico" ||
    pathname === "/images/favicon.png"
  )
}

export const onRequest: PagesFunction<ForgeEnv> = async (context) => {
  const url = new URL(context.request.url)
  const host = url.hostname
  const path = url.pathname

  if (isPagesDev(host)) {
    if (path === "/s" || path.startsWith(SHARE_PREFIX)) {
      return context.next()
    }
    return new Response(
      "Forbidden — use https://forge.gosilex.com. This pages.dev origin does not serve team content.",
      {
        status: 403,
        headers: {
          "content-type": "text/plain; charset=utf-8",
          "cache-control": "no-store",
          "x-forge-origin-policy": "pages-dev-blocked",
          "x-robots-tag": "noindex, nofollow",
        },
      },
    )
  }

  // Full artefact index — worker-only (ASSETS.fetch bypasses this).
  if (path === "/manifest.json" || path.startsWith("/registry/")) {
    return plain404()
  }

  if (path.startsWith("/api/") || path.startsWith(SHARE_PREFIX) || path === "/s") {
    return context.next()
  }

  if (isPublicShell(path)) {
    return context.next()
  }

  if (path.startsWith("/a/") || path === "/a") {
    const slug = extractSlugFromAPath(path)
    if (!slug) return plain404()

    const team = await isTeamRequest(context.request, context.env)
    if (team) return context.next()

    const vis = await getVisibility(context.env.SHARES, slug)
    if (vis === "public") return context.next()
    if (vis === "shared") return plain404()
    return loginRedirect()
  }

  // Other static (css leftover, random files): team or 404
  if (await isTeamRequest(context.request, context.env)) {
    return context.next()
  }
  return plain404()
}
