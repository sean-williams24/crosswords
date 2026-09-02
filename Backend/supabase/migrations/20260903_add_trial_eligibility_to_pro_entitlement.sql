-- The trial-redemption table is intentionally not client-readable. Expose only
-- the calling account's eligibility through the existing entitlement RPC.
BEGIN;

DROP FUNCTION IF EXISTS current_user_pro_entitlement();
CREATE FUNCTION current_user_pro_entitlement()
RETURNS TABLE (is_pro BOOLEAN, expires_at TIMESTAMPTZ, provider TEXT, cancel_at_period_end BOOLEAN, has_used_trial BOOLEAN)
LANGUAGE sql
STABLE
SECURITY DEFINER
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
        COALESCE((SELECT cancel_at_period_end FROM active_entitlements ORDER BY expires_at DESC NULLS LAST, updated_at DESC LIMIT 1), FALSE),
        EXISTS (SELECT 1 FROM pro_trial_redemptions WHERE user_id = auth.uid());
$$;

COMMIT;
