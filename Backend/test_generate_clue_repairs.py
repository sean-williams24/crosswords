#!/usr/bin/env python3

import unittest

from generate_clue_repairs import apply_repairs, audit_records, validate_repairs


class ClueRepairTests(unittest.TestCase):
    def setUp(self) -> None:
        self.targets = [{
            "index": 0,
            "word": "STANDISH",
            "current": {"text": "Old", "hint": "Old", "hard_text": "Old", "clues": ["Old", "Old", "Old"]},
        }]

    def response(self) -> dict:
        return {"repairs": [{
            "word": "STANDISH",
            "text": "Plymouth Colony military leader",
            "hint": "Pilgrim-era captain",
            "hard_text": "Longfellow's courtship rival",
            "clues": ["Captain in a Longfellow poem", "Plymouth's military man", "Myles of colonial fame"],
        }]}

    def test_validates_complete_non_leaking_repair_package(self) -> None:
        repairs = validate_repairs(self.targets, self.response())
        self.assertEqual(repairs[0]["word"], "STANDISH")
        self.assertEqual(repairs[0]["status"], "pending_review")

    def test_rejects_answer_leakage(self) -> None:
        response = self.response()
        response["repairs"][0]["clues"][0] = "Standish of Plymouth"
        with self.assertRaisesRegex(ValueError, "leaks"):
            validate_repairs(self.targets, response)

    def test_rejects_incomplete_repair_package(self) -> None:
        response = self.response()
        response["repairs"][0]["clues"].pop()
        with self.assertRaisesRegex(ValueError, "exactly three"):
            validate_repairs(self.targets, response)

    def test_apply_repairs_updates_only_the_proposed_clue_fields(self) -> None:
        repair = validate_repairs(self.targets, self.response())
        entries = [{
            "word": "STANDISH",
            "text": "Old",
            "hint": "Old",
            "hard_text": "Old",
            "clues": ["Old", "Old", "Old"],
            "metadata": "preserved",
        }]
        updated = apply_repairs(entries, repair)
        self.assertEqual(updated[0]["text"], "Plymouth Colony military leader")
        self.assertEqual(updated[0]["metadata"], "preserved")
        self.assertEqual(entries[0]["text"], "Old")

    def test_audit_records_require_applied_proposal_values(self) -> None:
        repair = validate_repairs(self.targets, self.response())[0]
        repair["status"] = "approved"
        entries = apply_repairs([{
            "word": "STANDISH",
            "text": "Old",
            "hint": "Old",
            "hard_text": "Old",
            "clues": ["Old", "Old", "Old"],
        }], [repair])
        records = audit_records(entries, {"repairs": [repair]})
        self.assertEqual(records[0]["word"], "STANDISH")
        entries[0]["text"] = "Changed again"
        with self.assertRaisesRegex(ValueError, "changed"):
            audit_records(entries, {"repairs": [repair]})
