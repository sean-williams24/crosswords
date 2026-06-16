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
    title: "Agreement to These Terms",
    body: [
      `These Terms & Conditions govern your use of the ${siteConfig.appName} iOS app and this website. By using ${siteConfig.appName}, you agree to these terms. If you do not agree, please do not use the app or website.`
    ]
  },
  {
    title: "About Backword",
    body: [
      "Backword is a word game app that includes Backword, daily crosswords, weekly crosswords, Word of the Day, scores, rating tiers, archives, ads, and optional Pro features. Features may change, be added, or be removed over time."
    ]
  },
  {
    title: "Eligibility and Accounts",
    body: [
      "Backword is intended for a general audience. If you are under the age required to agree to these terms in your country or region, you should use Backword only with permission from a parent or guardian.",
      "Backword may introduce user accounts and cross-device sync. If you create an account, you are responsible for keeping your login details secure and for activity that occurs through your account. You must provide accurate information and must not impersonate another person."
    ]
  },
  {
    title: "Acceptable Use",
    body: [
      "You may use Backword for personal, non-commercial entertainment. You must not misuse the app or website, interfere with their operation, attempt to access systems or data without permission, scrape or copy puzzle content at scale, reverse engineer the app except where permitted by law, bypass ads, subscriptions, access controls, or technical protections, or use Backword in a way that violates applicable law."
    ]
  },
  {
    title: "Scores, Ratings, and Game Content",
    body: [
      "Scores, streaks, rating tiers, puzzle availability, archives, and other game features are provided for entertainment. We may correct errors, adjust scoring rules, change puzzle schedules, remove or replace content, or reset inaccurate progress where reasonably necessary to protect the service or fix mistakes.",
      "Daily and weekly content may depend on backend availability, device settings, app version, subscription status, and network access. We do not guarantee that every puzzle, archive entry, score, or feature will always be available."
    ]
  },
  {
    title: "Pro Features, Purchases, and Subscriptions",
    body: [
      "Backword may offer optional paid features, subscriptions, or other in-app purchases. Purchases are processed by Apple through the App Store. Apple’s terms, payment rules, cancellation process, refund process, and subscription management controls apply to those purchases.",
      "Prices, billing periods, trial availability, renewal terms, and included Pro features are shown in the app or App Store before purchase. Subscriptions renew automatically unless cancelled through your Apple ID settings before the renewal date. We do not receive your payment card details.",
      "Pro features may change over time. If a purchase does not unlock correctly, use the restore purchases option in the app or contact us."
    ]
  },
  {
    title: "Advertising and Rewards",
    body: [
      "Backword may show ads, including interstitial and rewarded ads. Rewarded ads may grant in-app benefits only after the ad provider confirms completion. Ad availability is not guaranteed and may vary by region, device, consent choices, network availability, and ad provider decisions.",
      "You must not manipulate ad delivery, fake ad completion, or use automated tools to obtain rewards or avoid ads."
    ]
  },
  {
    title: "Intellectual Property",
    body: [
      "Backword, including its name, design, app interface, puzzle content, text, graphics, logos, scoring systems, and other materials, is owned by Sean Williams or licensed for use in Backword. These terms do not transfer ownership of any intellectual property to you.",
      "You may not copy, redistribute, sell, publish, or create derivative works from Backword content except for personal, non-commercial sharing of normal gameplay screenshots or results, provided that sharing does not misrepresent Backword or violate these terms."
    ]
  },
  {
    title: "Privacy",
    body: [
      "Our Privacy Policy explains how information is collected, used, and shared when you use Backword or visit this website. By using Backword, you acknowledge the Privacy Policy."
    ]
  },
  {
    title: "Third-Party Services",
    body: [
      "Backword relies on third-party services such as Apple, Google AdMob, Supabase, and website hosting providers. These services may be subject to their own terms and privacy policies. We are not responsible for third-party services outside our control."
    ]
  },
  {
    title: "Disclaimers",
    body: [
      "Backword is provided on an as-is and as-available basis. We try to keep the app and website reliable, enjoyable, and accurate, but we do not guarantee that they will be uninterrupted, error-free, secure, or available at all times.",
      "To the fullest extent permitted by law, we disclaim warranties of merchantability, fitness for a particular purpose, non-infringement, and any warranties arising from course of dealing or usage of trade."
    ]
  },
  {
    title: "Limitation of Liability",
    body: [
      "To the fullest extent permitted by law, Sean Williams and Backword will not be liable for indirect, incidental, special, consequential, exemplary, or punitive damages, or for loss of data, profits, goodwill, or other intangible losses arising from your use of or inability to use Backword.",
      "Nothing in these terms limits liability that cannot legally be limited, including liability for fraud or for death or personal injury caused by negligence where applicable."
    ]
  },
  {
    title: "Changes to Backword or These Terms",
    body: [
      "We may update, suspend, or discontinue any part of Backword, including games, features, subscriptions, archives, scoring, rating tiers, ads, or website content. We may also update these terms from time to time. When we make changes, we will update the date shown on this page. Continued use of Backword after changes means you accept the revised terms."
    ]
  },
  {
    title: "Governing Law",
    body: [
      "These terms are intended to be governed by the laws of England and Wales, except where local consumer protection laws require otherwise. If you live outside the United Kingdom, you may also have rights under the laws of your country or region."
    ]
  },
  {
    title: "Contact",
    body: [
      `Questions about these terms can be sent to ${siteConfig.supportEmail}.`
    ]
  }
] as const;
