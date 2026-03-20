"""
Weekly Crossword Puzzle Generator (13×13)
==========================================

Generates weekly pro-only crossword puzzles using a 13×13 grid.
More complex than the daily 9×9 with longer words and more clues.

Usage:
    python generate_weekly_puzzle.py --dry-run --output puzzles_weekly
    python generate_weekly_puzzle.py --date 2026-03-23 --start-number 1

Environment Variables (only needed for upload):
    SUPABASE_URL  — Your Supabase project URL
    SUPABASE_KEY  — Your Supabase service-role key (NOT anon key)
"""

import argparse
import json
import os
import random
import sys
import time
from datetime import date, timedelta
from pathlib import Path

GRID_SIZE = 13
TARGET_CLUES = 35
MIN_WORD_LENGTH = 3
MAX_WORD_LENGTH = 13

# ── Grid Templates ──────────────────────────────────────────────────────────
# Each template is a 13×13 grid. '#' = black, '.' = white.
# All templates have 180° rotational symmetry (standard crossword convention).
# No 2-cell runs. Every white cell is in at least one word slot (length ≥ 3).

def _t(s: str) -> list[list[bool]]:
    """Parse a compact template string into a 13×13 bool grid."""
    chars = [c for c in s if c in '.#']
    expected = GRID_SIZE * GRID_SIZE
    assert len(chars) == expected, f"Template has {len(chars)} cells, expected {expected}"
    return [[chars[r * GRID_SIZE + c] == '.' for c in range(GRID_SIZE)] for r in range(GRID_SIZE)]


TEMPLATES = [
    # Template 0 — 40 slots, max=9, blacks=47 (proven solvable w/ backtracking)
    _t("""
        ....####....#
        .#.........#.
        .#....#......
        .#.#.........
        .....##.#.#.#
        .###......###
        .....###.....
        ###......###.
        #.#.#.##.....
        .........#.#.
        ......#....#.
        .#.........#.
        #....####....
    """),
    # Template 1 — 40 slots, max=11, blacks=47
    _t("""
        ....##...#.#.
        ...#.#.#...#.
        ...........#.
        ...#...#...#.
        .#...........
        .#.##.##.#.#.
        ###...#...###
        .#.#.##.##.#.
        ...........#.
        .#...#...#...
        .#...........
        .#...#.#.#...
        .#.#...##....
    """),
    # Template 2 — 39 slots, max=11, blacks=46
    _t("""
        ##.#.........
        .#.#####...#.
        ...........#.
        .#.#.#...#...
        #.......#...#
        .....#.......
        #.#.##.##.#.#
        .......#.....
        #...#.......#
        ...#...#.#.#.
        .#...........
        .#...#####.#.
        .........#.##
    """),
    # Template 3 — 40 slots, max=11, blacks=44
    _t("""
        .......#.#.#.
        .###.###.#.#.
        ......#....#.
        .....#...#...
        #...#.#....#.
        #......#.....
        .#.........#.
        .....#......#
        .#....#.#...#
        ...#...#.....
        .#....#......
        .#.#.###.###.
        .#.#.#.......
    """),
    # Template 4 — 40 slots, max=11, blacks=46
    _t("""
        .........#.##
        #.#...###...#
        #...........#
        ......#.#.#.#
        ....#.#.#...#
        .......#.#.#.
        .#.........#.
        .#.#.#.......
        #...#.#.#....
        #.#.#.#......
        #...........#
        #...###...#.#
        ##.#.........
    """),
    # Template 5 — 37 slots, max=9, blacks=46
    _t("""
        ...#.#.#.....
        .###.#...###.
        .#.#.........
        .#.......#.#.
        ......#.#...#
        .#.......#.##
        .....#.#.....
        ##.#.......#.
        #...#.#......
        .#.#.......#.
        .........#.#.
        .###...#.###.
        .....#.#.#...
    """),
    # Template 6 — 40 slots, max=9, blacks=47
    _t("""
        .....#####...
        #.#...##.#.#.
        .........#.#.
        ##.......#.#.
        .........#...
        #.#.#.##.....
        ......#......
        .....##.#.#.#
        ...#.........
        .#.#.......##
        .#.#.........
        .#.#.##...#.#
        ...#####.....
    """),
    # Template 7 — 40 slots, max=10, blacks=40
    _t("""
        #...#.......#
        .....##...##.
        #...##.......
        .......#####.
        #....#.......
        ..........##.
        .#.........#.
        .##..........
        .......#....#
        .#####.......
        .......##...#
        .##...##.....
        #.......#...#
    """),
]


