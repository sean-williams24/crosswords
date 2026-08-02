#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from audit_clue_answer_alignment import (
    apply_sol_verdicts,
    apply_terra_verdicts,
    build_terra_batch_requests,
    field_values,
    new_chat_batch,
    new_audit,
    propose_removals,
    record_stage,
    estimate_terra_cost,
    validate_chat_decisions,
    validate_compact_results,
    validate_model_response,
    validate_removals,
    response_text,
    batch_usage,
    projected_total_cost,
)


class ClueAnswerAlignmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.bank_path = Path(self.temp_dir.name) / "word_bank.json"
        self.entries = [{
            "word": "STANDISH",
            "text": "A character in 'The Scarlet Letter'",
            "hint": "literary figure",
            "hard_text": "Name of a notable Puritan in fiction",
            "clues": [
                "Fictional character in Hawthorne's novel",
                "Puritan with a prominent role in literature",
                "Last name of a 17th-century New England figure",
            ],
        }]
        self.bank_path.write_text(json.dumps(self.entries, indent=4) + "\n")
        self.audit = new_audit(self.entries, self.bank_path)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def full_mismatch_response(self) -> dict:
        return {
            "results": [{
                "index": 0,
                "verdicts": [
                    {"field": field["field"], "verdict": "mismatch", "confidence": "high", "reason": "The claim does not identify this answer."}
                    for field in self.audit["records"][0]["fields"]
                ],
            }],
        }

    def test_all_stored_clue_fields_are_in_scope(self) -> None:
        self.assertEqual(
            [field["field"] for field in field_values(self.entries[0])],
            ["text", "hint", "hard_text", "clues[0]", "clues[1]", "clues[2]"],
        )

    def test_standish_mismatch_response_requires_exact_field_coverage(self) -> None:
        result = validate_model_response(self.audit["records"], self.full_mismatch_response())
        self.assertEqual(set(result[0]), {"text", "hint", "hard_text", "clues[0]", "clues[1]", "clues[2]"})
        incomplete = self.full_mismatch_response()
        incomplete["results"][0]["verdicts"].pop()
        with self.assertRaisesRegex(ValueError, "coverage"):
            validate_model_response(self.audit["records"], incomplete)

    def test_only_two_model_mismatches_become_removal_proposals(self) -> None:
        terra = validate_model_response(self.audit["records"], self.full_mismatch_response())
        apply_terra_verdicts(self.audit, terra)
        sol = validate_model_response(self.audit["records"], self.full_mismatch_response())
        apply_sol_verdicts(self.audit, sol)
        proposals = propose_removals(self.audit)
        self.assertEqual(proposals["removals"][0]["word"], "STANDISH")
        self.assertEqual(proposals["removals"][0]["status"], "pending_review")

    def test_terra_only_mismatch_produces_a_human_review_proposal(self) -> None:
        terra = validate_model_response(self.audit["records"], self.full_mismatch_response())
        apply_terra_verdicts(self.audit, terra, require_independent_verification=False)
        proposals = propose_removals(self.audit)
        self.assertEqual(proposals["removals"][0]["word"], "STANDISH")
        self.assertEqual(proposals["removals"][0]["reviewBasis"], "terra_only")

    def test_disagreement_requires_human_review_and_blocks_removal(self) -> None:
        terra = validate_model_response(self.audit["records"], self.full_mismatch_response())
        apply_terra_verdicts(self.audit, terra)
        sol_response = self.full_mismatch_response()
        sol_response["results"][0]["verdicts"][0]["verdict"] = "match"
        sol = validate_model_response(self.audit["records"], sol_response)
        apply_sol_verdicts(self.audit, sol)
        self.assertEqual(self.audit["records"][0]["fields"][0]["status"], "needs_human_review")
        self.assertEqual(propose_removals(self.audit)["removals"], [])

    def test_only_approved_proposals_can_validate_for_application(self) -> None:
        terra = validate_model_response(self.audit["records"], self.full_mismatch_response())
        apply_terra_verdicts(self.audit, terra)
        sol = validate_model_response(self.audit["records"], self.full_mismatch_response())
        apply_sol_verdicts(self.audit, sol)
        proposals = propose_removals(self.audit)
        self.assertEqual(validate_removals(self.entries, proposals, self.bank_path), [])
        proposals["removals"][0]["status"] = "approved"
        self.assertEqual(len(validate_removals(self.entries, proposals, self.bank_path)), 1)

    def test_chat_batch_binds_decisions_to_the_exact_export(self) -> None:
        batch = new_chat_batch(self.audit, "terra", limit=25)
        decisions = {
            "schemaVersion": batch["schemaVersion"],
            "bankSha256": batch["bankSha256"],
            "stage": batch["stage"],
            "batchId": batch["batchId"],
            "batchHash": batch["batchHash"],
            **self.full_mismatch_response(),
        }
        self.assertEqual(len(validate_chat_decisions(batch, decisions)), 1)
        self.assertEqual(record_stage(self.audit, batch, decisions), 1)
        stale = dict(decisions)
        stale["batchHash"] = "wrong"
        with self.assertRaisesRegex(ValueError, "batchHash"):
            validate_chat_decisions(batch, stale)

    def test_compact_chat_decision_expands_confirmed_matches(self) -> None:
        batch = new_chat_batch(self.audit, "terra", limit=25)
        decisions = {
            "schemaVersion": batch["schemaVersion"],
            "bankSha256": batch["bankSha256"],
            "stage": batch["stage"],
            "batchId": batch["batchId"],
            "batchHash": batch["batchHash"],
            "confirmedAllOtherFieldsMatch": True,
            "overrides": [{
                "index": 0,
                "field": "clues[0]",
                "verdict": "mismatch",
                "confidence": "high",
                "reason": "The clue does not identify the answer.",
            }],
        }
        expanded = validate_chat_decisions(batch, decisions)
        self.assertEqual(expanded[0]["clues[0]"]["verdict"], "mismatch")
        self.assertEqual(expanded[0]["text"]["verdict"], "match")

    def test_compact_api_response_requires_confirmation_and_expands_matches(self) -> None:
        compact = {
            "confirmedAllOtherFieldsMatch": True,
            "overrides": [{
                "index": 0,
                "field": "hint",
                "verdict": "needs_review",
                "confidence": "medium",
                "reason": "The clue is too vague to verify.",
            }],
        }
        expanded = validate_compact_results(self.audit["records"], compact, "Model confirmed match.")
        self.assertEqual(expanded[0]["hint"]["verdict"], "needs_review")
        self.assertEqual(expanded[0]["text"]["verdict"], "match")
        with self.assertRaisesRegex(ValueError, "confirm"):
            validate_compact_results(self.audit["records"], {"overrides": []}, "Model confirmed match.")

    def test_terra_cost_estimate_uses_batch_discount(self) -> None:
        cost = estimate_terra_cost({
            "inputTokens": 1_000_000,
            "cachedInputTokens": 200_000,
            "outputTokens": 1_000_000,
        })
        self.assertAlmostEqual(cost["directUSD"], 17.05)
        self.assertAlmostEqual(cost["batchUSD"], 8.525)

    def test_batch_requests_preserve_record_indexes_and_use_responses(self) -> None:
        requests, manifest = build_terra_batch_requests(self.audit["records"], batch_size=1)
        self.assertEqual(requests[0]["url"], "/v1/responses")
        self.assertEqual(requests[0]["body"]["max_output_tokens"], 4000)
        self.assertEqual(manifest, [{"customId": "terra-0-0", "indexes": [0]}])

    def test_response_text_extracts_responses_api_message_content(self) -> None:
        self.assertEqual(
            response_text({"output": [{"content": [{"type": "output_text", "text": "{}"}]}]}),
            "{}",
        )

    def test_batch_usage_and_projection_use_billable_output(self) -> None:
        raw_output = json.dumps({"response": {"body": {"usage": {
            "input_tokens": 20,
            "input_tokens_details": {"cached_tokens": 5},
            "output_tokens": 10,
        }}}})
        self.assertEqual(batch_usage(raw_output), {
            "inputTokens": 20,
            "cachedInputTokens": 5,
            "outputTokens": 10,
        })
        self.assertEqual(projected_total_cost(5.0, 100, 400), 25.0)


if __name__ == "__main__":
    unittest.main()
