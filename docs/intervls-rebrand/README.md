# Backword → Intervls release runbook

Repository implementation prepared on 29 October 2026. Support address confirmed by Sean: **support@intervls.com**. Nothing has been committed, deployed, submitted to Apple, posted to social media, or changed in production dashboards by this task.

See [local verification](verification.md) for the checks run and their limits.

## Current state and release gates

| Item | State |
| --- | --- |
| Overall iOS/web branding, account/paywall/legal/share copy | Implemented locally |
| Backword, Midword, Anagram, Quick Crossword, Pro Crossword names | Retained |
| Simplified web launch | Direct old-domain redirects at launch; browser-only history starts fresh; normal account sync retained |
| Supplied light/dark wordmarks and wordmark promotional artwork | Integrated from Sean’s supplied originals; supplied IV-icon trial installed for iOS visual review |
| App Store metadata, social announcements, support replies | Drafts prepared alongside this runbook |
| App Store screenshots and website video/images | Awaiting fresh captures from the updated app; see `capture-manifest.json` |
| App Store name / social username / relevant brand-conflict checks | Not verified in authenticated dashboards |
| DNS, email delivery, OAuth, Stripe, AdMob, analytics dashboards | Not changed or verified |
| Browser dashboard access | Browser discovery returned no available browser; no platform connectors were available for these operations |
| Xcode focused tests, upgrade rehearsal, device/visual checks | Awaiting developer verification under AGENTS.md |
| Commit, Apple submission, production release | Await review and completion of the gates below |

The feature switches control indexing and the optional notice. **They do not hide the new branding.** Keep this full change on a preview until the coordinated launch is ready. Prepare intervls.com against the reviewed preview/branch in the same Vercel project, while the existing Backword domains retain the existing production deployment. Do not promote this change just to display an advance notice.

## Simplified web launch decision — 4 November 2026

With nine known web users, the launch no longer includes a guest-history transfer
or local migration rehearsal. Both Backword hostnames will redirect directly to
Intervls at launch. History **already synced** to the existing Supabase account
remains available after signing into that same account. Browser-only guest
history and unsynced account saves start fresh on the new domain. Settings,
sessions, cached puzzles, and consent also start fresh. The iOS app's local data
and existing purchase/account identities remain compatible.

There is no recovery-screen promise. Before launch, players can use normal
sign-in and sync on the current Backword website. Account-history restoration,
Apple/Google sign-in, Pro access, and payment checks remain release gates.

## 1. Confirm names, assets, support, and access

- [ ] Confirm `Intervls` can be entered on the existing App Store app record (ID `6773428497`); review relevant name conflicts before approving the identity.
- [ ] In the existing Instagram, TikTok, and Facebook accounts, check the desired `intervls` username. Resolve unavailable handles before changing any username. Keep the existing account IDs, followers, and history.
- [ ] Review the brand kit in `../intervls-brand/`, including social crops, iOS icon, Light/Dark wordmarks, and App Store header/search previews.
- [ ] Confirm incoming and outgoing mail for `support@intervls.com`. Keep the old Gmail inbox monitored/forwarded. Verify provider MX/SPF/DKIM/DMARC records; preserve them during website DNS changes.
- [ ] Register the actual outbound address/domain with Apple's private email relay if replying to Hide My Email addresses. Verify a reply reaches a relay address.
- [ ] Record the current Vercel deployment, DNS records, OAuth origin/callback lists, Supabase Site URL, and checkout origins before making reversible configuration changes. Never record secrets in this repository.

## 2. Prepare the new domain without moving old players

Use the existing Vercel project and Supabase backend. Do not create another app, database, Stripe account, or Firebase project.

1. Deploy the reviewed branch as a preview with both rebrand switches false. Assign `intervls.com` and `www.intervls.com` to that preview/branch using Vercel's domain settings; leave the old domains on their existing production deployment. Use the project-specific A/CNAME records Vercel supplies, without replacing unrelated mail/TXT records or nameservers.
2. Verify HTTPS, `/contact`, `/privacy`, `/privacy-choices`, `/terms`, static images, and `/app-ads.txt` on intervls.com. The app reviewer must be able to open support/legal URLs. The new site's HTML stays `noindex` until launch.
3. Check that `www.intervls.com` redirects to the apex. Keep the existing `playbackword.com` → `www.playbackword.com` redirect during preparation.
4. Keep the old-domain registrations, DNS, and TLS. At launch, change both Backword hostnames to direct permanent redirects to Intervls using the domain settings described in section 5. No local migration rehearsal is needed.

### Google / Apple / Supabase

| Service | Prepare before launch | Preserve compatibility |
| --- | --- | --- |
| Google Web OAuth client | Add exact JavaScript origin `https://intervls.com`; update consent brand/logo, homepage, privacy URL, support details, and verify the new domain if requested | `https://www.playbackword.com`, `https://playbackword.com`, existing native client and development/test origins |
| Apple Services ID | Update description and website-domain configuration on the existing Services ID; retain its primary App ID association | Existing Services ID, native App ID, keys, and actual Supabase provider return URL |
| Supabase Auth redirect allowlist | Add `https://intervls.com/auth/callback` | Both old `/auth/callback` URLs and `backword://login-callback`; existing local/test callbacks |
| Supabase Auth Site URL | Switch to `https://intervls.com` at launch | Allowlist entries above |