# ── Word Bank ───────────────────────────────────────────────────────────────

def load_word_bank(exclude: set[str] | None = None) -> dict[int, list[dict]]:
    """Load word bank and organize by length, optionally excluding recently-used words."""
    bank_path = Path(__file__).parent / "word_bank.json"
    with open(bank_path) as f:
        words = json.load(f)

    excluded = {w.upper() for w in exclude} if exclude else set()

    by_length: dict[int, list[dict]] = {}
    for w in words:
        if w["word"].upper() in excluded:
            continue
        length = len(w["word"])
        if length < MIN_WORD_LENGTH or length > MAX_WORD_LENGTH:
            continue
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
                if length >= MIN_WORD_LENGTH:
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
                if length >= MIN_WORD_LENGTH:
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
    MAX_BACKTRACKS = 5_000_000
    MAX_CANDIDATES_PER_SLOT = 200
    MAX_SECONDS = 300  # 5 minutes per attempt

    start_time = time.monotonic()

    cell_to_slots: dict[tuple[int, int], list[tuple[int, int]]] = {}
    for si, slot in enumerate(slots):
        for pi, cell in enumerate(slot.cells):
            cell_to_slots.setdefault(cell, []).append((si, pi))

    candidates_by_length: dict[int, list[dict]] = {}
    for length, entries in word_bank.items():
        shuffled = entries[:]
        rng.shuffle(shuffled)
        candidates_by_length[length] = shuffled

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

    assignment: list[dict | None] = [None] * len(slots)
    used_words: set[str] = set()
    grid_letters: dict[tuple[int, int], str] = {}
    backtrack_count = [0]

    def _constraint_sets(si: int) -> list[set[str]] | None:
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
        sets = _constraint_sets(si)
        if sets is None:
            return []

        slot = slots[si]
        if not sets:
            result = []
            for w in all_words_by_length.get(slot.length, []):
                if w not in used_words:
                    result.append(word_to_entry[w])
                    if len(result) >= MAX_CANDIDATES_PER_SLOT:
                        break
            return result

        sets.sort(key=len)
        smallest = sets[0]
        rest = sets[1:]
        feasible = set()
        for word in smallest:
            if word not in used_words and all(word in s for s in rest):
                feasible.add(word)

        ordered = [w for w in all_words_by_length.get(slot.length, []) if w in feasible]
        return [word_to_entry[w] for w in ordered[:MAX_CANDIDATES_PER_SLOT]]

    def has_any_candidate(si: int) -> bool:
        sets = _constraint_sets(si)
        if sets is None:
            return False

        if not sets:
            slot = slots[si]
            for w in all_words_by_length.get(slot.length, []):
                if w not in used_words:
                    return True
            return False

        sets.sort(key=len)
        smallest = sets[0]
        rest = sets[1:]
        for word in smallest:
            if word not in used_words and all(word in s for s in rest):
                return True
        return False

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
        candidates = get_candidates(si)

        for entry in candidates:
            word = entry["word"].upper()

            used_words.add(word)
            assigned_set.add(si)
            placed_cells: list[tuple[tuple[int, int], str | None]] = []
            for pi, cell in enumerate(slots[si].cells):
                old = grid_letters.get(cell)
                placed_cells.append((cell, old))
                grid_letters[cell] = word[pi]

            assignment[si] = entry

            if forward_check_neighbors(si):
                if backtrack(idx + 1):
                    return True

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
    rng: random.Random | None = None,
) -> dict:
    """Convert solver output to raw format."""
    grid = [
        [None] * GRID_SIZE for _ in range(GRID_SIZE)
    ]

    for item in solution:
        slot: Slot = item["slot"]
        word = item["entry"]["word"].upper()
        for pi, (r, c) in enumerate(slot.cells):
            grid[r][c] = word[pi]

    words = []
    for item in solution:
        slot: Slot = item["slot"]
        entry = item["entry"]
        clue_variants = entry.get("clues", [])
        if clue_variants and rng:
            text = rng.choice(clue_variants)
        else:
            text = entry.get("hard_text", entry["text"])
        words.append({
            "direction": slot.direction,
            "number": 0,
            "answer": entry["word"].upper(),
            "text": text,
            "hint": entry["hint"],
            "startRow": slot.row,
            "startCol": slot.col,
        })

    return {"grid": grid, "words": words}


