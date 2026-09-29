import copy
from datetime import date, timedelta
import json
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch

from generate_anagram import hint_cell_index, load_pool, make_row, points_for_seconds, prepare, signature, validate_rows
from publish_anagram import validate_publication
from review_anagram_frequency import build_report


class AnagramContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pool = load_pool()

    def test_launch_batch_has_thirty_valid_immutable_rows(self):
        rows = prepare(date(2026, 9, 26), 1, 30, self.pool)
        self.assertEqual((rows[0]["puzzle_number"], rows[-1]["date"]), (1, "2026-10-25"))
        self.assertEqual(len({row["id"] for row in rows}), 30)
        self.assertEqual(rows, prepare(date(2026, 9, 26), 1, 30, self.pool))
        self.assertEqual(rows[0]["puzzle_data"]["answer"], "TRIANGLE")
        self.assertIn("INTEGRAL", rows[0]["puzzle_data"]["acceptedAnswers"])

    def test_replenishment_continues_issue_and_date(self):
        launch = prepare(date(2026, 9, 26), 1, 30, self.pool)
        next_rows = prepare(date(2026, 10, 26), 31, 14, self.pool)
        validate_rows(next_rows, launch)
        self.assertEqual(next_rows[0]["puzzle_number"], 31)
        self.assertEqual(next_rows[-1]["date"], "2026-11-08")

    def test_hint_position_is_stable_and_preserves_the_most_answers(self):
        rows = prepare(date(2026, 9, 26), 1, 30, self.pool)
        self.assertGreater(len({row["puzzle_data"]["hintCellIndex"] for row in rows}), 1)
        for issue, entry in enumerate(self.pool[:30], start=1):
            index = hint_cell_index(entry, issue)
            self.assertEqual(index, hint_cell_index(entry, issue))
            matching = sum(word[index] == entry["answer"][index] for word in entry["acceptedAnswers"])
            self.assertEqual(matching, max(
                sum(word[position] == letter for word in entry["acceptedAnswers"])
                for position, letter in enumerate(entry["answer"])))
        gardens = next(entry for entry in self.pool if entry["answer"] == "GARDENS")
        self.assertIn(hint_cell_index(gardens, 2), [1, 4, 6])
        triangle = self.pool[0]
        self.assertEqual(hint_cell_index(triangle, 1), 3)

    def test_hint_position_validation_rejects_invalid_or_avoidable_exclusions(self):
        gardens = next(entry for entry in self.pool if entry["answer"] == "GARDENS")
        row = make_row(date(2026, 10, 1), 1, gardens)
        for bad in [-1, len(gardens["answer"]), True, None]:
            broken = copy.deepcopy(row)
            broken["puzzle_data"]["hintCellIndex"] = bad
            with self.assertRaisesRegex(ValueError, "Invalid hint position"):
                validate_rows([broken])
        broken = copy.deepcopy(row)
        broken["puzzle_data"]["hintCellIndex"] = 0
        with self.assertRaisesRegex(ValueError, "Hint excludes avoidable alternatives"):
            validate_rows([broken])

    def test_wrong_scramble_or_repeated_combination_is_rejected(self):
        rows = prepare(date(2026, 10, 1), 1, 2, self.pool)
        broken = copy.deepcopy(rows)
        broken[0]["puzzle_data"]["initialScramble"] = "TRIANGLE"
        with self.assertRaisesRegex(ValueError, "Invalid scramble"):
            validate_rows(broken)
        repeated = copy.deepcopy(rows[0])
        repeated["id"] = "another-id"
        repeated["date"] = (date(2026, 10, 1) + timedelta(days=2)).isoformat()
        repeated["puzzle_number"] = 3
        with self.assertRaisesRegex(ValueError, "within 365 days"):
            validate_rows([repeated], rows)

    def test_rejects_missing_published_day_or_issue(self):
        published = prepare(date(2026, 10, 1), 1, 3, self.pool)
        next_row = prepare(date(2026, 10, 4), 4, 1, self.pool)
        with self.assertRaisesRegex(ValueError, "Gap in Anagram date or issue"):
            validate_rows(next_row, [published[0], published[2]])
        broken_issue = copy.deepcopy(published)
        broken_issue[1]["puzzle_number"] = 10
        with self.assertRaisesRegex(ValueError, "Gap in Anagram date or issue"):
            validate_rows(broken_issue)
        with self.assertRaisesRegex(ValueError, "sequence must start at issue 1"):
            validate_rows(next_row, [])

    def test_all_curated_combinations_are_distinct(self):
        signatures = [signature(entry["answer"]) for entry in self.pool]
        self.assertEqual(len(signatures), len(set(signatures)))
        self.assertNotIn("SATURDAY", {entry["answer"] for entry in self.pool})
        self.assertNotIn("DECEMBER", {entry["answer"] for entry in self.pool})

    def test_checked_in_launch_artifact_is_generated_and_approved(self):
        artifact = json.loads((Path(__file__).parent / "anagram_launch_2026-09-26.json").read_text())
        self.assertEqual(artifact["rows"], prepare(date(2026, 9, 26), 1, 30, self.pool,
                                                   include_hint=False))
        self.assertEqual(artifact["reviewStatus"], "approved")
        self.assertEqual(artifact["frequencyReview"], "reviewed")
        self.assertEqual(validate_publication(artifact, []), artifact["rows"])

    def test_publication_rejects_changed_or_noncontiguous_batch(self):
        launch = prepare(date(2026, 9, 26), 1, 30, self.pool)
        next_rows = prepare(date(2026, 10, 26), 31, 3, self.pool)
        artifact = {"reviewStatus": "approved", "frequencyReview": "reviewed", "firstReleaseDate": "2026-10-26", "rows": next_rows}
        self.assertEqual(validate_publication(artifact, launch), next_rows)
        changed = copy.deepcopy(artifact)
        changed["rows"][0]["puzzle_data"]["acceptedAnswers"] = ["ANOTHER"]
        with self.assertRaises(ValueError):
            validate_publication(changed, launch)

    def test_migration_and_schema_have_the_same_anagram_merge_policy(self):
        schema = (Path(__file__).parent / "supabase/schema.sql").read_text()
        migration = (Path(__file__).parent / "supabase/migrations/20260925_add_anagram_v1.sql").read_text()
        function = schema.split("CREATE OR REPLACE FUNCTION merge_game_progress(", 1)[1].split("CREATE TABLE user_entitlements", 1)[0].strip()
        self.assertIn(function, migration)
        self.assertIn("incoming_terminal <> current_terminal", function)
        self.assertIn("WHEN use_incoming AND (p_payload->>'hintUsed')::BOOLEAN", function)
        self.assertIn("merged_anagram_payload", function)

    def test_launch_reschedule_migration_is_guarded_and_restores_immutability(self):
        migration = (Path(__file__).parent / "supabase/migrations/20260926_reschedule_anagram_launch.sql").read_text()
        self.assertIn("refusing to reschedule launch", migration)
        self.assertIn("DROP TRIGGER anagram_immutable", migration)
        self.assertIn("DATE '2026-09-26'", migration)
        self.assertIn("DATE '2026-10-25'", migration)
        self.assertIn("CREATE TRIGGER anagram_immutable", migration)

    def test_sql_terminal_merge_recomputes_from_earliest_start_and_max_penalty(self):
        schema = (Path(__file__).parent / "supabase/schema.sql").read_text()
        function = schema.split("CREATE OR REPLACE FUNCTION merge_game_progress(", 1)[1].split("CREATE TABLE user_entitlements", 1)[0]
        self.assertIn("merged_start_at := LEAST(", function)
        self.assertIn("raw_elapsed_seconds BIGINT;", function)
        self.assertIn("FLOOR(GREATEST(\n                EXTRACT(EPOCH FROM (terminal_completed_at - merged_start_at)), 0))::BIGINT", function)
        self.assertIn("jsonb_build_object('elapsedSecondsAtCompletion', raw_elapsed_seconds)", function)
        self.assertIn("scoring_seconds := raw_elapsed_seconds +", function)
        self.assertIn("(merged_anagram_payload->>'penaltySeconds')::INTEGER", function)
        self.assertIn("same_terminal_and_start AND resolved_release_score > 0", function)
        self.assertIn("resolved_release_score := 0;", function)
        self.assertLess(function.index("EXTRACT(EPOCH FROM (terminal_completed_at - merged_start_at))"),
                        function.index("jsonb_build_object('releaseDateScore', resolved_release_score)"))

    def test_shared_contract_fixtures_and_score_boundaries(self):
        fixture = json.loads((Path(__file__).parent.parent / "docs/fixtures/anagram-v1.json").read_text())
        validate_rows(fixture["puzzles"])
        for case in fixture["scoreCases"]:
            self.assertEqual(points_for_seconds(case["elapsedWithPenaltySeconds"]), case["points"])

    def test_frequency_report_records_rank_and_zipf_for_editorial_review(self):
        fake = types.ModuleType("wordfreq")
        fake.top_n_list = lambda language, count: ["triangle", "integral"]
        fake.zipf_frequency = lambda word, language: 4.25
        with patch.dict(sys.modules, {"wordfreq": fake}):
            report = build_report()
        self.assertEqual(report["entries"][0]["top200kRank"], 1)
        self.assertEqual(report["entries"][0]["acceptedAnswers"][0]["top200kRank"], 2)
        self.assertEqual(report["entries"][0]["zipf"], 4.25)


if __name__ == "__main__":
    unittest.main()
