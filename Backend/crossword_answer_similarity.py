"""Rules for keeping closely related answers out of the same crossword."""

from __future__ import annotations

import re


MIN_COMPARABLE_LENGTH = 5
MIN_SHARED_PREFIX_LENGTH = 5
MIN_SHARED_PREFIX_RATIO = 0.7


def normalized_answer(answer: str) -> str:
    """Return the letters-only, uppercase form used for answer comparison."""
    return re.sub(r"[^A-Z]", "", answer.upper())


def are_too_similar_answers(first: str, second: str) -> bool:
    """Whether two answers would feel confusingly related in one puzzle.

    Exact duplicates are included for completeness. For distinct answers, avoid
    containment and long shared stems only when both answers are at least five
    letters long. This preserves the limited short-answer bank while excluding
    pairs such as INVERSE/INVERTER and INVERT/INVERTER.
    """
    first_normalized = normalized_answer(first)
    second_normalized = normalized_answer(second)

    if not first_normalized or not second_normalized:
        return False
    if first_normalized == second_normalized:
        return True
    if min(len(first_normalized), len(second_normalized)) < MIN_COMPARABLE_LENGTH:
        return False
    if first_normalized in second_normalized or second_normalized in first_normalized:
        return True

    shared_prefix_length = 0
    for first_letter, second_letter in zip(first_normalized, second_normalized):
        if first_letter != second_letter:
            break
        shared_prefix_length += 1

    return (
        shared_prefix_length >= MIN_SHARED_PREFIX_LENGTH
        and shared_prefix_length / min(len(first_normalized), len(second_normalized))
        >= MIN_SHARED_PREFIX_RATIO
    )
