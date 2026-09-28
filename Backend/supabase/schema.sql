-- ============================================================
-- Crosswords App — Supabase Database Schema
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Puzzles table
-- ============================================================

CREATE TABLE puzzles (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    puzzle_number INT NOT NULL UNIQUE,
    date          DATE NOT NULL UNIQUE,
    grid_data     JSONB NOT NULL,
    clues         JSONB NOT NULL,
    is_free       BOOLEAN NOT NULL DEFAULT TRUE,
    published_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast date lookups
CREATE INDEX idx_puzzles_date ON puzzles (date);

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE puzzles ENABLE ROW LEVEL SECURITY;

-- Allow anonymous (anon) users to read puzzles whose date is today or earlier.
-- This prevents leaking future puzzles.
CREATE POLICY "Public can read released puzzles"
    ON puzzles
    FOR SELECT
    USING (date <= CURRENT_DATE);

-- Only authenticated service-role users can insert/update/delete.
-- (The anon key used in the app cannot mutate data.)

-- ============================================================
-- Words of the Day table
-- ============================================================

CREATE TABLE words_of_the_day (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date          DATE NOT NULL UNIQUE,
    word_data     JSONB NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast date lookups
CREATE INDEX idx_wotd_date ON words_of_the_day (date);

ALTER TABLE words_of_the_day ENABLE ROW LEVEL SECURITY;

-- Allow anonymous users to read words whose date is today or earlier.
CREATE POLICY "Public can read released words"
    ON words_of_the_day
    FOR SELECT
    USING (date <= CURRENT_DATE);

-- ============================================================
-- Example: Insert a puzzle
-- ============================================================
-- INSERT INTO puzzles (puzzle_number, date, grid_data, clues)
-- VALUES (
--   1,
--   '2026-03-07',
--   '{
--     "size": 9,
--     "cells": [
--       [{"letter":"S","clueNumber":1,"acrossClueId":0,"downClueId":1}, ...]
--     ]
--   }',
--   '[
--     {"id":0,"direction":"across","number":1,"text":"Celestial body","hint":"Hollywood celebrity","answer":"STAR","startRow":0,"startCol":0,"length":4},
--     ...
--   ]'
-- );

-- ============================================================
-- Weekly Puzzles table (pro-only, 13×13)
-- ============================================================

