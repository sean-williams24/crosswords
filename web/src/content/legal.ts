import { siteConfig } from "../lib/siteConfig";

export const privacySections = [
  {
    title: "Who We Are",
    body: [
      `${siteConfig.appName} is operated by ${siteConfig.developerName}. This Privacy Policy explains how information is collected, used, and shared when you use the ${siteConfig.appName} iOS app or visit this website.`
    ]
  },
  {
    title: "Information We Collect",
    body: [
      "Gameplay and settings data: Backword stores game progress, guesses, completed puzzles, scores, rating tier progress, preferences, onboarding state, and ad frequency state so the app can remember your progress and provide the game experience. This data is currently stored locally on your device.",
      "Account and cloud sync data: Backword may introduce user accounts and cross-device sync. If you create an account or use sync features, we may collect account details such as your email address or user identifier, along with gameplay progress, scores, rating history, settings, and subscription-related access state so your progress can be restored across devices.",
      "Puzzle content requests: Backword connects to backend services to fetch daily Backword words, daily and weekly crosswords, archive content, and Word of the Day. These requests may involve standard technical information such as IP address, device or browser information, request timestamps, and network metadata.",
      "Purchase information: If you buy or restore a subscription or in-app purchase, Apple processes the payment. Backword receives purchase entitlement information from Apple so Pro features can be unlocked. We do not receive or store your payment card details.",
      "Advertising information: Backword uses Google AdMob to show ads. Google and its partners may collect information such as device identifiers, advertising identifiers where permitted, ad interactions, approximate location, diagnostics, and usage information to deliver ads, limit ad frequency, prevent fraud, and report ad performance.",
      "Website information: When you visit this website, hosting providers may process standard technical information such as IP address, browser type, device information, pages visited, and timestamps for security, diagnostics, and reliability."
    ]
  },
  {
    title: "How We Use Information",
    body: [
      "We use information to provide and improve Backword, deliver puzzles and game content, save progress, calculate scores and rating tiers, restore purchases, provide Pro access, show ads where applicable, troubleshoot problems, protect against abuse or fraud, and respond to support or privacy requests."
    ]
  },
  {
    title: "Advertising and AdMob",
    body: [
      "Backword may show interstitial and rewarded ads through Google AdMob. Ads may be personalized or non-personalized depending on your region, consent choices, device settings, and Google’s ad settings. Even non-personalized ads may use mobile identifiers or similar technologies for frequency capping, aggregated reporting, security, and fraud prevention where permitted.",
      "Where required, Backword will ask for permission before allowing tracking for advertising purposes. You can change tracking permission in iOS Settings. If tracking is disabled, ads may still appear, but they may be less relevant."
    ]
  },
  {
    title: "Third-Party Services",
    body: [
      "Backword uses third-party services that may process information according to their own privacy policies, including Apple for App Store purchases and subscriptions, Google AdMob for advertising, Supabase for backend content delivery and planned account/cloud-sync features, and website hosting providers for serving this website.",
      "We expect service providers to protect information appropriately and use it only for the services they provide to Backword, subject to their own terms and policies."
    ]
  },
  {
    title: "Data Retention and Deletion",
    body: [
      "Local gameplay and settings data remains on your device until you delete the app, clear the data through app features where available, or overwrite it through normal use.",
      "If account or cloud-sync features are enabled, account data, gameplay progress, scores, and settings may be retained while your account remains active or as needed to provide the service, comply with legal obligations, resolve disputes, prevent abuse, and maintain backups.",
      `You can request deletion of account-related personal information by contacting ${siteConfig.supportEmail}. Purchase history and subscription records handled by Apple must be managed through your Apple ID and App Store settings.`
    ]
  },
  {
    title: "Your Choices",
    body: [
      "You can delete local app data by deleting the app from your device. You can manage subscriptions through your Apple ID and App Store settings. You can manage tracking permission in iOS Settings and may be able to manage ad personalization through your device settings or Google’s ad settings.",
      "If account features are introduced, you may contact us to request access to, correction of, or deletion of personal information associated with your account, subject to applicable law and reasonable verification."
    ]
  },
  {
    title: "Children's Privacy",
    body: [
      "Backword is intended for a general audience and is not directed specifically to children under 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided personal information, please contact us so we can take appropriate action."
    ]
  },
  {
    title: "Security",
    body: [
      "We use reasonable technical and organizational measures to protect information. No method of transmission or storage is completely secure, so we cannot guarantee absolute security."
    ]
  },
  {
    title: "International Processing",
    body: [
      "Backword and its service providers may process information in countries other than where you live. Data protection laws may vary between countries, but we take steps intended to protect information as described in this policy."
    ]
  },
  {
    title: "Changes to This Policy",
    body: [
      "We may update this Privacy Policy from time to time. When we make changes, we will update the date shown on this page. Continued use of Backword after an update means the revised policy applies."
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
