import random
import sys
import unittest
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

import generate_puzzle
import generate_weekly_puzzle
import sync_supabase_crossword_edits as sync


def entry() -> dict:
    return {
        "word": "ORBIT",
        "text": "Path around a star",
        "hint": "Dormant fallback",
        "hard_text": "Celestial route",
        "clues": [
            "Circular path",
            "Route around a planet",
        ],
    }


def row(table_date: str, clue: dict) -> dict:
    return {
        "id": f"row-{table_date}",
        "date": table_date,
        "puzzle_number": 10,
        "clues": [clue],
    }


def clue(**overrides) -> dict:
    base = {
        "id": 3,
        "number": 4,
        "direction": "across",
        "answer": "ORBIT",
        "text": "Path around a star",
        "hint": "Circular path",
    }
    base.update(overrides)
    return base


class SupabaseCrosswordEditSyncTests(unittest.TestCase):
    def test_daily_text_diff_produces_text_replacement(self) -> None:
        entries = [entry()]
        rows = {"daily": [row("2026-07-01", clue(text="Track around a planet", hint="Circular path"))]}

        replacements = sync.scan_rows(entries, rows)

        self.assertEqual(len(replacements), 1)
        self.assertEqual(replacements[0]["status"], "ready")
        self.assertEqual(replacements[0]["field"], "text")
        self.assertEqual(replacements[0]["current"], "Path around a star")
        self.assertEqual(replacements[0]["proposed"], "Track around a planet")

    def test_weekly_hint_diff_produces_hard_text_replacement(self) -> None:
        entries = [entry()]
        rows = {"weekly": [row("2026-07-05", clue(text="Circular path", hint="Route followed by a satellite"))]}

        replacements = sync.scan_rows(entries, rows)

        self.assertEqual(len(replacements), 1)
        self.assertEqual(replacements[0]["status"], "ready")
        self.assertEqual(replacements[0]["field"], "hard_text")
        self.assertEqual(replacements[0]["current"], "Celestial route")
        self.assertEqual(replacements[0]["proposed"], "Route followed by a satellite")

    def test_pre_provenance_clue_edit_exports_manual_candidates(self) -> None:
        entries = [entry()]
        rows = {"daily": [row("2026-07-01", clue(hint="Path followed by a satellite"))]}

        replacements = sync.scan_rows(entries, rows)

        self.assertEqual(len(replacements), 1)
        self.assertEqual(replacements[0]["status"], "manualReviewRequired")
        self.assertIsNone(replacements[0]["field"])
        self.assertEqual(
            replacements[0]["candidateFields"],
            [
                {"field": "clues[0]", "current": "Circular path"},
                {"field": "clues[1]", "current": "Route around a planet"},
            ],
        )

    def test_provenance_backed_clue_edit_applies_exact_index(self) -> None:
        entries = [entry()]
        rows = {"daily": [row(
            "2026-07-01",
            clue(
                hint="Path followed by a satellite",
                hintSourceField="clues",
                hintSourceIndex=1,
            ),
        )]}
        report = {"replacements": sync.scan_rows(entries, rows)}

        changed = sync.apply_report(entries, report)

        self.assertEqual(changed, 1)
        self.assertEqual(entries[0]["clues"][0], "Circular path")
        self.assertEqual(entries[0]["clues"][1], "Path followed by a satellite")

    def test_stale_word_bank_current_value_fails_apply(self) -> None:
        entries = [entry()]
        report = {
            "replacements": [
                {
                    "id": "daily:2026-07-01:3:ORBIT:hint",
                    "status": "ready",
                    "wordBankIndex": 0,
                    "answer": "ORBIT",
                    "field": "clues[0]",
                    "current": "Older clue",
                    "proposed": "Path followed by a satellite",
                }
            ]
        }

        with self.assertRaisesRegex(ValueError, "changed since export"):
            sync.apply_report(entries, report)

    def test_resolve_obvious_manual_items_fills_normalized_match(self) -> None:
        report = {
            "replacements": [
                {
                    "status": "manualReviewRequired",
                    "field": None,
                    "current": None,
                    "proposed": "What you\u2019ve done with effort in the past?",
                    "candidateFields": [
                        {"field": "clues[0]", "current": "Past participle of obtain"},
                        {"field": "clues[2]", "current": "What you've done with effort in the past?"},
                    ],
                }
            ]
        }

        resolved = sync.resolve_obvious_manual_items(report)

        self.assertEqual(resolved, 1)
        self.assertEqual(report["replacements"][0]["status"], "ready")
        self.assertEqual(report["replacements"][0]["field"], "clues[2]")
        self.assertEqual(report["replacements"][0]["current"], "What you've done with effort in the past?")

    def test_daily_generator_payload_includes_source_metadata(self) -> None:
        slot = generate_puzzle.Slot(0, 0, "across", 5)
        solution = [{"slot": slot, "entry": entry()}]

        raw = generate_puzzle.assemble_raw(generate_puzzle.TEMPLATES[0], solution, random.Random(1))
        payload = generate_puzzle.build_puzzle_payload(raw, puzzle_number=1, puzzle_date="2026-07-01")

        payload_clue = payload["clues"][0]
        self.assertEqual(payload_clue["textSourceField"], "text")
        self.assertIsNone(payload_clue["textSourceIndex"])
        self.assertEqual(payload_clue["hintSourceField"], "clues")
        self.assertIsInstance(payload_clue["hintSourceIndex"], int)
        self.assertEqual(payload_clue["hint"], entry()["clues"][payload_clue["hintSourceIndex"]])

    def test_weekly_generator_payload_includes_source_metadata(self) -> None:
        slot = generate_weekly_puzzle.Slot(0, 0, "across", 5)
        solution = [{"slot": slot, "entry": entry()}]

        raw = generate_weekly_puzzle.assemble_raw(
            generate_weekly_puzzle.TEMPLATES[0],
            solution,
            random.Random(2),
        )
        payload = generate_weekly_puzzle.build_puzzle_payload(raw, puzzle_number=1, puzzle_date="2026-07-05")

        payload_clue = payload["clues"][0]
        self.assertEqual(payload_clue["textSourceField"], "clues")
        self.assertIsInstance(payload_clue["textSourceIndex"], int)
        self.assertEqual(payload_clue["text"], entry()["clues"][payload_clue["textSourceIndex"]])
        self.assertEqual(payload_clue["hintSourceField"], "hard_text")
        self.assertIsNone(payload_clue["hintSourceIndex"])


if __name__ == "__main__":
    unittest.main()
