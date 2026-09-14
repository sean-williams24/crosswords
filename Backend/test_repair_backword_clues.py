#!/usr/bin/env python3

from __future__ import annotations

import base64
import json
import os
import sys
import types
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

if "openai" not in sys.modules:
    openai_stub = types.ModuleType("openai")
    openai_stub.OpenAI = object
    sys.modules["openai"] = openai_stub

import repair_backword_clues as repair


LEGACY_ROW = {
    "id": "legacy-id",
    "date": "2026-05-20",
    "word_data": {
        "word": "CASTLE",
        "category": "History",
        "definition": "A fortified building.",
        "reject": False,
    },
}
POST_ROW = {
    "id": "post-id",
    "date": "2026-05-21",
    "word_data": {"word": "CHEESY", "clue": "CORN", "reject": False},
}


def build_report(rows, morphology, proposal=("CHESS", {"validatedClue": "CHESS"})):
    with patch.object(repair, "morphology_verdicts", return_value=morphology), patch.object(
        repair, "propose_validated_clue", return_value=proposal
    ) as propose:
        report = repair.build_report(
            rows,
            cutoff=repair.DEFAULT_CUTOFF,
            through_date=repair.DEFAULT_CUTOFF,
            enrichment_model="enrichment",
            validator_model="validator",
            api_key="test-key",
        )
    return report, propose


class ReportBuildingTests(unittest.TestCase):
    def test_codex_export_has_immutable_sources_and_correct_review_routing(self) -> None:
        handoff = repair.build_codex_input(
            [LEGACY_ROW, POST_ROW], cutoff=repair.DEFAULT_CUTOFF, through_date=repair.DEFAULT_CUTOFF
        )

        legacy, post = handoff["entries"]
        self.assertEqual("generate_current_style_clue", legacy["reviewTask"])
        self.assertEqual("review_existing_clue_morphology", post["reviewTask"])
        self.assertEqual("History", legacy["sourceWordData"]["category"])
        self.assertEqual(2, handoff["source"]["rowCount"])
        self.assertEqual(
            repair.json_sha256([
                {"id": entry["id"], "wordDataSha256": entry["sourceWordDataSha256"]}
                for entry in handoff["entries"]
            ]),
            handoff["source"]["rowsSha256"],
        )

    def test_legacy_rows_add_validated_clue_and_preserve_legacy_metadata(self) -> None:
        report, propose = build_report(
            [LEGACY_ROW, POST_ROW],
            {"post-id": {"decision": "KEEP", "reason": "Exact form is valid."}},
        )

        legacy, post = report["entries"]
        self.assertEqual("legacy_category", legacy["era"])
        self.assertEqual("add", legacy["action"])
        self.assertEqual("proposed", legacy["status"])
        self.assertEqual("CHESS", legacy["proposedClue"])
        self.assertEqual("History", legacy["sourceWordData"]["category"])
        self.assertEqual("A fortified building.", legacy["sourceWordData"]["definition"])
        self.assertEqual("unchanged", post["action"])
        self.assertEqual("unchanged", post["status"])
        propose.assert_called_once_with("CASTLE", "enrichment", "validator", "test-key")

    def test_only_explicit_post_cutover_replace_verdict_generates_a_repair(self) -> None:
        post_two = {
            "id": "post-keep-id",
            "date": "2026-05-22",
            "word_data": {"word": "CHEESY", "clue": "CORNY", "reject": False},
        }
        report, propose = build_report(
            [POST_ROW, post_two],
            {
                "post-id": {"decision": "REPLACE", "reason": "Wrong adjective form."},
                "post-keep-id": {"decision": "KEEP", "reason": "Exact form is valid."},
            },
            proposal=("CORNY", {"validatedClue": "CORNY"}),
        )

        replacing, unchanged = report["entries"]
        self.assertEqual(("replace", "proposed", "CORNY"), (
            replacing["action"], replacing["status"], replacing["proposedClue"]
        ))
        self.assertEqual(("unchanged", "unchanged"), (unchanged["action"], unchanged["status"]))
        propose.assert_called_once_with("CHEESY", "enrichment", "validator", "test-key")

    def test_validator_failure_and_ambiguous_morphology_remain_unresolved(self) -> None:
        report, _ = build_report(
            [LEGACY_ROW, POST_ROW],
            {"post-id": {"decision": "UNRESOLVED", "reason": "Ambiguous answer form."}},
            proposal=(None, {"failure": "Validator rejected candidate."}),
        )

        self.assertTrue(all(entry["status"] == "unresolved" for entry in report["entries"]))
        with self.assertRaisesRegex(ValueError, "unresolved"):
            repair.validate_report(report, require_reviewed=True)

    def test_rejected_legacy_answer_and_validator_rejection_never_produce_a_patch(self) -> None:
        with patch.object(repair.generate_backword, "enrich_words", return_value=[{
            "word": "CASTLE", "reject": True, "clue": ""
        }]):
            clue, evidence = repair.propose_validated_clue("CASTLE", "enrichment", "validator", "test-key")
        self.assertIsNone(clue)
        self.assertIn("rejected", evidence["generation"]["failure"].lower())

        with patch.object(repair.generate_backword, "enrich_words", return_value=[{
            "word": "CASTLE", "reject": False, "clue": "CHESS"
        }]), patch.object(repair, "validate_candidate", return_value=(False, {"semantic": "rejected"})):
            clue, evidence = repair.propose_validated_clue("CASTLE", "enrichment", "validator", "test-key")
        self.assertIsNone(clue)
        self.assertEqual("Generated clue did not pass every current validation gate.", evidence["failure"])