def generate_puzzle(word_bank: dict[int, list[dict]], seed: int | None = None) -> dict | None:
    """Generate a single 13x13 puzzle. Returns raw dict or None on failure."""
    rng = random.Random(seed)

    template_indices = list(range(len(TEMPLATES)))
    rng.shuffle(template_indices)

    for ti in template_indices:
        template = TEMPLATES[ti]
        slots = extract_slots(template)

        lengths_needed = {s.length for s in slots}
        if not all(len(word_bank.get(l, [])) >= 1 for l in lengths_needed):
            missing = [l for l in lengths_needed if len(word_bank.get(l, [])) < 1]
            print(f"  Template {ti}: missing word lengths {missing}, skipping")
            continue

        for attempt in range(20):
            sub_rng = random.Random(rng.randint(0, 2**31) + attempt)
            print(f"  Template {ti} attempt {attempt+1}/20 ({len(slots)} slots)...", end=" ", flush=True)
            solution = solve_grid(slots, word_bank, sub_rng)
            if solution:
                print("SUCCESS")
                return assemble_raw(template, solution, sub_rng)
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

    if len(words) < 20 or len(words) > 60:
        print(f"  WARNING: {len(words)} clues (expected ~{TARGET_CLUES})")

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
                print(f"  ERROR: Word '{answer}' letter mismatch at ({gr},{gc})")
                return False

        for field in ["text", "hint"]:
            if not word.get(field):
                print(f"  ERROR: Word '{answer}' missing '{field}'")
                return False

    # Count some stats
    word_lengths = [len(w["answer"]) for w in words]
    avg_len = sum(word_lengths) / len(word_lengths) if word_lengths else 0
    max_len = max(word_lengths) if word_lengths else 0
    long_words = sum(1 for l in word_lengths if l >= 7)
    print(f"  Valid: {len(words)} clues, avg length {avg_len:.1f}, max {max_len}, {long_words} words ≥7 letters")
    return True


# ── Payload Builder ─────────────────────────────────────────────────────────

def build_puzzle_payload(raw: dict, puzzle_number: int, puzzle_date: str) -> dict:
    """Convert raw generation output to the Supabase-ready payload."""
    grid = raw["grid"]
    words = raw["words"]

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
        "is_free": False,  # Weekly puzzles are pro-only
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
    result = client.table("weekly_puzzles").insert(payload).execute()
    print(f"  Uploaded weekly puzzle #{payload['puzzle_number']} for {payload['date']}")
    return result


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generate weekly 13×13 crossword puzzles")
    parser.add_argument("--count", type=int, default=1, help="Number of puzzles to generate")
    parser.add_argument("--date", type=str, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--start-number", type=int, default=1, help="Starting puzzle number")
    parser.add_argument("--dry-run", action="store_true", help="Generate without uploading")
    parser.add_argument("--output", type=str, help="Output directory for JSON files")
    parser.add_argument("--seed", type=int, help="Random seed for reproducibility")
    parser.add_argument(
        "--exclude-words", type=str, dest="exclude_words",
        help="Path to JSON file containing list of words to exclude"
    )
    args = parser.parse_args()

    exclude: set[str] = set()
    if args.exclude_words:
        try:
            with open(args.exclude_words) as f:
                exclude = set(json.load(f))
            print(f"  Excluding {len(exclude)} recently-used words")
        except Exception as e:
            print(f"  Warning: could not load exclusion list: {e}")

    print("Loading word bank...")
    word_bank = load_word_bank(exclude=exclude)
    total_words = sum(len(v) for v in word_bank.values())
    print(f"  {total_words} words loaded ({', '.join(f'{k}-letter: {len(v)}' for k, v in sorted(word_bank.items()))})")

    start_date = (
        date.fromisoformat(args.date) if args.date else date.today() + timedelta(days=1)
    )

    generated = 0
    for i in range(args.count):
        puzzle_number = args.start_number + i
        puzzle_date = (start_date + timedelta(weeks=i)).isoformat()
        seed = (args.seed + i) if args.seed is not None else (hash(puzzle_date) & 0xFFFFFFFF)

        print(f"\nGenerating weekly puzzle #{puzzle_number} for {puzzle_date} (seed={seed})...")

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
            path = os.path.join(args.output, f"weekly_{puzzle_number}.json")
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

    print(f"\nDone! Generated {generated}/{args.count} weekly puzzles.")


if __name__ == "__main__":
    main()
