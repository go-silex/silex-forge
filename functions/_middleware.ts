/**
 * Defense-in-depth: block unauthenticated content on *.pages.dev.
 *
 * Cloudflare Access on the custom domain (forge.gosilex.com) does not
 * automatically cover the project.pages.dev origin. Until/unless Access
 * is enforced on that host, refuse non-share traffic so internal /a/*
 * and the catalogue cannot be scraped via the twin origin.
 *
 * /s/* remains reachable so capability URLs still resolve if someone has
 * a key (canonical mint always uses forge.gosilex.com).
 */

const SHARE_PREFIX = "/s/"

function isPagesDev(host: string): boolean {
  return host === "pages.dev" || host.endsWith(".pages.dev")
}

export const onRequest: PagesFunction = async (context) => {
  const url = new URL(context.request.url)

  if (!isPagesDev(url.hostname)) {
    return context.next()
  }

  // Allow share capability path only (KV-gated in functions/s/[[path]].ts)
  if (url.pathname === "/s" || url.pathname.startsWith(SHARE_PREFIX)) {
    return context.next()
  }

  // Optional: real Access JWT already verified at edge — still allow team
  // through pages.dev after Access app is live (they get a real assertion).
  // Presence alone is NOT enough: require Access cookie flow via edge.
  // If Access is not applied, this header is client-spoofable → still block
  // static content unless we see CF-generated Access path (we cannot trust
  // the header alone). Hard-block non-/s on pages.dev.
  return new Response(
    "Forbidden — use https://forge.gosilex.com (Access). This pages.dev origin does not serve team content.",
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
