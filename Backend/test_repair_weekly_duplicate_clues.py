import sys
import unittest
from copy import deepcopy
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

import repair_weekly_duplicate_clues as repair


def word_entry() -> dict:
    return {
        "word": "ORBIT",
        "text": "Path around a star",
        "hint": "Dormant fallback",
        "hard_text": "Celestial route",
        "clues": ["Same clue!", "Circular path", "Route around a planet"],
    }


def puzzle_clue(clue_id: int = 3, **overrides) -> dict:
    clue = {
        "id": clue_id,
        "number": 4,
        "direction": "across",
        "answer": "ORBIT",
        "text": "Same clue",
        "hint": "Same clue.",
        "textSourceField": None,
        "textSourceIndex": None,
        "untouched": "metadata",
    }
    clue.update(overrides)
    return clue


def puzzle_row(row_date: str, clues: list[dict] | None = None) -> dict:
    return {
        "id": f"row-{row_date}",
        "date": row_date,
        "puzzle_number": 10,
        "clues": clues or [puzzle_clue()],
    }


def report_for(entries: list[dict], rows: list[dict], through_date: str = "2026-07-17") -> dict:
    replacements = repair.scan_rows(entries, rows, through_date)
    return repair.build_report(entries, rows, replacements, through_date, repair.BANK_PATH)


class RepairWeeklyDuplicateCluesTests(unittest.TestCase):
    def test_scan_includes_cutoff_and_excludes_future_rows(self) -> None:
        rows = [
            puzzle_row("2026-07-17"),
            puzzle_row("2026-07-18"),
        ]

        replacements = repair.scan_rows([word_entry()], rows, "2026-07-17")

        self.assertEqual(len(replacements), 1)
        self.assertEqual(replacements[0]["date"], "2026-07-17")

    def test_scan_normalizes_case_whitespace_and_trailing_punctuation(self) -> None:
        clue = puzzle_clue(text="  SAME   CLUE! ", hint="same clue")

        replacements = repair.scan_rows([word_entry()], [puzzle_row("2026-07-12", [clue])], "2026-07-17")

        self.assertEqual(len(replacements), 1)

    def test_scan_selects_first_non_identical_word_bank_clue(self) -> None:
        replacements = repair.scan_rows([word_entry()], [puzzle_row("2026-07-12")], "2026-07-17")

        item = replacements[0]
        self.assertEqual(item["status"], "ready")
        self.assertEqual(item["proposedText"], "Circular path")
        self.assertEqual(item["proposedTextSourceField"], "clues")
        self.assertEqual(item["proposedTextSourceIndex"], 1)

    def test_scan_reports_answer_missing_from_word_bank(self) -> None:
        clue = puzzle_clue(answer="MISSING")

        replacements = repair.scan_rows([word_entry()], [puzzle_row("2026-07-12", [clue])], "2026-07-17")

        item = replacements[0]
        self.assertEqual(item["status"], "unresolved")
        self.assertEqual(item["reason"], "Answer is absent from the current word bank")
        self.assertEqual(item["puzzleNumber"], 10)
        self.assertEqual(item["rowId"], "row-2026-07-12")

    def test_validate_rejects_stale_supabase_clue(self) -> None:
        entries = [word_entry()]
        original_rows = [puzzle_row("2026-07-12")]
        report = report_for(entries, original_rows)
        current_rows = deepcopy(original_rows)
        current_rows[0]["clues"][0]["hint"] = "Changed elsewhere"

        errors, _ = repair.validate_report(entries, report, current_rows)

        self.assertEqual(len(errors), 1)
        self.assertIn("Supabase clue changed since export", errors[0])

    def test_validate_rejects_stale_word_bank_source(self) -> None:
        entries = [word_entry()]
        rows = [puzzle_row("2026-07-12")]
        report = report_for(entries, rows)
        entries[0]["clues"][1] = "Changed bank clue"

        errors, _ = repair.validate_report(entries, report, rows)

        self.assertEqual(len(errors), 1)
        self.assertIn("word-bank source clue changed since export", errors[0])

    def test_prepare_updates_groups_row_changes_and_preserves_other_fields(self) -> None:
        entries = [word_entry(), {**word_entry(), "word": "COMET", "clues": ["Same clue", "Icy visitor"]}]
        duplicate_two = puzzle_clue(
            clue_id=5,
            answer="COMET",
            number=8,
            direction="down",
        )
        unrelated = puzzle_clue(clue_id=7, text="Already distinct", hint="Different hint")
        rows = [puzzle_row("2026-07-12", [puzzle_clue(), duplicate_two, unrelated])]
        original_unrelated = deepcopy(unrelated)
        report = report_for(entries, rows)

        updates, already_applied = repair.prepare_updates(entries, report, rows)

        self.assertEqual(len(updates), 1)
        self.assertEqual(already_applied, 0)
        self.assertEqual(updates[0]["clues"][0]["text"], "Circular path")
        self.assertEqual(updates[0]["clues"][0]["textSourceIndex"], 1)
        self.assertEqual(updates[0]["clues"][1]["text"], "Icy visitor")
        self.assertEqual(updates[0]["clues"][2], original_unrelated)
        self.assertEqual(rows[0]["clues"][0]["text"], "Same clue")

    def test_prepare_updates_is_idempotent(self) -> None:
        entries = [word_entry()]
        rows = [puzzle_row("2026-07-12")]
        report = report_for(entries, rows)
        first_updates, _ = repair.prepare_updates(entries, report, rows)

        second_updates, already_applied = repair.prepare_updates(entries, report, first_updates)

        self.assertEqual(second_updates, [])
        self.assertEqual(already_applied, 1)

    def test_prepare_updates_skips_unresolved_items(self) -> None:
        clue = puzzle_clue(answer="MISSING")
        rows = [puzzle_row("2026-07-12", [clue])]
        report = report_for([word_entry()], rows)

        updates, already_applied = repair.prepare_updates([word_entry()], report, [])

        self.assertEqual(updates, [])
        self.assertEqual(already_applied, 0)

    def test_validate_rejects_future_report_cutoff(self) -> None:
        report = report_for([word_entry()], [], "2999-01-01")

        errors, _ = repair.validate_report([word_entry()], report, [])

        self.assertIn("Report cutoff 2999-01-01 is later than today", errors)


if __name__ == "__main__":
    unittest.main()
