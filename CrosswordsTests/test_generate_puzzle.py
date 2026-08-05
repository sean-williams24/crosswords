import random
import sys
import unittest
from collections import deque
from datetime import date
from pathlib import Path
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parents[1] / "Backend"
sys.path.insert(0, str(BACKEND_DIR))

import generate_puzzle
import generate_weekly_puzzle
from crossword_answer_similarity import AnswerSimilarityIndex, are_too_similar_answers


def line_runs(line: list[bool]) -> list[int]:
    runs = []
    current = 0
    for is_white in line + [False]:
        if is_white:
            current += 1
        elif current:
            runs.append(current)
            current = 0
    return runs


def transformed_template_keys(template: list[list[bool]]) -> set[tuple]:
    def rotate(grid: list[list[bool]]) -> list[list[bool]]:
        return [list(row) for row in zip(*grid[::-1])]

    def reflect(grid: list[list[bool]]) -> list[list[bool]]:
        return [row[::-1] for row in grid]

    keys = set()
    current = [row[:] for row in template]
    for _ in range(4):
        keys.add(tuple(tuple(row) for row in current))
        keys.add(tuple(tuple(row) for row in reflect(current)))
        current = rotate(current)
    return keys


def slot_signature(slots: list[generate_puzzle.Slot]) -> tuple:
    return tuple(
        sorted((slot.direction, slot.row, slot.col, slot.length) for slot in slots)
    )


