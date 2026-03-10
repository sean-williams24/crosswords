"""
Crossword Puzzle Generator (Algorithmic)
=========================================

Generates daily crossword puzzles using a built-in word bank and
constraint-satisfaction backtracking. No API keys required.

Usage:
    python generate_puzzle.py --count 7        # Generate 7 puzzles
    python generate_puzzle.py --date 2026-03-14 # Generate for specific date
    python generate_puzzle.py --dry-run         # Generate without uploading
    python generate_puzzle.py --output puzzles  # Save JSON files locally

Environment Variables (only needed for upload):
    SUPABASE_URL  — Your Supabase project URL
    SUPABASE_KEY  — Your Supabase service-role key (NOT anon key)
"""

import argparse
import json
import os
import random
import sys
from datetime import date, timedelta
from pathlib import Path

GRID_SIZE = 9
TARGET_CLUES = 15

# ── Grid Templates ──────────────────────────────────────────────────────────
# Each template is a 9×9 grid. True = white (letter), False = black square.
# Templates have 180° rotational symmetry (standard crossword convention).

def _t(s: str) -> list[list[bool]]:
    """Parse a compact template string into a 9×9 bool grid.
    '#' = black, '.' = white. Whitespace is ignored."""
    chars = [c for c in s if c in '.#']
    assert len(chars) == 81, f"Template has {len(chars)} cells, expected 81"
    return [[chars[r * 9 + c] == '.' for c in range(9)] for r in range(9)]


# All templates have 180° rotational symmetry. No 2-cell runs.
# Every run is length 1 (part of perpendicular word only) or ≥ 3 (word slot, max 6).
TEMPLATES = [
    _t("""
        #.....##.
        ...###...
        #......#.
        .##.#....
        .#.....#.
        ....#.##.
        .#......#
        ...###...
        .##.....#
    """),
    _t("""
        ####....#
        .....##.#
        .#......#
        .....#...
        ....#....
        ...#.....
        #......#.
        #.##.....
        #....####
    """),
    _t("""
        ...#.....
        #.....###
        ...#.....
        #.....##.
        .#.###.#.
        .##.....#
        .....#...
        ###.....#
        .....#...
    """),
    _t("""
        ...#...#.
        #....#.#.
        #......#.
        #....#.#.
        #.#.#.#.#
        .#.#....#
        .#......#
        .#.#....#
        .#...#...
    """),
    _t("""
        #......#.
        .#.###.#.
        ....#....
        .#....#.#
        ....#....
        #.#....#.
        ....#....
        .#.###.#.
        .#......#
    """),
    _t("""
        #...##...
        .##....##
        .....#...
        .##....#.
        ....#....
        .#....##.
        ...#.....
        ##....##.
        ...##...#
    """),
    _t("""
        ......##.
        .##....#.
        .#.....#.
        .#......#
        .#.###.#.
        #......#.
        .#.....#.
        .#....##.
        .##......
    """),
    _t("""
        #......#.
        .#.#.#.#.
        ...#.#...
        ....#....
        #.#####.#
        ....#....
        ...#.#...
        .#.#.#.#.
        .#......#
    """),
    _t("""
        .#.....#.
        ...##....
        .#.#...#.
        #...#....
        .#######.
        ....#...#
        .#...#.#.
        ....##...
        .#.....#.
    """),
    _t("""
        #...#.#.#
        .#......#
        ......#.#
        .#.#.....
        #...#...#
        .....#.#.
        #.#......
        #......#.
        #.#.#...#
    """),
    _t("""
        ...#.#.#.
        ##.....#.
        ...#.#.#.
        #.#......
        ...###...
        ......#.#
        .#.#.#...
        .#.....##
        .#.#.#...
    """),
    _t("""
        .....#...
        ...##.#.#
        ......#.#
        .#.....#.
        .#.....#.
        .#.....#.
        #.#......
        #.#.##...
        ...#.....
    """),
    _t("""
        ....##.#.
        #....#.#.
        .....#.#.
        #....#...
        #.#.#.#.#
        ...#....#
        .#.#.....
        .#.#....#
        .#.##....
    """),
    _t("""
        ...###.#.
        #.#......
        .....#...
        #.#......
        .#.###.#.
        ......#.#
        ...#.....
        ......#.#
        .#.###...
    """),
    _t("""
        ...#.....
        .##.##.#.
        .##......
        .#.....#.
        ##.....##
        .#.....#.
        ......##.
        .#.##.##.
        .....#...
    """),
    _t("""
        .....#...
        ##.#.#.#.
        ...#.#...
        ###....#.
        ....#....
        .#....###
        ...#.#...
        .#.#.#.##
        ...#.....
    """),
    _t("""
        #.#.#....
        #.....##.
        ....#....
        #...##.#.
        ...###...
        .#.##...#
        ....#....
        .##.....#
        ....#.#.#
    """),
    _t("""
        ......#.#
        #.#.#....
        ......#.#
        ##.#....#
        ...#.#...
        #....#.##
        #.#......
        ....#.#.#
        #.#......
    """),
]


