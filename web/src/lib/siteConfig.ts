import { brand } from "../features/brand/brand";

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
  appName: brand.name,
  tagline: brand.tagline,
  appStoreUrl: "https://apps.apple.com/app/id6773428497",
  developerName: "Sean Williams",
  supportEmail: "support@intervls.com",
  socialLinks: [
    { label: "Instagram", href: "https://instagram.com/play.backword?dlrf=MTg1d3pmcmsydzIycA%3D%3D&utm_source=qr" },
    { label: "TikTok", href: "https://www.tiktok.com/@play.backword" },
    { label: "Facebook", href: "https://www.facebook.com/share/1CWvuRkqxe/?mibextid=wwXIfr" }
  ],
  lastUpdated: "October 29, 2026",
  environment: {
    supabaseUrl: "VITE_SUPABASE_URL",
    supabaseAnonKey: "VITE_SUPABASE_ANON_KEY"
  },
  appStoreCampaigns: {
    providerToken: import.meta.env.VITE_APP_STORE_PROVIDER_TOKEN ?? "",
    tokens: campaignTokensFromEnvironment()
  }
} as const;
