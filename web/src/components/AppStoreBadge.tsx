import { siteConfig } from "../lib/siteConfig";

export function AppStoreBadge() {
  return (
    <a
      className="inline-flex transition hover:-translate-y-0.5 focus:outline-none focus:ring-2 focus:ring-heading focus:ring-offset-2 focus:ring-offset-ink"
      href={siteConfig.appStoreUrl}
      aria-label="Download Backword on the App Store"
    >
      <img
        alt="Download on the App Store"
        className="h-12 w-auto"
        src="/Download_on_the_App_Store_Badge_US-UK_RGB_wht_092917.svg"
      />
    </a>
  );
}