# ── Word Bank ───────────────────────────────────────────────────────────────

def load_word_bank() -> dict[int, list[dict]]:
    """Load word bank and organize by length."""
    bank_path = Path(__file__).parent / "word_bank.json"
    with open(bank_path) as f:
        words = json.load(f)

    by_length: dict[int, list[dict]] = {}
    for w in words:
        length = len(w["word"])
        by_length.setdefault(length, []).append(w)

    return by_length


# ── Slot Extraction ─────────────────────────────────────────────────────────

class Slot:
    """A word slot in the grid defined by position, direction, and length."""

    def __init__(self, row: int, col: int, direction: str, length: int):
        self.row = row
        self.col = col
        self.direction = direction
        self.length = length
        self.cells: list[tuple[int, int]] = []
        for i in range(length):
            if direction == "across":
                self.cells.append((row, col + i))
            else:
                self.cells.append((row + i, col))

    def __repr__(self):
        return f"Slot({self.direction}, ({self.row},{self.col}), len={self.length})"


def extract_slots(template: list[list[bool]]) -> list[Slot]:
    """Find all word slots (length >= 3) from a grid template."""
    slots = []
    size = len(template)

    # Across slots
    for r in range(size):
        c = 0
        while c < size:
            if template[r][c]:
                start = c
                while c < size and template[r][c]:
                    c += 1
                length = c - start
                if length >= 3:
                    slots.append(Slot(r, start, "across", length))
            else:
                c += 1

    # Down slots
    for c in range(size):
        r = 0
        while r < size:
            if template[r][c]:
                start = r
                while r < size and template[r][c]:
                    r += 1
                length = r - start
                if length >= 3:
                    slots.append(Slot(start, c, "down", length))
            else:
                r += 1

    return slots


# ── Constraint-Satisfaction Solver ──────────────────────────────────────────

