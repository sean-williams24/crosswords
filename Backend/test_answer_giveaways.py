import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

import audit_answer_giveaways as audit
import generate_puzzle
import generate_weekly_puzzle
from answer_leakage import giveaway_candidates, leaks_answer
from word_bank_safety import certification_errors, current_pairs, new_certification


def entry(word: str, text: str, hard_text: str = "A less direct clue", clues=None, hint: str = "Dormant") -> dict:
    return {
        "word": word,
        "text": text,
        "hint": hint,
        "hard_text": hard_text,
        "clues": clues or ["Alternative clue"],
    }


class MechanicalGiveawayTests(unittest.TestCase):
    def test_blocks_prefixed_answer_root(self) -> None:
        issues = giveaway_candidates("AFIRE", "On fire")
        self.assertTrue(any(issue.root == "fire" for issue in issues))
        self.assertTrue(leaks_answer("AFIRE", "On fire"))

    def test_blocks_ular_spelling_family(self) -> None:
        issues = giveaway_candidates("CIRCULAR", "In the shape of a circle")
        self.assertTrue(any(issue.root == "circle" for issue in issues))
        self.assertTrue(leaks_answer("CIRCULAR", "In the shape of a circle"))

    def test_blocks_gerund_agent_spelling_family(self) -> None:
        self.assertTrue(leaks_answer("TYPEWRITING", "Creating text with a typewriter"))

    def test_allows_ordinary_synonyms(self) -> None:
        self.assertFalse(leaks_answer("AFIRE", "Burning brightly"))
        self.assertFalse(leaks_answer("CIRCULAR", "Round"))

    def test_avoids_incidental_short_substrings(self) -> None:
        self.assertFalse(leaks_answer("ART", "A strong start"))


