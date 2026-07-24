#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from audit_word_bank_inflections import (
    active_field_values,
    apply_replacements,
    build_chat_batch,
    new_chat_audit,
    new_chat_replacements,
    record_chat_batch,
    scan_entries,
    validate_chat_decisions,
    validate_chat_preconditions,
    validate_complete_chat_review,
)
from inflection_safety import known_bad_backword_pair_reason, scan_clue


class InflectionSafetyTests(unittest.TestCase):
    def test_strict_base_verb_rejects_third_person_clue(self) -> None:
        issues = scan_clue("ABSORB", "What a sponge does.")
        self.assertEqual([issue.reason for issue in issues], ["THIRD_PERSON_CLUE"])
        self.assertEqual(issues[0].proposed, "Act like a sponge.")

    def test_strict_base_verb_rejects_gerund_clue(self) -> None:
        issues = scan_clue("APPEAL", "Requesting something earnestly.")
        self.assertEqual([issue.reason for issue in issues], ["GERUND_CLUE_FOR_BASE_VERB"])
        self.assertEqual(issues[0].proposed, "Request something earnestly.")

    def test_third_person_answer_rejects_infinitive_greets_clues(self) -> None:
        cases = [
            ("To welcome or acknowledge", "Welcomes or acknowledges"),
            ("To say hello with enthusiasm", "Says hello with enthusiasm"),
            ("To meet with a smile or gesture", "Meets with a smile or gesture"),
        ]
        for clue, proposed in cases:
            with self.subTest(clue=clue):
                issues = scan_clue("GREETS", clue)
                self.assertEqual(
                    [issue.reason for issue in issues],
                    ["INFINITIVE_CLUE_FOR_THIRD_PERSON"],
                )
                self.assertEqual(issues[0].proposed, proposed)
                self.assertEqual(scan_clue("GREETS", proposed), [])

    def test_gerund_suggestions_double_required_consonants(self) -> None:
        cases = [
            ("STARTING", "To begin an action", "Beginning an action"),
            ("KICKING", "To hit with a foot", "Hitting with a foot"),
            ("SLAPPING", "To slap with an open palm", "Slapping with an open palm"),
            ("SPEWING", "To emit forcefully", "Emitting forcefully"),
        ]
        for word, clue, proposed in cases:
            with self.subTest(word=word):
                issues = scan_clue(word, clue)
                self.assertEqual(
                    [issue.reason for issue in issues],
                    ["INFINITIVE_CLUE_FOR_GERUND"],
                )
                self.assertEqual(issues[0].proposed, proposed)

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

    def test_backword_adjacent_process_pair_is_rejected(self) -> None:
        self.assertEqual(
            known_bad_backword_pair_reason("LARVAE", "TRANSFORMATION"),
            "ADJACENT_PROCESS",
        )

    def test_backword_good_lateral_pair_is_allowed(self) -> None:
        self.assertIsNone(known_bad_backword_pair_reason("CASTLE", "CHESS"))

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


class ChatReviewWorkflowTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.bank_path = Path(self.temp_dir.name) / "word_bank.json"
        self.entries = [{
            "word": "GREETS",
            "text": "To welcome or acknowledge",
            "hint": "Warm reception for newcomers",
            "hard_text": "Offers a friendly acknowledgment upon arrival",
            "clues": [
                "To say hello with enthusiasm",
                "Welcomes someone at the door",
                "To meet with a smile or gesture",
            ],
        }]
        self.bank_path.write_text(json.dumps(self.entries, indent=4) + "\n")
        self.audit = new_chat_audit(self.entries, self.bank_path)
        self.replacements = new_chat_replacements(self.audit)
        self.batch = build_chat_batch(self.audit, 100)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def decisions(self) -> dict:
        replacements = [
            ("text", "To welcome or acknowledge", "Welcomes or acknowledges"),
            (
                "clues[0]",
                "To say hello with enthusiasm",
                "Says hello with enthusiasm",
            ),
            (
                "clues[2]",
                "To meet with a smile or gesture",
                "Meets with a smile or gesture",
            ),
        ]
        return {
            "schemaVersion": 1,
            "bankSha256": self.batch["bankSha256"],
            "batchId": self.batch["batchId"],
            "batchHash": self.batch["batchHash"],
            "confirmedAllOtherFieldsMatch": True,
            "replacements": [
                {
                    "index": 0,
                    "word": "GREETS",
                    "field": field,
                    "current": current,
                    "proposed": proposed,
                    "reason": "Match the third-person singular answer form",
                    "status": "accepted",
                }
                for field, current, proposed in replacements
            ],
        }

    def test_active_fields_exclude_dormant_hint(self) -> None:
        fields = active_field_values(self.entries[0])
        self.assertEqual(
            [field["field"] for field in fields],
            ["text", "hard_text", "clues[0]", "clues[1]", "clues[2]"],
        )
        self.assertEqual(self.audit["activeFieldCount"], 5)

    def test_batch_resume_advances_after_recording(self) -> None:
        changed = record_chat_batch(
            self.entries,
            self.audit,
            self.replacements,
            self.batch,
            self.decisions(),
        )
        self.assertEqual(changed, 3)
        self.assertEqual(self.audit["remainingFieldCount"], 0)
        self.assertEqual(build_chat_batch(self.audit, 100)["entryCount"], 0)
        self.assertEqual(
            self.replacements["batchHashes"],
            {self.batch["batchId"]: self.batch["batchHash"]},
        )

    def test_stale_bank_hash_is_rejected(self) -> None:
        self.bank_path.write_text(json.dumps([{**self.entries[0], "text": "Changed"}]))
        with self.assertRaisesRegex(ValueError, "Stale audit report"):
            validate_chat_preconditions(
                self.entries,
                self.audit,
                self.replacements,
                self.bank_path,
            )

    def test_batch_hash_precondition_is_required(self) -> None:
        decisions = self.decisions()
        decisions["batchHash"] = "stale"
        with self.assertRaisesRegex(ValueError, "batchHash"):
            validate_chat_decisions(
                self.entries,
                self.audit,
                self.batch,
                decisions,
            )

    def test_recorded_batch_hash_is_retained_and_validated(self) -> None:
        record_chat_batch(
            self.entries,
            self.audit,
            self.replacements,
            self.batch,
            self.decisions(),
        )
        self.replacements["batchHashes"][self.batch["batchId"]] = "stale"
        with self.assertRaisesRegex(ValueError, "batch-hash map"):
            validate_chat_preconditions(
                self.entries,
                self.audit,
                self.replacements,
                self.bank_path,
            )

    def test_exact_current_value_precondition_is_required(self) -> None:
        decisions = self.decisions()
        decisions["replacements"][0]["current"] = "Changed clue"
        with self.assertRaisesRegex(ValueError, "current-value mismatch"):
            validate_chat_decisions(
                self.entries,
                self.audit,
                self.batch,
                decisions,
            )

    def test_full_review_gate_and_safe_application(self) -> None:
        with self.assertRaisesRegex(ValueError, "incomplete"):
            validate_complete_chat_review(
                self.entries,
                self.audit,
                self.replacements,
                self.bank_path,
            )
        record_chat_batch(
            self.entries,
            self.audit,
            self.replacements,
            self.batch,
            self.decisions(),
        )
        updated = validate_complete_chat_review(
            self.entries,
            self.audit,
            self.replacements,
            self.bank_path,
        )
        self.assertEqual(updated[0]["text"], "Welcomes or acknowledges")
        self.assertEqual(updated[0]["clues"][0], "Says hello with enthusiasm")
        self.assertEqual(updated[0]["clues"][2], "Meets with a smile or gesture")
        self.assertEqual(updated[0]["hint"], "Warm reception for newcomers")

    def test_invalid_replacement_is_rejected(self) -> None:
        decisions = self.decisions()
        decisions["replacements"][0]["proposed"] = "GREETS perhaps"
        with self.assertRaisesRegex(ValueError, "answer leakage"):
            validate_chat_decisions(
                self.entries,
                self.audit,
                self.batch,
                decisions,
            )

    def test_unresolved_replacement_blocks_complete_review(self) -> None:
        decisions = self.decisions()
        decisions["replacements"][0]["status"] = "pending"
        record_chat_batch(
            self.entries,
            self.audit,
            self.replacements,
            self.batch,
            decisions,
        )
        with self.assertRaisesRegex(ValueError, "Unresolved replacement"):
            validate_complete_chat_review(
                self.entries,
                self.audit,
                self.replacements,
                self.bank_path,
            )


if __name__ == "__main__":
    unittest.main()
