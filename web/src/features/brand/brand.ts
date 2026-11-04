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
