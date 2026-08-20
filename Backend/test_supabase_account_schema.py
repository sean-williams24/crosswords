from pathlib import Path
import unittest


SCHEMA = Path(__file__).parent / "supabase" / "schema.sql"
FUNCTIONS = Path(__file__).parent / "supabase" / "functions"
FUNCTION_CONFIG = Path(__file__).parent / "supabase" / "config.toml"
MIGRATION = Path(__file__).parent / "supabase" / "migrations" / "20260812_preserve_crossword_release_date_scores.sql"
ENTITLEMENT_AUDIT_MIGRATION = Path(__file__).parent / "supabase" / "migrations" / "20260813_add_apple_subscription_event_audit.sql"


class SupabaseAccountSchemaTests(unittest.TestCase):
    def test_account_tables_are_scoped_to_authenticated_users(self):
        schema = SCHEMA.read_text()

        self.assertIn("CREATE TABLE game_progress", schema)
        self.assertIn("PRIMARY KEY (user_id, game_type, content_key)", schema)
        self.assertIn("ALTER TABLE game_progress ENABLE ROW LEVEL SECURITY", schema)
        self.assertIn("auth.uid() = user_id", schema)

    def test_merge_function_and_account_entitlement_contract_exist(self):
        schema = SCHEMA.read_text()

        self.assertIn("CREATE OR REPLACE FUNCTION merge_game_progress", schema)
        self.assertIn("p_status = 'solved'", schema)
        self.assertIn("CREATE TABLE user_entitlements", schema)
        self.assertIn("CREATE OR REPLACE FUNCTION current_user_pro_entitlement", schema)

    def test_merge_upsert_keeps_whole_record_and_uses_declared_ranking(self):
        schema = SCHEMA.read_text()

        self.assertIn("RETURNING * INTO current_row", schema)
        self.assertIn("p_status = 'solved'", schema)
        self.assertIn("p_release_score > current_row.release_score", schema)
        self.assertIn("p_progress_rank > current_row.progress_rank", schema)
        self.assertIn("p_client_updated_at > current_row.client_updated_at", schema)

    def test_crossword_conflicts_preserve_the_release_day_score_snapshot(self):
        schema = SCHEMA.read_text()
        migration = MIGRATION.read_text()

        self.assertIn("resolved_release_score", schema)
        self.assertIn("GREATEST(current_row.release_score, p_release_score)", schema)
        self.assertIn("'{releaseDateScore}'", schema)
        self.assertIn("CREATE OR REPLACE FUNCTION merge_game_progress", migration)
        self.assertIn("GREATEST(current_row.release_score, p_release_score)", migration)

    def test_deletion_cascades_progress_and_releases_subscription_claim(self):
        schema = SCHEMA.read_text()
        deletion_function = (FUNCTIONS / "delete-account" / "index.ts").read_text()

        self.assertIn("REFERENCES auth.users(id) ON DELETE CASCADE", schema)
        self.assertIn("REFERENCES auth.users(id) ON DELETE SET NULL", schema)
        self.assertIn('.update({ user_id: null })', deletion_function)
        self.assertIn("deleteUser", deletion_function)

    def test_delete_account_function_accepts_browser_cors_preflight(self):
        deletion_function = (FUNCTIONS / "delete-account" / "index.ts").read_text()
        function_config = FUNCTION_CONFIG.read_text()

        self.assertIn('request.method === "OPTIONS"', deletion_function)
        self.assertIn('"Access-Control-Allow-Origin": "*"', deletion_function)
        self.assertIn('"Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"', deletion_function)
        self.assertIn('"Access-Control-Allow-Methods": "POST, OPTIONS"', deletion_function)
        self.assertIn('new Response("ok", { headers: corsHeaders })', deletion_function)
        self.assertIn("[functions.delete-account]", function_config)
        delete_account_config = function_config.split("[functions.delete-account]", maxsplit=1)[1]
        self.assertIn("verify_jwt = false", delete_account_config)

    def test_entitlement_claim_rejects_duplicate_and_malformed_transactions(self):
        claim_function = (FUNCTIONS / "claim-apple-entitlement" / "index.ts").read_text()

        self.assertIn("Missing transaction identifiers", claim_function)
        self.assertIn("Transaction identifiers do not match", claim_function)
        self.assertIn("already linked to another Backword account", claim_function)
        self.assertIn("appAccountToken", claim_function)
        self.assertIn('console.error("Apple entitlement claim failed"', claim_function)
        self.assertIn('console.error("Apple entitlement claim unauthenticated"', claim_function)
        self.assertIn('new URL("/auth/v1/user", supabaseURL)', claim_function)
        self.assertIn("Authorization: authorization", claim_function)

    def test_notifications_are_protected_and_reconcile_with_apple(self):
        notification_function = (FUNCTIONS / "app-store-notifications" / "index.ts").read_text()

        self.assertIn("APPLE_NOTIFICATION_WEBHOOK_SECRET", notification_function)
        self.assertIn("getAppleTransaction(transactionID)", notification_function)
        self.assertIn("entitlementStatus(transaction)", notification_function)
        self.assertIn("notificationUUID", notification_function)
        self.assertIn("apple_subscription_events", notification_function)
        self.assertIn("auto_renew_status", notification_function)
        self.assertIn('console.error("Apple subscription audit event failed"', notification_function)
        self.assertIn('console.error("App Store notification processing failed"', notification_function)

    def test_entitlement_audit_migration_is_additive_and_private(self):
        schema = SCHEMA.read_text()
        migration = ENTITLEMENT_AUDIT_MIGRATION.read_text()

        self.assertIn("ADD COLUMN IF NOT EXISTS auto_renew_status BOOLEAN", migration)
        self.assertIn("CREATE TABLE IF NOT EXISTS apple_subscription_events", migration)
        self.assertIn("notification_uuid       TEXT PRIMARY KEY", migration)
        self.assertIn("ALTER TABLE apple_subscription_events ENABLE ROW LEVEL SECURITY", migration)
        self.assertNotIn("DROP ", migration)
        self.assertIn("CREATE TABLE apple_subscription_events", schema)
        self.assertIn("auto_renew_status       BOOLEAN", schema)
