export const brand = {
  name: "Intervls",
  proName: "Intervls Pro",
  homeTitle: "Intervls — Free daily word games",
  tagline: "Free daily word games to challenge your mind",
  origin: "https://intervls.com",
  domain: "intervls.com",
  legacyOrigins: ["https://www.playbackword.com", "https://playbackword.com"],
  indexingEnabled: import.meta.env.VITE_REBRAND_INDEXING_ALLOWED === "true",
  noticeEnabled: import.meta.env.VITE_REBRAND_NOTICE_ENABLED === "true",
  launchEnabled: import.meta.env.VITE_REBRAND_LAUNCH_ENABLED === "true"
} as const;

export function isLegacyOrigin(origin: string) {
  return (brand.legacyOrigins as readonly string[]).includes(origin);
}

export function migrationDestination(path: string): string {
  const url = new URL(brand.origin);
  if (!path.startsWith("/") || path.startsWith("//") || /[\\\r\n]/.test(path)) return url.href;
  const candidate = new URL(path, brand.origin);
  if (candidate.origin !== brand.origin || !/^\/(?:|home|backword(?:\/\d{4}-\d{2}-\d{2})?|midword(?:\/\d{4}-\d{2}-\d{2})?|anagram(?:\/\d{4}-\d{2}-\d{2})?|crossword(?:\/\d{4}-\d{2}-\d{2})?|weekly-crossword(?:\/\d{4}-\d{2}-\d{2})?|archive|player-profile|pro|info|contact|privacy|privacy-choices|terms)$/.test(candidate.pathname)) return url.href;
  url.pathname = candidate.pathname;
  for (const [key, value] of candidate.searchParams) {
    if (/^utm_(source|medium|campaign|content|term)$/.test(key) || (key === "checkout" && ["success", "cancelled"].includes(value))) {
      url.searchParams.append(key, value);
    } else if (key === "return_to" && /^\/(?:archive|weekly-crossword)(?:\/\d{4}-\d{2}-\d{2})?$/.test(value)) {
      url.searchParams.set(key, value);
    }
  }
  // OAuth codes, tokens, fragments, and browser sessions never leave their origin.
  return url.href;
}
