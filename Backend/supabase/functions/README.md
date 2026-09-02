# Supabase account functions

Deploy `claim-apple-entitlement`, `app-store-notifications`, `delete-account`,
`create-stripe-checkout`, and `stripe-webhook` after
applying `schema.sql`. Deploy with the included
`Backend/supabase/config.toml`: the Apple notification endpoint verifies its
own webhook secret, while `delete-account` and `create-stripe-checkout` verify
their callers in code so browser CORS preflight
requests can reach the handler. The remaining account function requires the
caller's session through Supabase's platform JWT check.

Set these function secrets outside source control:

- `SUPABASE_SERVICE_ROLE_KEY`
- `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, and `APPLE_BUNDLE_ID`
- `APPLE_NOTIFICATION_WEBHOOK_SECRET`
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_MONTHLY_PRICE_ID`,
  `STRIPE_ANNUAL_PRICE_ID`, and `WEB_ORIGIN`

Configure the App Store Server Notifications V2 URL to
`/functions/v1/app-store-notifications?token=<APPLE_NOTIFICATION_WEBHOOK_SECRET>`.
The function re-checks the referenced transaction against Apple's Server API
before changing an entitlement. Configure Google and Apple providers
and the `backword://login-callback`, production web callback, and localhost
redirect URLs in Supabase Auth. Apple web OAuth also requires its Services ID
and regularly rotated client secret.

`apple_subscription_events` is an append-only, service-role-only audit trail.
It stores a decoded event summary, never the signed JWS payload. Failure to
write an audit event is logged but never prevents the entitlement update.

Configure Stripe to deliver subscription and invoice events to
`/functions/v1/stripe-webhook`. The webhook verifies Stripe's raw-body
signature and only trusts Stripe subscription metadata written by
`create-stripe-checkout`; browser callers can never grant Pro directly.

Web subscriptions use Stripe Managed Payments. Create tax-inclusive, eligible
digital-product prices in Stripe, and keep the `STRIPE_SECRET_KEY` and price
IDs in Supabase Edge Function secrets. Checkout uses Stripe's Managed Payments
preview API version and Stripe Link manages customer billing and subscriptions;
do not configure or deploy Stripe's ordinary Billing Customer Portal.
