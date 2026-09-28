import copy
from datetime import date, timedelta
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import MagicMock, patch

import automate_anagram as auto
from generate_anagram import prepare, read_published_rows, signature
from publish_anagram import publish_artifact, validate_publication


def group(word, alternatives=(), external=(), seed=False):
    key = signature(word)
    info = lambda value: {"word": value, "zipf": 4.0, "top200kRank": 100}
    return {"signature": key, "primary": word, "seed": seed,
            "bankWords": [info(word), *[info(w) for w in alternatives]],
            "externalWords": [info(w) for w in external]}


def review(batch, _prompt, _model):
    return {"groups": [
        {"signature": candidate["signature"], "complete": True, "reason": "OK",
         "words": [{"word": item["word"], "accept": item in candidate["bankWords"],
                    "reason": "OK" if item in candidate["bankWords"] else "Not common"}
                   for item in candidate["bankWords"] + candidate["externalWords"]]}
        for candidate in batch
    ]}


class AutomatedAnagramTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from generate_anagram import load_pool
        cls.launch = prepare(date(2026, 9, 26), 1, 30, load_pool())

    def test_candidate_sources_primary_threshold_and_missing_bank_alternative(self):
        fake = types.ModuleType("wordfreq")
        fake.top_n_list = lambda _language, _limit: ["triangle", "integral", "relating", "obscurex"]
        scores = {"triangle": 4.0, "integral": 3.8, "relating": 3.4, "obscurex": 3.499}
        fake.zipf_frequency = lambda word, _language: scores[word]
        with tempfile.TemporaryDirectory() as directory:
            bank = Path(directory) / "bank.json"
            pool = Path(directory) / "pool.json"
            bank.write_text(json.dumps([{"word": "TRIANGLE"}, {"word": "INTEGRAL"},
                                        {"word": "OBSCUREX"}]))
            pool.write_text(json.dumps({"schemaVersion": 1,
                                        "source": "Backend/word_bank.json",
                                        "entries": [{"answer": "TRIANGLE"}]}))
            with patch.object(auto, "BANK", bank), patch.object(auto, "POOL", pool), \
                    patch.dict(sys.modules, {"wordfreq": fake}):
                groups, seeds = auto.candidate_groups()
        self.assertEqual(seeds, [signature("TRIANGLE")])
        candidate = groups[signature("TRIANGLE")]
        self.assertEqual(candidate["primary"], "TRIANGLE")
        self.assertEqual([w["word"] for w in candidate["bankWords"]], ["TRIANGLE", "INTEGRAL"])
        self.assertEqual([w["word"] for w in candidate["externalWords"]], ["RELATING"])
        self.assertNotIn(signature("OBSCUREX"), groups)

    def test_review_requires_complete_exact_matching_verdicts(self):
        candidate = group("TRIANGLE", ("INTEGRAL",), ("RELATING",))
        first = review([candidate], "", "")["groups"][0]
        self.assertEqual(auto.approved_answers(candidate, first, first), ["INTEGRAL"])
        external_approved = copy.deepcopy(first)
        external_approved["words"][-1]["accept"] = True
        self.assertIsNone(auto.approved_answers(candidate, first, external_approved))
        disagreement = copy.deepcopy(first)
        disagreement["words"][1]["accept"] = False
        self.assertIsNone(auto.approved_answers(candidate, first, disagreement))
        incomplete = copy.deepcopy(first)
        incomplete["complete"] = False
        self.assertIsNone(auto.approved_answers(candidate, first, incomplete))
        for malformed in ({"groups": []}, {"groups": [{**first, "words": first["words"][:-1]}]},
                          {"groups": [{**first, "signature": "wrong"}]}):
            with self.assertRaises(ValueError):
                auto.validate_review(malformed, [candidate])

    def test_buffer_and_never_used_priority(self):
        start, issue, count = auto.buffer_plan(self.launch, date(2026, 9, 26))
        self.assertEqual((start, issue, count), (date(2026, 10, 26), 31, 1))
        self.assertEqual(auto.buffer_plan(self.launch, date(2026, 9, 25))[2], 0)
        groups = {g["signature"]: g for g in [group("BALANCE"), group("PICTURE", seed=True),
                                             group("LIBRARY")]}
        releases = {signature("BALANCE"): date(2025, 10, 26)}
        unused, reused = auto.order_candidates(groups, [signature("PICTURE")], releases,
                                                 31, date(2026, 10, 26), date(2026, 10, 27))
        self.assertEqual(unused[0]["primary"], "PICTURE")
        self.assertEqual(reused[0]["primary"], "BALANCE")

    def test_full_buffer_skips_review_and_existing_gap_fails(self):
        report = {}
        self.assertIsNone(auto.build_artifact(
            self.launch, date(2026, 9, 25), {}, [],
            reviewer=lambda *_: self.fail("Full buffer must not call AI"), report=report))
        self.assertEqual(report["status"], "buffer_full")
        with self.assertRaisesRegex(ValueError, "Gap in Anagram date or issue"):
            auto.buffer_plan(self.launch[:10] + self.launch[11:], date(2026, 9, 26))

    def test_repeat_boundary_and_future_queue(self):
        candidate = group("TRIANGLE")
        bundle = {"candidate": candidate,
                  "lexical": review([candidate], "", "")["groups"][0],
                  "adversarial": review([candidate], "", "")["groups"][0]}
        start = date(2026, 10, 26)
        for days, expected in ((364, 0), (365, 1)):
            releases = {candidate["signature"]: start - timedelta(days=days)}
            rows, _ = auto.assign_rows([bundle], releases, start, 31, 1)
            self.assertEqual(len(rows), expected)
        # A future queued row counts even though its release day has not arrived.
        future = {candidate["signature"]: date(2026, 10, 25)}
        unused, reused = auto.order_candidates({candidate["signature"]: candidate}, [],
                                                 future, 31, start, start)
        self.assertEqual(unused + reused, [])
        rows, _ = auto.assign_rows([bundle, bundle], {}, start, 31, 2)
        self.assertEqual(len(rows), 1)
        eligible_on_second_day = {candidate["signature"]: start - timedelta(days=364)}
        unused_first = group("BASEBALL")
        first_bundle = {"candidate": unused_first,
                        "lexical": review([unused_first], "", "")["groups"][0],
                        "adversarial": review([unused_first], "", "")["groups"][0]}
        rows, _ = auto.assign_rows([first_bundle, bundle], eligible_on_second_day,
                                   start, 31, 2)
        self.assertEqual([row["puzzle_data"]["answer"] for row in rows],
                         ["BASEBALL", "TRIANGLE"])

    def test_review_retries_are_bounded_and_incomplete_batch_never_approves(self):
        candidates = [group(word) for word in ("BASEBALL", "BICYCLE", "BROCCOLI")]
        groups = {item["signature"]: item for item in candidates}
        status = {}
        with self.assertRaisesRegex(ValueError, "Approved only 0/1"):
            auto.build_artifact(self.launch, date(2026, 9, 26), groups, [],
                                reviewer=lambda *_: {"groups": []}, report=status,
                                max_attempts=2, batch_size=1)
        self.assertEqual(status["status"], "failed")
        self.assertEqual(len(status["attempts"]), 2)

    def test_automated_artifact_binds_rows_and_review_evidence(self):
        candidate = group("BASEBALL", seed=True)
        groups = {candidate["signature"]: candidate}
        artifact = auto.build_artifact(self.launch, date(2026, 9, 26), groups,
                                       [candidate["signature"]], reviewer=review)
        with patch.object(auto, "candidate_groups", return_value=(groups, [candidate["signature"]])):
            self.assertEqual(validate_publication(artifact, self.launch), artifact["rows"])
            changed = copy.deepcopy(artifact)
            changed["rows"][0]["puzzle_data"]["answer"] = "BICYCLE"
            with self.assertRaisesRegex(ValueError, "digest mismatch"):
                validate_publication(changed, self.launch)
            changed["contentDigest"] = auto.canonical_digest(
                {k: v for k, v in changed.items() if k != "contentDigest"})
            with self.assertRaises(ValueError):
                validate_publication(changed, self.launch)
            evidence = copy.deepcopy(artifact)
            evidence["reviews"][0]["lexical"]["complete"] = False
            evidence["contentDigest"] = auto.canonical_digest(
                {k: v for k, v in evidence.items() if k != "contentDigest"})
            with self.assertRaisesRegex(ValueError, "did not agree"):
                validate_publication(evidence, self.launch)
            with self.assertRaisesRegex(ValueError, "stale"):
                validate_publication(artifact, self.launch + artifact["rows"])

    def test_publisher_inserts_once_and_verifies_readback(self):
        candidate = group("BASEBALL", seed=True)
        groups = {candidate["signature"]: candidate}
        artifact = auto.build_artifact(self.launch, date(2026, 9, 26), groups,
                                       [candidate["signature"]], reviewer=review)
        client = MagicMock()
        with patch("publish_anagram.read_published_rows",
                   side_effect=[self.launch, self.launch + artifact["rows"]]), \
             patch.object(auto, "candidate_groups", return_value=(groups, [])):
            self.assertEqual(publish_artifact(artifact, client), artifact["rows"])
        client.table().insert.assert_called_once_with(artifact["rows"])
        with patch("publish_anagram.read_published_rows", return_value=self.launch + artifact["rows"]), \
             patch.object(auto, "candidate_groups", return_value=(groups, [])):
            with self.assertRaisesRegex(ValueError, "stale"):
                publish_artifact(artifact, client)
        self.assertEqual(client.table().insert.call_count, 1)

    def test_publisher_reports_failed_readback(self):
        candidate = group("BASEBALL", seed=True)
        groups = {candidate["signature"]: candidate}
        artifact = auto.build_artifact(self.launch, date(2026, 9, 26), groups,
                                       [candidate["signature"]], reviewer=review)
        client = MagicMock()
        with patch("publish_anagram.read_published_rows",
                   side_effect=[self.launch, self.launch]), \
             patch.object(auto, "candidate_groups", return_value=(groups, [])):
            with self.assertRaisesRegex(RuntimeError, "did not verify"):
                publish_artifact(artifact, client)
        client.table().insert.assert_called_once_with(artifact["rows"])

    def test_model_uses_structured_output(self):
        client = MagicMock()
        client.chat.completions.create.return_value.choices = [
            types.SimpleNamespace(message=types.SimpleNamespace(content='{"groups": []}'))]
        fake_openai = types.ModuleType("openai")
        fake_openai.OpenAI = lambda **_kwargs: client
        with patch.dict(sys.modules, {"openai": fake_openai}), \
             patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}):
            self.assertEqual(auto.model_review([], auto.LEXICAL_REVIEW, "gpt-5.4"),
                             {"groups": []})
        self.assertEqual(client.chat.completions.create.call_args.kwargs["response_format"],
                         auto.REVIEW_FORMAT)

    def test_paginated_remote_read_includes_future_rows(self):
        pages = [[{"date": f"day-{n}"} for n in range(1000)], [{"date": "future"}]]
        fake_client = MagicMock()
        fake_client.table().select().order().range().execute.side_effect = [
            types.SimpleNamespace(data=page) for page in pages]
        fake_client.reset_mock()
        fake_supabase = types.ModuleType("supabase")
        fake_supabase.create_client = lambda *_: fake_client
        with patch.dict(sys.modules, {"supabase": fake_supabase}), \
             patch.dict("os.environ", {"SUPABASE_URL": "url", "SUPABASE_KEY": "key"}):
            rows = read_published_rows()
        self.assertEqual(len(rows), 1001)
        self.assertEqual(rows[-1]["date"], "future")
        self.assertEqual(fake_client.table().select().order().range.call_count, 2)

    def test_dry_run_never_calls_publisher(self):
        candidate = group("BASEBALL", seed=True)
        groups = {candidate["signature"]: candidate}
        with tempfile.TemporaryDirectory() as directory:
            artifact_path = Path(directory) / "artifact.json"
            report_path = Path(directory) / "report.json"
            args = ["automate_anagram.py", "--dry-run", "--today", "2026-09-26",
                    "--output", str(artifact_path), "--report", str(report_path)]
            with patch.object(sys, "argv", args), \
                 patch.object(auto, "read_published_rows", return_value=self.launch), \
                 patch.object(auto, "candidate_groups", return_value=(groups, [candidate["signature"]])), \
                 patch.object(auto, "model_review", side_effect=review), \
                 patch("publish_anagram.publish_artifact") as publish:
                auto.main()
            publish.assert_not_called()
            self.assertEqual(json.loads(report_path.read_text())["status"], "prepared")
            self.assertTrue(artifact_path.exists())


if __name__ == "__main__":
    unittest.main()
