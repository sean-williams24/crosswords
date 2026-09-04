-- Persist Stripe customer ownership before Checkout redirects. Webhook events
-- remain the entitlement source of truth, but deletion needs this durable link
-- to cancel subscriptions created moments before webhook delivery.
CREATE TABLE IF NOT EXISTS stripe_customer_accounts (
    user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    customer_id TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO stripe_customer_accounts (user_id, customer_id)
SELECT user_id, provider_customer_id
FROM user_entitlements
WHERE provider = 'stripe'
  AND user_id IS NOT NULL
  AND provider_customer_id IS NOT NULL
ON CONFLICT DO NOTHING;

ALTER TABLE stripe_customer_accounts ENABLE ROW LEVEL SECURITY;
