-- Preserve the release-window score snapshot if a different device has a
-- better crossword grid. The grid itself is still selected as one whole
-- record; only the independent historical score metadata is promoted.
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
    resolved_release_score INTEGER;
    use_incoming BOOLEAN := FALSE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
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
    resolved_release_score := CASE
        WHEN is_crossword THEN GREATEST(current_row.release_score, p_release_score)
        ELSE p_release_score
    END;
    use_incoming :=
        (p_status = 'solved' AND current_row.status <> 'solved') OR
        (p_status = 'solved' AND current_row.status = 'solved' AND p_release_score > current_row.release_score) OR
        (p_status <> 'solved' AND current_row.status <> 'solved' AND incoming_terminal AND NOT current_terminal) OR
        (p_status <> 'solved' AND current_row.status <> 'solved' AND incoming_terminal = current_terminal AND p_progress_rank > current_row.progress_rank) OR
        (p_status <> 'solved' AND current_row.status <> 'solved' AND incoming_terminal = current_terminal AND p_progress_rank = current_row.progress_rank AND p_client_updated_at > current_row.client_updated_at) OR
        (p_status = 'solved' AND current_row.status = 'solved' AND p_release_score = current_row.release_score AND p_client_updated_at > current_row.client_updated_at);

    IF use_incoming THEN
        UPDATE game_progress
        SET release_date = p_release_date,
            schema_version = p_schema_version,
            status = p_status,
            progress_rank = p_progress_rank,
            release_score = resolved_release_score,
            client_updated_at = p_client_updated_at,
            payload = CASE
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
    ELSIF is_crossword AND p_release_score > current_row.release_score THEN
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