class DailyTemplateTests(unittest.TestCase):
    def test_daily_template_pool_has_expected_size(self) -> None:
        eligible = generate_puzzle.daily_template_indices()

        self.assertEqual(12, len(eligible))
        self.assertEqual(
            generate_puzzle.TARGET_DAILY_TEMPLATE_COUNT,
            len(eligible),
        )
        self.assertEqual(13, len(generate_puzzle.TEMPLATES) - len(eligible))

    def test_eligible_templates_meet_structure_and_length_rules(self) -> None:
        for index in generate_puzzle.daily_template_indices():
            template = generate_puzzle.TEMPLATES[index]
            slots = generate_puzzle.extract_slots(template)

            self.assertTrue(
                all(
                    template[row][col]
                    == template[generate_puzzle.GRID_SIZE - 1 - row][
                        generate_puzzle.GRID_SIZE - 1 - col
                    ]
                    for row in range(generate_puzzle.GRID_SIZE)
                    for col in range(generate_puzzle.GRID_SIZE)
                ),
                f"Template {index} is not rotationally symmetric",
            )

            runs = []
            for row in template:
                runs.extend(line_runs(row))
            for col in range(generate_puzzle.GRID_SIZE):
                runs.extend(line_runs([row[col] for row in template]))
            self.assertNotIn(2, runs, f"Template {index} contains a 2-cell run")

            white_cells = {
                (row, col)
                for row in range(generate_puzzle.GRID_SIZE)
                for col in range(generate_puzzle.GRID_SIZE)
                if template[row][col]
            }
            covered_cells = {cell for slot in slots for cell in slot.cells}
            self.assertEqual(
                white_cells,
                covered_cells,
                f"Template {index} contains an orphaned white cell",
            )
            if index >= generate_puzzle.LEGACY_TEMPLATE_COUNT:
                self.assertTrue(
                    self.is_connected(white_cells),
                    f"New template {index} is disconnected",
                )

            three_letter_count = sum(slot.length == 3 for slot in slots)
            long_word_count = sum(
                slot.length >= generate_puzzle.MIN_LONG_WORD_LENGTH for slot in slots
            )
            self.assertLessEqual(
                three_letter_count,
                generate_puzzle.MAX_THREE_LETTER_SLOTS,
            )
            self.assertGreaterEqual(
                long_word_count,
                generate_puzzle.MIN_LONG_WORD_SLOTS,
            )
            self.assertLessEqual(
                max(slot.length for slot in slots),
                generate_puzzle.MAX_DAILY_WORD_LENGTH,
            )
            self.assertLessEqual(generate_puzzle.MIN_DAILY_CLUES, len(slots))
            self.assertLessEqual(len(slots), generate_puzzle.MAX_DAILY_CLUES)

    def test_new_templates_all_include_seven_or_eight_letter_answers(self) -> None:
        eligible = set(generate_puzzle.daily_template_indices())
        new_indices = set(
            range(generate_puzzle.LEGACY_TEMPLATE_COUNT, len(generate_puzzle.TEMPLATES))
        )

        self.assertEqual(9, len(new_indices))
        self.assertTrue(new_indices.issubset(eligible))
        for index in new_indices:
            slots = generate_puzzle.extract_slots(generate_puzzle.TEMPLATES[index])
            self.assertTrue(any(7 <= slot.length <= 8 for slot in slots))

    def test_eligible_templates_are_unique_under_rotation_and_reflection(self) -> None:
        canonical_keys = []
        for index in generate_puzzle.daily_template_indices():
            variants = transformed_template_keys(generate_puzzle.TEMPLATES[index])
            canonical_keys.append(min(variants))

        self.assertEqual(len(canonical_keys), len(set(canonical_keys)))

    def test_generator_only_attempts_eligible_unexcluded_templates(self) -> None:
        attempted_slots = []

        def reject_solution(slots, _word_bank, _rng):
            attempted_slots.append(slots)
            return None

        word_bank = {
            length: [{"word": "A" * length}]
            for length in range(3, generate_puzzle.MAX_DAILY_WORD_LENGTH + 1)
        }
        excluded = {generate_puzzle.daily_template_indices()[0]}

        with patch.object(generate_puzzle, "solve_grid", side_effect=reject_solution), \
             patch("builtins.print"):
            result = generate_puzzle.generate_puzzle(
                word_bank,
                seed=7,
                excluded_template_indices=excluded,
            )

        self.assertIsNone(result)
        self.assertEqual(
            (generate_puzzle.TARGET_DAILY_TEMPLATE_COUNT - 1) * 5,
            len(attempted_slots),
        )
        expected_signatures = {
            slot_signature(generate_puzzle.extract_slots(generate_puzzle.TEMPLATES[index]))
            for index in generate_puzzle.daily_template_indices()
            if index not in excluded
        }
        self.assertEqual(
            expected_signatures,
            {slot_signature(slots) for slots in attempted_slots},
        )
        for slots in attempted_slots:
            self.assertLessEqual(
                sum(slot.length == 3 for slot in slots),
                generate_puzzle.MAX_THREE_LETTER_SLOTS,
            )

    def test_batch_uses_every_template_before_starting_a_new_cycle(self) -> None:
        used = set()
        first_cycle = []
        word_bank = {
            length: [{"word": "A" * length}]
            for length in range(3, generate_puzzle.MAX_DAILY_WORD_LENGTH + 1)
        }

        def accept_first_slot(slots, _word_bank, _rng):
            slot = slots[0]
            return [{
                "slot": slot,
                "entry": {
                    "word": "A" * slot.length,
                    "text": "Test clue",
                    "hint": "Test hint",
                },
            }]

        with patch.object(generate_puzzle, "solve_grid", side_effect=accept_first_slot), \
             patch("builtins.print"):
            for seed in range(generate_puzzle.TARGET_DAILY_TEMPLATE_COUNT):
                used = generate_puzzle.template_exclusions_for_next_puzzle(used)
                raw = generate_puzzle.generate_puzzle(
                    word_bank,
                    seed=seed,
                    excluded_template_indices=used,
                )
                self.assertIsNotNone(raw)
                template_index = raw["_template_index"]
                first_cycle.append(template_index)
                used.add(template_index)

            self.assertEqual(len(first_cycle), len(set(first_cycle)))
            self.assertEqual(7, len(set(first_cycle[:7])))
            self.assertEqual(
                set(),
                generate_puzzle.template_exclusions_for_next_puzzle(used),
            )

    @staticmethod
    def is_connected(white_cells: set[tuple[int, int]]) -> bool:
        start = next(iter(white_cells))
        visited = {start}
        pending = deque([start])
        while pending:
            row, col = pending.popleft()
            for row_delta, col_delta in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                neighbour = (row + row_delta, col + col_delta)
                if neighbour in white_cells and neighbour not in visited:
                    visited.add(neighbour)
                    pending.append(neighbour)
        return visited == white_cells