Apple's provider callback is normally the Supabase project's `/auth/v1/callback`; it is distinct from the website's `/auth/callback`. Preserve the configured working provider callback rather than replacing it with the website URL. Google uses Identity Services ID tokens directly on the web; do not substitute an OAuth code flow.

### Stripe Edge Function settings

Deploy only the changed `create-stripe-checkout` function after review. Existing deployments remain compatible with `WEB_ORIGIN` alone. Add the following Supabase function secrets/settings through the authenticated dashboard, keeping existing secret keys, webhook endpoints, price IDs, and customer/subscription metadata intact:

```text
WEB_ORIGIN=https://www.playbackword.com
WEB_ALLOWED_ORIGINS=["https://www.playbackword.com","https://playbackword.com","https://intervls.com"]
WEB_CHECKOUT_RETURN_ORIGIN=https://www.playbackword.com
```

At launch, set `WEB_CHECKOUT_RETURN_ORIGIN=https://intervls.com` and update `WEB_ORIGIN` to the new primary origin for consistency. Keep the explicit old/new allowlist. Origins must have no trailing slash or path. Keep test origins out of production unless explicitly needed. Requests from an unlisted Origin receive 403; server requests without an Origin still require authentication.

Update the existing Stripe product names, business website/support details, and customer-facing branding supported by Managed Payments. Inspect a test Checkout and its resulting communications; Stripe remains merchant of record, so some fields are controlled by Stripe. Keep Stripe Link for subscription management. Do not create replacement prices or subscriptions for the rename.

## 3. Verify the repository changes

Run only focused affected tests. Agents may run the web unit tests and static checks. The developer handles Xcode tests, app builds, simulator/device review, and capture under the repository instructions.

### Web / account and launch checks

Use the Intervls preview with the same existing backend. No local HTTPS, hosts
file changes, or Safari migration profile is required.

- [ ] Sign in on Intervls with Apple and Google. Confirm sign-out and re-sign-in work in a private window without a Vercel login prompt.
- [ ] Use an existing account with known cloud history. Compare its games, scores, ratings, and streaks on Intervls. Check Home, dated games, Archive, and Player Profile; use the same provider/account.
- [ ] Check guest saves while signed out on Intervls. In each game, make a saved action, refresh the same tab, and check it remains:
  - Backword / Midword: submit a valid guess and confirm it appears in the guess history. Letters merely typed into the answer box are an unsaved draft.
  - Anagram: press Start, then place at least one tile. The arrangement and running game should restore.
  - Quick Crossword: enter at least one grid letter. It should restore without a separate Submit action.
  - Keep the same origin and browser session throughout. Explain in launch/support copy that browser-only Backword history and unsynced saves do not transfer.
- [ ] Confirm an existing Apple Pro account stays Pro without offering a second subscription. Check Stripe Pro access with its existing account.
- [ ] With a separate non-Pro test account, check Stripe Checkout, cancellation/success return links, and subscription management in the appropriate test environment.
- [ ] Confirm support/legal pages, static images, and `/app-ads.txt` load publicly; keep the preview noindex.
- [ ] After the launch redirects are enabled, test both old hostnames at `/`, a dated game, `/contact`, `/privacy`, and `/app-ads.txt`. Confirm they reach the corresponding Intervls URL without a redirect loop. Sign in afresh on Intervls rather than reusing an old callback URL.

The old migration/recovery screens and local rehearsal commands have been removed.
Stop a running rehearsal terminal with Ctrl-C. The failed administrator setup did
not install a hosts-file routing block; generated local certificate files remain
ignored in `web/.rehearsal/` and are not required by this release.

### iOS / purchase checks — developer

- [ ] Run focused `IntervlsBrandTests`, `LegalLinkTests`, `FeedbackEmailContentTests`, `LaunchSplashViewTests`, `PuzzleResultShareTests`, affected account tests, and `StoreServiceTests` in Xcode.
- [ ] Upgrade an installed Backword build without reinstalling. Check guest and account saves, preferences, Keychain/sign-in, active Pro, Restore Purchases, and existing dated links.
- [ ] Review Home, splash, sign-in, Settings, paywall, share cards, icon, Light/Dark appearance, and accessibility text sizes on iPhone/iPad.
- [ ] Verify Apple and Stripe Pro accounts across iOS/web, cancellation/renewal handling, checkout return links, and prevention of a second active subscription.

## 4. Complete assets and App Store submission

Use `app-store-metadata.en-GB.json` as the copy source and audit every active App Store localisation. Preserve bundle ID `com.backword.app`, Apple app ID `6773428497`, products `com.backword.monthlypro` / `com.backword.annualpro`, the current subscription group, and purchase history. Prices remain £1.49 monthly / £8.99 annually unless changed separately.

