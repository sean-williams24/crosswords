# Supabase account functions

Deploy `claim-apple-entitlement`, `app-store-notifications`, and
`delete-account` after applying `schema.sql`. Deploy with the included
`Backend/supabase/config.toml`: the Apple notification endpoint verifies its
own webhook secret, while `delete-account` verifies its caller in code so it
can allow unauthenticated browser CORS preflight requests. The other account
functions require the caller's session through Supabase's platform JWT check.

Set these function secrets outside source control:

- `SUPABASE_SERVICE_ROLE_KEY`
- `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, and `APPLE_BUNDLE_ID`
- `APPLE_NOTIFICATION_WEBHOOK_SECRET`

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