class CrosswordAnswerSimilarityTests(unittest.TestCase):
    def test_rejects_observed_shared_stem_pair(self) -> None:
        self.assertTrue(are_too_similar_answers("INVERSE", "INVERTER"))

    def test_rejects_contained_answer(self) -> None:
        self.assertTrue(are_too_similar_answers("INVERT", "INVERTER"))

    def test_allows_unrelated_answers(self) -> None:
        self.assertFalse(are_too_similar_answers("MARBLE", "PLANET"))

    def test_allows_same_prefix_answers_that_are_not_close_spellings(self) -> None:
        self.assertFalse(are_too_similar_answers("PROVIDER", "PROVISION"))

    def test_preserves_distinct_short_answers(self) -> None:
        self.assertFalse(are_too_similar_answers("CART", "CARD"))

    def test_rejects_duplicate_answer_regardless_of_punctuation(self) -> None:
        self.assertTrue(are_too_similar_answers("O'REILLY", "OREILLY"))

    def test_index_rejects_similar_and_contained_answers(self) -> None:
        index = AnswerSimilarityIndex()
        index.add("INVERSE")
        index.add("SOMETHING")

        self.assertFalse(index.is_available("INVERTER"))
        self.assertFalse(index.is_available("THING"))
        self.assertTrue(index.is_available("MARBLE"))

        index.remove("INVERSE")
        self.assertTrue(index.is_available("INVERTER"))

    def test_daily_and_weekly_solvers_reject_similar_answers(self) -> None:
        word_bank = {
            7: [{"word": "INVERSE"}],
            8: [{"word": "INVERTER"}],
        }

        for generator in (generate_puzzle, generate_weekly_puzzle):
            with self.subTest(generator=generator.__name__):
                slots = [
                    generator.Slot(0, 0, "across", 7),
                    generator.Slot(2, 0, "across", 8),
                ]
                self.assertIsNone(generator.solve_grid(slots, word_bank, random.Random(1)))

    def test_daily_and_weekly_solvers_use_distinct_alternative(self) -> None:
        word_bank = {
            7: [{"word": "INVERSE"}],
            8: [{"word": "INVERTER"}, {"word": "OUTBURST"}],
        }

        for generator in (generate_puzzle, generate_weekly_puzzle):
            with self.subTest(generator=generator.__name__):
                slots = [
                    generator.Slot(0, 0, "across", 7),
                    generator.Slot(2, 0, "across", 8),
                ]
                solution = generator.solve_grid(slots, word_bank, random.Random(1))

                self.assertIsNotNone(solution)
                self.assertEqual(
                    {"INVERSE", "OUTBURST"},
                    {item["entry"]["word"] for item in solution},
                )


class WeeklyPuzzleScheduleTests(unittest.TestCase):
    def test_repairs_earliest_gap_even_when_future_buffer_is_full(self) -> None:
        rows = [
            {"puzzle_number": 21, "date": "2026-08-02"},
            {"puzzle_number": 22, "date": "2026-08-09"},
            {"puzzle_number": 23, "date": "2026-08-16"},
            {"puzzle_number": 25, "date": "2026-08-30"},
            {"puzzle_number": 26, "date": "2026-09-06"},
            {"puzzle_number": 27, "date": "2026-09-13"},
            {"puzzle_number": 28, "date": "2026-09-20"},
        ]

        plan = generate_weekly_puzzle.plan_weekly_generation(
            rows,
            release_sunday=date(2026, 8, 2),
        )

        self.assertEqual(plan.reason, "repair_gap")
        self.assertEqual(plan.count, 1)
        self.assertEqual(plan.start.puzzle_number, 24)
        self.assertEqual(plan.start.puzzle_date, date(2026, 8, 23))
        self.assertEqual(plan.future_count, 6)

    def test_tops_up_only_to_three_future_sundays(self) -> None:
        rows = [
            {"puzzle_number": 21, "date": "2026-08-02"},
            {"puzzle_number": 22, "date": "2026-08-09"},
        ]

        plan = generate_weekly_puzzle.plan_weekly_generation(
            rows,
            release_sunday=date(2026, 8, 2),
        )

        self.assertEqual(plan.reason, "top_up_buffer")
        self.assertEqual(plan.count, 2)
        self.assertEqual(plan.start.puzzle_number, 23)
        self.assertEqual(plan.start.puzzle_date, date(2026, 8, 16))

    def test_rejects_number_date_mismatch_that_cannot_be_repaired_safely(self) -> None:
        rows = [
            {"puzzle_number": 23, "date": "2026-08-16"},
            {"puzzle_number": 25, "date": "2026-08-23"},
        ]

        with self.assertRaisesRegex(ValueError, "inconsistent"):
            generate_weekly_puzzle.plan_weekly_generation(
                rows,
                release_sunday=date(2026, 8, 2),
            )


