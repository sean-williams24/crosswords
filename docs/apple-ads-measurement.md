# Apple Ads campaign measurement

## What the app supplies

The app links `AdServices.framework` and uses Firebase Analytics' built-in Apple
Ads attribution. Firebase retrieves attribution and records `firebase_campaign`;
the app does not exchange or log raw attribution tokens itself. This is the
[Google-supported integration](https://support.google.com/analytics/answer/10311900).

`AppleAdsAttributionService` configures default `platform`/`environment` event
parameters and the user property `app_environment` immediately after Firebase
initialisation. It does not force analytics collection on or modify consent.
Default parameters also apply to automatic SDK events. They have lower
precedence than parameters supplied by a particular event.

| Question | Measurement |
| --- | --- |
| How much did an ad or keyword cost? | Apple Ads spend, taps, average CPT and CPA |
| How many downloads did Apple attribute? | Apple Ads new downloads; keep redownloads separate |
| How many users opened the app? | Firebase automatic `first_open` and User acquisition |
| Did they play? | Users with `game_started` |
| Did they finish a puzzle? | Users with `game_completed`; use `outcome` to separate solved/won from failed/gave_up |
| Did they return? | GA4 retention/cohort reports for acquired users |
| Did they buy Pro? | Users with `pro_entitlement_activated`, emitted only for a direct verified purchase |

No campaign changes are needed in the game ViewModels. Attribution applies to
the existing Backword, Anagram and crossword milestones. Midword is outside
this change.

## Configure Firebase / GA4 before launch

1. Open the GA4 property linked to the app's Firebase project. Confirm its iOS
   data stream matches `com.backword.app`.
2. Under **Admin → Custom definitions**, register `app_environment` as a
   **user-scoped** custom dimension using that user property. Register
   `environment`, `game` and `outcome` as **event-scoped** custom dimensions
   using the matching event parameters if they are not already registered.
   Do this before the campaign; custom definitions are not retroactive.
3. Mark `pro_entitlement_activated` as a key event. Use its user count for
   purchasers. For completed puzzles, use `game_completed` user counts filtered
   to `outcome=won` or `outcome=solved`; the event also includes failures and
   giving up, so its unfiltered count is not successful completions.
4. Use **User acquisition** or an Exploration with **First user source / medium**
   and first-user campaign dimensions. Google's documented Apple Ads source /
   medium is `Apple / search`; confirm the received values. Avoid using session
   source as the original acquisition source for returning users.
5. Filter reports to the **iOS app stream** and
   **app_environment = appstore**. Compare unique users, not total events, when
   calculating the share of acquired players who finish a puzzle or buy Pro.
6. Google's documented term is the Apple Ads **keyword ID**, not the keyword
   text. Keep an Apple Ads keyword-report export to map IDs to text. Do not
   expect every install to have keyword-level detail or a campaign name. Confirm
   which campaign dimensions the first attributed production users populate
   before relying on a keyword-level report.

These console settings are manual; the repository cannot create or verify them.

## Verify and release

1. Run from Xcode with the existing `-FIRDebugEnabled` launch argument and check
   Firebase **DebugView**. Play/complete a puzzle and confirm the milestone,
   `platform=ios`, `environment=debug`, and `app_environment=debug`. Verify Pro
   activation using a direct sandbox purchase if testing purchases; a restore
   must not emit a new activation.
2. Check a TestFlight build labels users `testflight` before using the production
   cohort filter. Detection currently relies on Apple's sandbox receipt. If a
   build has no receipt, verify the observed label rather than assuming it.
3. Ship this version to the App Store before enabling the campaign. Xcode and
   TestFlight installs are not an end-to-end Apple Ads attribution test. Keep
   Firebase debug launch arguments out of release verification.
4. After genuine Apple Ads downloads open the released app, allow normal report
   processing and confirm Apple-attributed users appear in User acquisition.
   Check gameplay/Pro events for that cohort. If attribution is missing, first
   confirm the installed version, data stream and active campaign; missing
   attribution alone does not establish an organic source.
5. Export Apple Ads keyword spend and download results when reviewing the test.
   Use its CPA for cost per attributed download. Cost per engaged user or buyer
   requires combining spend with the matching Firebase acquired-user cohort;
   Firebase does not import Apple Ads spend automatically in this integration.

Firebase counts an install at the first app open; Apple Ads reports App Store
downloads. Their attribution windows and reporting times can also differ, so
do not expect identical totals. Reinstalls may create another `first_open`;
it is not a count of unique people. Review time zone and date range when
comparing reports. Ordinary reports can take 24–48 hours to process new data.

References: [Google app attribution](https://support.google.com/analytics/answer/10311900),
[Firebase default event parameters](https://firebase.google.com/docs/analytics/ios/events),
[Apple attribution measurement differences](https://ads.apple.com/app-store/help/attribution/0027-mobile-measurement-providers).