class MorphologyReviewTests(unittest.TestCase):
    def test_malformed_or_incomplete_reviewer_response_fails_closed(self) -> None:
        response = SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps({"reviews": []})))]
        )
        client = SimpleNamespace(
            chat=SimpleNamespace(completions=SimpleNamespace(create=lambda **_: response))
        )
        with patch.object(repair.generate_backword, "OpenAI", return_value=client):
            verdicts = repair.morphology_verdicts(
                [{"id": "row-id", "word": "CHEESY", "currentClue": "CORN"}],
                "validator",
                "test-key",
            )

        self.assertEqual("UNRESOLVED", verdicts["row-id"]["decision"])
        self.assertIn("failed closed", verdicts["row-id"]["reason"])


class ApplyWorkflowTests(unittest.TestCase):
    @staticmethod
    def refresh_manifest(report: dict) -> None:
        report["source"]["rowsSha256"] = repair.json_sha256([
            {"id": entry["id"], "wordDataSha256": entry["sourceWordDataSha256"]}
            for entry in report["entries"]
        ])

    def reviewed_report(self) -> dict:
        report, _ = build_report(
            [LEGACY_ROW, POST_ROW],
            {"post-id": {"decision": "KEEP", "reason": "Exact form is valid."}},
        )
        report["entries"][0]["status"] = "approved"
        return report

    def test_apply_requires_completed_human_review_and_intact_validated_proposal(self) -> None:
        report = self.reviewed_report()
        report["entries"][0]["status"] = "proposed"
        with self.assertRaisesRegex(ValueError, "awaiting human review"):
            repair.validate_report(report, require_reviewed=True)

        report["entries"][0]["status"] = "approved"
        report["entries"][0]["proposedClue"] = "OTHER"
        with self.assertRaisesRegex(ValueError, "validated clue"):
            repair.validate_report(report, require_reviewed=True)

    def test_source_hash_tampering_is_rejected(self) -> None:
        report = self.reviewed_report()
        report["entries"][0]["sourceWordData"]["category"] = "Changed"
        with self.assertRaisesRegex(ValueError, "source payload hash"):
            repair.validate_report(report, require_reviewed=True)

    def test_approve_all_records_only_pending_patch_proposals(self) -> None:
        report = self.reviewed_report()
        report["entries"][0]["status"] = "proposed"
        report["entries"].append({
            **report["entries"][0],
            "id": "skipped-id",
            "status": "skipped",
        })
        self.refresh_manifest(report)

        self.assertEqual(1, repair.approve_all_proposals(report))
        self.assertEqual("approved", report["entries"][0]["status"])
        self.assertEqual("skipped", report["entries"][2]["status"])

    def test_apply_is_idempotent_and_leaves_conflicts_untouched(self) -> None:
        report = self.reviewed_report()
        entry = report["entries"][0]
        patched = repair.patched_word_data(entry)
        changed = {**LEGACY_ROW, "word_data": {**LEGACY_ROW["word_data"], "category": "Changed"}}
        current_rows = [
            LEGACY_ROW,
            {"id": "already-id", "date": "2026-05-19", "word_data": patched},
            {**changed, "id": "conflict-id"},
        ]
        already = {**entry, "id": "already-id"}
        conflict = {**entry, "id": "conflict-id"}
        report["entries"] = [entry, already, conflict]
        self.refresh_manifest(report)
        updates = []

        with patch.object(repair, "fetch_rows_by_ids", return_value=current_rows), patch.object(
            repair, "update_word_data", side_effect=lambda _client, row_id, payload: updates.append((row_id, payload))
        ):
            outcomes = repair.apply_report(report, object())

        self.assertEqual([("legacy-id", patched)], updates)
        self.assertEqual(
            {"legacy-id": "applied", "already-id": "already_applied", "conflict-id": "conflict"},
            {outcome["id"]: outcome["outcome"] for outcome in outcomes},
        )

    def test_rollback_restores_only_currently_patched_rows(self) -> None:
        report = self.reviewed_report()
        entry = report["entries"][0]
        patched = repair.patched_word_data(entry)
        updates = []
        with patch.object(repair, "fetch_rows_by_ids", return_value=[{**LEGACY_ROW, "word_data": patched}]), patch.object(
            repair, "update_word_data", side_effect=lambda _client, row_id, payload: updates.append((row_id, payload))
        ):
            outcomes = repair.apply_report(report, object(), rollback=True)

        self.assertEqual([("legacy-id", LEGACY_ROW["word_data"])], updates)
        self.assertEqual("applied", outcomes[0]["outcome"])