CREATE TABLE weekly_puzzles (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    puzzle_number INT NOT NULL UNIQUE,
    date          DATE NOT NULL UNIQUE,
    grid_data     JSONB NOT NULL,
    clues         JSONB NOT NULL,
    is_free       BOOLEAN NOT NULL DEFAULT FALSE,
    published_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_weekly_puzzles_date ON weekly_puzzles (date);

ALTER TABLE weekly_puzzles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read released weekly puzzles"
    ON weekly_puzzles
    FOR SELECT
    USING (date <= CURRENT_DATE);

-- ============================================================
-- Backword table (daily 6-letter word game)
-- ============================================================

CREATE TABLE backword_words (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    puzzle_number INT NOT NULL UNIQUE,
    date          DATE NOT NULL UNIQUE,
    word_data     JSONB NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_backword_date ON backword_words (date);

ALTER TABLE backword_words ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read released backword words"
    ON backword_words
    FOR SELECT
    USING (date <= CURRENT_DATE);

-- Anagram issue numbers and release dates are immutable once inserted. Future
-- answers remain hidden behind RLS, even though service-role jobs prefill rows.
CREATE TABLE anagram_puzzles (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date           DATE NOT NULL UNIQUE,
    puzzle_number  INT NOT NULL UNIQUE CHECK (puzzle_number > 0),
    schema_version INT NOT NULL DEFAULT 1 CHECK (schema_version = 1),
    puzzle_data    JSONB NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (jsonb_typeof(puzzle_data) = 'object'),
    CHECK (puzzle_data ?& ARRAY['answer', 'acceptedAnswers', 'initialScramble'])
);

CREATE INDEX idx_anagram_date ON anagram_puzzles (date);
ALTER TABLE anagram_puzzles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can read released anagrams"
    ON anagram_puzzles FOR SELECT USING (date <= CURRENT_DATE + 1);

CREATE OR REPLACE FUNCTION reject_anagram_mutation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Published Anagram rows are immutable';
END;
$$;

CREATE TRIGGER anagram_immutable
    BEFORE UPDATE OR DELETE ON anagram_puzzles
    FOR EACH ROW EXECUTE FUNCTION reject_anagram_mutation();

-- ============================================================
-- Accounts, cloud progress, and account-linked subscriptions
-- ============================================================

-- Auth identities live in auth.users. Keep the public profile deliberately
-- small: display information belongs in auth metadata and must never drive
-- authorization decisions.
CREATE TABLE profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.create_profile_for_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id) VALUES (NEW.id)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.create_profile_for_new_user();

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own profile"
    ON profiles FOR SELECT USING (auth.uid() = id);

-- `payload` is a versioned cross-platform record. The explicit ranking
-- columns make conflict resolution deterministic without attempting to merge
-- incompatible crossword grids or Backword guesses server-side.
CREATE TABLE game_progress (
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    game_type           TEXT NOT NULL CHECK (game_type IN ('backword', 'daily_crossword', 'weekly_crossword', 'anagram')),
    content_key         TEXT NOT NULL,
    release_date        DATE NOT NULL,
    schema_version      INTEGER NOT NULL DEFAULT 1 CHECK (schema_version > 0),
    status              TEXT NOT NULL CHECK (status IN ('in_progress', 'solved', 'failed', 'gave_up')),
    progress_rank       INTEGER NOT NULL DEFAULT 0 CHECK (progress_rank >= 0),
    release_score       INTEGER NOT NULL DEFAULT 0 CHECK (release_score BETWEEN 0 AND 5),
    client_updated_at   TIMESTAMPTZ NOT NULL,
    payload             JSONB NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, game_type, content_key)
);

CREATE INDEX idx_game_progress_user_release_date
    ON game_progress (user_id, release_date DESC);