def solve_grid(
    slots: list[Slot],
    word_bank: dict[int, list[dict]],
    rng: random.Random,
) -> list[dict] | None:
    """
    Fill all slots using backtracking with constraint propagation.
    Returns list of {slot, word_entry} dicts or None if unsolvable.
    """
    MAX_BACKTRACKS = 500_000
    MAX_CANDIDATES_PER_SLOT = 100
    MAX_SECONDS = 30  # time limit per solve attempt

    import time
    start_time = time.monotonic()

    # Map cells to list of (slot_index, position_in_slot) for intersection detection
    cell_to_slots: dict[tuple[int, int], list[tuple[int, int]]] = {}
    for si, slot in enumerate(slots):
        for pi, cell in enumerate(slot.cells):
            cell_to_slots.setdefault(cell, []).append((si, pi))

    # Pre-filter word bank entries by length and shuffle
    candidates_by_length: dict[int, list[dict]] = {}
    for length, entries in word_bank.items():
        shuffled = entries[:]
        rng.shuffle(shuffled)
        candidates_by_length[length] = shuffled

    # Build position-letter index: words_index[length][position][letter] -> set of word strings
    words_index: dict[int, dict[int, dict[str, set[str]]]] = {}
    word_to_entry: dict[str, dict] = {}
    all_words_by_length: dict[int, list[str]] = {}
    for length, entries in candidates_by_length.items():
        words_index[length] = {}
        all_words_by_length[length] = []
        for entry in entries:
            word = entry["word"].upper()
            word_to_entry[word] = entry
            all_words_by_length[length].append(word)
            for pos, ch in enumerate(word):
                words_index[length].setdefault(pos, {}).setdefault(ch, set()).add(word)

    # State
    assignment: list[dict | None] = [None] * len(slots)
    used_words: set[str] = set()
    grid_letters: dict[tuple[int, int], str] = {}
    backtrack_count = [0]

    def _constraint_sets(si: int) -> list[set[str]] | None:
        """Get sorted list of constraint sets for slot si. Returns None if impossible."""
        slot = slots[si]
        length = slot.length
        idx = words_index.get(length)
        if not idx:
            return None
        sets = []
        for pi, cell in enumerate(slot.cells):
            if cell in grid_letters:
                ch = grid_letters[cell]
                matching = idx.get(pi, {}).get(ch)
                if not matching:
                    return None
                sets.append(matching)
        return sets

    def get_candidates(si: int) -> list[dict]:
        """Get valid candidates for slot si given current assignments."""
        sets = _constraint_sets(si)
        if sets is None:
            return []

        slot = slots[si]
        if not sets:
            # No constraints — use pre-shuffled order
            result = []
            for w in all_words_by_length.get(slot.length, []):
                if w not in used_words:
                    result.append(word_to_entry[w])
                    if len(result) >= MAX_CANDIDATES_PER_SLOT:
                        break
            return result

        # Sort by smallest set first, iterate through it
        sets.sort(key=len)
        smallest = sets[0]
        rest = sets[1:]
        feasible = set()
        for word in smallest:
            if word not in used_words and all(word in s for s in rest):
                feasible.add(word)

        # Maintain pre-shuffled order
        ordered = [w for w in all_words_by_length.get(slot.length, []) if w in feasible]
        return [word_to_entry[w] for w in ordered[:MAX_CANDIDATES_PER_SLOT]]

    def has_any_candidate(si: int) -> bool:
        """Quick check: does slot si have at least one valid candidate?"""
        sets = _constraint_sets(si)
        if sets is None:
            return False

        if not sets:
            # No constraints — any unused word works
            slot = slots[si]
            for w in all_words_by_length.get(slot.length, []):
                if w not in used_words:
                    return True
            return False

        # Iterate through smallest set
        sets.sort(key=len)
        smallest = sets[0]
        rest = sets[1:]
        for word in smallest:
            if word not in used_words and all(word in s for s in rest):
                return True
        return False

    # Sort slots by most constrained first (most intersections, fewest candidates)
    slot_order = list(range(len(slots)))

    def slot_constraint_score(si: int) -> tuple:
        slot = slots[si]
        intersections = sum(
            1 for cell in slot.cells if len(cell_to_slots.get(cell, [])) > 1
        )
        num_candidates = len(candidates_by_length.get(slot.length, []))
        return (-intersections, num_candidates)

    slot_order.sort(key=slot_constraint_score)

    assigned_set = set()

    def forward_check_neighbors(si: int) -> bool:
        """Check that unassigned slots sharing cells with slot si still have candidates."""
        slot = slots[si]
        checked = set()
        for cell in slot.cells:
            for sj, _ in cell_to_slots.get(cell, []):
                if sj != si and sj not in assigned_set and sj not in checked:
                    checked.add(sj)
                    if not has_any_candidate(sj):
                        return False
        return True

    def backtrack(idx: int) -> bool:
        if backtrack_count[0] > MAX_BACKTRACKS:
            return False
        if time.monotonic() - start_time > MAX_SECONDS:
            return False

        if idx == len(slot_order):
            return True

        backtrack_count[0] += 1
        si = slot_order[idx]
        slot = slots[si]
        candidates = get_candidates(si)

        for entry in candidates:
            word = entry["word"].upper()

            # Place word
            used_words.add(word)
            assigned_set.add(si)
            placed_cells: list[tuple[tuple[int, int], str | None]] = []
            for pi, cell in enumerate(slot.cells):
                old = grid_letters.get(cell)
                placed_cells.append((cell, old))
                grid_letters[cell] = word[pi]

            assignment[si] = entry

            # Forward check: ensure neighboring slots still have candidates
            if forward_check_neighbors(si):
                if backtrack(idx + 1):
                    return True

            # Undo
            assignment[si] = None
            assigned_set.discard(si)
            used_words.discard(word)
            for cell, old in placed_cells:
                if old is None:
                    del grid_letters[cell]
                else:
                    grid_letters[cell] = old

        return False

    if backtrack(0):
        return [
            {"slot": slots[si], "entry": assignment[si]}
            for si in range(len(slots))
            if assignment[si] is not None
        ]
    return None


# ── Puzzle Assembly ─────────────────────────────────────────────────────────

