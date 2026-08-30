import sys
import json
import tempfile
import unittest
from datetime import date
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

import audit_unreleased_puzzles as unreleased
from word_bank_safety import current_pairs, new_certification


def entry() -> dict:
    return {
        "word": "AFIRE",
        "text": "Blazing",
        "hint": "Dormant fallback",
        "hard_text": "Lit up",
        "clues": ["Set ablaze"],
    }


def row(clue_text: str, row_date: str = "2026-09-01") -> dict:
    return {
        "id": "future-row",
        "date": row_date,
        "puzzle_number": 9,
        "clues": [{
            "id": 1,
            "answer": "AFIRE",
            "text": clue_text,
            "hint": "Set ablaze",
            "textSourceField": "text",
            "hintSourceField": "clues",
            "hintSourceIndex": 0,
        }],
    }


class UnreleasedPuzzleAuditTests(unittest.TestCase):
    def setUp(self) -> None:
        self.entries = [entry()]
        self.certificate = new_certification([
            {**pair, "provenance": "deterministic", "auditStatus": "deterministic_safe"}
            for pair in current_pairs(self.entries)
        ])

    def test_flags_uncertified_future_clue(self) -> None:
        findings = unreleased.audit_rows({"daily": [row("On fire")], "weekly": []}, self.certificate)

        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0]["reason"], "deterministic_leak")
        self.assertEqual(findings[0]["channel"], "text")

    def test_builds_source_mapped_certified_update(self) -> None:
        rows = {"daily": [row("On fire")], "weekly": []}
        findings = unreleased.audit_rows(rows, self.certificate)

        package = unreleased.build_updates(rows, findings, self.entries, self.certificate)

        self.assertEqual(package["updates"][0]["replacement"], "Blazing")
        self.assertEqual(package["updates"][0]["status"], "pending_review")

    def test_apply_requires_exact_original_clues_payload(self) -> None:
        rows = {"daily": [row("On fire")], "weekly": []}
        finding = unreleased.audit_rows(rows, self.certificate)[0]
        package = unreleased.build_updates(rows, [finding], self.entries, self.certificate)
        package["updates"][0]["status"] = "approved"

        applied = unreleased.apply_updates_to_rows(rows, package)

        self.assertEqual(applied["daily"][0]["clues"][0]["text"], "Blazing")
        rows["daily"][0]["clues"][0]["text"] = "Changed remotely"
        with self.assertRaisesRegex(ValueError, "changed since update export"):
            unreleased.apply_updates_to_rows(rows, package)

    def test_historical_updates_use_exact_source_mapped_certified_repairs(self) -> None:
        previous = [{
            "word": "AFIRE", "text": "On fire", "hint": "Dormant fallback",
            "hard_text": "Lit up", "clues": ["In flames"],
        }]
        current = [entry()]
        rows = {"daily": [{
            **row("On fire"),
            "clues": [{
                **row("On fire")["clues"][0],
                "hint": "In flames",
                "hintSourceField": "clues",
                "hintSourceIndex": 0,
            }],
        }], "weekly": []}

        package = unreleased.build_historical_updates(rows, previous, current, self.certificate)

        self.assertEqual([(item["channel"], item["replacement"]) for item in package["updates"]], [
            ("text", "Blazing"), ("hint", "Set ablaze"),
        ])
        self.assertEqual(
            unreleased.apply_updates_to_rows(rows, package)["daily"][0]["clues"][0]["text"],
            "Blazing",
        )

    def test_historical_updates_allow_unique_exact_fallback_without_metadata(self) -> None:
        previous = [{**entry(), "text": "On fire"}]
        rows = {"daily": [{
            **row("On fire"),
            "clues": [{"id": 1, "answer": "AFIRE", "text": "On fire", "hint": "Unchanged"}],
        }], "weekly": []}

        package = unreleased.build_historical_updates(rows, previous, self.entries, self.certificate)

        self.assertEqual(len(package["updates"]), 1)
        self.assertEqual(package["updates"][0]["replacement"], "Blazing")

    def test_released_rows_are_not_selected_by_artifact_loader(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "puzzle_9.json"
            path.write_text(json.dumps({**row("Blazing", "2026-08-26"), "is_free": True}))

            rows = unreleased.load_artifacts(Path(directory), after=date(2026, 8, 26))

        self.assertEqual(rows["daily"], [])

    def test_artifact_loader_ignores_malformed_cache_json(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".cache").mkdir()
            (root / ".cache" / "partial.json").write_text("")
            (root / "future_puzzle.json").write_text(json.dumps({
                **row("Blazing"), "is_free": True,
            }))

            rows = unreleased.load_artifacts(root, after=date(2026, 8, 30))

        self.assertEqual(len(rows["daily"]), 1)


if __name__ == "__main__":
    unittest.main()
