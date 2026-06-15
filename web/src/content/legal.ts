import { siteConfig } from "../lib/siteConfig";

export const privacySections = [
  {
    title: "Overview",
    body: [
      `${siteConfig.appName} is designed to be a small, focused word game. This placeholder privacy policy explains the intended data practices for the app and website and should be reviewed before launch.`
    ]
  },
  {
    title: "Information We Collect",
    body: [
      "The app may store gameplay progress, settings, purchases, and performance information needed to run the game. If advertising or analytics are enabled, third-party providers may collect device and usage information under their own policies."
    ]
  },
  {
    title: "How We Use Information",
    body: [
      "Information is used to provide gameplay, remember progress, improve reliability, support purchases, and keep the experience fair and functional."
    ]
  },
  {
    title: "Advertising",
    body: [
      "Backword may use Google AdMob to show ads. Google may use device identifiers and related data to deliver and measure advertising. Production wording should be aligned with the final App Store privacy disclosures."
    ]
  },
  {
    title: "Contact",
    body: [
      `Questions about privacy can be sent to ${siteConfig.supportEmail}.`
    ]
  }
] as const;

export const termsSections = [
  {
    title: "Agreement",
    body: [
      `By using ${siteConfig.appName}, you agree to these placeholder terms. These terms should be reviewed and finalized before the public launch.`
    ]
  },
  {
    title: "Use of the App",
    body: [
      "You may use the app and website for personal, non-commercial entertainment. Do not attempt to interfere with the service, misuse game data, or bypass access controls."
    ]
  },
  {
    title: "Purchases and Ads",
    body: [
      "The app may include ads, optional purchases, or subscriptions. Any final purchase terms should match the live App Store configuration."
    ]
  },
  {
    title: "Availability",
    body: [
      "The service may change, pause, or stop at any time. Puzzle availability, scoring, and features may evolve as Backword develops."
    ]
  },
  {
    title: "Contact",
    body: [
      `Questions about these terms can be sent to ${siteConfig.supportEmail}.`
    ]
  }
] as const;
