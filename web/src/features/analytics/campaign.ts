export type CampaignContext = {
  source: string;
  medium: string;
  campaign: string;
  content: string | null;
  capturedAt: number;
};

const campaignStorageKey = "backword:web:analytics:first-campaign:v1";
export const campaignContextLifetimeMs = 90 * 24 * 60 * 60 * 1_000;

function normaliseParameter(value: string | null, maximumLength: number): string | null {
  if (!value) return null;
  const normalised = value.trim().toLowerCase();
  return /^[a-z0-9][a-z0-9_-]*$/.test(normalised) && normalised.length <= maximumLength
    ? normalised
    : null;
}

export function campaignContextFromUrl(url: URL, capturedAt = Date.now()): CampaignContext | null {
  const source = normaliseParameter(url.searchParams.get("utm_source"), 40);
  const medium = normaliseParameter(url.searchParams.get("utm_medium"), 40);
  const campaign = normaliseParameter(url.searchParams.get("utm_campaign"), 60);
  const content = normaliseParameter(url.searchParams.get("utm_content"), 80);
  if (!source || !medium || !campaign) return null;
  return { source, medium, campaign, content, capturedAt };
}

export function readCampaignContext(storage: Storage, now = Date.now()): CampaignContext | null {
  try {
    const parsed: unknown = JSON.parse(storage.getItem(campaignStorageKey) ?? "null");
    if (!parsed || typeof parsed !== "object") return null;
    const value = parsed as Partial<CampaignContext>;
    if (
      typeof value.source !== "string" || typeof value.medium !== "string" ||
      typeof value.campaign !== "string" || (value.content !== null && typeof value.content !== "string") ||
      typeof value.capturedAt !== "number" || value.capturedAt + campaignContextLifetimeMs < now
    ) {
      storage.removeItem(campaignStorageKey);
      return null;
    }
    return value as CampaignContext;
  } catch {
    storage.removeItem(campaignStorageKey);
    return null;
  }
}

export function captureFirstCampaignContext(storage: Storage, url: URL, now = Date.now()): CampaignContext | null {
  const existing = readCampaignContext(storage, now);
  if (existing) return existing;
  const context = campaignContextFromUrl(url, now);
  if (context) storage.setItem(campaignStorageKey, JSON.stringify(context));
  return context;
}

export function clearCampaignContext(storage: Storage) {
  storage.removeItem(campaignStorageKey);
}

export function resolveAppleCampaignToken(
  context: CampaignContext | null,
  campaignTokens: Record<string, string>
): string | null {
  if (!context) return campaignTokens.default ?? null;
  return campaignTokens[`${context.source}:${context.campaign}`]
    ?? campaignTokens[context.source]
    ?? campaignTokens.default
    ?? null;
}

export function appStoreCampaignUrl(
  appStoreUrl: string,
  providerToken: string,
  campaignToken: string | null
): string {
  if (!providerToken || !campaignToken) return appStoreUrl;
  const url = new URL(appStoreUrl);
  url.searchParams.set("pt", providerToken);
  url.searchParams.set("ct", campaignToken);
  url.searchParams.set("mt", "8");
  return url.toString();
}
