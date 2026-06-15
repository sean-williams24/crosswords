#!/usr/bin/env python3
"""
Conservative clue inflection helpers shared by word-bank and Backword audits.

These checks intentionally flag review-worthy patterns instead of pretending to
be a full grammar parser. The workflow is review-first: flagged fields are
exported with proposed replacements, then applied only from that reviewed file.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any


TERMINAL_RE = re.compile(r"[.?!]$")

BASE_VERB_ENDINGS = (
    "act", "add", "adjust", "advance", "affirm", "appeal", "ask", "bake",
    "bask", "bite", "blanch", "climb", "clone", "copy", "cut", "do", "draw",
    "eat", "fix", "give", "go", "hold", "jump", "leave", "make", "move",
    "nix", "play", "reach", "read", "run", "say", "send", "soak", "take",
    "try", "use", "walk", "write",
)

BASE_VERB_CLUE_STARTS = {
    "abandon", "absorb", "achieve", "adjust", "admire", "advance", "affirm",
    "anchor", "appeal", "authorize", "avenge", "babble", "bake", "bask",
    "bisect", "bite", "blanch", "bestow", "duplicate", "nix", "jut",
}

PARTICIPLE_PREFIXES = (
    "being ", "becoming ", "causing ", "creating ", "doing ", "having ",
    "holding ", "keeping ", "leaving ", "making ", "moving ", "requesting ",
    "running ", "taking ", "using ",
)

PAST_CLUE_MARKERS = ("past tense of ",)

IRREGULAR_PAST_OR_PARTICIPLE = {
    "arisen", "arose", "ate", "awoke", "bade", "been", "began", "bent", "bit",
    "beheld", "bitten", "bled", "blew", "blown", "bore", "bought", "brought", "built",
    "came", "caught", "chose", "chosen", "clung", "dealt", "did", "done", "drew",
    "drank", "drawn", "driven", "drove", "dwelt", "eaten", "fell", "felt", "flew",
    "flown", "forgave", "fought", "frozen", "froze", "gave", "given", "gone",
    "gotten", "grew", "grown", "held", "hung", "kept", "knelt", "known", "laid",
    "lain", "leant", "leapt", "led", "left", "lent", "lied", "lit", "lost",
    "made", "meant", "met", "paid", "pled", "ran", "rang", "read", "ridden",
    "fallen", "risen", "rode", "rose", "said", "sang", "sank", "sat", "saw", "seen", "sent",
    "shone", "shook", "shorn", "shown", "slain", "slept", "slid", "slung", "sold", "sought",
    "sown", "sped", "spilt", "spoke", "spent", "spun", "stood", "stridden",
    "strode", "struck", "stunk", "sung", "sunk", "swept", "swore", "swung",
    "taught", "thought", "threw", "told", "took", "tore", "torn", "trod", "trodden",
    "dug", "fed", "got", "had", "hid", "went", "were", "withstood", "woke", "won",
    "wore", "worn", "wound", "wove", "woven", "written", "wrote",
}

THIRD_PERSON_VERB_ANSWERS = {
    "does", "goes", "has", "is", "makes", "says", "sees", "uses",
}

IRREGULAR_PLURAL_ANSWERS = {
    "addenda", "antennae", "dice", "fishermen", "iraqis", "israelis", "salesmen",
    "sportsmen", "stadia", "stimuli",
}

ADJECTIVE_SUFFIXES = (
    "able", "al", "ant", "ent", "ful", "ic", "ical", "ish", "ive", "less",
    "ous", "y",
)


@dataclass(frozen=True)
class InflectionIssue:
    reason: str
    detail: str
    proposed: str


def normalize_space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def ensure_terminal(value: str) -> str:
    value = normalize_space(value)
    if not value:
        return value
    return value if TERMINAL_RE.search(value) else f"{value}."


def lower_first(value: str) -> str:
    return value[:1].lower() + value[1:] if value else value


def upper_first(value: str) -> str:
    return value[:1].upper() + value[1:] if value else value


def tokens(value: str) -> list[str]:
    normalized = re.sub(r"[^a-z0-9]+", " ", value.lower())
    return normalized.split()


def is_pluralish_answer(answer: str) -> bool:
    word = answer.lower()
    if word in IRREGULAR_PLURAL_ANSWERS:
        return True
    if word in THIRD_PERSON_VERB_ANSWERS:
        return False
    if len(word) <= 3:
        return word in {"ads", "cds", "djs", "pjs", "tix", "ups"}
    if word.endswith(("ss", "us", "is", "ous")):
        return False
    return word.endswith("s")


def is_past_or_participle(answer: str) -> bool:
    word = answer.lower()
    if word in {"imbed"}:
        return False
    return word in IRREGULAR_PAST_OR_PARTICIPLE or (len(word) > 3 and word.endswith("ed"))


def is_gerund(answer: str) -> bool:
    word = answer.lower()
    return len(word) > 5 and word.endswith("ing")


def is_adverb(answer: str) -> bool:
    word = answer.lower()
    return len(word) > 4 and word.endswith("ly")


def looks_like_adjective(answer: str) -> bool:
    word = answer.lower()
    return (
        word.endswith(ADJECTIVE_SUFFIXES)
        or is_past_or_participle(word)
        or is_gerund(word)
        or word in {"able", "ablaze", "abroad", "absurd", "adept", "agile", "ajar", "akin", "aloof"}
    )


def looks_like_base_verb(answer: str, clue: str = "") -> bool:
    word = answer.lower()
    if is_pluralish_answer(word) or is_past_or_participle(word) or is_gerund(word) or is_adverb(word):
        return False
    if word in BASE_VERB_CLUE_STARTS:
        return True
    clue_tokens = tokens(clue)
    return bool(clue_tokens and clue_tokens[0] in BASE_VERB_ENDINGS)


def imperative_from_gerund(clue: str) -> str | None:
    stripped = clue.strip().rstrip(".?!")
    lowered = stripped.lower()
    gerund_to_base = {
        "asking": "Ask",
        "being": "Be",
        "becoming": "Become",
        "causing": "Cause",
        "creating": "Create",
        "doing": "Do",
        "giving": "Give",
        "having": "Have",
        "holding": "Hold",
        "keeping": "Keep",
        "leaving": "Leave",
        "making": "Make",
        "moving": "Move",
        "requesting": "Request",
        "running": "Run",
        "taking": "Take",
        "using": "Use",
    }
    first, _, rest = stripped.partition(" ")
    base = gerund_to_base.get(first.lower())
    if not base:
        return None
    return ensure_terminal(f"{base} {rest}".strip())


def proposal_for_what_does(clue: str) -> str:
    stripped = clue.strip().rstrip(".?!")
    stripped = re.sub(r",\s*(perhaps|sometimes|loosely|for one)$", "", stripped, flags=re.IGNORECASE)
    match = re.match(r"(?i)^what\s+(.+?)\s+does(?:\s+(.+))?$", stripped)
    if not match:
        return ensure_terminal(stripped)
    subject = match.group(1)
    rest = (match.group(2) or "").strip()
    if rest:
        return ensure_terminal(f"Do what {subject} does {rest}")
    return ensure_terminal(f"Act like {subject}")


def proposal_for_plural_clue(answer: str, clue: str) -> str:
    stripped = clue.strip().rstrip(".?!")
    if re.match(r"(?i)^(people|things|items|messages|passes|discs)\b", stripped):
        return ensure_terminal(stripped)
    if re.match(r"(?i)^[a-z]+s\b", stripped):
        return ensure_terminal(stripped)
    return ensure_terminal(f"Examples of {lower_first(stripped)}")


def proposal_for_single_word_pair(answer: str, clue: str) -> str:
    answer_l = answer.lower()
    clue_l = clue.lower().strip()
    known = {
        ("achieve", "excels"): "SUCCESS",
        ("duplicate", "clones"): "COPY",
        ("cruelty", "unkind"): "MALICE",
    }
    if (answer_l, clue_l) in known:
        return known[(answer_l, clue_l)]
    if clue_l.endswith("s") and not answer_l.endswith("s"):
        return clue_l[:-1].upper()
    if answer_l.endswith("s") and not clue_l.endswith("s"):
        return f"{clue_l}s".upper()
    return clue.upper()


def scan_clue(answer: str, clue: str, *, single_word_pair: bool = False) -> list[InflectionIssue]:
    issues: list[InflectionIssue] = []
    answer_l = answer.lower()
    clue_l = normalize_space(clue).lower()
    clue_words = tokens(clue)

    if not clue_l:
        return issues

    if single_word_pair and len(clue_words) == 1:
        clue_word = clue_words[0]
        if answer_l != clue_word:
            if clue_word.endswith("s") and not answer_l.endswith("s"):
                issues.append(InflectionIssue(
                    reason="THIRD_PERSON_SINGLE_WORD",
                    detail="Single-word clue is third-person singular while answer is not.",
                    proposed=proposal_for_single_word_pair(answer, clue),
                ))
            elif looks_like_adjective(answer) != looks_like_adjective(clue_word):
                issues.append(InflectionIssue(
                    reason="PART_OF_SPEECH_SINGLE_WORD",
                    detail="Single-word clue appears to use a different part of speech from the answer.",
                    proposed=proposal_for_single_word_pair(answer, clue),
                ))

    if looks_like_base_verb(answer, clue):
        if re.search(r"\bwhat\s+.+\s+does\b", clue_l):
            issues.append(InflectionIssue(
                reason="THIRD_PERSON_CLUE",
                detail="Clue wording implies a third-person answer form, not the base verb.",
                proposed=proposal_for_what_does(clue),
            ))
        elif clue_l.startswith(PARTICIPLE_PREFIXES):
            proposal = imperative_from_gerund(clue)
            if proposal:
                issues.append(InflectionIssue(
                    reason="GERUND_CLUE_FOR_BASE_VERB",
                    detail="Clue wording implies an -ING answer form, not the base verb.",
                    proposed=proposal,
                ))

    if is_past_or_participle(answer):
        if "what " in clue_l and " does" in clue_l:
            issues.append(InflectionIssue(
                reason="PRESENT_CLUE_FOR_PAST_OR_PARTICIPLE",
                detail="Clue wording implies present-tense action while answer is past/participle.",
                proposed="Already in that state.",
            ))
    elif any(marker in clue_l for marker in PAST_CLUE_MARKERS) and not is_past_or_participle(answer):
        issues.append(InflectionIssue(
            reason="PAST_CLUE_FOR_NON_PAST",
            detail="Clue wording implies a past-tense answer form.",
            proposed=ensure_terminal(re.sub(r"(?i)\bpast tense of\s+", "", clue.strip().rstrip(".?!"))),
        ))

    if is_pluralish_answer(answer):
        if re.match(r"(?i)^a\s+(?:person|thing|device|helper|unit|sound|word)\b", clue.strip()):
            issues.append(InflectionIssue(
                reason="SINGULAR_CLUE_FOR_PLURAL",
                detail="Clue wording reads singular while answer is plural.",
                proposed=proposal_for_plural_clue(answer, clue),
            ))

    return dedupe_issues(issues)


def dedupe_issues(issues: list[InflectionIssue]) -> list[InflectionIssue]:
    seen: set[tuple[str, str]] = set()
    unique: list[InflectionIssue] = []
    for issue in issues:
        key = (issue.reason, issue.proposed)
        if key in seen:
            continue
        seen.add(key)
        unique.append(issue)
    return unique


def field_values(entry: dict[str, Any]) -> list[dict[str, Any]]:
    values: list[dict[str, Any]] = []
    for name in ("text", "hint", "hard_text", "hardText"):
        value = entry.get(name)
        if isinstance(value, str) and value.strip():
            values.append({"field": name, "clueIndex": None, "value": value})
    for index, clue in enumerate(entry.get("clues") or []):
        if isinstance(clue, str) and clue.strip():
            values.append({"field": "clues", "clueIndex": index, "value": clue})
    return values


def field_label(field: str, clue_index: int | None = None) -> str:
    return f"clues[{clue_index}]" if field == "clues" and clue_index is not None else field


def get_field(entry: dict[str, Any], label: str) -> str:
    match = re.fullmatch(r"clues\[(\d+)\]", label)
    if match:
        clues = entry.get("clues") or []
        index = int(match.group(1))
        return clues[index] if index < len(clues) else ""
    value = entry.get(label)
    return value if isinstance(value, str) else ""


def set_field(entry: dict[str, Any], label: str, value: str) -> None:
    match = re.fullmatch(r"clues\[(\d+)\]", label)
    if match:
        clues = entry.setdefault("clues", [])
        index = int(match.group(1))
        if index >= len(clues):
            raise IndexError(f"{label} does not exist for {entry.get('word')}")
        clues[index] = value
        return
    entry[label] = value