ALTER TABLE game_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own game progress"
    ON game_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own game progress"
    ON game_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own game progress"
    ON game_progress FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own game progress"
    ON game_progress FOR DELETE USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION merge_game_progress(
    p_game_type TEXT,
    p_content_key TEXT,
    p_release_date DATE,
    p_schema_version INTEGER,
    p_status TEXT,
    p_progress_rank INTEGER,
    p_release_score INTEGER,
    p_client_updated_at TIMESTAMPTZ,
    p_payload JSONB
)
RETURNS game_progress
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    current_row game_progress;
    incoming_terminal BOOLEAN := p_status IN ('solved', 'failed', 'gave_up');
    current_terminal BOOLEAN;
    is_crossword BOOLEAN := p_game_type IN ('daily_crossword', 'weekly_crossword');
    is_anagram BOOLEAN := p_game_type = 'anagram';
    resolved_release_score INTEGER;
    use_incoming BOOLEAN := FALSE;
    merged_anagram_payload JSONB;
    selected_anagram_payload JSONB;
    selected_release_score INTEGER;
    merged_start_at TIMESTAMPTZ;
    terminal_completed_at TIMESTAMPTZ;
    raw_elapsed_seconds BIGINT;
    scoring_seconds NUMERIC;
    same_terminal_and_start BOOLEAN;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;
    IF is_anagram AND (
        p_schema_version <> 1 OR p_content_key <> p_release_date::TEXT OR
        p_payload->>'date' IS DISTINCT FROM p_content_key OR
        p_payload->>'schemaVersion' IS DISTINCT FROM '1' OR
        p_payload->>'startedAt' IS NULL OR
        p_status NOT IN ('in_progress', 'solved', 'gave_up') OR
        (p_status IN ('solved', 'gave_up') AND (
            p_payload->>'completedAt' IS NULL OR
            p_payload->>'outcome' IS DISTINCT FROM p_status)) OR
        (p_status = 'in_progress' AND p_payload->>'outcome' IS NOT NULL)
    ) THEN
        RAISE EXCEPTION 'Invalid Anagram progress envelope';
    END IF;

    SELECT * INTO current_row
    FROM game_progress
    WHERE user_id = auth.uid()
      AND game_type = p_game_type
      AND content_key = p_content_key
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO game_progress (
            user_id, game_type, content_key, release_date, schema_version,
            status, progress_rank, release_score, client_updated_at, payload
        ) VALUES (
            auth.uid(), p_game_type, p_content_key, p_release_date, p_schema_version,
            p_status, p_progress_rank, p_release_score, p_client_updated_at, p_payload
        ) RETURNING * INTO current_row;
        RETURN current_row;
    END IF;

    current_terminal := current_row.status IN ('solved', 'failed', 'gave_up');
    -- Crossword grid conflicts remain whole-record decisions, but the
    -- release-window score is an independent historical fact. Preserve the
    -- highest captured value so a more advanced Archive grid on another
    -- device cannot erase points earned on the original release day.
    resolved_release_score := CASE
        WHEN is_crossword OR is_anagram THEN GREATEST(current_row.release_score, p_release_score)
        ELSE p_release_score
    END;
    -- Solved records always win. Two solved records keep the higher valid
    -- release score. For all remaining ties, terminal state, rank, then the
    -- most recent client update win.
    use_incoming :=
        (p_status = 'solved' AND current_row.status <> 'solved') OR
        (p_status = 'solved' AND current_row.status = 'solved' AND p_release_score > current_row.release_score) OR
        (p_status <> 'solved' AND current_row.status <> 'solved' AND incoming_terminal AND NOT current_terminal) OR
        (p_status <> 'solved' AND current_row.status <> 'solved' AND incoming_terminal = current_terminal AND p_progress_rank > current_row.progress_rank) OR
        (p_status <> 'solved' AND current_row.status <> 'solved' AND incoming_terminal = current_terminal AND p_progress_rank = current_row.progress_rank AND p_client_updated_at > current_row.client_updated_at) OR
        (p_status = 'solved' AND current_row.status = 'solved' AND p_release_score = current_row.release_score AND p_client_updated_at > current_row.client_updated_at);

    IF is_anagram THEN
        IF incoming_terminal <> current_terminal THEN
            use_incoming := incoming_terminal;
        ELSIF incoming_terminal THEN
            -- A terminal attempt cannot be replayed. Keep the first completed
            -- outcome, regardless of whether it solved or gave up.
            use_incoming := COALESCE((p_payload->>'completedAt')::TIMESTAMPTZ, p_client_updated_at)
                < COALESCE((current_row.payload->>'completedAt')::TIMESTAMPTZ, current_row.client_updated_at);
        ELSIF (p_payload->>'hintUsed')::BOOLEAN IS DISTINCT FROM
              (current_row.payload->>'hintUsed')::BOOLEAN THEN
            -- The hinted arrangement owns its locked tile and Undo history.
            use_incoming := COALESCE((p_payload->>'hintUsed')::BOOLEAN, FALSE);
        ELSE
            use_incoming := p_progress_rank > current_row.progress_rank OR
                (p_progress_rank = current_row.progress_rank AND
                 p_client_updated_at > current_row.client_updated_at);
        END IF;

        selected_anagram_payload := CASE WHEN use_incoming THEN p_payload ELSE current_row.payload END;
        selected_release_score := CASE WHEN use_incoming THEN p_release_score ELSE current_row.release_score END;
        merged_start_at := LEAST(
            (p_payload->>'startedAt')::TIMESTAMPTZ,
            (current_row.payload->>'startedAt')::TIMESTAMPTZ);
        same_terminal_and_start :=
            (p_payload->>'startedAt')::TIMESTAMPTZ =
                (current_row.payload->>'startedAt')::TIMESTAMPTZ AND
            (p_payload->>'completedAt')::TIMESTAMPTZ IS NOT DISTINCT FROM
                (current_row.payload->>'completedAt')::TIMESTAMPTZ AND
            p_status = current_row.status;
        merged_anagram_payload :=
            selected_anagram_payload ||
            jsonb_build_object(
                'startedAt', CASE
                    WHEN (p_payload->>'startedAt')::TIMESTAMPTZ <
                         (current_row.payload->>'startedAt')::TIMESTAMPTZ
                    THEN p_payload->>'startedAt'
                    ELSE current_row.payload->>'startedAt' END,
                'hintUsed', COALESCE((p_payload->>'hintUsed')::BOOLEAN, FALSE) OR
                            COALESCE((current_row.payload->>'hintUsed')::BOOLEAN, FALSE),
                'hintSource', CASE
                    WHEN use_incoming AND (p_payload->>'hintUsed')::BOOLEAN = TRUE
                    THEN p_payload->>'hintSource'
                    WHEN NOT use_incoming AND (current_row.payload->>'hintUsed')::BOOLEAN = TRUE
                    THEN current_row.payload->>'hintSource'
                    WHEN (p_payload->>'hintUsed')::BOOLEAN = TRUE
                    THEN p_payload->>'hintSource'
                    ELSE current_row.payload->>'hintSource' END,
                'penaltySeconds', GREATEST(
                    COALESCE((p_payload->>'penaltySeconds')::INTEGER, 0),
                    COALESCE((current_row.payload->>'penaltySeconds')::INTEGER, 0)),
                'releaseDateScore', selected_release_score
            );

        IF use_incoming THEN
            incoming_terminal := p_status IN ('solved', 'gave_up');
        ELSE
            incoming_terminal := current_row.status IN ('solved', 'gave_up');
        END IF;
        IF incoming_terminal THEN
            terminal_completed_at := (selected_anagram_payload->>'completedAt')::TIMESTAMPTZ;
            raw_elapsed_seconds := FLOOR(GREATEST(
                EXTRACT(EPOCH FROM (terminal_completed_at - merged_start_at)), 0))::BIGINT;
            merged_anagram_payload := merged_anagram_payload ||
                jsonb_build_object('elapsedSecondsAtCompletion', raw_elapsed_seconds);

            -- A positive snapshot proves the selected solve earned release-day
            -- points. A score from the other branch is usable only when both
            -- branches represent the exact same terminal attempt and start.
            IF selected_anagram_payload->>'outcome' = 'solved' AND
                (selected_release_score > 0 OR
                 (same_terminal_and_start AND resolved_release_score > 0)) THEN
                scoring_seconds := raw_elapsed_seconds +
                    (merged_anagram_payload->>'penaltySeconds')::INTEGER;
                resolved_release_score := CASE
                    WHEN scoring_seconds < 30 THEN 5
                    WHEN scoring_seconds < 60 THEN 4
                    WHEN scoring_seconds < 120 THEN 3
                    WHEN scoring_seconds < 180 THEN 2
                    ELSE 1 END;
            ELSE
                resolved_release_score := 0;
            END IF;
        ELSE
            -- Preserve a historical snapshot only while no terminal attempt
            -- has been selected. Normal in-progress Anagram rows score zero.
            resolved_release_score := GREATEST(current_row.release_score, p_release_score);
        END IF;
        merged_anagram_payload := merged_anagram_payload ||
            jsonb_build_object('releaseDateScore', resolved_release_score);
    END IF;

    IF use_incoming THEN
        UPDATE game_progress
        SET release_date = p_release_date,
            schema_version = p_schema_version,
            status = p_status,
            progress_rank = p_progress_rank,
            release_score = resolved_release_score,
            client_updated_at = p_client_updated_at,
            payload = CASE
                WHEN is_anagram THEN merged_anagram_payload
                WHEN is_crossword THEN jsonb_set(
                    p_payload,
                    '{releaseDateScore}',
                    to_jsonb(resolved_release_score),
                    TRUE
                )
                ELSE p_payload
            END,
            updated_at = NOW()
        WHERE user_id = auth.uid()
          AND game_type = p_game_type
          AND content_key = p_content_key
        RETURNING * INTO current_row;
    ELSIF is_anagram AND (
        merged_anagram_payload IS DISTINCT FROM current_row.payload OR
        resolved_release_score > current_row.release_score
    ) THEN
        UPDATE game_progress
        SET release_score = resolved_release_score,
            payload = merged_anagram_payload,
            updated_at = NOW()
        WHERE user_id = auth.uid()
          AND game_type = p_game_type
          AND content_key = p_content_key
        RETURNING * INTO current_row;
    ELSIF is_crossword AND p_release_score > current_row.release_score THEN
        -- The current grid won the conflict, so retain it. Only promote the
        -- immutable score snapshot stored alongside that grid.
        UPDATE game_progress
        SET release_score = resolved_release_score,
            payload = jsonb_set(
                current_row.payload,
                '{releaseDateScore}',
                to_jsonb(resolved_release_score),
                TRUE
            ),
            updated_at = NOW()
        WHERE user_id = auth.uid()
          AND game_type = p_game_type
          AND content_key = p_content_key
        RETURNING * INTO current_row;
    END IF;
    RETURN current_row;
