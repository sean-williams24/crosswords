-- Match the deployed daily crossword and Backword release window: the next
-- dated row is readable before local midnight, while clients select only
-- their own local date. Rows beyond tomorrow remain hidden.
ALTER POLICY "Public can read released anagrams"
    ON public.anagram_puzzles
    USING (date <= CURRENT_DATE + 1);
