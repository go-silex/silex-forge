import type { ForgeEnv } from "./access"

/** Best-effort Shlink mint. No defaults — needs Pages env SHLINK_API_KEY + SHLINK_API_URL. */
export async function maybeShortlink(
  env: ForgeEnv,
  longUrl: string,
  slug: string,
): Promise<string | undefined> {
  const apiKey = env.SHLINK_API_KEY
  const apiUrl = env.SHLINK_API_URL
  if (!apiKey || !apiUrl) return undefined
  const customSlug = `f-${slug}`.slice(0, 50)
  try {
    const res = await fetch(apiUrl, {
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