END;
$$;

CREATE TABLE user_entitlements (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider                TEXT NOT NULL CHECK (provider IN ('apple', 'stripe')),
    provider_subscription_id TEXT NOT NULL,
    provider_customer_id    TEXT,
    original_transaction_id TEXT UNIQUE,
    user_id                 UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    product_id              TEXT NOT NULL,
    environment             TEXT CHECK (environment IN ('Sandbox', 'Production')),
    status                  TEXT NOT NULL CHECK (status IN ('active', 'expired', 'revoked', 'billing_retry')),
    expires_at              TIMESTAMPTZ,
    revocation_at           TIMESTAMPTZ,
    app_account_token       UUID,
    auto_renew_status       BOOLEAN,
    cancel_at_period_end    BOOLEAN NOT NULL DEFAULT FALSE,
    source_event_at          TIMESTAMPTZ,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, provider_subscription_id)
);

CREATE INDEX idx_user_entitlements_user_status
    ON user_entitlements (user_id, status, expires_at DESC);

ALTER TABLE user_entitlements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own entitlement status"
    ON user_entitlements FOR SELECT USING (auth.uid() = user_id);

-- Checkout stores this link before the customer is redirected to Stripe. It
-- lets account deletion cancel a new web subscription even before its webhook
-- has populated the entitlement snapshot.
CREATE TABLE stripe_customer_accounts (
    user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    customer_id TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE stripe_customer_accounts ENABLE ROW LEVEL SECURITY;

-- A web trial is blocked once this account has used a recorded Apple or
-- Stripe introductory period. Apple determines its own Apple ID eligibility,
-- so it remains the only best-effort direction of this shared policy.
CREATE TABLE pro_trial_redemptions (
    user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    provider     TEXT NOT NULL CHECK (provider IN ('apple', 'stripe')),
    redeemed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE pro_trial_redemptions ENABLE ROW LEVEL SECURITY;

-- Service-role-only idempotency record for Stripe webhook retries. No client
-- policy is intentionally added.
CREATE TABLE stripe_webhook_events (
    event_id        TEXT PRIMARY KEY,
    event_type      TEXT NOT NULL,
    subscription_id TEXT,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE stripe_webhook_events ENABLE ROW LEVEL SECURITY;

-- Append-only diagnostic history for App Store Server Notifications. Clients
-- have no policy for this table; only the notification Edge Function, using
-- the service role, writes it. It is not part of Pro access decisions.
CREATE TABLE apple_subscription_events (
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

CREATE INDEX idx_apple_subscription_events_original_transaction
    ON apple_subscription_events (original_transaction_id, event_at DESC);

CREATE INDEX idx_apple_subscription_events_account
    ON apple_subscription_events (account_id, event_at DESC);

ALTER TABLE apple_subscription_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION current_user_pro_entitlement()
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
