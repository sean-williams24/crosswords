import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))

from answer_leakage import clue_ideas_are_redundant, leaks_answer, normalize_clue_idea, redundant_clue_groups, scan_text


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


if __name__ == "__main__":
    unittest.main()
