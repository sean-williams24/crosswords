#!/usr/bin/env python3

from __future__ import annotations

import unittest

from audit_word_bank_inflections import apply_replacements, scan_entries
from inflection_safety import scan_clue


class InflectionSafetyTests(unittest.TestCase):
    def test_strict_base_verb_rejects_third_person_clue(self) -> None:
        issues = scan_clue("ABSORB", "What a sponge does.")
        self.assertEqual([issue.reason for issue in issues], ["THIRD_PERSON_CLUE"])
        self.assertEqual(issues[0].proposed, "Act like a sponge.")

    def test_strict_base_verb_rejects_gerund_clue(self) -> None:
        issues = scan_clue("APPEAL", "Requesting something earnestly.")
        self.assertEqual([issue.reason for issue in issues], ["GERUND_CLUE_FOR_BASE_VERB"])
        self.assertEqual(issues[0].proposed, "Request something earnestly.")

    def test_backword_known_bad_pairs_are_rejected(self) -> None:
        cases = [
            ("ACHIEVE", "EXCELS", "SUCCESS"),
            ("DUPLICATE", "CLONES", "COPY"),
            ("CRUELTY", "UNKIND", "MALICE"),
        ]
        for answer, clue, expected in cases:
            with self.subTest(answer=answer, clue=clue):
                issues = scan_clue(answer, clue, single_word_pair=True)
                self.assertTrue(issues)
                self.assertEqual(issues[0].proposed, expected)

    def test_scan_entries_returns_only_flagged_entries(self) -> None:
        entries = [
            {"word": "ABILITY", "text": "Skill or talent."},
            {"word": "ABSORB", "text": "Soak up liquid.", "clues": ["What a sponge does."]},
        ]
        findings = scan_entries(entries)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0]["word"], "ABSORB")
        self.assertEqual(findings[0]["fields"][0]["field"], "clues[0]")

    def test_apply_replacements_checks_current_value_and_updates_field(self) -> None:
        entries = [
            {"word": "ABSORB", "text": "Soak up liquid.", "clues": ["What a sponge does."]},
        ]
        replacements = {
            "replacements": [
                {
                    "index": 0,
                    "word": "ABSORB",
                    "fields": [
                        {
                            "field": "clues[0]",
                            "current": "What a sponge does.",
                            "proposed": "Take in like a sponge.",
                        }
                    ],
                }
            ]
        }
        changed = apply_replacements(entries, replacements)
        self.assertEqual(changed, 1)
        self.assertEqual(entries[0]["clues"][0], "Take in like a sponge.")


if __name__ == "__main__":
    unittest.main()
