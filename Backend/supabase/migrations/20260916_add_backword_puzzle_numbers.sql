-- A Backword issue number is its immutable chronological release sequence.
ALTER TABLE backword_words ADD COLUMN puzzle_number INT;

WITH numbered_words AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY date ASC) AS puzzle_number
    FROM backword_words
)
UPDATE backword_words
SET puzzle_number = numbered_words.puzzle_number
FROM numbered_words
WHERE backword_words.id = numbered_words.id;

ALTER TABLE backword_words
    ALTER COLUMN puzzle_number SET NOT NULL,
    ADD CONSTRAINT backword_words_puzzle_number_key UNIQUE (puzzle_number);