class GiveawayAuditTests(unittest.TestCase):
    def write_bank(self, entries: list[dict]) -> tuple[tempfile.TemporaryDirectory, Path]:
        directory = tempfile.TemporaryDirectory()
        path = Path(directory.name) / "bank.json"
        path.write_text(json.dumps(entries))
        return directory, path

    def test_audit_marks_mechanical_giveaways_for_terra(self) -> None:
        entries = [entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            text_field = report["records"][0]["fields"][0]
            self.assertEqual(text_field["status"], "confirmed_deterministic_giveaway")
            self.assertTrue(text_field["deterministicIssues"])
        finally:
            directory.cleanup()

    def test_terra_decision_requires_exact_batch_coverage(self) -> None:
        entries = [entry("BREACH", "Break through", clues=["An opening"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            batch = audit.new_batch(report, "primary", 10)
            decision = {
                "schemaVersion": audit.SCHEMA_VERSION,
                "bankSha256": report["bankSha256"],
                "policyVersion": report["policyVersion"],
                "scannerVersion": report["scannerVersion"],
                "stage": "primary",
                "batchId": batch["batchId"],
                "batchHash": batch["batchHash"],
                "decisions": [],
            }
            with self.assertRaisesRegex(ValueError, "cover every"):
                audit.record_decisions(report, batch, decision)
        finally:
            directory.cleanup()

    def test_certification_accepts_safe_pairs_and_ignores_hint(self) -> None:
        entries = [entry("RAPID", "Fast", hard_text="Moving swiftly", clues=["Quick"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            certificate = audit.certify(entries, report, path)
            self.assertEqual(certification_errors(entries, certificate), [])
            entries[0]["hint"] = "Changed dormant metadata"
            self.assertEqual(certification_errors(entries, certificate), [])
        finally:
            directory.cleanup()

    def test_certification_rejects_changed_active_pair(self) -> None:
        entries = [entry("RAPID", "Fast", hard_text="Moving swiftly", clues=["Quick"])]
        certificate = new_certification([
            {**pair, "provenance": "deterministic", "auditStatus": "deterministic_safe"}
            for pair in current_pairs(entries)
        ])
        entries[0]["text"] = "Speedy"
        self.assertTrue(any("does not exactly cover" in error for error in certification_errors(entries, certificate)))

    def test_missing_certification_fails_closed_without_a_traceback(self) -> None:
        entries = [entry("RAPID", "Fast", hard_text="Moving swiftly", clues=["Quick"])]
        with tempfile.TemporaryDirectory() as directory:
            missing_certificate = Path(directory) / "missing.json"
            with (
                patch.object(audit, "load_entries", return_value=entries),
                patch.object(audit, "CERTIFICATION_PATH", missing_certificate),
                patch.object(sys, "argv", ["audit_answer_giveaways.py", "validate-certification"]),
            ):
                with self.assertRaisesRegex(ValueError, "Missing word-bank giveaway certification"):
                    audit.main()

    def test_approved_repair_requires_blind_terra_verification(self) -> None:
        entries = [entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            field = report["records"][0]["fields"][0]
            field["status"] = "confirmed_giveaway"
            package = audit.build_repair_package(report)
            repair = package["repairs"][0]
            repair.update({"status": "approved", "after": "Blazing"})
            repair["verification"] = {
                "verdict": "safe",
                "reason": "Not mechanically related",
                "proposalFingerprint": audit.replacement_fingerprint(repair),
            }
            self.assertEqual(audit.validate_repair_package(entries, package, path), [])
            updated = audit.apply_repairs(entries, package)
            self.assertEqual(updated[0]["text"], "Blazing")
        finally:
            directory.cleanup()

    def test_replacement_verification_is_hash_bound_and_resumable(self) -> None:
        entries = [entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            report["records"][0]["fields"][0]["status"] = "confirmed_giveaway"
            package = audit.build_repair_package(report)
            repair = package["repairs"][0]
            repair.update({"status": "proposed", "after": "Blazing"})
            batch = audit.replacement_verification_batch(entries, package, 10)
            proposal_fingerprint = batch["records"][0]["proposalFingerprint"]
            decisions = {
                "schemaVersion": audit.SCHEMA_VERSION,
                "bankSha256": package["bankSha256"],
                "policyVersion": package["policyVersion"],
                "scannerVersion": package["scannerVersion"],
                "stage": "replacement_verify",
                "batchId": batch["batchId"],
                "batchHash": batch["batchHash"],
                "decisions": [{"proposalFingerprint": proposal_fingerprint, "verdict": "safe", "reason": "No construction path remains"}],
            }
            self.assertEqual(audit.record_replacement_decisions(package, batch, decisions), 1)
            self.assertEqual(repair["status"], "verified")
            self.assertEqual(repair["verification"]["proposalFingerprint"], proposal_fingerprint)
            repair["after"] = "On fire"
            repair["status"] = "approved"
            self.assertTrue(any("verification is stale" in error for error in audit.validate_repair_package(entries, package, path)))
        finally:
            directory.cleanup()

    def test_preserving_enumeration_invalidates_verified_proposal(self) -> None:
        package = {"repairs": [{
            "before": "Old wording (5,7)", "after": "Replacement wording",
            "status": "verified", "verification": {"verdict": "safe"},
        }]}
        self.assertEqual(audit.normalize_proposal_enumerations(package), 1)
        repair = package["repairs"][0]
        self.assertEqual(repair["after"], "Replacement wording (5,7)")
        self.assertEqual(repair["status"], "proposed")
        self.assertNotIn("verification", repair)

    def test_repair_report_is_compact_before_after_artifact(self) -> None:
        package = {
            "bankSha256": "bank",
            "repairs": [{
                "word": "AFIRE", "field": "text", "before": "On fire", "after": "Blazing",
                "status": "verified", "verification": {"verdict": "safe"},
            }],
        }
        report = audit.repair_report(package)
        self.assertIn("| AFIRE | text | On fire | Blazing | safe |", report)

    def test_proposal_report_matches_each_authoring_record(self) -> None:
        batch = {"records": [{
            "fingerprint": "fingerprint", "word": "AFIRE", "field": "text", "before": "On fire",
        }]}
        report = audit.proposal_report(batch, [{
            "fingerprint": "fingerprint", "word": "AFIRE", "field": "text", "after": "Blazing",
        }])
        self.assertIn("| AFIRE | text | On fire | Blazing |", report)
        with self.assertRaisesRegex(ValueError, "mismatched"):
            audit.proposal_report(batch, [{
                "fingerprint": "other", "word": "AFIRE", "field": "text", "after": "Blazing",
            }])

    def test_normalize_proposals_restores_batch_fingerprint_and_applies_override(self) -> None:
        batch = {"records": [{
            "fingerprint": "correct", "word": "AFIRE", "field": "text", "before": "On fire",
        }]}
        normalized = audit.normalize_proposals(batch, [{
            "fingerprint": "truncated", "word": "AFIRE", "field": "text", "after": "Blazing",
        }], {"AFIRE text": "Burning"})
        self.assertEqual(normalized, [{
            "fingerprint": "correct", "word": "AFIRE", "field": "text", "after": "Burning",
        }])

    def test_only_hash_bound_verified_repairs_can_be_approved(self) -> None:
        repair = {
            "word": "AFIRE", "field": "text", "before": "On fire", "after": "Blazing",
            "status": "verified", "fingerprint": "original-pair",
        }
        repair["verification"] = {
            "verdict": "safe", "reason": "No construction path remains",
            "proposalFingerprint": audit.replacement_fingerprint(repair),
        }
        package = {"repairs": [repair]}
        self.assertEqual(audit.approve_verified_repairs(package), 1)
        self.assertEqual(repair["status"], "approved")

    def test_approved_clues_array_repair_targets_the_right_index(self) -> None:
        entries = [entry(
            "BREAKFAST", "First meal of the day", hard_text="Start-of-day meal",
            clues=["Eggs and toast time", "First fuel after sleep", "Breaking the overnight fast"],
        )]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            field = next(item for item in report["records"][0]["fields"] if item["field"] == "clues[2]")
            package = audit.build_repair_package({**report, "records": [{**report["records"][0], "fields": [field]}]})
            repair = package["repairs"][0]
            repair.update({"status": "approved", "after": "Day's opening repast"})
            repair["verification"] = {
                "verdict": "safe", "reason": "No construction path remains",
                "proposalFingerprint": audit.replacement_fingerprint(repair),
            }
            self.assertEqual(audit.validate_repair_package(entries, package, path), [])
            self.assertEqual(audit.apply_repairs(entries, package)[0]["clues"][2], "Day's opening repast")
        finally:
            directory.cleanup()

    def test_refresh_preserves_review_for_unchanged_pairs(self) -> None:
        original = [
            entry("BREACH", "Break through", clues=["An opening"]),
            entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"]),
        ]
        directory, path = self.write_bank(original)
        try:
            report = audit.new_audit(original, path)
            breach = report["records"][0]["fields"][0]
            breach.update({"status": "terra_safe", "terraPrimary": {"verdict": "safe", "reason": "Ordinary synonym"}})
            repaired = json.loads(json.dumps(original))
            repaired[1]["text"] = "Blazing"
            path.write_text(json.dumps(repaired))
            refreshed = audit.refresh_audit_after_repairs(repaired, report, path)
            preserved = refreshed["records"][0]["fields"][0]
            changed = refreshed["records"][1]["fields"][0]
            self.assertEqual(preserved["status"], "terra_safe")
            self.assertEqual(changed["status"], "deterministic_safe")
        finally:
            directory.cleanup()

    def test_refresh_does_not_preserve_stale_safe_status_over_live_leak(self) -> None:
        entries = [entry("COMPUTING", "Using computers", clues=["Digital processing"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            field = report["records"][0]["fields"][0]
            # Simulate a stale audit produced before this derivational form
            # was recognised by the deterministic policy.
            field["status"] = "deterministic_safe"
            refreshed = audit.refresh_audit_after_repairs(entries, report, path)
            current = refreshed["records"][0]["fields"][0]
            self.assertEqual(current["status"], "confirmed_deterministic_giveaway")
            self.assertTrue(current["deterministicIssues"])
        finally:
            directory.cleanup()

    def test_replacement_verification_rejects_duplicate_hint(self) -> None:
        entries = [entry("RIVERSIDE", "Along a watercourse", clues=["Near a flowing channel"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            field = report["records"][0]["fields"][0]
            field["status"] = "confirmed_giveaway"
            package = audit.build_repair_package(report)
            repair = package["repairs"][0]
            repair.update({"status": "proposed", "after": "Near a flowing channel"})
            with self.assertRaisesRegex(ValueError, "duplicate hint proposals"):
                audit.replacement_verification_batch(entries, package, 10)
        finally:
            directory.cleanup()

    def test_import_proposals_requires_current_safe_pending_pair(self) -> None:
        entries = [entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            package = audit.build_repair_package(report)
            repair = package["repairs"][0]
            with patch.object(audit, "bank_sha256", return_value=package["bankSha256"]):
                self.assertEqual(audit.import_proposals(entries, package, [{"fingerprint": repair["fingerprint"], "after": "Blazing"}]), 1)
            self.assertEqual(repair["status"], "proposed")
            self.assertEqual(repair["after"], "Blazing")
        finally:
            directory.cleanup()

    def test_import_proposals_accepts_unique_word_field_identity(self) -> None:
        entries = [entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            package = audit.build_repair_package(report)
            repair = package["repairs"][0]
            with patch.object(audit, "bank_sha256", return_value=package["bankSha256"]):
                self.assertEqual(
                    audit.import_proposals(entries, package, [{"word": "AFIRE", "field": "text", "after": "Blazing"}]),
                    1,
                )
            self.assertEqual(repair["status"], "proposed")
        finally:
            directory.cleanup()

    def test_import_proposals_reopens_manual_review_with_fresh_verification_required(self) -> None:
        entries = [entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"])]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            package = audit.build_repair_package(report)
            repair = package["repairs"][0]
            repair.update({
                "status": "manual_review",
                "after": "On the blaze",
                "verification": {"verdict": "giveaway", "reason": "Too close"},
            })
            with patch.object(audit, "bank_sha256", return_value=package["bankSha256"]):
                self.assertEqual(
                    audit.import_proposals(entries, package, [{"fingerprint": repair["fingerprint"], "after": "Blazing"}]),
                    1,
                )
            self.assertEqual(repair["status"], "proposed")
            self.assertEqual(repair["after"], "Blazing")
            self.assertIsNone(repair["verification"])
        finally:
            directory.cleanup()

    def test_resume_import_skips_only_unmatched_stale_pairs(self) -> None:
        entries = [
            entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"]),
            entry("CIRCULAR", "In the shape of a circle", hard_text="Round", clues=["Loop-like"]),
        ]
        directory, path = self.write_bank(entries)
        try:
            package = audit.build_repair_package(audit.new_audit(entries, path))
            repair = package["repairs"][0]
            proposals = [
                {"fingerprint": "already-applied-pair", "after": "Ignored"},
                {"fingerprint": repair["fingerprint"], "after": "Blazing"},
            ]
            with patch.object(audit, "bank_sha256", return_value=package["bankSha256"]):
                self.assertEqual(audit.import_proposals(entries, package, proposals, skip_unmatched=True), 1)
            self.assertEqual(repair["status"], "proposed")
        finally:
            directory.cleanup()

    def test_import_proposals_rejects_ambiguous_word_field_identity(self) -> None:
        entries = [
            entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"]),
            entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"]),
        ]
        directory, path = self.write_bank(entries)
        try:
            report = audit.new_audit(entries, path)
            package = audit.build_repair_package(report)
            with patch.object(audit, "bank_sha256", return_value=package["bankSha256"]):
                with self.assertRaisesRegex(ValueError, "ambiguous"):
                    audit.import_proposals(entries, package, [{"word": "AFIRE", "field": "text", "after": "Blazing"}])
        finally:
            directory.cleanup()

    def test_authoring_batch_contains_current_pending_records_in_order(self) -> None:
        entries = [
            entry("AFIRE", "On fire", hard_text="Burning brightly", clues=["Set ablaze"]),
            entry("CIRCULAR", "In the shape of a circle", hard_text="Round", clues=["Loop-like"]),
        ]
        directory, path = self.write_bank(entries)
        try:
            package = audit.build_repair_package(audit.new_audit(entries, path))
            batch = audit.authoring_batch(package, 1)
            self.assertEqual(batch["stage"], "replacement_authoring")
            self.assertEqual(len(batch["records"]), 1)
            self.assertEqual(batch["records"][0]["word"], "AFIRE")
            self.assertEqual(batch["records"][0]["field"], "text")
            self.assertEqual(batch["records"][0]["before"], "On fire")
        finally:
            directory.cleanup()

    def test_generators_call_certification_before_word_selection(self) -> None:
        for generator in (generate_puzzle, generate_weekly_puzzle):
            with self.subTest(generator=generator.__name__), patch.object(generator, "validate_certification") as validate:
                generator.load_word_bank(certification_path=Path("/tmp/certification.json"))
                validate.assert_called_once()


if __name__ == "__main__":
    unittest.main()
