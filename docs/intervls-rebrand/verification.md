# Local verification — 29 October 2026

## Simplified web launch — 4 November 2026

- Replaced the cross-domain guest migration plan with direct Vercel domain
  redirects to be enabled manually at launch. The existing apex-to-www Backword
  redirect stays in place during preparation.
- Removed the migration gate, recovery page/links, migration analytics, and local
  HTTPS/localhost rehearsal tooling. Retired `/move` and `/recover-history` links
  fall through to Home without clearing browser storage.
- Kept normal account cloud sync, guest ownership protections, save keys, durable
  upload queues, native callbacks, and purchase identities.
- Updated release/support/App Review copy: only already-synced cloud history
  follows the account; browser-only history and unsynced saves do not transfer.
- All **81 focused tests passed across 12 files**, covering routes/navigation,
  preview/indexing policy, launch copy, analytics, guest ownership, durable queues,
  account-bound/paginated transport, AuthProvider, and the Pro page.
- Application and tooling TypeScript checks (`tsc --noEmit`) and
  `git diff --check` passed. These mocked/unit checks do not verify live accounts,
  checkout, or domain redirects.
- No production domains, DNS, dashboards, or backend settings changed by agents.
  Stop any running rehearsal server with Ctrl-C. The earlier generated private
  CA files stay ignored; administrator setup failed before hosts routing began.

The earlier migration coordinator/rehearsal test results below describe retired
code and are no longer launch requirements.

## Approved title and tagline update

- Home uses `Intervls — Free daily word games` in the static HTML and after React navigation. Page-specific game titles remain intact.
- Updated descriptions, social titles, Info copy, draft App Store/social/capture copy, and promotional PNGs to use `Free daily word games to challenge your mind`. The App Store subtitle uses the shorter `Free daily word games` within its field limit.
- All 40 focused metadata, routing, release-artifact and importer tests passed. Promotional images were inspected visually. The promotional-only renderer mode preserves the wordmark PDFs/SVGs and all icons.

## Passed

- Final focused run: **95 tests passed**, zero failures, across App routes, five game pages, brand separation, preview/indexing policy, release copy, icon/promotional image dimensions and alpha checks, and advance notice. Report: `/private/tmp/intervls-final-focused-tests.json` (local, temporary).
- Separate focused runs passed for the all-five-game migration coordinator, interrupted/offline retries, score conflict preservation, final browser recheck, guest ownership, concurrent queue writes, old bookmark gate, migration UI, account-bound/paginated transport, low backend row caps, account switches, Checkout CORS configuration, analytics event schema, Player Profile, Archive, AuthProvider, footer, sign-in, paywall, contact, and result sharing.
- TypeScript checks: `tsc -p web/tsconfig.app.json --noEmit` and `tsc -p web/tsconfig.node.json --noEmit`.
- Swift syntax parsing for changed source and new brand tests; standalone type checking of Foundation-only `AppBrand.swift` and `LegalLink.swift` using a temporary writable module cache.
- `plutil -lint` for the Xcode project and Info.plist; `git diff --check`.
- Native brand renderer executed successfully; icon and social-preview exports inspected visually. Artwork PNG unit checks confirm the declared sizes and RGB exports without alpha.

The unit tests use local fixtures/mocks. They do not establish that production OAuth, DNS, Stripe, App Store entitlements, or domain recovery have been configured correctly.

## Not run or completed

- No iOS build, simulator launch, device test, Xcode unit-test execution, upgrade rehearsal, or fresh app capture. These remain developer checks under AGENTS.md.
- No web production build or live browser runtime verification.
- No production dashboard verification or changes: browser discovery returned no available browser session, and no relevant service connectors were available.
- No commits, pushes, deployment, Apple submission/release, social posts/profile updates, or outbound email.

The full rebrand stays a reviewable local change. Fresh captures and the runbook's production gates must be completed before launch.

## Supplied wordmark integration

- Replaced the draft lettering with `intervls-light2.pdf` and `intervls-dark2.png`, preserving both original source files.
- Updated the iOS light/dark/share PDFs, website SVG wrappers, link-preview image, and wordmark promotional exports. Both appearances use a matching cropped canvas; their PDF renders and website preview PNG were inspected visually.
- Focused tests passed for theme selection, source hashes, embedded PNG fidelity, iOS master/catalog/share binding, release artifacts, and result sharing. The importer also ran against a temporary fixture proving that it preserves source files and separately managed icon files.
- XML validation and TypeScript checks passed. The SVG wrappers were checked structurally; native SVG preview rendering was unavailable, and no live browser/app runtime verification was performed.
- Hashes confirmed the existing app icon, website icon, and Apple touch icon were unchanged. The importer no longer generates or overwrites icons.

## Supplied trial iOS icon — 30 October 2026

- Installed `IV-icon.png` in the existing AppIcon catalog as a 1024 × 1024 RGB PNG without alpha. The source contains only opaque pixels; the importer verified every decoded pixel before and after export. The supplied source hash remains unchanged.
- Preserved the prior draft as `intervls-icon-draft.png`. The website favicon and Apple touch icon remain separately managed.
- All 12 focused release-artifact tests passed, including catalog binding, dimensions, alpha checks, and draft preservation. The installed PNG was inspected visually; no iOS build or simulator run was performed. Device/Home-screen visual review remains with the developer.
