-- Additive subscription diagnostics only. Existing entitlement and gameplay
-- data remain unchanged, and the application does not read this table to make
-- access decisions.
ALTER TABLE user_entitlements
    ADD COLUMN IF NOT EXISTS auto_renew_status BOOLEAN;

CREATE TABLE IF NOT EXISTS apple_subscription_events (
    notification_uuid       TEXT PRIMARY KEY,
    notification_type       TEXT NOT NULL,
    subtype                 TEXT,
    original_transaction_id TEXT,
    transaction_id          TEXT,
    environment             TEXT CHECK (environment IN ('Sandbox', 'Production')),
    event_at                TIMESTAMPTZ,
    account_id              UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    resulting_status        TEXT CHECK (resulting_status IN ('active', 'expired', 'revoked', 'billing_retry')),
    expires_at              TIMESTAMPTZ,
    revocation_at           TIMESTAMPTZ,
    auto_renew_status       BOOLEAN,
    received_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apple_subscription_events_original_transaction
    ON apple_subscription_events (original_transaction_id, event_at DESC);

CREATE INDEX IF NOT EXISTS idx_apple_subscription_events_account
    ON apple_subscription_events (account_id, event_at DESC);

ALTER TABLE apple_subscription_events ENABLE ROW LEVEL SECURITY;
