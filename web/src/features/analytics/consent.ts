export type AnalyticsConsent = "accepted" | "declined" | null;

export const analyticsConsentStorageKey = "backword:web:analytics-consent:v1";

export function readAnalyticsConsent(storage: Storage): AnalyticsConsent {
  const value = storage.getItem(analyticsConsentStorageKey);
  return value === "accepted" || value === "declined" ? value : null;
}

export function writeAnalyticsConsent(storage: Storage, consent: Exclude<AnalyticsConsent, null>) {
  storage.setItem(analyticsConsentStorageKey, consent);
}
