/** Keep browser access independent of the server-selected Checkout return destination. */
export function allowedWebOrigins(legacyOrigin: string | undefined, configured: string | undefined): string[] {
  const values: unknown = configured ? JSON.parse(configured) : legacyOrigin ? [legacyOrigin] : [];
  if (!Array.isArray(values) || !values.every((value) => typeof value === "string" && validOrigin(value))) {
    throw new Error("Web subscription origins are not configured correctly.");
  }
  return [...new Set(values)];
}

export function validOrigin(value: string) {
  try {
    const url = new URL(value);
    return value === url.origin && (url.protocol === "https:" || (url.protocol === "http:" && ["localhost", "127.0.0.1"].includes(url.hostname)));
  } catch { return false; }
}

export function checkoutCorsHeaders(origin: string | null, allowed: string[]): Record<string, string> {
  return {
    ...(origin && allowed.includes(origin) ? { "Access-Control-Allow-Origin": origin } : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin"
  };
}
