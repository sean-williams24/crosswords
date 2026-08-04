"""Rules for keeping closely related answers out of the same crossword."""

from __future__ import annotations

import re


MIN_COMPARABLE_LENGTH = 5
MIN_SHARED_PREFIX_LENGTH = 5
MIN_SHARED_PREFIX_RATIO = 0.7
MAX_NEAR_MATCH_EDIT_DISTANCE = 2


def normalized_answer(answer: str) -> str:
    """Return the letters-only, uppercase form used for answer comparison."""
    return re.sub(r"[^A-Z]", "", answer.upper())


def are_within_edit_distance(first: str, second: str, maximum: int) -> bool:
    """Return whether two strings differ by no more than ``maximum`` edits."""
    if abs(len(first) - len(second)) > maximum:
        return False

    previous = list(range(len(second) + 1))
    for first_index, first_letter in enumerate(first, start=1):
        current = [first_index]
        for second_index, second_letter in enumerate(second, start=1):
            current.append(min(
                previous[second_index] + 1,
                current[second_index - 1] + 1,
                previous[second_index - 1] + (first_letter != second_letter),
            ))
        if min(current) > maximum:
            return False
        previous = current
    return previous[-1] <= maximum


class AnswerSimilarityIndex:
    """Tracks placed answers while keeping candidate checks inexpensive."""

    def __init__(self) -> None:
        self._words: set[str] = set()
        self._words_by_prefix: dict[str, set[str]] = {}
        self._substring_counts: dict[str, int] = {}

    def add(self, answer: str) -> None:
        normalized = normalized_answer(answer)
        if not normalized or normalized in self._words:
            return
        self._words.add(normalized)
        if len(normalized) < MIN_COMPARABLE_LENGTH:
            return
        self._words_by_prefix.setdefault(
            normalized[:MIN_SHARED_PREFIX_LENGTH], set()
        ).add(normalized)
        for substring in self._substrings(normalized):
            self._substring_counts[substring] = self._substring_counts.get(substring, 0) + 1

    def remove(self, answer: str) -> None:
        normalized = normalized_answer(answer)
        if normalized not in self._words:
            return
        self._words.remove(normalized)
        if len(normalized) < MIN_COMPARABLE_LENGTH:
            return
        prefix_words = self._words_by_prefix[normalized[:MIN_SHARED_PREFIX_LENGTH]]
        prefix_words.remove(normalized)
        if not prefix_words:
            del self._words_by_prefix[normalized[:MIN_SHARED_PREFIX_LENGTH]]
        for substring in self._substrings(normalized):
            remaining = self._substring_counts[substring] - 1
            if remaining:
                self._substring_counts[substring] = remaining
            else:
                del self._substring_counts[substring]

    def is_available(self, answer: str) -> bool:
        normalized = normalized_answer(answer)
        if not normalized or normalized in self._words:
            return False
        if len(normalized) < MIN_COMPARABLE_LENGTH:
            return True
        if normalized in self._substring_counts:
            return False
        if any(used_word in normalized for used_word in self._words):
            return False
        return not any(
            are_too_similar_answers(normalized, used_word)
            for used_word in self._words_by_prefix.get(
                normalized[:MIN_SHARED_PREFIX_LENGTH], set()
            )
        )

    @staticmethod
    def _substrings(word: str) -> set[str]:
        return {
            word[start:end]
            for start in range(len(word))
            for end in range(start + MIN_COMPARABLE_LENGTH, len(word) + 1)
        }


def are_too_similar_answers(first: str, second: str) -> bool:
    """Whether two answers would feel confusingly related in one puzzle.

    Exact duplicates are included for completeness. For distinct answers, avoid
    containment and close shared-stem variants only when both answers are at
    least five letters long. A shared stem must also leave the full spellings
    within two edits, which preserves the short-answer bank and avoids
    excluding broader same-prefix families while still rejecting pairs such as
    INVERSE/INVERTER and INVERT/INVERTER.
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
        and are_within_edit_distance(
            first_normalized,
            second_normalized,
            MAX_NEAR_MATCH_EDIT_DISTANCE,
        )
    )
