# Intervls Web

Vite + React website for Intervls, hosted on Vercel with Supabase gameplay and accounts.

The rebrand is prepared locally. Read [the release runbook](../docs/intervls-rebrand/README.md) before deployment: the new branding is visible even with the launch switch off. Both old HTTPS origins must retain save recovery and callbacks.

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
VITE_ANALYTICS_DEBUG=false
VITE_FIREBASE_API_KEY=
VITE_FIREBASE_AUTH_DOMAIN=
VITE_FIREBASE_PROJECT_ID=backword-537c1
VITE_FIREBASE_APP_ID=
VITE_FIREBASE_MEASUREMENT_ID=
VITE_APP_STORE_PROVIDER_TOKEN=
VITE_APP_STORE_CAMPAIGN_TOKENS={"default":"web_default","tiktok:launch":"tiktok_launch","instagram:launch":"instagram_launch"}
```

Keep browser game integration in `src/lib` and page-level gameplay in `src/pages` or feature-specific folders.

Midword is available at `/midword` and in Home, the game menu, Player Profile,
and the Pro archive. It uses the existing Supabase configuration and the native
`midword_puzzles` table and `midword` progress type; no new browser credentials
are needed. Its focused checks are:

```bash
npm run test -- src/features/midword src/pages/MidwordPage.test.tsx
```

To regenerate its offline guess dictionary from the attributed wordfreq data:

```bash
../Backend/.venv/bin/python scripts/generate_midword_guesses.py
```

While running `npm run dev`, the game menu includes a **Debug → Force Pro
access** switch. It requires a signed-in test account, is saved only in that
browser, and affects only the client-side entitlement used to exercise protected
web routes. It does not write to Supabase or change Stripe/Apple subscription
state. The switch is unavailable in built, preview, and production deployments.

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

To test event instrumentation locally or in a Vercel Preview deployment, copy
the Firebase configuration into that environment and set
`VITE_ANALYTICS_DEBUG=true`. It deliberately enables Analytics for that build
and adds GA4's `debug_mode` parameter, so events appear in DebugView without a
browser extension. Accept the analytics prompt in the test browser, restart the
Vite server after changing local environment values, and remove the flag when
testing is finished. Never set this flag in Vercel's Production environment.

Create the corresponding App Store Connect campaign links before publishing a
campaign. `VITE_APP_STORE_PROVIDER_TOKEN` is the provider token from App Store
Connect and `VITE_APP_STORE_CAMPAIGN_TOKENS` maps accepted website campaigns to
their Apple `ct` tokens. Use lower-case UTM links such as:

```text
https://intervls.com/?utm_source=tiktok&utm_medium=organic_social&utm_campaign=launch&utm_content=video_a
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
`https://intervls.com`, `https://www.playbackword.com`, and `https://playbackword.com`; add
`https://backword.vercel.app` when using Vercel's production URL for testing,
and your local origin (normally `http://localhost:5173`) for local development.
Origins must not include a path. Apple web login still needs the deployed site's `/auth/callback`, local development's
`/auth/callback`, a Services ID, and a client secret in Supabase. Apply
`Backend/supabase/schema.sql`, then deploy the Edge Functions described in
`Backend/supabase/functions/README.md` before enabling account-linked Pro.

## App Store Connect privacy links

Before submitting an app version with accounts or cloud sync, set these public
URLs in App Store Connect:

- **Privacy Policy URL:** `https://intervls.com/privacy`
- **Privacy Choices URL:** `https://intervls.com/privacy-choices`

The iOS app exposes both links in Settings and on the paywall. Update the App
Privacy data types in App Store Connect whenever Intervls’s data practices or
third-party SDK configuration changes.


## Rebrand switches

`VITE_REBRAND_LAUNCH_ENABLED=false` keeps preparation noindex and leaves the legacy game routes playable. Enable it only on the coordinated launch deployment to show the old-domain migration bridge. `VITE_REBRAND_NOTICE_ENABLED=false` is an optional advance-notice switch. Vite embeds both at build time. The renamed UI itself is not gated by these switches.

`/move` on either old HTTPS origin verifies all five games and the current account's queued saves. `/recover-history` on Intervls links back to both original origins. Guest progress is only removed after verified server readback; an explicit continue-without-history action retains it. The existing browser storage keys remain stable. Checkout origin configuration belongs in Supabase, not Vercel/browser variables.
