#!/usr/bin/env python3
"""Canonical answer-leakage checks for crossword word-bank clues."""

from __future__ import annotations

from dataclasses import dataclass
import re
from collections import defaultdict


MIN_CONSTITUENT_LEN = 3
SAFE_SHORT_ROOTS = {"art", "bag", "run", "ten"}
STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "in", "into",
    "is", "it", "of", "on", "one", "or", "that", "the", "thing", "to", "who", "with",
    "what", "where", "when", "why", "how", "your", "you", "that", "this", "these",
    "those", "to", "do", "does", "did", "done", "can", "might", "may",
}
CLUE_PREFIX_RE = re.compile(
    r"^(?:"
    r"could\s+be|maybe|often|seen\s+as|associated\s+with|a\s+sign\s+of|"
    r"possibly|perhaps|sometimes|loosely|for\s+one|think\s+of|"
    r"another\s+way\s+to\s+say|kind\s+of|type\s+of"
    r")\s+",
    re.IGNORECASE,
)
CLUE_SUFFIX_RE = re.compile(
    r",?\s*(?:perhaps|maybe|sometimes|loosely|for\s+one|in\s+a\s+way|of\s+sorts)$",
    re.IGNORECASE,
)

ORDINAL_ROOTS = {
    "first": "one",
    "second": "two",
    "third": "three",
    "fourth": "four",
    "fifth": "five",
    "sixth": "six",
    "seventh": "seven",
    "eighth": "eight",
    "ninth": "nine",
    "tenth": "ten",
    "eleventh": "eleven",
    "twelfth": "twelve",
    "thirteenth": "thirteen",
    "fourteenth": "fourteen",
    "fifteenth": "fifteen",
    "sixteenth": "sixteen",
    "seventeenth": "seventeen",
    "eighteenth": "eighteen",
    "nineteenth": "nineteen",
    "twentieth": "twenty",
}


@dataclass(frozen=True)
class LeakageIssue:
    reason: str
    answer_form: str
    clue_form: str
    root: str
    rule: str

    def as_dict(self) -> dict[str, str]:
        return {
            "reason": self.reason,
            "answerForm": self.answer_form,
            "clueForm": self.clue_form,
            "root": self.root,
            "rule": self.rule,
        }


def normalize_text(text: str) -> str:
    text = text.lower().replace("'s", "")
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def tokens(text: str) -> list[str]:
    normalized = normalize_text(text)
    return normalized.split() if normalized else []


