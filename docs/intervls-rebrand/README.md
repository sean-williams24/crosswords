# Backword → Intervls release runbook

Repository implementation prepared on 29 October 2026. Support address confirmed by Sean: **support@intervls.com**. Nothing has been committed, deployed, submitted to Apple, posted to social media, or changed in production dashboards by this task.

See [local verification](verification.md) for the checks run and their limits.

## Current state and release gates

| Item | State |
| --- | --- |
| Overall iOS/web branding, account/paywall/legal/share copy | Implemented locally |
| Backword, Midword, Anagram, Quick Crossword, Pro Crossword names | Retained |
| Both-origin recovery page, all-game coordinator, durable queue and readback | Implemented and covered by focused tests |
| Supplied light/dark wordmarks and wordmark promotional artwork | Integrated from Sean’s supplied originals; supplied IV-icon trial installed for iOS visual review |
| App Store metadata, social announcements, support replies | Drafts prepared alongside this runbook |
| App Store screenshots and website video/images | Awaiting fresh captures from the updated app; see `capture-manifest.json` |
| App Store name / social username / relevant brand-conflict checks | Not verified in authenticated dashboards |
| DNS, email delivery, OAuth, Stripe, AdMob, analytics dashboards | Not changed or verified |
| Browser dashboard access | Browser discovery returned no available browser; no platform connectors were available for these operations |
| Xcode focused tests, upgrade rehearsal, device/visual checks | Awaiting developer verification under AGENTS.md |
| Commit, Apple submission, production release | Await review and completion of the gates below |

The feature switches control migration/indexing and the optional notice. **They do not hide the new branding.** Keep this full change on a preview until the coordinated launch is ready. Prepare intervls.com against the reviewed preview/branch in the same Vercel project, while the existing Backword domains retain the existing production deployment. Do not promote this change just to display an advance notice.

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
3. Check that `www.intervls.com` redirects to the apex. **Do not configure a Vercel domain-level redirect for either Backword hostname.** Such redirects would bypass browser saves and auth callbacks.
4. Retain old-domain DNS, TLS, JavaScript/fonts/images, `/move`, and `/auth/callback` indefinitely. Do not merge apex/www origins before their local saves have been inspected.

### Google / Apple / Supabase

| Service | Prepare before launch | Keep for recovery and older iOS versions |
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

### Web / migration rehearsal

- [ ] On both old HTTPS origins, prepare histories spanning all five games: partial, completed, failed/gave-up, Archive play, hints, historical scores, and streaks. Include signed-in caches and queued uploads.
- [ ] Open an old Home/game/archive/profile bookmark with the launch-enabled preview. The old origin must display the migration check before leaving.
- [ ] Sign in using Apple, then repeat with a separate Google test account. Check per-game verified states, cross-device conflicts, successful readback, and restored Pro access.
- [ ] Disconnect during upload/readback, reload, cancel sign-in, switch accounts, and retry. Failed records must stay local; another account must not receive a claimed guest batch.
- [ ] Edit in another tab during sync, including an earlier game while a later game uploads. Continuation must remain blocked until the full current state is verified. Old app/tab versions may still write: close/reload them and recheck.
- [ ] Open intervls.com, sign in with the same provider/account, and compare history, scores, ratings, and streaks. Settings, cached puzzles, and analytics consent start independently on the new origin.
- [ ] Verify the explicit “continue without moving history” choice preserves the old saves and that `/recover-history` remains accessible in the mobile menu as well as the footer.
- [ ] Verify long histories beyond one backend page load fully, and pending uploads survive another tab's writes. No OAuth tokens/codes/session are copied into the destination URL.

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

1. Confirm Apple approval, completed captures, brand approval, email delivery, and successful both-domain auth/migration/payment rehearsal.
2. Promote the reviewed Vercel release to production with `VITE_REBRAND_LAUNCH_ENABLED=true` and `VITE_REBRAND_NOTICE_ENABLED=false`. Vite embeds these at build time; changing dashboard values requires a fresh deployment. Ensure the old and new domains all use that release; retain only the explicit www.intervls.com and old informational-page redirects supplied in `web/vercel.json`.
3. Update Supabase Site URL and Checkout return origin to `https://intervls.com`; keep legacy auth origins/callbacks. Confirm callbacks, old dated links, and app-ads.txt again.
4. Release the approved iOS version manually. Allow Apple's availability window; confirm the renamed listing is visible before the social launch announcement.
5. Rename existing social profiles, apply approved assets/bios/links and contact fields, then update the website's social profile URLs to the actually secured usernames. Refresh active ad creatives/landing pages, QR codes, and campaign links while retaining existing campaign identifiers where continuity is useful.
6. Update AdMob display/consent details and linked website, Firebase/GA4 display and website settings, Google OAuth consent branding, and Apple Ads creatives/campaign display names. Keep service IDs, app registrations, and historical analytics.
7. Verify the new Search Console property, submit `https://intervls.com/sitemap.xml`, inspect canonical URLs, and monitor indexing. The old game/Home pages remain migration bridges with noindex; **do not submit Change of Address or blanket-redirect those pages** under this save-first policy.

## 6. Monitor, recover, and retain

For the first 48 hours, check both domains daily for sign-in errors, per-game migration failures, pending queue recovery, missing history/Pro reports, Stripe return issues, and ad verification. Check weekly during the first month, then as part of routine maintenance. For consenting users, GA4's `domain_migration` event reports only `started`, `verified`, `failed`, and `continued_without_history`; it contains no account IDs or puzzle payloads. Consent-free users remain untracked, so support/rehearsal checks are still necessary.

Keep old-domain registrations, TLS, callbacks, migration code/static dependencies, and the old support inbox available indefinitely. Do not clear a player's old storage until their new-domain history is confirmed. Keep a “formerly Backword” explanation in active support/social surfaces for at least 90 days.

If authentication, sync, or payment checks fail, hold launch or revert to the last validated deployment/configuration. Choose a known-good version that understands both historical queue arrays and the new per-write queue entries; retain stored entries during rollback. Do not erase saves, rewrite accounts, rotate product IDs, or run database rollback migrations for this rename. The iOS release cannot be instantaneously rolled back like the website, so retain backend compatibility with both old and renamed app versions.
