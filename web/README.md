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

Guest progress, settings, cached content, and statistics remain in versioned
browser-local storage. Signing in with Apple or Google moves game progress into
an account-scoped cache and synchronises it through Supabase. Settings and
puzzle caches intentionally remain device-local.

## Account setup

Enable Google and Apple providers in Supabase Auth. Google web sign-in uses
Google Identity Services and exchanges its ID token directly with Supabase, so
add the deployed site origin (for example `https://www.playbackword.com`) to
the Google Web OAuth client’s Authorized JavaScript origins. Apple web login
still needs the deployed site's `/auth/callback`, local development's
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
