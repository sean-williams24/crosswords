function campaignTokensFromEnvironment(): Record<string, string> {
  try {
    const parsed: unknown = JSON.parse(import.meta.env.VITE_APP_STORE_CAMPAIGN_TOKENS ?? "{}");
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
    return Object.fromEntries(Object.entries(parsed).filter(([key, value]) =>
      /^[a-z0-9:_-]+$/.test(key) && typeof value === "string" && value.length > 0 && value.length <= 30
    ));
  } catch {
    return {};
  }
}

export const siteConfig = {
  appName: "Backword",
  tagline: "A word game that works backwards.",
  appStoreUrl: "https://apps.apple.com/app/backword/id6773428497",
  developerName: "Sean Williams",
  supportEmail: "backword.support@gmail.com",
  lastUpdated: "August 31, 2026",
  environment: {
    supabaseUrl: "VITE_SUPABASE_URL",
    supabaseAnonKey: "VITE_SUPABASE_ANON_KEY"
  },
  appStoreCampaigns: {
    providerToken: import.meta.env.VITE_APP_STORE_PROVIDER_TOKEN ?? "",
    tokens: campaignTokensFromEnvironment()
  }
} as const;