class WeeklyPuzzleGenerationTests(unittest.TestCase):
    def test_generation_failure_retries_same_slot_before_advancing(self) -> None:
        attempts = iter([None, {"answer": "FIRST"}, {"answer": "SECOND"}])
        uploaded_slots = []

        def payload_builder(raw, puzzle_number, puzzle_date):
            return {
                "puzzle_number": puzzle_number,
                "date": puzzle_date,
                "clues": [{"answer": raw["answer"]}],
            }

        result = generate_weekly_puzzle.generate_scheduled_puzzles(
            {3: []},
            count=2,
            start_number=24,
            start_date=date(2026, 8, 23),
            exclude=set(),
            dry_run=False,
            output=None,
            seed=1,
            max_runtime_seconds=None,
            generator=lambda _bank, seed: next(attempts),
            validator=lambda _raw: True,
            payload_builder=payload_builder,
            uploader=lambda payload: uploaded_slots.append((payload["puzzle_number"], payload["date"])),
        )

        self.assertFalse(result.timed_out)
        self.assertEqual(result.generated, 2)
        self.assertEqual(uploaded_slots, [(24, "2026-08-23"), (25, "2026-08-30")])

    def test_unconfirmed_upload_failure_retries_same_slot(self) -> None:
        attempts = iter([{"answer": "FIRST"}, {"answer": "SECOND"}])
        upload_attempts = []

        def uploader(payload):
            upload_attempts.append((payload["puzzle_number"], payload["date"]))
            if len(upload_attempts) == 1:
                raise RuntimeError("temporary outage")

        result = generate_weekly_puzzle.generate_scheduled_puzzles(
            {3: []},
            count=1,
            start_number=24,
            start_date=date(2026, 8, 23),
            exclude=set(),
            dry_run=False,
            output=None,
            seed=1,
            max_runtime_seconds=None,
            generator=lambda _bank, seed: next(attempts),
            validator=lambda _raw: True,
            payload_builder=lambda raw, number, puzzle_date: {
                "puzzle_number": number,
                "date": puzzle_date,
                "clues": [{"answer": raw["answer"]}],
            },
            uploader=uploader,
            uploaded_exists=lambda _payload: False,
        )

        self.assertEqual(result.generated, 1)
        self.assertEqual(upload_attempts, [(24, "2026-08-23"), (24, "2026-08-23")])

    def test_generation_deadline_leaves_current_slot_unresolved(self) -> None:
        times = iter([0.0, 0.0, 6.0])
        generation_attempts = []

        result = generate_weekly_puzzle.generate_scheduled_puzzles(
            {3: []},
            count=1,
            start_number=24,
            start_date=date(2026, 8, 23),
            exclude=set(),
            dry_run=True,
            output=None,
            seed=1,
            max_runtime_seconds=5,
            generator=lambda _bank, seed: generation_attempts.append(seed) or None,
            validator=lambda _raw: True,
            clock=lambda: next(times),
        )

        self.assertTrue(result.timed_out)
        self.assertEqual(result.generated, 0)
        self.assertEqual(len(generation_attempts), 1)


if __name__ == "__main__":
    unittest.main()
