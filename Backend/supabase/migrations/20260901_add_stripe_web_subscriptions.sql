-- Preserve all existing App Store records while allowing Stripe to grant the
-- same account-level Pro entitlement. Provider IDs, rather than client input,
-- are the immutable source references for every entitlement.
ALTER TABLE user_entitlements ADD COLUMN IF NOT EXISTS id UUID DEFAULT uuid_generate_v4();
UPDATE user_entitlements SET id = uuid_generate_v4() WHERE id IS NULL;
ALTER TABLE user_entitlements ALTER COLUMN id SET NOT NULL;
ALTER TABLE user_entitlements DROP CONSTRAINT IF EXISTS user_entitlements_pkey;
ALTER TABLE user_entitlements ADD PRIMARY KEY (id);

ALTER TABLE user_entitlements ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'apple';
ALTER TABLE user_entitlements ADD COLUMN IF NOT EXISTS provider_subscription_id TEXT;
UPDATE user_entitlements
SET provider_subscription_id = original_transaction_id
WHERE provider_subscription_id IS NULL;
ALTER TABLE user_entitlements ALTER COLUMN provider_subscription_id SET NOT NULL;
ALTER TABLE user_entitlements ADD COLUMN IF NOT EXISTS provider_customer_id TEXT;
ALTER TABLE user_entitlements ADD COLUMN IF NOT EXISTS cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE user_entitlements ADD COLUMN IF NOT EXISTS source_event_at TIMESTAMPTZ;
ALTER TABLE user_entitlements ADD CONSTRAINT user_entitlements_provider_check CHECK (provider IN ('apple', 'stripe'));
ALTER TABLE user_entitlements ADD CONSTRAINT user_entitlements_provider_subscription_key UNIQUE (provider, provider_subscription_id);
ALTER TABLE user_entitlements ADD CONSTRAINT user_entitlements_apple_original_transaction_key UNIQUE (original_transaction_id);
ALTER TABLE user_entitlements ALTER COLUMN environment DROP NOT NULL;
ALTER TABLE user_entitlements DROP CONSTRAINT IF EXISTS user_entitlements_environment_check;
ALTER TABLE user_entitlements ADD CONSTRAINT user_entitlements_environment_check CHECK (environment IS NULL OR environment IN ('Sandbox', 'Production'));

CREATE TABLE IF NOT EXISTS pro_trial_redemptions (
    user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    provider     TEXT NOT NULL CHECK (provider IN ('apple', 'stripe')),
    redeemed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE pro_trial_redemptions ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS stripe_webhook_events (
    event_id        TEXT PRIMARY KEY,
    event_type      TEXT NOT NULL,
    subscription_id TEXT,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE stripe_webhook_events ENABLE ROW LEVEL SECURITY;

DROP FUNCTION IF EXISTS current_user_pro_entitlement();
CREATE FUNCTION current_user_pro_entitlement()
RETURNS TABLE (is_pro BOOLEAN, expires_at TIMESTAMPTZ, provider TEXT, cancel_at_period_end BOOLEAN)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    WITH active_entitlements AS (
        SELECT *
        FROM user_entitlements
        WHERE user_id = auth.uid()
          AND status IN ('active', 'billing_retry')
          AND revocation_at IS NULL
          AND (expires_at IS NULL OR expires_at > NOW())
    )
    SELECT
        EXISTS (SELECT 1 FROM active_entitlements),
        (SELECT MAX(expires_at) FROM active_entitlements),
        (SELECT provider FROM active_entitlements ORDER BY expires_at DESC NULLS LAST, updated_at DESC LIMIT 1),
        COALESCE((SELECT cancel_at_period_end FROM active_entitlements ORDER BY expires_at DESC NULLS LAST, updated_at DESC LIMIT 1), FALSE);
$$;