def assemble_raw(
    template: list[list[bool]],
    solution: list[dict],
) -> dict:
    """Convert solver output to the raw format used by validate/build."""
    grid = [
        [None] * GRID_SIZE for _ in range(GRID_SIZE)
    ]

    # Fill grid letters
    for item in solution:
        slot: Slot = item["slot"]
        word = item["entry"]["word"].upper()
        for pi, (r, c) in enumerate(slot.cells):
            grid[r][c] = word[pi]

    # Build words list
    words = []
    for item in solution:
        slot: Slot = item["slot"]
        entry = item["entry"]
        words.append({
            "direction": slot.direction,
            "number": 0,  # assigned later by build_puzzle_payload
            "answer": entry["word"].upper(),
            "text": entry["text"],
            "hint": entry["hint"],
            "startRow": slot.row,
            "startCol": slot.col,
        })

    return {"grid": grid, "words": words}


def generate_puzzle(word_bank: dict[int, list[dict]], seed: int | None = None) -> dict | None:
    """Generate a single puzzle. Returns raw dict or None on failure."""
    rng = random.Random(seed)

    # Try templates in shuffled order, with multiple attempts per template
    template_indices = list(range(len(TEMPLATES)))
    rng.shuffle(template_indices)

    for ti in template_indices:
        template = TEMPLATES[ti]
        slots = extract_slots(template)

        # Check we have words for all required lengths
        lengths_needed = {s.length for s in slots}
        if not all(len(word_bank.get(l, [])) >= 1 for l in lengths_needed):
            continue

        # Try up to 5 times with different random shuffles
        for attempt in range(5):
            sub_rng = random.Random(rng.randint(0, 2**31) + attempt)
            print(f"  Template {ti} attempt {attempt+1}/5 ({len(slots)} slots)...", end=" ", flush=True)
            solution = solve_grid(slots, word_bank, sub_rng)
            if solution:
                print("SUCCESS")
                return assemble_raw(template, solution)
            else:
                print("failed")

    return None


# ── Validation ──────────────────────────────────────────────────────────────

def validate_puzzle(raw: dict) -> bool:
    """Validate the generated puzzle structure."""
    grid = raw.get("grid", [])
    words = raw.get("words", [])

    if len(grid) != GRID_SIZE:
        print(f"  ERROR: Grid has {len(grid)} rows, expected {GRID_SIZE}")
        return False

    for i, row in enumerate(grid):
        if len(row) != GRID_SIZE:
            print(f"  ERROR: Row {i} has {len(row)} columns, expected {GRID_SIZE}")
            return False

    if len(words) < 10 or len(words) > 25:
        print(f"  WARNING: {len(words)} clues (expected ~{TARGET_CLUES})")

    # Verify each word matches the grid
    for word in words:
        answer = word["answer"]
        r, c = word["startRow"], word["startCol"]
        direction = word["direction"]

        for i, letter in enumerate(answer):
            gr = r + (i if direction == "down" else 0)
            gc = c + (i if direction == "across" else 0)

            if gr >= GRID_SIZE or gc >= GRID_SIZE:
                print(f"  ERROR: Word '{answer}' goes out of bounds at ({gr},{gc})")
                return False

            if grid[gr][gc] is None:
                print(f"  ERROR: Word '{answer}' overlaps black square at ({gr},{gc})")
                return False

            if grid[gr][gc].upper() != letter.upper():
                print(
                    f"  ERROR: Word '{answer}' letter mismatch at ({gr},{gc}): "
                    f"grid='{grid[gr][gc]}', expected='{letter}'"
                )
                return False

        for field in ["text", "hint"]:
            if not word.get(field):
                print(f"  ERROR: Word '{answer}' missing '{field}'")
                return False

    print(f"  Valid: {len(words)} clues, {GRID_SIZE}x{GRID_SIZE} grid")
    return True


# ── Payload Builder ─────────────────────────────────────────────────────────

