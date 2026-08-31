import { siteConfig } from "../lib/siteConfig";
import { appStoreCampaignUrl, resolveAppleCampaignToken } from "../features/analytics/campaign";
import { useAnalytics } from "../features/analytics/AnalyticsProvider";
import { appStoreClick } from "../features/analytics/events";

type AppStoreBadgeProps = {
  placement: "header" | "weekly_modal" | "footer";
};

export function AppStoreBadge({ placement = "header" }: Partial<AppStoreBadgeProps>) {
  const { campaignContext, consent, track } = useAnalytics();
  const campaignToken = consent === "accepted"
    ? resolveAppleCampaignToken(campaignContext, siteConfig.appStoreCampaigns.tokens)
    : null;
  const href = appStoreCampaignUrl(siteConfig.appStoreUrl, siteConfig.appStoreCampaigns.providerToken, campaignToken);
  return (
    <a
      className="inline-flex transition hover:-translate-y-0.5 focus:outline-none focus:ring-2 focus:ring-heading focus:ring-offset-2 focus:ring-offset-ink"
      href={href}
      aria-label={placement === "footer" ? "Download Backword on the App Store from footer" : "Download Backword on the App Store"}
      onClick={() => track(appStoreClick(placement, campaignToken))}
    >
      <img
        alt="Download on the App Store"
        className="h-14 w-auto"
        src="/Download_on_the_App_Store_Badge_US-UK_RGB_wht_092917.svg"
      />
    </a>
  );
}
