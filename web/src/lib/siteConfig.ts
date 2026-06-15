export const siteConfig = {
  appName: "Backword",
  tagline: "A word game that works backwards.",
  appStoreUrl: "https://apps.apple.com/app/backword/id0000000000",
  supportEmail: "support@backword.com",
  lastUpdated: "June 15, 2026",
  futureEnvironment: {
    supabaseUrl: "VITE_SUPABASE_URL",
    supabaseAnonKey: "VITE_SUPABASE_ANON_KEY"
  }
} as const;
