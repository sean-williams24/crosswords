-- App Store transactions have an original transaction ID; Stripe subscriptions
-- do not. Retain Apple uniqueness while allowing Stripe entitlement rows.
BEGIN;

ALTER TABLE user_entitlements
    ALTER COLUMN original_transaction_id DROP NOT NULL;

COMMIT;
