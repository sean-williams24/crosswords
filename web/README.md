# Backword Web

Minimal Vite + React website for Backword, ready for Vercel static hosting and future Supabase-powered gameplay.

## Scripts

```bash
npm install
npm run dev
npm run build
npm run preview
npm run test
```

## Replace Before Launch

- `src/lib/siteConfig.ts`: production App Store URL, support email, and display metadata.
- `src/content/legal.ts`: reviewed privacy policy and terms copy.
- `public/app-ads.txt`: production Google AdMob publisher line.

## Backword game configuration

The browser game reads released daily content directly from Supabase. Create a
local `.env` file and configure the same values in Vercel before deployment:

```bash
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
VITE_GOOGLE_WEB_CLIENT_ID=
VITE_ANALYTICS_ENABLED=false
VITE_FIREBASE_API_KEY=
VITE_FIREBASE_AUTH_DOMAIN=
VITE_FIREBASE_PROJECT_ID=backword-537c1
VITE_FIREBASE_APP_ID=
VITE_FIREBASE_MEASUREMENT_ID=
VITE_APP_STORE_PROVIDER_TOKEN=
VITE_APP_STORE_CAMPAIGN_TOKENS={"default":"web_default","tiktok:launch":"tiktok_launch","instagram:launch":"instagram_launch"}
```

Keep browser game integration in `src/lib` and page-level gameplay in `src/pages` or feature-specific folders.

Web Pro purchases use Stripe Managed Payments through Supabase Edge Functions.
Set Stripe's server secrets and the deployed `WEB_ORIGIN` through the Supabase
dashboard, not in Vercel or a browser `.env` file. Create tax-inclusive GBP
Stripe prices for £1.49/month and £8.99/year using an eligible digital-product
tax code, then configure Stripe webhooks as documented in
`Backend/supabase/functions/README.md`. Stripe Link manages web subscription
changes, cancellations, and payment methods; do not enable the ordinary Stripe
Billing Customer Portal.

## Analytics and campaign attribution

Register the production website as a Web app in the existing Firebase project,
then add its public Firebase configuration above in Vercel's **Production**
environment. Set `VITE_ANALYTICS_ENABLED=true` only in Production; preview and
local environments remain off. Analytics initialises only after a visitor
explicitly accepts the website analytics prompt.

Create the corresponding App Store Connect campaign links before publishing a
campaign. `VITE_APP_STORE_PROVIDER_TOKEN` is the provider token from App Store
Connect and `VITE_APP_STORE_CAMPAIGN_TOKENS` maps accepted website campaigns to
their Apple `ct` tokens. Use lower-case UTM links such as:

```text
https://www.playbackword.com/?utm_source=tiktok&utm_medium=organic_social&utm_campaign=launch&utm_content=video_a
```

GA4 custom event dimensions to create: `game`, `outcome`, `mode`, `release_day`,
`score_band`, `duration_band`, `placement`, `reason`, `entry_point`, `plan`,
`trial_eligible`, `provider`, and `feature`. Mark `game_completed`,
`app_store_click`, `sign_in_succeeded`, and `pro_entitlement_activated` as key
events.

Guest progress, settings, cached content, and statistics remain in versioned
browser-local storage. Signing in with Apple or Google moves game progress into
an account-scoped cache and synchronises it through Supabase. Settings and
puzzle caches intentionally remain device-local.

## Account setup

Enable Google and Apple providers in Supabase Auth. Google web sign-in uses
Google Identity Services and exchanges its ID token directly with Supabase, so
add every exact site origin that can show the Google button to the Google Web
OAuth client’s Authorized JavaScript origins. For Backword this includes
`https://www.playbackword.com` and `https://playbackword.com`; add
`https://backword.vercel.app` when using Vercel's production URL for testing,
and your local origin (normally `http://localhost:5173`) for local development.
Origins must not include a path. Apple web login still needs the deployed site's `/auth/callback`, local development's
`/auth/callback`, a Services ID, and a client secret in Supabase. Apply
`Backend/supabase/schema.sql`, then deploy the Edge Functions described in
`Backend/supabase/functions/README.md` before enabling account-linked Pro.

## App Store Connect privacy links

Before submitting an app version with accounts or cloud sync, set these public
URLs in App Store Connect:

- **Privacy Policy URL:** `https://www.playbackword.com/privacy`
- **Privacy Choices URL:** `https://www.playbackword.com/privacy-choices`

The iOS app exposes both links in Settings and on the paywall. Update the App
Privacy data types in App Store Connect whenever Backword’s data practices or
third-party SDK configuration changes.
