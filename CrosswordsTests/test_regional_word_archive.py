import json
import unittest
from collections import Counter
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1] / "Backend"
WORD_BANK_PATH = BACKEND_DIR / "word_bank.json"
ARCHIVE_PATH = BACKEND_DIR / "US_UK_regional_words.json"

CONTEXT_WORDS = {
    "ANALOGUE",
    "ANNEX",
    "CHECKS",
    "CURB",
    "DEPENDENT",
    "DRAFT",
    "DRAFTS",
    "EON",
    "GRAY",
    "GREY",
    "LICENSE",
    "METERS",
    "MUM",
    "PRIZE",
    "PROGRAM",
    "PROGRAMS",
    "STORIES",
    "STORY",
    "TIRE",
}

REMAINING_TERMINOLOGY_WORDS = {
    "AFTERWARD",
    "AMONG",
    "AMONGST",
    "BACKWARD",
    "CHECKER",
    "CHECKERS",
    "CZAR",
    "FLUTIST",
    "GOTTEN",
    "LEARNED",
    "LEARNT",
    "MATH",
    "ONWARD",
    "ONWARDS",
    "SPECIALTY",
    "SPELLED",
    "SPILLED",
    "SPILT",
    "SPOILED",
    "TSAR",
    "WHISKEY",
    "WHISKY",
}

EXPECTED_CONTEXT_LINKS = {
    ("ANALOG", "ANALOGUE"),
    ("ANALOGUE", "ANALOG"),
    ("ANNEX", "ANNEXE"),
    ("ANNEXE", "ANNEX"),
    ("CHECKS", "CHEQUES"),
    ("CHEQUES", "CHECKS"),
    ("CHECKS", "BILLS"),
    ("BILLS", "CHECKS"),
    ("CURB", "KERB"),
    ("KERB", "CURB"),
    ("DEPENDENT", "DEPENDANT"),
    ("DEPENDANT", "DEPENDENT"),
    ("DRAFT", "DRAUGHT"),
    ("DRAUGHT", "DRAFT"),
    ("DRAFT", "CONSCRIPTION"),
    ("CONSCRIPTION", "DRAFT"),
    ("DRAFTS", "DRAUGHTS"),
    ("DRAUGHTS", "DRAFTS"),
    ("EON", "AEON"),
    ("AEON", "EON"),
    ("GRAY", "GREY"),
    ("GREY", "GRAY"),
    ("LICENSE", "LICENCE"),
    ("LICENCE", "LICENSE"),
    ("METERS", "METRES"),
    ("METRES", "METERS"),
    ("MUM", "MOM"),
    ("MOM", "MUM"),
    ("PRIZE", "PRISE"),
    ("PRISE", "PRIZE"),
    ("PROGRAM", "PROGRAMME"),
    ("PROGRAMME", "PROGRAM"),
    ("PROGRAMS", "PROGRAMMES"),
    ("PROGRAMMES", "PROGRAMS"),
    ("STORIES", "STOREYS"),
    ("STOREYS", "STORIES"),
    ("STORY", "STOREY"),
    ("STOREY", "STORY"),
    ("TIRE", "TYRE"),
    ("TYRE", "TIRE"),
}

FORBIDDEN_ACTIVE_CONTEXT_TERMS = {
    "ANALOGUE": {"digital", "clock", "signal"},
    "ANNEX": {"building", "structure", "wing"},
    "CHECKS": {"restaurant", "bank", "payment", "bill"},
    "CURB": {"street", "road", "pavement", "concrete"},
    "DEPENDENT": {"tax return", "supported relative", "family member"},
    "DRAFT": {"air current", "breeze", "military", "enlistment"},
    "DRAFTS": {"air current", "breeze", "military", "enlistment"},
    "EON": {"indefinite age", "endless period"},
    "GRAY": {"color", "colour", "shade", "storm cloud"},
    "GREY": {"color", "colour", "shade", "storm cloud"},
    "LICENSE": {"driving permit", "permission document", "certificate"},
    "METERS": {"metric units", "centimetres", "track distances"},
    "MUM": {"mother", "female parent"},
    "PRIZE": {"leverage", "lid open", "with a tool"},
    "PROGRAM": {"television", "series of events", "event agenda"},
    "PROGRAMS": {"performances", "organized activities", "event schedules"},
    "STORIES": {"building levels", "building floors"},
    "STORY": {"building level", "building floor"},
    "TIRE": {"vehicle", "wheel", "rubber covering", "road"},
}


class RegionalWordArchiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.active = json.loads(WORD_BANK_PATH.read_text())
        cls.archive = json.loads(ARCHIVE_PATH.read_text())
        cls.active_by_word = {
            entry["word"].upper(): entry
            for entry in cls.active
        }

    def test_expected_inventory_counts(self) -> None:
        self.assertEqual(len(self.active), 22_403)
        self.assertEqual(len(self.archive), 438)
        self.assertEqual(
            len({entry["word"].upper() for entry in self.archive}),
            435,
        )

        category_counts = Counter(entry["category"] for entry in self.archive)
        self.assertEqual(
            category_counts,
            Counter(
                {
                    "clear_spelling": 404,
                    "context_split": 32,
                    "terminology": 2,
                }
            ),
        )

    def test_archive_metadata_and_clue_fields_are_valid(self) -> None:
        for entry in self.archive:
            self.assertIn(entry["region"], {"US", "UK"})
            self.assertIn(
                entry["category"],
                {"clear_spelling", "context_split", "terminology"},
            )
            self.assertIsInstance(entry["counterpart"], str)
            self.assertTrue(entry["counterpart"].strip())

            for field in ("word", "text", "hint", "hard_text"):
                self.assertIsInstance(entry[field], str)
                self.assertTrue(entry[field].strip())

            self.assertIsInstance(entry["clues"], list)
            self.assertTrue(entry["clues"])
            self.assertTrue(
                all(isinstance(clue, str) and clue.strip() for clue in entry["clues"])
            )

            if entry["category"] in {"context_split", "terminology"}:
                self.assertIsInstance(entry.get("sense"), str)
                self.assertTrue(entry["sense"].strip())
            if entry["category"] == "context_split":
                self.assertEqual(len(entry["clues"]), 3)

    def test_clear_spellings_are_not_active(self) -> None:
        active_words = {entry["word"].upper() for entry in self.active}
        clear_words = {
            entry["word"].upper()
            for entry in self.archive
            if entry["category"] == "clear_spelling"
        }
        self.assertTrue(clear_words.isdisjoint(active_words))

    def test_only_context_words_overlap_active_and_archive(self) -> None:
        active_words = {entry["word"].upper() for entry in self.active}
        archive_words = {entry["word"].upper() for entry in self.archive}
        self.assertEqual(active_words & archive_words, CONTEXT_WORDS)

    def test_context_pairs_and_sense_specific_duplicates_exist(self) -> None:
        archive_links = {
            (entry["word"].upper(), entry["counterpart"].upper())
            for entry in self.archive
        }
        self.assertTrue(EXPECTED_CONTEXT_LINKS.issubset(archive_links))

        duplicate_words = {
            word: count
            for word, count in Counter(
                entry["word"].upper() for entry in self.archive
            ).items()
            if count > 1
        }
        self.assertEqual(
            duplicate_words,
            {
                "CHECKS": 2,
                "DRAFT": 2,
                "DRAUGHTS": 2,
            },
        )
        for word in duplicate_words:
            senses = {
                entry.get("sense")
                for entry in self.archive
                if entry["word"].upper() == word
            }
            self.assertEqual(len(senses), duplicate_words[word])

    def test_active_context_entries_exclude_regional_senses(self) -> None:
        self.assertTrue(CONTEXT_WORDS.issubset(self.active_by_word))

        for word, forbidden_terms in FORBIDDEN_ACTIVE_CONTEXT_TERMS.items():
            entry = self.active_by_word[word]
            searchable = " ".join(
                [
                    entry["text"],
                    entry["hint"],
                    entry["hard_text"],
                    *entry["clues"],
                ]
            ).lower()
            for term in forbidden_terms:
                self.assertNotIn(term, searchable, f"{word} still contains {term!r}")

    def test_mom_and_draughts_are_archived_with_22_cases_remaining(self) -> None:
        active_words = {entry["word"].upper() for entry in self.active}
        self.assertNotIn("MOM", active_words)
        self.assertNotIn("DRAUGHTS", active_words)
        self.assertTrue(REMAINING_TERMINOLOGY_WORDS.issubset(active_words))
        self.assertEqual(len(REMAINING_TERMINOLOGY_WORDS), 22)

        terminology_entries = {
            entry["word"].upper(): entry
            for entry in self.archive
            if entry["category"] == "terminology"
        }
        self.assertEqual(set(terminology_entries), {"MOM", "DRAUGHTS"})
        self.assertEqual(terminology_entries["MOM"]["counterpart"], "MUM")
        self.assertEqual(terminology_entries["DRAUGHTS"]["counterpart"], "CHECKERS")


if __name__ == "__main__":
    unittest.main()
