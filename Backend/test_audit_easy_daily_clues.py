import json
import sys
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

import audit_easy_daily_clues as audit


def entry(word: str, text: str = "Current main clue") -> dict:
    return {
        "word": word,
        "text": text,
        "hint": "Dormant fallback",
        "hard_text": "A different indirect angle",
        "clues": ["First alternate idea", "Second alternate idea"],
    }


class CalibrationTests(unittest.TestCase):
    def test_reviewed_calibration_is_complete(self) -> None:
        entries = audit.load_entries(audit.BANK_PATH)
        calibration = audit.build_calibration(entries)

        self.assertEqual(len(calibration), 150)
        self.assertEqual(sum(item["decision"] == "keep" for item in calibration), 31)
        self.assertEqual(sum(item["decision"] == "replace" for item in calibration), 119)

        by_word = {item["word"].upper(): item["decision"] for item in calibration}
        self.assertEqual(by_word["CITY"], "keep")
        self.assertEqual(by_word["PIXEL"], "keep")
        self.assertEqual(by_word["BED"], "replace")
        self.assertEqual(by_word["RED"], "replace")
        butterfly = next(item for item in calibration if item["word"] == "BUTTERFLY")
        self.assertFalse(butterfly["inDailyScope"])
        self.assertEqual(sum(item["inDailyScope"] for item in calibration), 149)


class ClassificationTests(unittest.TestCase):
    def test_only_nonempty_three_to_eight_character_entries_are_eligible(self) -> None:
        entries = [
            entry("IT"),
            entry("CAT"),
            entry("EIGHTLET"),
            entry("NINECHARS"),
            entry("EMPTY", ""),
        ]

        self.assertEqual(
            audit.eligible_records(entries),
            [
                {"index": 1, "word": "CAT", "currentText": "Current main clue"},
                {"index": 2, "word": "EIGHTLET", "currentText": "Current main clue"},
            ],
        )

    def test_response_requires_exact_batch_coverage_and_preconditions(self) -> None:
        batch = [{"index": 4, "word": "MOUSE", "currentText": "Small rodent"}]

        with self.assertRaisesRegex(ValueError, "Missing classification"):
            audit.validate_classification_response(batch, {"classifications": []})

        with self.assertRaisesRegex(ValueError, "precondition mismatch"):
            audit.validate_classification_response(batch, {
                "classifications": [{
                    "index": 4,
                    "word": "MOUSE",
                    "currentText": "Changed clue",
                    "decision": "replace",
                    "reason": "Immediate definition",
                }],
            })

    def test_pending_first_pass_supports_resume(self) -> None:
        entries = [entry("CAT"), entry("MOUSE")]
        report = {"classifications": [{"index": 0}]}

        self.assertEqual(
            audit.pending_first_pass(entries, report),
            [{"index": 1, "word": "MOUSE", "currentText": "Current main clue"}],
        )

    def test_records_chat_classification_and_rejects_nonpending_index(self) -> None:
        entries = [entry("CAT"), entry("MOUSE")]
        report = {"classifications": []}
        response = {"classifications": [{
            "index": 0,
            "word": "CAT",
            "currentText": "Current main clue",
            "decision": "keep",
            "reason": "Requires a specific animal",
        }]}

        self.assertEqual(
            audit.record_classifications(entries, report, response, second_pass=False),
            1,
        )
        self.assertEqual(report["classifications"][0]["source"], "firstPass")
        with self.assertRaisesRegex(ValueError, "not pending"):
            audit.record_classifications(entries, report, response, second_pass=False)

    def test_second_pass_reconciles_borderline_without_losing_first_decision(self) -> None:
        report = {"classifications": [{
            "index": 2,
            "word": "APPLE",
            "currentText": "Common fruit",
            "decision": "borderline",
            "reason": "Could require crossings",
            "source": "firstPass",
        }]}

        audit.merge_second_pass(report, [{
            "index": 2,
            "word": "APPLE",
            "currentText": "Common fruit",
            "decision": "replace",
            "reason": "Everyday answer is immediate",
        }])

        result = report["classifications"][0]
        self.assertEqual(result["firstPassDecision"], "borderline")
        self.assertEqual(result["secondPassDecision"], "replace")
        self.assertEqual(result["decision"], "replace")
        self.assertEqual(result["source"], "secondPass")

    def test_local_triage_separates_obvious_from_specialist_clues(self) -> None:
        obvious = {"word": "BED", "currentText": "Where you sleep"}
        specialist = {"word": "XYLEM", "currentText": "Plant tissue carrying water"}

        self.assertGreaterEqual(
            audit.local_difficulty_score(obvious, zipf=5.0),
            audit.LOCAL_REPLACE_THRESHOLD,
        )
        self.assertLessEqual(
            audit.local_difficulty_score(specialist, zipf=2.5),
            audit.LOCAL_KEEP_THRESHOLD,
        )

    def test_local_triage_preserves_narrow_borderline_band(self) -> None:
        record = {"word": "TERM", "currentText": "A defined expression"}
        # Pin the frequency so this remains a stable threshold-boundary test.
        score = audit.local_difficulty_score(record, zipf=3.3)
        decision = (
            "replace" if score >= audit.LOCAL_REPLACE_THRESHOLD
            else "keep" if score <= audit.LOCAL_KEEP_THRESHOLD
            else "borderline"
        )
        self.assertEqual(decision, "borderline")


