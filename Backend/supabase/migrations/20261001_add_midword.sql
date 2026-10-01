CREATE TABLE IF NOT EXISTS public.midword_puzzles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    puzzle_number INTEGER NOT NULL UNIQUE CHECK (puzzle_number > 0),
    date DATE NOT NULL UNIQUE,
    first_word TEXT NOT NULL CHECK (first_word ~ '^[A-Z]+$'),
    second_word TEXT NOT NULL CHECK (second_word ~ '^[A-Z]+$'),
    answer TEXT NOT NULL CHECK (answer ~ '^[A-Z]{3,6}$'),
    alternatives TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.midword_puzzles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can read released Midword puzzles"
    ON public.midword_puzzles FOR SELECT
    USING (date <= (NOW() AT TIME ZONE 'Pacific/Kiritimati')::date);

REVOKE ALL ON TABLE public.midword_puzzles FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.midword_puzzles TO anon, authenticated;
GRANT SELECT, INSERT ON TABLE public.midword_puzzles TO service_role;

ALTER TABLE public.game_progress DROP CONSTRAINT game_progress_game_type_check;
ALTER TABLE public.game_progress ADD CONSTRAINT game_progress_game_type_check
    CHECK (game_type IN ('backword', 'anagram', 'midword', 'daily_crossword', 'weekly_crossword'));

CREATE OR REPLACE FUNCTION public.publish_midword_batch(p_rows JSONB)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    item JSONB;
    inserted_count INTEGER := 0;
    next_number INTEGER;
    item_date DATE;
    first_word TEXT;
    second_word TEXT;
    answer TEXT;
BEGIN
    IF jsonb_typeof(p_rows) <> 'array' THEN
        RAISE EXCEPTION 'Midword batch must be an array';
    END IF;
    FOR item IN SELECT value FROM jsonb_array_elements(p_rows)
    LOOP
        item_date := (item->>'date')::DATE;
        next_number := (item->>'puzzle_number')::INTEGER;
        first_word := item->>'first_word';
        second_word := item->>'second_word';
        answer := item->>'answer';
        IF first_word !~ '^[A-Z]+$' OR second_word !~ '^[A-Z]+$'
           OR answer !~ '^[A-Z]{3,6}$' OR next_number < 1
           OR first_word = answer OR second_word = answer
           OR first_word = second_word THEN
            RAISE EXCEPTION 'Invalid Midword puzzle';
        END IF;
        IF EXISTS (SELECT 1 FROM midword_puzzles AS p
                   WHERE p.date = item_date OR p.puzzle_number = next_number
                      OR (p.first_word = (item->>'first_word') AND p.second_word = (item->>'second_word'))) THEN
            RAISE EXCEPTION 'Midword date, number, or prompt pair already used';
        END IF;
        INSERT INTO midword_puzzles (date, puzzle_number, first_word, second_word, answer, alternatives)
        VALUES (item_date, next_number, first_word, second_word, answer, '{}');
        inserted_count := inserted_count + 1;
    END LOOP;
    RETURN inserted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.publish_midword_batch(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.publish_midword_batch(JSONB) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_midword_batch(JSONB) TO service_role;
