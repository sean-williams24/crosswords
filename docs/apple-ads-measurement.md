# Apple Ads campaign measurement

## What the app supplies

The app links `AdServices.framework` and uses Firebase Analytics' built-in Apple
Ads attribution. Firebase retrieves attribution and records `firebase_campaign`;
the app does not exchange or log raw attribution tokens itself. This is the
[Google-supported integration](https://support.google.com/analytics/answer/10311900).

`AppleAdsAttributionService` configures default `platform`/`environment` event
parameters and the user property `app_environment` immediately after Firebase
initialisation and the app's advertising restrictions. It does not force
analytics collection on or modify consent.
Default parameters also apply to automatic SDK events. They have lower
precedence than parameters supplied by a particular event.

The iOS app denies Firebase ad storage, ad user data and ad personalization in
`Info.plist` and reapplies those denials at startup before reporting context and
app-owned events. Gameplay analytics collection and analytics-storage consent
are unchanged. Requesting a rewarded hint, accepting UMP consent or approving
ATT does not enable advertising use of Firebase gameplay data. AdMob rewarded
ads continue through their separate consent flow.

These restrictions limit advertising identifiers, remarketing and some Google
Ads conversion exports. Apple supports an AdServices standard attribution
response without ATT permission, but that does not establish that Firebase's
integration works identically with these advertising-consent restrictions.
The release checks below are required to verify that integration.

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

Review the iOS stream's advertising integrations, audience exports and available
personalization controls, plus property-level data sharing. Confirm gameplay
data is not being used for remarketing or shared for cross-company advertising
tracking. If iOS and web share a GA4 property, review the scope before changing
property-wide controls. Do not assume an ATT approval authorizes every form of
advertising data use.

## Check attribution after the advertising restrictions

The goal is to check both whether attribution still works and whether its
coverage changes. One attributed install establishes the first, not the second.

1. **Save a baseline before releasing.** For a representative period, record
   Apple Ads new downloads, Firebase first opens, and Firebase new users acquired
   with **First user source / medium = Apple / search**. Record campaigns,
   countries, date range, time zones and the existing app version. If you have
   no previous campaign data, you can check functionality but cannot establish
   unchanged coverage yet.
2. **Check the app locally in Xcode.** Add
   `-FIRAnalyticsVerboseLoggingEnabled` alongside the existing Firebase debug
   argument. Confirm `ad_storage`, `ad_user_data` and `ad_personalization` are
   denied. Confirm gameplay events still arrive in DebugView and the
   `app_environment` property is restored. Repeat on an upgraded installation,
   and after a rewarded hint with ATT allowed and denied: the Firebase
   advertising states should stay denied. This checks the configuration, not
   Apple Ads install attribution.
3. **Release the app version and observe genuine campaign installs.** A user
   must download the released version through an Apple Ads campaign and open
   it. Xcode and TestFlight installs cannot substitute for this check. Include
   new players who never request a hint, so the test does not depend on ATT
   being shown or approved. Do not collect or manually log attribution tokens.
4. **Allow report processing, typically 24–48 hours.** In GA4's User acquisition
   report or an Exploration, select the iOS stream and the new **App version**,
   plus **app_environment = appstore**. Look for **Apple / search** using the
   *first-user* acquisition dimension and **New users** (or `first_open` events),
   rather than all users: returning players who update could retain attribution
   from an older release. Google documents keyword IDs in the
   campaign term where supplied; do not require keyword text or a campaign
   name to consider attribution successful. Then check that these acquired
   users also have gameplay events. Keep Firebase debug mode out of release
   verification.
5. **Compare coverage over a comparable period.** With campaign targeting and
   spend reasonably stable, compare Apple-attributed Firebase first opens/new users
   against Apple Ads new downloads before and after release. Filter Firebase
   to the new app version to avoid mixing releases. Downloads and first opens
   differ, reports have lag, and small counts fluctuate, so identical totals
   are not an acceptance criterion. A sustained large decline warrants
   investigation; a single install does not prove there is no impact.
6. **Investigate missing attribution without weakening consent.** If Apple Ads
   shows new downloads and the new version has ordinary first opens but no
   Apple-attributed users, check the installed version, iOS data stream,
   campaign/date filters, reporting delay and `AdServices.framework` linkage.
   If these are correct, investigate Firebase's consent-dependent attribution
   behavior. Missing attribution is not proof of organic acquisition, and it
   is not a reason to grant advertising permissions without consent.

Apple Ads' own spend and download reports remain the independent reference.
These checks establish whether the app still receives attribution; they do not
promise that detailed attribution is unchanged for every user.

Sources: [Google consent configuration](https://developers.google.com/tag-platform/security/guides/app-consent?platform=ios),
[consent effects on reporting](https://support.google.com/analytics/answer/13802165),
[Google's Apple Ads integration](https://support.google.com/analytics/answer/10311900),
[report processing times](https://support.google.com/analytics/answer/11198161),
[Apple's standard and detailed attribution responses](https://developer.apple.com/documentation/adservices/aaattribution/attributiontoken()).

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