def build_puzzle_payload(raw: dict, puzzle_number: int, puzzle_date: str) -> dict:
    """Convert raw generation output to the Supabase-ready payload."""
    grid = raw["grid"]
    words = raw["words"]

    # Assign clue numbers
    clue_number = 0
    number_map = {}

    for r in range(GRID_SIZE):
        for c in range(GRID_SIZE):
            if grid[r][c] is None:
                continue
            needs_across = (c == 0 or grid[r][c - 1] is None) and (
                c + 1 < GRID_SIZE and grid[r][c + 1] is not None
            )
            needs_down = (r == 0 or grid[r - 1][c] is None) and (
                r + 1 < GRID_SIZE and grid[r + 1][c] is not None
            )
            if needs_across or needs_down:
                clue_number += 1
                number_map[(r, c)] = clue_number

    # Build clues with IDs
    clue_id = 0
    clues = []
    across_ids = [[None] * GRID_SIZE for _ in range(GRID_SIZE)]
    down_ids = [[None] * GRID_SIZE for _ in range(GRID_SIZE)]

    for word in words:
        r, c = word["startRow"], word["startCol"]
        num = number_map.get((r, c), 0)
        length = len(word["answer"])

        clue = {
            "id": clue_id,
            "direction": word["direction"],
            "number": num,
            "text": word["text"],
            "hint": word["hint"],
            "answer": word["answer"].upper(),
            "startRow": r,
            "startCol": c,
            "length": length,
        }
        clues.append(clue)

        for i in range(length):
            cr = r + (i if word["direction"] == "down" else 0)
            cc = c + (i if word["direction"] == "across" else 0)
            if word["direction"] == "across":
                across_ids[cr][cc] = clue_id
            else:
                down_ids[cr][cc] = clue_id

        clue_id += 1

    # Build cells
    cells = []
    for r in range(GRID_SIZE):
        row_cells = []
        for c in range(GRID_SIZE):
            letter = grid[r][c]
            row_cells.append(
                {
                    "letter": letter.upper() if letter else None,
                    "clueNumber": number_map.get((r, c)),
                    "acrossClueId": across_ids[r][c],
                    "downClueId": down_ids[r][c],
                }
            )
        cells.append(row_cells)

    return {
        "puzzle_number": puzzle_number,
        "date": puzzle_date,
        "grid_data": {"size": GRID_SIZE, "cells": cells},
        "clues": clues,
        "is_free": True,
    }


# ── Supabase Upload ────────────────────────────────────────────────────────

def upload_to_supabase(payload: dict):
    """Upload a puzzle to Supabase."""
    try:
        from supabase import create_client
    except ImportError:
        print("Install supabase: pip install supabase-py")
        sys.exit(1)

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        print("Set SUPABASE_URL and SUPABASE_KEY environment variables")
        sys.exit(1)

    client = create_client(url, key)
    result = client.table("puzzles").insert(payload).execute()
    print(f"  Uploaded puzzle #{payload['puzzle_number']} for {payload['date']}")
    return result


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generate crossword puzzles")
    parser.add_argument(
        "--count", type=int, default=1, help="Number of puzzles to generate"
    )
    parser.add_argument("--date", type=str, help="Start date (YYYY-MM-DD)")
    parser.add_argument(
        "--start-number", type=int, default=1, help="Starting puzzle number"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Generate without uploading"
    )
    parser.add_argument("--output", type=str, help="Output directory for JSON files")
    parser.add_argument("--seed", type=int, help="Random seed for reproducibility")
    args = parser.parse_args()

    print("Loading word bank...")
    word_bank = load_word_bank()
    total_words = sum(len(v) for v in word_bank.values())
    print(f"  {total_words} words loaded ({', '.join(f'{k}-letter: {len(v)}' for k, v in sorted(word_bank.items()))})")

    start_date = (
        date.fromisoformat(args.date) if args.date else date.today() + timedelta(days=1)
    )

    generated = 0
    for i in range(args.count):
        puzzle_number = args.start_number + i
        puzzle_date = (start_date + timedelta(days=i)).isoformat()
        seed = (args.seed + i) if args.seed is not None else (hash(puzzle_date) & 0xFFFFFFFF)

        print(f"\nGenerating puzzle #{puzzle_number} for {puzzle_date} (seed={seed})...")

        raw = generate_puzzle(word_bank, seed=seed)
        if raw is None:
            print("  Generation failed: could not fill grid")
            continue

        if not validate_puzzle(raw):
            print("  Validation failed, skipping.")
            continue

        payload = build_puzzle_payload(raw, puzzle_number, puzzle_date)

        if args.output:
            os.makedirs(args.output, exist_ok=True)
            path = os.path.join(args.output, f"puzzle_{puzzle_number}.json")
            with open(path, "w") as f:
                json.dump(payload, f, indent=2)
            print(f"  Saved to {path}")

        if not args.dry_run:
            try:
                upload_to_supabase(payload)
            except Exception as e:
                print(f"  Upload failed: {e}")
        else:
            print("  (dry run — not uploading)")

        generated += 1

    print(f"\nDone! Generated {generated}/{args.count} puzzles.")


if __name__ == "__main__":
    main()