class ProposalValidationTests(unittest.TestCase):
    def test_rejects_leakage_and_derived_forms(self) -> None:
        bagged = entry("BAGGED", "Put away after shopping")
        errors = audit.validate_proposed_text(bagged, "Put into a bag")
        self.assertTrue(any("answer leakage" in error for error in errors))

    def test_rejects_active_clue_idea_reuse(self) -> None:
        mouse = entry("MOUSE", "Small rodent")
        mouse["clues"] = ["Tiny household rodent"]
        errors = audit.validate_proposed_text(mouse, "Household rodent of tiny size")
        self.assertTrue(any("clues[0]" in error for error in errors))

    def test_rejects_qualifiers_antonyms_and_inflection_mismatch(self) -> None:
        self.assertIn(
            "replacement uses a discouraged qualifier",
            audit.validate_proposed_text(entry("SOFT"), "Perhaps yielding to pressure"),
        )
        self.assertIn(
            "replacement is antonym-only",
            audit.validate_proposed_text(entry("SOFT"), "Opposite of hard"),
        )
        errors = audit.validate_proposed_text(entry("ABSORB"), "What a sponge does")
        self.assertTrue(any("inflection mismatch" in error for error in errors))

    def test_accepts_safe_distinct_proposal(self) -> None:
        mouse = entry("MOUSE", "Small rodent")
        self.assertEqual(audit.validate_proposed_text(mouse, "Clicking companion on a desktop"), [])


class ApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.bank_path = Path(self.temp_dir.name) / "bank.json"
        self.entries = [entry("MOUSE", "Small rodent"), entry("CITY", "Large urban area")]
        audit.write_json(self.bank_path, self.entries)
        self.bank_hash = audit.bank_sha256(self.bank_path)
        self.audit_report = {
            "schemaVersion": 1,
            "bankSha256": self.bank_hash,
            "classifications": [
                {
                    "index": 0,
                    "word": "MOUSE",
                    "currentText": "Small rodent",
                    "decision": "replace",
                    "reason": "Immediate",
                },
                {
                    "index": 1,
                    "word": "CITY",
                    "currentText": "Large urban area",
                    "decision": "keep",
                    "reason": "Needs a specific term",
                },
            ],
        }
        self.proposals = {
            "schemaVersion": 1,
            "bankSha256": self.bank_hash,
            "auditSha256": audit.audit_sha256(self.audit_report),
            "proposals": [{
                "index": 0,
                "word": "MOUSE",
                "currentText": "Small rodent",
                "proposedText": "Clicking companion on a desktop",
                "status": "accepted",
                "history": [],
            }],
        }

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_apply_changes_only_approved_text(self) -> None:
        original = deepcopy(self.entries)
        updated = audit.apply_approved(
            self.entries, self.audit_report, self.proposals, self.bank_path
        )

        self.assertEqual(updated[0]["text"], "Clicking companion on a desktop")
        self.assertEqual(updated[0]["hint"], original[0]["hint"])
        self.assertEqual(updated[0]["hard_text"], original[0]["hard_text"])
        self.assertEqual(updated[0]["clues"], original[0]["clues"])
        self.assertEqual(updated[1], original[1])
        self.assertEqual(self.entries, original)

    def test_apply_rejects_incomplete_approval_set(self) -> None:
        self.proposals["proposals"][0]["status"] = "pending"
        with self.assertRaisesRegex(ValueError, "remain unapproved"):
            audit.apply_approved(self.entries, self.audit_report, self.proposals, self.bank_path)

    def test_apply_rejects_stale_bank_hash(self) -> None:
        self.bank_path.write_text(json.dumps(self.entries, indent=4))
        with self.assertRaisesRegex(ValueError, "Stale report"):
            audit.apply_approved(self.entries, self.audit_report, self.proposals, self.bank_path)

    def test_proposal_report_rejects_changed_audit(self) -> None:
        self.audit_report["classifications"][0]["reason"] = "Edited after generation"
        with self.assertRaisesRegex(ValueError, "different audit"):
            audit.validate_proposal_report(
                self.entries,
                self.audit_report,
                self.proposals,
                self.bank_path,
                require_complete=False,
            )

    def test_keep_original_withdraws_proposal_and_updates_audit_hash(self) -> None:
        audit.keep_original_clues(self.audit_report, self.proposals, {0})

        self.assertEqual(self.audit_report["classifications"][0]["decision"], "keep")
        self.assertEqual(self.audit_report["classifications"][0]["source"], "userOverride")
        self.assertEqual(self.proposals["proposals"], [])
        self.assertEqual(self.proposals["withdrawnProposals"][0]["index"], 0)
        self.assertEqual(
            self.proposals["auditSha256"],
            audit.audit_sha256(self.audit_report),
        )

    def test_rebase_after_exact_entry_removal_preserves_proposals(self) -> None:
        old_entries = [
            entry("MOUSE", "Small rodent"),
            entry("ALLIE", "Friendly companion"),
            entry("CITY", "Large urban area"),
        ]
        new_entries = [old_entries[0], old_entries[2]]
        old_bank_path = Path(self.temp_dir.name) / "old-bank.json"
        new_bank_path = Path(self.temp_dir.name) / "new-bank.json"
        audit.write_json(old_bank_path, old_entries)
        audit.write_json(new_bank_path, new_entries)
        audit_report = {
            "schemaVersion": 1,
            "sourceBank": str(old_bank_path),
            "bankSha256": audit.bank_sha256(old_bank_path),
            "eligibleEntryCount": 3,
            "classifications": [
                {"index": 0, "word": "MOUSE", "currentText": "Small rodent", "decision": "replace", "reason": "Immediate"},
                {"index": 1, "word": "ALLIE", "currentText": "Friendly companion", "decision": "keep", "reason": "Specific"},
                {"index": 2, "word": "CITY", "currentText": "Large urban area", "decision": "keep", "reason": "Specific"},
            ],
        }
        audit.update_audit_summary(audit_report)
        proposal_report = {
            "schemaVersion": 1,
            "sourceBank": str(old_bank_path),
            "bankSha256": audit.bank_sha256(old_bank_path),
            "auditSha256": audit.audit_sha256(audit_report),
            "proposals": [{
                "index": 0,
                "word": "MOUSE",
                "currentText": "Small rodent",
                "proposedText": "Clicking companion on a desktop",
                "status": "accepted",
                "history": [],
            }],
        }

        rebased_audit, rebased_proposals = audit.rebase_after_removed_entry(
            old_entries,
            new_entries,
            audit_report,
            proposal_report,
            old_bank_path,
            new_bank_path,
            1,
        )

        self.assertEqual(
            [(item["index"], item["word"]) for item in rebased_audit["classifications"]],
            [(0, "MOUSE"), (1, "CITY")],
        )
        self.assertEqual(rebased_audit["eligibleEntryCount"], 2)
        self.assertEqual(rebased_proposals["proposals"][0]["index"], 0)
        self.assertEqual(
            rebased_proposals["auditSha256"],
            audit.audit_sha256(rebased_audit),
        )

    def test_rebase_rejects_any_additional_bank_change(self) -> None:
        old_entries = [entry("MOUSE", "Small rodent"), entry("CITY", "Large urban area")]
        new_entries = [entry("CITY", "Changed clue")]
        old_bank_path = Path(self.temp_dir.name) / "old-bank.json"
        new_bank_path = Path(self.temp_dir.name) / "new-bank.json"
        audit.write_json(old_bank_path, old_entries)
        audit.write_json(new_bank_path, new_entries)
        audit_report = {
            "schemaVersion": 1,
            "bankSha256": audit.bank_sha256(old_bank_path),
            "eligibleEntryCount": 2,
            "classifications": [
                {"index": 0, "word": "MOUSE", "currentText": "Small rodent", "decision": "keep", "reason": "Specific"},
                {"index": 1, "word": "CITY", "currentText": "Large urban area", "decision": "keep", "reason": "Specific"},
            ],
        }
        audit.update_audit_summary(audit_report)
        proposal_report = {
            "schemaVersion": 1,
            "bankSha256": audit.bank_sha256(old_bank_path),
            "auditSha256": audit.audit_sha256(audit_report),
            "proposals": [],
        }

        with self.assertRaisesRegex(ValueError, "changes beyond"):
            audit.rebase_after_removed_entry(
                old_entries,
                new_entries,
                audit_report,
                proposal_report,
                old_bank_path,
                new_bank_path,
                0,
            )


if __name__ == "__main__":
    unittest.main()