Fresh captures are a launch blocker. `capture-manifest.json` lists all nine App Store placements and website media needing review. Make new captures from the updated app; keep the historic `output/app-store/2026-10-19/` set intact. Stage the new originals under `output/app-store/intervls/sources/`.

Reuse the native Core Text/device composition workflow documented in `output/app-store/2026-10-19/README.md`. Adapt its source dimensions to the new originals; never resize an original merely to satisfy an old source-dimension assertion. Home, Backword, Quick Crossword, Midword, Anagram, Archive, iPad, Pro Crossword, and rating all require review; the last two historic exports do not have equivalent reusable native renderers. Render them from fresh captures using the same composition rules. Do not label historic exports as refreshed Intervls imagery.

- [ ] Regenerate opaque sRGB upload images at the display-slot dimensions actually offered by App Store Connect; inspect full-resolution output and the upload preview.
- [ ] Replace website Home poster/video and game screenshots after capture review.
- [ ] Upload the approved icon, screenshots, headers/search artwork, metadata, support/privacy URLs, and subscription/group display names. Audit custom product pages, previews, and in-app events if present.
- [ ] Confirm root `app-ads.txt` is reachable on the new domain before changing the listing's developer/marketing website. Keep it available on the old domains too.
- [ ] Confirm the next editable app version and unused build number against App Store Connect/TestFlight, then update the archive version/build accordingly. The repository retains its current numbers until that check.
- [ ] Submit under the existing listing, with manual release. Explain the rebrand in review notes. Hold public release until all other gates pass.

Advance notice can be posted using `social-and-support-copy.md` while Apple reviews. A small advance-notice-only website change must be released separately if desired; promoting this full branch would expose the new branding early.

## 5. Coordinated launch

1. Confirm Apple approval, completed captures, brand approval, email delivery, and successful new-domain sign-in, cloud-history, and payment checks.
2. Build and promote the reviewed Vercel release to production with `VITE_REBRAND_LAUNCH_ENABLED=true` and `VITE_REBRAND_NOTICE_ENABLED=false`. Vite embeds these at build time; changing dashboard values requires a fresh deployment. Move `intervls.com` and `www.intervls.com` from the preview branch to Production and verify the new site publicly before redirecting old players.
3. Update Supabase Site URL, `WEB_ORIGIN`, and `WEB_CHECKOUT_RETURN_ORIGIN` to `https://intervls.com`; retain existing account/provider identifiers and the explicit Checkout allowlist. In Vercel **Project → Settings → Domains**, edit **each** `playbackword.com` and `www.playbackword.com`: select **Redirect to Another Domain**, choose **308 Permanent Redirect**, target **intervls.com**, and save. Replace the apex's existing www redirect so both old hostnames go directly to Intervls. Verify dated paths and campaign query strings are preserved. Keep `www.intervls.com` redirecting to the apex. Browser sessions are origin-local: users sign in again on Intervls. Test a fresh Apple/Google flow there and native `backword://login-callback`; retain existing provider callback/allowlist entries for compatibility, but do not rely on old web callbacks once the domain redirects are enabled.
4. Release the approved iOS version manually. Allow Apple's availability window; confirm the renamed listing is visible before the social launch announcement.
5. Rename existing social profiles, apply approved assets/bios/links and contact fields, then update the website's social profile URLs to the actually secured usernames. Refresh active ad creatives/landing pages, QR codes, and campaign links while retaining existing campaign identifiers where continuity is useful.
6. Update AdMob display/consent details and linked website, Firebase/GA4 display and website settings, Google OAuth consent branding, and Apple Ads creatives/campaign display names. Keep service IDs, app registrations, and historical analytics.
7. Verify the new Search Console property, submit `https://intervls.com/sitemap.xml`, inspect canonical URLs, and monitor indexing. The old domains now permanently redirect to the equivalent new URLs; keep those redirects active.

## 6. Monitor and retain

For the first 48 hours, check sign-in, missing cloud history/Pro reports, Stripe
returns, old-domain redirects, and ad verification daily. Check weekly during the
first month, then as part of routine maintenance. Missing-history replies must
distinguish cloud-synced history from browser-only/unsynced records; do not direct
players to a recovery screen or promise that local history transferred.

Keep both old-domain registrations, DNS, TLS, permanent redirects, and the old
support inbox active. Keep a “formerly Backword” explanation in active
support/social surfaces for at least 90 days.

If authentication, account sync, or payment checks fail, hold launch or restore
the recorded Vercel deployment/domain settings and backend origin settings.
Choose a known-good version that understands both historical queue arrays and
the new per-write queue entries. Retain stored entries during rollback. Do not
erase saves, rewrite accounts, rotate product IDs, or run database rollback
migrations for this rename. An iOS release cannot be instantly rolled back like
the website, so retain backend compatibility with both app versions.