def compact(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def normalize_clue_idea(text: str) -> str:
    """Return a narrow key for detecting wrapper-only clue rewrites."""
    normalized = re.sub(r"\s+", " ", text).strip()
    normalized = normalized.strip(" \t\r\n\"'")
    normalized = normalized.rstrip(".?!")

    changed = True
    while changed:
        before = normalized
        normalized = CLUE_PREFIX_RE.sub("", normalized).strip()
        normalized = CLUE_SUFFIX_RE.sub("", normalized).strip()
        normalized = normalized.rstrip(".?!")
        changed = normalized != before

    normalized = normalized.replace("___", " blank ")
    normalized = re.sub(r"['’]s\b", "", normalized)
    normalized = re.sub(r"[^a-z0-9]+", " ", normalized.lower())
    return re.sub(r"\s+", " ", normalized).strip()


def redundant_clue_groups(field_values: list[tuple[str, str]]) -> dict[str, list[tuple[str, str]]]:
    """Group fields that repeat the same normalized clue idea."""
    grouped: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for field, value in field_values:
        key = normalize_clue_idea(value)
        if key:
            grouped[key].append((field, value))
    return {key: values for key, values in grouped.items() if len(values) > 1}


def clue_content_tokens(text: str) -> set[str]:
    """Meaning-bearing tokens for conservative same-entry clue comparison."""
    return {
        token
        for token in tokens(normalize_clue_idea(text))
        if token not in STOPWORDS and len(token) > 2
    }


def clue_ideas_are_redundant(left: str, right: str) -> bool:
    left_idea = normalize_clue_idea(left)
    right_idea = normalize_clue_idea(right)
    if not left_idea or not right_idea:
        return False
    if left_idea == right_idea:
        return True

    left_tokens = clue_content_tokens(left)
    right_tokens = clue_content_tokens(right)
    if len(left_tokens) < 2 or len(right_tokens) < 2:
        return False

    overlap = left_tokens & right_tokens
    if len(overlap) >= 2 and (overlap == left_tokens or overlap == right_tokens):
        return True
    if len(overlap) >= 2 and len(overlap) / min(len(left_tokens), len(right_tokens)) >= 0.6:
        return True
    if len(overlap) >= 3 and len(overlap) / min(len(left_tokens), len(right_tokens)) >= 0.6:
        return True
    return False


def check_terms(answer: str) -> list[str]:
    parts = tokens(answer)
    if not parts:
        return []
    terms = [" ".join(parts)]
    if len(parts) > 1:
        terms.extend(part for part in parts if len(part) >= MIN_CONSTITUENT_LEN)
    return terms


def contains_term(text: str, term: str) -> bool:
    text_tokens = tokens(text)
    term_tokens = tokens(term)
    if not text_tokens or not term_tokens:
        return False
    width = len(term_tokens)
    return any(text_tokens[index:index + width] == term_tokens for index in range(len(text_tokens) - width + 1))


def singularize(word: str) -> str:
    if len(word) > 4 and word.endswith("ies"):
        return word[:-3] + "y"
    if len(word) > 4 and word.endswith("ves") and not word.endswith("aves"):
        return word[:-3] + "f"
    if len(word) > 4 and word.endswith("es") and word[:-1].endswith("e"):
        return word[:-1]
    if len(word) > 3 and word.endswith("es"):
        return word[:-2]
    if len(word) > 3 and word.endswith("s"):
        return word[:-1]
    return word


def verb_base(word: str) -> str:
    word = singularize(word)
    if len(word) > 5 and word.endswith("ing"):
        return _undouble(word[:-3])
    if len(word) > 4 and word.endswith("ed"):
        return _undouble(word[:-2])
    return word


def _undouble(root: str) -> str:
    if len(root) >= 2 and root[-1] == root[-2]:
        return root[:-1]
    return root


def root_is_safe(root: str) -> bool:
    return len(root) >= 4 or root in SAFE_SHORT_ROOTS


def answer_roots(answer_token: str) -> list[tuple[str, str]]:
    word = singularize(answer_token)
    roots: list[tuple[str, str]] = []

    if word in ORDINAL_ROOTS:
        roots.append((ORDINAL_ROOTS[word], "ordinal_to_cardinal"))

    suffix_rules = [
        ("ed", "past_tense_to_verb"),
        ("ing", "gerund_to_verb"),
        ("er", "agent_er_to_verb"),
        ("or", "agent_or_to_verb"),
        ("ist", "agent_ist_to_field"),
        ("ian", "agent_ian_to_field"),
        ("istic", "adjective_istic_to_noun"),
        ("ical", "adjective_ical_to_noun"),
        ("ic", "adjective_ic_to_noun"),
        ("y", "adjective_y_to_noun"),
        ("ness", "noun_ness_to_adjective"),
        ("ity", "noun_ity_to_adjective"),
        ("tion", "noun_tion_to_verb"),
    ]

    for suffix, rule in suffix_rules:
        if len(word) <= len(suffix) + 2 or not word.endswith(suffix):
            continue
        raw_root = word[:-len(suffix)]
        root = _undouble(raw_root)
        candidates = {raw_root, root}
        if suffix in {"ed", "er", "or", "istic", "ical", "ic"}:
            candidates.add(root + "e")
        for candidate in candidates:
            if suffix == "y" and candidate not in SAFE_SHORT_ROOTS:
                continue
            if root_is_safe(candidate):
                roots.append((candidate, rule))

    if word != answer_token and root_is_safe(word):
        roots.append((word, "singularized_answer"))

    seen = set()
    unique: list[tuple[str, str]] = []
    for root, rule in roots:
        if root not in seen and root not in STOPWORDS:
            unique.append((root, rule))
            seen.add(root)
    return unique


def clue_roots(clue_token: str) -> set[str]:
    word = verb_base(clue_token)
    roots = {word}
    if len(word) > 5 and word.endswith("istic"):
        roots.add(word[:-5])
    if len(word) > 4 and word.endswith("ical"):
        roots.add(word[:-4])
        roots.add(word[:-4] + "e")
    if len(word) > 3 and word.endswith("ic"):
        roots.add(word[:-2])
        roots.add(word[:-2] + "e")
    if len(word) > 5 and word.endswith(("ant", "ent")):
        roots.add(word[:-3])
    if len(word) > 3 and word.endswith("y"):
        roots.add(word[:-1])
    return {root for root in roots if root_is_safe(root)}


def scan_text(answer: str, text: str) -> list[LeakageIssue]:
    if not answer or not text:
        return []

    issues: list[LeakageIssue] = []
    for term in check_terms(answer):
        if contains_term(text, term):
            issues.append(LeakageIssue("EXACT_ANSWER", answer, term, term, "whole_token"))

    compact_text = compact(text)
    for term in check_terms(answer):
        compact_term = compact(term)
        if len(compact_term) < 4:
            continue
        if compact_term and compact_term in compact_text and not contains_term(text, term):
            issues.append(LeakageIssue("ANSWER_FRAGMENT", answer, term, term, "compact_substring"))

    answer_tokens = [token for token in tokens(answer) if token not in STOPWORDS]
    clue_tokens = [token for token in tokens(text) if token not in STOPWORDS]
    clue_root_map = {token: clue_roots(token) for token in clue_tokens}
    for answer_token in answer_tokens:
        for root, rule in answer_roots(answer_token):
            for clue_token, roots in clue_root_map.items():
                if root in roots:
                    issues.append(LeakageIssue("DERIVED_ANSWER", answer_token, clue_token, root, rule))

    return _deduplicate(issues)


def leaks_answer(answer: str, text: str) -> bool:
    return bool(scan_text(answer, text))


def _deduplicate(issues: list[LeakageIssue]) -> list[LeakageIssue]:
    seen = set()
    unique: list[LeakageIssue] = []
    for issue in issues:
        key = (issue.reason, issue.answer_form, issue.clue_form, issue.root, issue.rule)
        if key not in seen:
            unique.append(issue)
            seen.add(key)
    return unique
