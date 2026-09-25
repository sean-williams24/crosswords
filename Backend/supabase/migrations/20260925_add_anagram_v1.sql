-- Add dated Anagram content and its cross-device progress contract.
-- Apply before any Anagram client reads or writes cloud progress.
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
    ON anagram_puzzles FOR SELECT USING (date <= CURRENT_DATE);

CREATE OR REPLACE FUNCTION reject_anagram_mutation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Published Anagram rows are immutable';
END;
$$;

CREATE TRIGGER anagram_immutable
    BEFORE UPDATE OR DELETE ON anagram_puzzles
    FOR EACH ROW EXECUTE FUNCTION reject_anagram_mutation();


ALTER TABLE game_progress DROP CONSTRAINT IF EXISTS game_progress_game_type_check;
ALTER TABLE game_progress ADD CONSTRAINT game_progress_game_type_check
    CHECK (game_type IN ('backword', 'daily_crossword', 'weekly_crossword', 'anagram'));

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
