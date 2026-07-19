import sys
import unittest
from collections import deque
from pathlib import Path
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parents[1] / "Backend"
sys.path.insert(0, str(BACKEND_DIR))

import generate_puzzle


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


if __name__ == "__main__":
    unittest.main()
