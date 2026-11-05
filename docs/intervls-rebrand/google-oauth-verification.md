# Google OAuth branding remediation

Google reported three findings on the Intervls branding submission: homepage
ownership, insufficient privacy disclosures, and a logo that does not uniquely
identify the brand. These steps address each finding; approval remains Google's
decision. Local repository changes do not update the live website or console.

## 1. Verify ownership

1. Sign in to [Search Console](https://search.google.com/search-console) with a
   Google account that is also an **Owner or Editor of the existing Google Cloud
   project** used by Intervls sign-in.
2. Add a **Domain** property for `intervls.com` (without a scheme or path).
3. Add the exact DNS TXT verification record supplied by Google at the domain's
   DNS provider. Preserve existing mail and other verification records.
4. Click Verify and keep the TXT record in place. Registration with a domain
   registrar, Vercel domain assignment, and working HTTPS do not replace Search
   Console verification.
5. In Google Auth Platform → Branding, ensure Authorized domains includes
   `intervls.com`, the app name is `Intervls`, and the homepage, privacy and terms
   URLs are `https://intervls.com`, `https://intervls.com/privacy`, and
   `https://intervls.com/terms`. Check other configured domains as well.
6. Wait **24 hours after successful ownership verification** before retrying,
   as instructed by the rejection dialog.

## 2. Publish and review the privacy disclosures

The policy source is `web/src/content/legal.ts`. Its Google Sign-In Data section
describes the basic identity/profile data, Supabase authentication and storage,
local sessions, gameplay/Pro purposes, Stripe billing email sharing, advertising
and analytics restrictions, retention, account deletion, and Google access
removal. Check these statements against the production configuration before
publishing. The policy has its own last-updated date.

After deploying the reviewed changes, open the exact homepage and privacy URLs
in a signed-out/private browser. Both must be publicly readable without a Vercel
login, application login, or consent gate blocking the content. Confirm the
homepage's privacy link matches the console URL exactly. The current app renders
legal content with React; if Google still reports insufficient content after the
published policy is readable, investigate what its reviewer/crawler receives
and consider prerendering the public legal routes. The cause of the original
content finding has not been established from the screenshot alone.

## 3. Check the submitted logo

Compare the image actually uploaded in Google Auth Platform → Branding with the
current Intervls website branding. Use an owned Intervls asset with readable
lettering; do not upload the Google sign-in button/icon, a game-specific Backword
logo, or an earlier unrelated draft. The current square app artwork is
`docs/intervls-brand/intervls-icon.png` (website copy:
`web/public/brand/intervls-icon.png`). It contains the Intervls wordmark, but this
does not establish which image Google reviewed or guarantee acceptance.

If the current matching Intervls artwork was already submitted and you believe
the finding is wrong, request an additional review and provide the matching
homepage/logo evidence through the available review/support process. Do not
redesign the brand solely on the assumption that Google reviewed an old image.

## 4. Retry after all three findings are addressed

Choose **I have fixed the issues** only after ownership is verified, the policy
is published and readable, the logo is checked/updated, and the required 24-hour
ownership wait has elapsed. Preserve the existing OAuth clients, client IDs,
native callbacks, Supabase project, and working Google Identity token flow.

References:

- [Google verification requirements](https://support.google.com/cloud/answer/13464321?hl=en)
- [Search Console ownership verification](https://support.google.com/webmasters/answer/9008080?hl=en)
- [App identity and branding findings](https://support.google.com/cloud/answer/13804963?hl=en)
