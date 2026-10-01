import unittest
import json
import re
import tempfile
from datetime import date
from pathlib import Path

from generate_midword import default_start_date, load_approved, select_puzzles
from build_midword_bank import discover


class MidwordGeneratorTests(unittest.TestCase):
    def test_migration_preserves_existing_game_types(self):
        migration_dir = Path(__file__).parent / "supabase" / "migrations"

        def allowed_types(path: Path) -> set[str]:
            sql = path.read_text()
            match = re.search(r"CHECK\s*\(game_type\s+IN\s*\(([^)]*)\)\)", sql)
            self.assertIsNotNone(match, f"No game type constraint in {path}")
            return set(re.findall(r"'([^']+)'", match.group(1)))

        anagram_types = allowed_types(migration_dir / "20260925_add_anagram_v1.sql")
        midword_types = allowed_types(migration_dir / "20261001_add_midword.sql")
        schema_types = allowed_types(Path(__file__).parent / "supabase" / "schema.sql")
        self.assertEqual(midword_types, anagram_types | {"midword"})
        self.assertEqual(schema_types, midword_types)

    def test_migration_declares_midword_data_api_access(self):
        migration = (Path(__file__).parent / "supabase" / "migrations" /
                     "20261001_add_midword.sql").read_text()
        self.assertIn("GRANT SELECT ON TABLE public.midword_puzzles TO anon, authenticated;", migration)
        self.assertIn("GRANT SELECT, INSERT ON TABLE public.midword_puzzles TO service_role;", migration)
        self.assertIn("REVOKE ALL ON FUNCTION public.publish_midword_batch(JSONB) FROM anon, authenticated;", migration)

    def test_first_publication_can_include_launch_day(self):
        self.assertEqual(default_start_date(date(2026, 10, 1)), date(2026, 10, 1))
        planned = select_puzzles(load_approved(), [], date(2026, 10, 1), 1)
        self.assertEqual(planned[0]["date"], "2026-10-01")

    def test_approved_inventory_and_compounds(self):
        triples = load_approved()
        self.assertGreaterEqual(len(triples), 21)
        self.assertTrue(all(3 <= len(middle) <= 6 for _, middle, _ in triples))
        self.assertIn(("BANK", "NOTE", "BOOK"), triples)

    def test_gap_filling_preserves_numbers_and_pairs(self):
        existing = [{"date": "2026-10-03", "puzzle_number": 8, "first_word": "BANK", "answer": "NOTE", "second_word": "BOOK"}]
        planned = select_puzzles(load_approved(), existing, date(2026, 10, 2), 3)
        self.assertEqual([p["date"] for p in planned], ["2026-10-02", "2026-10-04"])
        self.assertEqual([p["puzzle_number"] for p in planned], [9, 10])
        self.assertNotIn(("BANK", "BOOK"), [(p["first_word"], p["second_word"]) for p in planned])

    def test_exhaustion_is_all_or_nothing(self):
        with self.assertRaisesRegex(ValueError, "exhausted"):
            select_puzzles([("BANK", "NOTE", "BOOK")], [], date(2026, 10, 2), 2)

    def test_no_known_competing_link_for_approved_pairs(self):
        words = {entry["word"] for entry in json.loads((Path(__file__).parent / "word_bank.json").read_text())}
        for first, answer, second in load_approved():
            possible = [link for link in words
                        if 3 <= len(link) <= 6 and first + link in words and link + second in words]
            self.assertEqual([link for link in possible if link != answer], [],
                             f"{first} / {second} also has a known link")

    def test_discovery_only_emits_unreviewed_candidates(self):
        words = {"BANK", "NOTE", "BOOK", "BANKNOTE", "NOTEBOOK", "RAIN", "BOW", "TIE", "RAINBOW", "BOWTIE"}
        rows = discover(words, {("BANK", "NOTE", "BOOK")})
        self.assertFalse(any(row["answer"] == "NOTE" for row in rows))
        self.assertTrue(all(row["review_status"] == "unreviewed" for row in rows))

    def test_approved_inventory_rejects_duplicate_prompt_pairs(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "approved.json"
            path.write_text(json.dumps({"triples": ["BANK NOTE BOOK", "BANK CARD BOOK"]}))
            with self.assertRaisesRegex(ValueError, "prompt pair"):
                load_approved(path)


if __name__ == "__main__":
    unittest.main()
