import json
from pathlib import Path
import tempfile
import unittest
from datetime import date
from unittest.mock import Mock, patch

import automate_midword as automation


def candidate(first="BANK", answer="NOTE", second="BOOK"):
    row = {"first_word": first, "answer": answer, "second_word": second,
           "first_compound": first + answer, "second_compound": answer + second}
    return {**row, "id": automation.candidate_id(row)}


def safe_review(batch, prompt, model):
    return {"reviews": [{"id": item["id"], "accept": True,
                         "firstMeaning": "A compound using both ordinary component meanings",
                         "secondMeaning": "A compound using both ordinary component meanings",
                         "competingAnswers": [], "difficulty": "moderate", "reason": "Familiar and unambiguous"}
                        for item in batch]}


class MidwordAutomationTests(unittest.TestCase):
    def setUp(self):
        inventory = patch.object(automation, "load_inventory", return_value=([], set()))
        inventory.start()
        self.addCleanup(inventory.stop)

    def build(self, candidates=None, existing=None, reviewer=safe_review, days=1, **kwargs):
        return automation.build_batch(existing or [], date(2026, 11, 17), days,
                                      reviewer=reviewer,
                                      candidates=candidates if candidates is not None else [candidate()],
                                      **kwargs)

    def test_new_puzzle_needs_two_independent_reviews(self):
        reviewer = Mock(side_effect=safe_review)
        artifact = self.build(reviewer=reviewer)
        self.assertEqual(reviewer.call_count, 2)
        self.assertEqual(reviewer.call_args_list[0].args[1], automation.LEXICAL_REVIEW)
        self.assertEqual(reviewer.call_args_list[1].args[1], automation.ADVERSARIAL_REVIEW)
        self.assertEqual(artifact["rows"][0]["answer"], "NOTE")
        self.assertEqual(artifact["reviews"][0]["source"], "automated")
        self.assertIn("lexical", artifact["reviews"][0])
        self.assertIn("adversarial", artifact["reviews"][0])

    def test_either_reviewer_can_reject_false_split(self):
        for rejected_prompt in (automation.LEXICAL_REVIEW, automation.ADVERSARIAL_REVIEW):
            with self.subTest(prompt=rejected_prompt):
                def reviewer(batch, prompt, model):
                    response = safe_review(batch, prompt, model)
                    if prompt == rejected_prompt:
                        response["reviews"][0].update(accept=False, reason="MAN+AGE is a false split")
                    return response
                with self.assertRaisesRegex(ValueError, "no rows published"):
                    self.build(candidates=[candidate("CHAIR", "MAN", "AGE")], reviewer=reviewer)

    def test_competing_answer_rejects_even_an_accept_verdict(self):
        def reviewer(batch, prompt, model):
            response = safe_review(batch, prompt, model)
            if prompt == automation.ADVERSARIAL_REVIEW:
                response["reviews"][0]["competingAnswers"] = ["CARD"]
            return response
        with self.assertRaisesRegex(ValueError, "no rows published"):
            self.build(reviewer=reviewer)

    def test_reviewer_response_must_exactly_cover_candidates(self):
        batch = [candidate()]
        valid = safe_review(batch, "", "")["reviews"][0]
        cases = [None, {}, {"reviews": []}, {"reviews": [valid, valid]},
                 {"reviews": [{**valid, "id": "invented"}]},
                 {"reviews": [{**valid, "accept": "true"}]},
                 {"reviews": [{**valid, "competingAnswers": None}]},
                 {"reviews": [{**valid, "difficulty": "unknown"}]},
                 {"reviews": [{key: value for key, value in valid.items() if key != "difficulty"}]},
                 {"reviews": [{**valid, "firstMeaning": ""}]}]
        for response in cases:
            with self.subTest(response=response), self.assertRaises(ValueError):
                automation.validate_review(response, batch)

    def test_duplicate_input_ids_cannot_share_one_review(self):
        batch = [candidate()]
        with self.assertRaisesRegex(ValueError, "Duplicate input"):
            automation.validate_review(safe_review(batch, "", ""), batch + batch)

    def test_later_moderate_candidate_is_preferred_over_easy_first_batch(self):
        calls = 0
        def reviewer(batch, prompt, model):
            nonlocal calls
            calls += 1
            response = safe_review(batch, prompt, model)
            if calls <= 2:
                response["reviews"][0]["difficulty"] = "easy"
            return response
        report = {}
        artifact = self.build(candidates=[candidate(), candidate("FIRE", "WORK", "SHOP")],
                              reviewer=reviewer, batch_size=1, report=report)
        self.assertEqual(calls, 4)
        self.assertEqual(artifact["reviews"][0]["difficulty"], "moderate")
        self.assertEqual(report["moderate"], 1)
        self.assertEqual(report["easyFallback"], 0)

    def test_moderate_editorial_reserve_beats_easy_automated_candidate(self):
        def reviewer(batch, prompt, model):
            response = safe_review(batch, prompt, model)
            response["reviews"][0]["difficulty"] = "easy"
            return response
        reserve = [("HAND", "BOOK", "STORE")]
        with patch.object(automation, "load_inventory", return_value=(reserve, set(reserve))):
            artifact = self.build(reviewer=reviewer)
        self.assertEqual(artifact["rows"][0]["answer"], "BOOK")
        self.assertEqual(artifact["reviews"][0]["source"], "editorial")

    def test_difficulty_disagreement_is_only_an_easy_fallback(self):
        def reviewer(batch, prompt, model):
            response = safe_review(batch, prompt, model)
            if prompt == automation.ADVERSARIAL_REVIEW:
                response["reviews"][0]["difficulty"] = "easy"
            return response
        report = {}
        artifact = self.build(reviewer=reviewer, report=report)
        self.assertEqual(artifact["reviews"][0]["difficulty"], "easy")
        self.assertEqual(report["easyFallback"], 1)

    def test_either_review_marking_too_hard_rejects_candidate(self):
        for hard_prompt in (automation.LEXICAL_REVIEW, automation.ADVERSARIAL_REVIEW):
            with self.subTest(prompt=hard_prompt):
                def reviewer(batch, prompt, model):
                    response = safe_review(batch, prompt, model)
                    if prompt == hard_prompt:
                        response["reviews"][0]["difficulty"] = "too_hard"
                    return response
                with self.assertRaisesRegex(ValueError, "no rows published"):
                    self.build(reviewer=reviewer)

    def test_selection_is_stable_for_same_source_and_day(self):
        pool = [candidate(), candidate("FIRE", "WORK", "SHOP")]
        first = self.build(candidates=pool)
        second = self.build(candidates=list(reversed(pool)))
        self.assertEqual(first, second)

    def test_malformed_batch_is_logged_and_next_batch_can_succeed(self):
        calls = 0
        def reviewer(batch, prompt, model):
            nonlocal calls
            calls += 1
            return {} if calls == 1 else safe_review(batch, prompt, model)
        report = {}
        artifact = self.build(candidates=[candidate(), candidate("FIRE", "WORK", "SHOP")],
                              reviewer=reviewer, batch_size=1, report=report)
        self.assertEqual(len(artifact["rows"]), 1)
        self.assertIn("error", report["attempts"][0])
        self.assertEqual(report["attempts"][1]["accepted"], 1)

    def test_api_failure_stops_without_silently_using_reserve(self):
        with patch.object(automation, "load_inventory", return_value=([("BANK", "NOTE", "BOOK")], set())):
            with self.assertRaisesRegex(RuntimeError, "API unavailable"):
                self.build(reviewer=Mock(side_effect=RuntimeError("API unavailable")))

    def test_full_buffer_needs_no_discovery_or_model_calls(self):
        existing = [{"date": "2026-11-17", "puzzle_number": 1,
                     "first_word": "BANK", "answer": "NOTE", "second_word": "BOOK"}]
        reviewer = Mock(side_effect=AssertionError("Unexpected AI call"))
        with patch.object(automation, "candidate_pool", side_effect=AssertionError("Unexpected discovery")):
            artifact = automation.build_batch(existing, date(2026, 11, 17), 1, reviewer=reviewer)
        self.assertEqual(artifact["rows"], [])
        reviewer.assert_not_called()

    def test_reserve_is_used_when_new_candidates_do_not_fill_window(self):
        with patch.object(automation, "load_inventory", return_value=([("FIRE", "WORK", "SHOP")], set())):
            artifact = self.build(days=2)
        self.assertEqual([row["answer"] for row in artifact["rows"]], ["NOTE", "WORK"])
        self.assertEqual([review["source"] for review in artifact["reviews"]], ["automated", "editorial"])

    def test_used_pair_is_not_republished_with_a_different_answer(self):
        existing = [{"date": "2026-01-01", "puzzle_number": 1,
                     "first_word": "BANK", "answer": "CARD", "second_word": "BOOK"}]
        with self.assertRaisesRegex(ValueError, "no rows published"):
            self.build(existing=existing)

    def test_nearby_history_including_future_rows_prevents_answer_repeat(self):
        for release in ("2026-11-10", "2026-11-18"):
            with self.subTest(release=release):
                existing = [{"date": release, "puzzle_number": 4,
                             "first_word": "WALL", "answer": "NOTE", "second_word": "PAD"}]
                artifact = self.build(existing=existing, candidates=[candidate(), candidate("FIRE", "WORK", "SHOP")])
                self.assertEqual(artifact["rows"][0]["answer"], "WORK")
                self.assertEqual(artifact["rows"][0]["puzzle_number"], 5)

    def test_missing_dates_preserve_published_content(self):
        existing = [{"date": "2026-11-17", "puzzle_number": 42,
                     "first_word": "BANK", "answer": "NOTE", "second_word": "BOOK"}]
        artifact = self.build(existing=existing, days=2, candidates=[candidate("FIRE", "WORK", "SHOP")])
        self.assertEqual([row["date"] for row in artifact["rows"]], ["2026-11-18"])
        self.assertEqual(artifact["rows"][0]["puzzle_number"], 43)
        self.assertEqual(existing[0]["answer"], "NOTE")

    def test_partial_coverage_never_returns_a_publishable_batch(self):
        report = {}
        with self.assertRaisesRegex(ValueError, "1 of 2"), patch.object(automation, "model_review"):
            self.build(days=2, report=report)
        self.assertEqual(report["attempts"][0]["accepted"], 1)

    def test_generation_effort_is_bounded(self):
        report = {}
        with self.assertRaisesRegex(ValueError, "no rows published"):
            self.build(days=2, candidates=[candidate(), candidate("FIRE", "WORK", "SHOP")],
                       batch_size=1, max_attempts=1, report=report)
        self.assertEqual(len(report["attempts"]), 1)

    def test_discovery_excludes_used_editorial_and_competing_prompt_pairs(self):
        words = ["BANK", "NOTE", "BOOK", "BANKNOTE", "NOTEBOOK",
                 "FIRE", "WORK", "SHOP", "FIREWORK", "WORKSHOP",
                 "RAIN", "BOW", "TIE", "RAINBOW", "BOWTIE"]
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "word_bank.json").write_text(json.dumps([{"word": word} for word in words]))
            with (patch.object(automation, "ROOT", root),
                  patch("wordfreq.top_n_list", return_value=[]),
                  patch("build_midword_bank.zipf_frequency", return_value=4)):
                pool = automation.candidate_pool([{"first_word": "BANK", "second_word": "BOOK"}],
                                                 [("RAIN", "BOW", "TIE")])
        self.assertEqual([row["id"] for row in pool], ["FIRE WORK SHOP"])

    def run_cli(self, folder, client, **build_kwargs):
        args = ["automate_midword.py", "--publish", "--output", str(folder / "puzzles.json"),
                "--report", str(folder / "report.json")]
        with (patch("sys.argv", args),
              patch.dict("os.environ", {"SUPABASE_URL": "https://example.test", "SUPABASE_KEY": "test"}),
              patch("supabase.create_client", return_value=client),
              patch.object(automation, "fetch_existing", return_value=[]),
              patch.object(automation, "build_batch", **build_kwargs)):
            return automation.main()

    def test_cli_publishes_complete_batch_once_and_saves_evidence(self):
        artifact = self.build()
        client = Mock()
        def build(*args, **kwargs):
            kwargs["report"].update(status="ready", targetDate="2026-12-07")
            return artifact
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            self.assertEqual(self.run_cli(folder, client, side_effect=build), 0)
            self.assertEqual(json.loads((folder / "puzzles.json").read_text()), artifact)
            self.assertEqual(json.loads((folder / "report.json").read_text())["status"], "published")
        client.rpc.assert_called_once_with("publish_midword_batch", {"p_rows": artifact["rows"]})
        client.rpc.return_value.execute.assert_called_once()

    def test_cli_failure_writes_report_without_uploading(self):
        client = Mock()
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            self.assertEqual(self.run_cli(folder, client, side_effect=ValueError("not enough safe puzzles")), 1)
            report = json.loads((folder / "report.json").read_text())
            self.assertEqual(report["status"], "failed")
            self.assertEqual(report["error"], "not enough safe puzzles")
            self.assertFalse((folder / "puzzles.json").exists())
        client.rpc.assert_not_called()


if __name__ == "__main__":
    unittest.main()
