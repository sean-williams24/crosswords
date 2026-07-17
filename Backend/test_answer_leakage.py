import json
import random
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))

from answer_leakage import (
    clue_ideas_are_redundant,
    clue_ideas_may_be_redundant,
    is_antonym_only_clue,
    leaks_answer,
    normalize_clue_idea,
    or_clause_repeats_other,
    redundant_clue_groups,
    scan_text,
)
from fix_duplicate_clues import apply_quality_report, bank_sha256, hint_is_safe_for_field
import generate_puzzle
import generate_weekly_puzzle


class AnswerLeakageTests(unittest.TestCase):
    def test_blocks_compact_answer_fragment(self):
        self.assertTrue(leaks_answer("CASE", "Suitcase or legal matter"))

    def test_blocks_ordinal_root(self):
        issues = scan_text("TENTH", "One part of ten equal divisions")
        self.assertTrue(any(issue.reason == "DERIVED_ANSWER" and issue.root == "ten" for issue in issues))

    def test_blocks_past_tense_root(self):
        issues = scan_text("BAGGED", "Put into a bag")
        self.assertTrue(any(issue.reason == "DERIVED_ANSWER" and issue.root == "bag" for issue in issues))

    def test_blocks_agent_and_verb_variants(self):
        self.assertTrue(leaks_answer("SMOKER", "One who smokes"))
        self.assertTrue(leaks_answer("RUNNER", "One who runs"))

    def test_blocks_adjective_family_variant(self):
        self.assertTrue(leaks_answer("ARTY", "Pretentiously artistic"))

    def test_blocks_participle_nominal_variant(self):
        self.assertTrue(leaks_answer("RESULTING", "Resultant of previous events"))

    def test_blocks_able_derivation(self):
        issues = scan_text("NOTABLE", "Deserving recognition or note")
        self.assertTrue(any(issue.reason == "DERIVED_ANSWER" and issue.root == "note" for issue in issues))

    def test_allows_unrelated_embedded_short_root(self):
        self.assertFalse(leaks_answer("ART", "A strong start"))

    def test_allows_unrelated_short_prefix(self):
        self.assertFalse(leaks_answer("CAT", "Concatenate strings"))

    def test_normalizes_wrapper_only_clue_rewrites(self):
        self.assertEqual(normalize_clue_idea("Maybe burning fiercely"), "burning fiercely")
        self.assertEqual(normalize_clue_idea("Burning fiercely, perhaps"), "burning fiercely")
        self.assertEqual(normalize_clue_idea("Burning fiercely?"), "burning fiercely")

    def test_redundant_clue_groups_catches_wrapped_duplicates(self):
        groups = redundant_clue_groups([
            ("text", "Maybe burning fiercely"),
            ("clues[0]", "Burning fiercely"),
            ("hard_text", "Like a campfire gone wild"),
        ])
        self.assertEqual(list(groups), ["burning fiercely"])
        self.assertEqual([field for field, _ in groups["burning fiercely"]], ["text", "clues[0]"])

    def test_rejects_high_overlap_definition_rewrites(self):
        self.assertTrue(clue_ideas_are_redundant(
            "Leave behind completely",
            "Completely forsake or leave behind",
        ))
        self.assertTrue(clue_ideas_are_redundant(
            "Skill or talent",
            "Natural talent or learned skill",
        ))
        self.assertFalse(clue_ideas_are_redundant(
            "On fire",
            "Campfire emergency",
        ))

    def test_broad_review_catches_stem_repetition(self):
        self.assertTrue(clue_ideas_may_be_redundant(
            "Important quality",
            "A matter of importance",
        ))

    def test_detects_antonym_only_clue(self):
        self.assertTrue(is_antonym_only_clue("Opposite of cautious"))
        self.assertTrue(is_antonym_only_clue("Direction opposite of north"))
        self.assertTrue(is_antonym_only_clue("Often opposite of firm"))
        self.assertTrue(is_antonym_only_clue("A sign of opposite of false"))

    def test_allows_legitimate_opposition_wording(self):
        self.assertFalse(is_antonym_only_clue("When the outcome is the opposite of what was intended"))

    def test_detects_repeated_or_clause(self):
        self.assertTrue(or_clause_repeats_other(
            "A sharp line or a competitive advantage",
            "Advantage",
        ))

    def test_accepts_safe_hint_promotion(self):
        entry = {
            "word": "NOTABLE",
            "text": "Worthy of attention",
            "hint": "Remarkable",
            "hard_text": "Standing out for significance",
            "clues": ["Deserving recognition or note", "Important enough to remember"],
        }
        self.assertTrue(hint_is_safe_for_field(entry, "clues[0]"))


class QualityReportTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.bank_path = Path(self.temp_dir.name) / "bank.json"
        self.entries = [{
            "word": "TRIAL",
            "text": "A formal examination",
            "hint": "Court proceeding",
            "hard_text": "A test before judgment",
            "clues": ["First option", "Second possibility", "Third choice"],
        }]
        self.bank_path.write_text(json.dumps(self.entries))

    def tearDown(self):
        self.temp_dir.cleanup()

    def report(self, actions):
        return {
            "schemaVersion": 1,
            "bankSha256": bank_sha256(self.bank_path),
            "changes": [{"index": 0, "word": "TRIAL", "actions": actions}],
        }

    def test_applies_descending_clue_deletions(self):
        report = self.report([
            {"action": "delete", "field": "clues[0]", "before": "First option"},
            {"action": "delete", "field": "clues[2]", "before": "Third choice"},
        ])
        apply_quality_report(self.entries, report, self.bank_path)
        self.assertEqual(self.entries[0]["clues"], ["Second possibility"])

    def test_rejects_scalar_deletion(self):
        report = self.report([
            {"action": "delete", "field": "text", "before": "A formal examination"},
        ])
        with self.assertRaisesRegex(ValueError, "Only clues"):
            apply_quality_report(self.entries, report, self.bank_path)

    def test_rejects_dormant_hint_changes(self):
        report = self.report([{
            "action": "replace",
            "field": "hint",
            "before": "Court proceeding",
            "after": "A different fallback",
        }])
        with self.assertRaisesRegex(ValueError, "only change active clue fields"):
            apply_quality_report(self.entries, report, self.bank_path)

    def test_rejects_empty_clue_array(self):
        actions = [
            {"action": "delete", "field": f"clues[{index}]", "before": value}
            for index, value in enumerate(self.entries[0]["clues"])
        ]
        with self.assertRaisesRegex(ValueError, "cannot leave clues"):
            apply_quality_report(self.entries, self.report(actions), self.bank_path)

    def test_rejects_stale_report_hash(self):
        report = self.report([
            {"action": "delete", "field": "clues[0]", "before": "First option"},
        ])
        self.bank_path.write_text(json.dumps(self.entries, indent=2))
        with self.assertRaisesRegex(ValueError, "Stale clue-quality report"):
            apply_quality_report(self.entries, report, self.bank_path)


class VariableClueArrayTests(unittest.TestCase):
    def test_daily_and_weekly_generators_accept_one_clue(self):
        entry = {
            "word": "CAT",
            "text": "Household feline",
            "hint": "Pet that purrs",
            "hard_text": "Mouser, perhaps",
            "clues": ["Companion with whiskers"],
        }
        daily_slot = generate_puzzle.Slot(0, 0, "across", 3)
        weekly_slot = generate_weekly_puzzle.Slot(0, 0, "across", 3)
        daily = generate_puzzle.assemble_raw(
            [[False] * generate_puzzle.GRID_SIZE for _ in range(generate_puzzle.GRID_SIZE)],
            [{"slot": daily_slot, "entry": entry}],
            random.Random(1),
        )
        weekly = generate_weekly_puzzle.assemble_raw(
            [[False] * generate_weekly_puzzle.GRID_SIZE for _ in range(generate_weekly_puzzle.GRID_SIZE)],
            [{"slot": weekly_slot, "entry": entry}],
            random.Random(1),
        )
        self.assertEqual(daily["words"][0]["hint"], "Companion with whiskers")
        self.assertEqual(weekly["words"][0]["text"], "Companion with whiskers")


if __name__ == "__main__":
    unittest.main()