class CodexDecisionTests(unittest.TestCase):
    def handoff(self) -> dict:
        return repair.build_codex_input(
            [LEGACY_ROW, POST_ROW], cutoff=repair.DEFAULT_CUTOFF, through_date=repair.DEFAULT_CUTOFF
        )

    def decisions(self, handoff: dict) -> dict:
        legacy, post = handoff["entries"]
        return {"decisions": [
            {
                "id": legacy["id"], "sourceWordDataSha256": legacy["sourceWordDataSha256"],
                "decision": "REPLACE", "proposedClue": "CHESS", "reason": "A castle is strongly associated with chess.",
            },
            {
                "id": post["id"], "sourceWordDataSha256": post["sourceWordDataSha256"],
                "decision": "KEEP", "reason": "The existing clue needs no word-form change.",
            },
        ]}

    def test_codex_decisions_create_a_normal_human_review_artifact(self) -> None:
        handoff = self.handoff()
        report = repair.build_report_from_codex_decisions(handoff, self.decisions(handoff))
        legacy, post = report["entries"]
        self.assertEqual(("add", "proposed", "CHESS"), (
            legacy["action"], legacy["status"], legacy["proposedClue"]
        ))
        self.assertEqual(("unchanged", "unchanged"), (post["action"], post["status"]))
        self.assertEqual("interactive_codex", report["models"]["enrichment"])

    def test_codex_decisions_require_full_snapshot_matched_coverage(self) -> None:
        handoff = self.handoff()
        decisions = self.decisions(handoff)
        decisions["decisions"].pop()
        with self.assertRaisesRegex(ValueError, "every source row"):
            repair.build_report_from_codex_decisions(handoff, decisions)

        decisions = self.decisions(handoff)
        decisions["decisions"][0]["sourceWordDataSha256"] = "stale"
        with self.assertRaisesRegex(ValueError, "source snapshot"):
            repair.build_report_from_codex_decisions(handoff, decisions)

    def test_compact_codex_decisions_expand_only_after_full_legacy_and_keep_confirmation(self) -> None:
        handoff = self.handoff()
        compact = {
            "sourceRowsSha256": handoff["source"]["rowsSha256"],
            "confirmedAllOtherPostCutoverCluesKeep": True,
            "legacyClues": {"2026-05-20": "CONSCIENCE"},
            "postCutoverReplacements": {"2026-05-21": "CORNY"},
        }
        report = repair.build_report_from_codex_decisions(handoff, compact)
        self.assertEqual(["CONSCIENCE", "CORNY"], [entry["proposedClue"] for entry in report["entries"]])

        compact["legacyClues"] = {}
        with self.assertRaisesRegex(ValueError, "every legacy date"):
            repair.build_report_from_codex_decisions(handoff, compact)


class CredentialTests(unittest.TestCase):
    def test_service_key_detection_rejects_public_jwt_and_accepts_service_jwt(self) -> None:
        def jwt(role: str) -> str:
            payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=")
            return f"header.{payload}.signature"

        self.assertFalse(repair.is_service_role_key(jwt("anon")))
        self.assertTrue(repair.is_service_role_key(jwt("service_role")))
        self.assertTrue(repair.is_service_role_key("sb_secret_example"))

    def test_credential_values_are_trimmed_before_they_form_requests(self) -> None:
        with patch.dict(
            os.environ,
            {"SUPABASE_URL": "https://example.supabase.co%0A%0A", "SUPABASE_KEY": "sb_secret_example\n"},
            clear=False,
        ), patch.object(repair, "load_backend_env"):
            self.assertEqual(
                ("https://example.supabase.co", "sb_secret_example"),
                repair.supabase_credentials(require_service_role=True),
            )

    def test_codex_export_can_read_with_public_credentials_without_supabase_sdk(self) -> None:
        response = MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps([LEGACY_ROW]).encode()
        with patch.object(repair, "supabase_credentials", return_value=("https://example.supabase.co", "anon-key")), patch.object(
            repair, "urlopen", return_value=response
        ) as open_request:
            rows = repair.fetch_released_rows_via_rest(repair.DEFAULT_CUTOFF)

        self.assertEqual([LEGACY_ROW], rows)
        self.assertIn("date=lte.2026-05-21", open_request.call_args.args[0].full_url)

    def test_rest_apply_client_uses_service_authenticated_preflight_and_patch(self) -> None:
        client = repair.RestSupabaseClient("https://example.supabase.co", "service-key")
        get_response = MagicMock()
        get_response.__enter__.return_value.read.return_value = json.dumps([LEGACY_ROW]).encode()
        patch_response = MagicMock()
        patch_response.__enter__.return_value.read.return_value = b""
        with patch.object(repair, "urlopen", side_effect=[get_response, patch_response]) as open_request:
            rows = repair.fetch_rows_by_ids(client, ["legacy-id"])
            repair.update_word_data(client, "legacy-id", LEGACY_ROW["word_data"])

        self.assertEqual([LEGACY_ROW], rows)
        get_request, patch_request = [call.args[0] for call in open_request.call_args_list]
        self.assertEqual("GET", get_request.method)
        self.assertIn("id=in.%28legacy-id%29", get_request.full_url)
        self.assertEqual("PATCH", patch_request.method)
        self.assertIn("id=eq.legacy-id", patch_request.full_url)
        self.assertEqual("Bearer service-key", patch_request.get_header("Authorization"))


if __name__ == "__main__":
    unittest.main()
