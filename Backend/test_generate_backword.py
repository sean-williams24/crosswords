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

import generate_backword


def word_item(word: str) -> dict:
    return {"word": word, "reject": False, "clue": "CLUE"}


def validation_response(reviews: list[dict]) -> SimpleNamespace:
    return SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps({"reviews": reviews})))]
    )


def review(word: str, clue: str, accept: bool, reason: str) -> dict:
    return {"word": word, "clue": clue, "accept": accept, "reason": reason}


class GenerateBackwordTests(unittest.TestCase):
    def test_rejects_known_wrong_word_form_but_allows_intended_form(self) -> None:
        self.assertEqual(
            "WRONG_WORD_FORM",
            generate_backword.local_rejection_reason({"word": "CHEESY", "clue": "CORN"}),
        )
        self.assertIsNone(
            generate_backword.local_rejection_reason({"word": "CHEESY", "clue": "CORNY"})
        )

    def test_validate_clues_requires_both_reviewers_to_accept(self) -> None:
        client = MagicMock()
        client.chat.completions.create.side_effect = [
            validation_response([review("CHEESY", "CORNY", True, "OK")]),
            validation_response([review("CHEESY", "CORNY", False, "WEAK_ASSOCIATION")]),
        ]

        with patch.object(generate_backword, "OpenAI", return_value=client):
            accepted = generate_backword.validate_clues(
                [{"word": "CHEESY", "clue": "CORNY"}], "validator-model", "test-key"
            )

        self.assertEqual([], accepted)
        self.assertEqual(2, client.chat.completions.create.call_count)

    def test_validate_clues_accepts_intended_form_after_two_approvals(self) -> None:
        client = MagicMock()
        client.chat.completions.create.side_effect = [
            validation_response([review("CHEESY", "CORNY", True, "OK")]),
            validation_response([review("CHEESY", "CORNY", True, "OK")]),
        ]
        item = {"word": "CHEESY", "clue": "CORNY"}

        with patch.object(generate_backword, "OpenAI", return_value=client):
            accepted = generate_backword.validate_clues([item], "validator-model", "test-key")

        self.assertEqual([item], accepted)

    def test_validate_clues_fails_closed_on_reviewer_error(self) -> None:
        client = MagicMock()
        client.chat.completions.create.side_effect = RuntimeError("service unavailable")

        with patch.object(generate_backword, "OpenAI", return_value=client):
            accepted = generate_backword.validate_clues(
                [{"word": "CASTLE", "clue": "CHESS"}], "validator-model", "test-key"
            )

        self.assertEqual([], accepted)
        self.assertEqual(1, client.chat.completions.create.call_count)

    def test_validate_clues_fails_closed_on_mismatched_or_incomplete_review(self) -> None:
        client = MagicMock()
        client.chat.completions.create.return_value = validation_response([
            review("WRONGGG", "CHESS", True, "OK")
        ])

        with patch.object(generate_backword, "OpenAI", return_value=client):
            accepted = generate_backword.validate_clues(
                [{"word": "CASTLE", "clue": "CHESS"}], "validator-model", "test-key"
            )

        self.assertEqual([], accepted)
        self.assertEqual(1, client.chat.completions.create.call_count)

    def test_validate_clues_fails_closed_on_malformed_review_schema(self) -> None:
        client = MagicMock()
        client.chat.completions.create.return_value = SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps({"items": []})))]
        )

        with patch.object(generate_backword, "OpenAI", return_value=client):
            accepted = generate_backword.validate_clues(
                [{"word": "CASTLE", "clue": "CHESS"}], "validator-model", "test-key"
            )

        self.assertEqual([], accepted)

    def test_generate_suitable_words_retries_until_count_is_met(self) -> None:
        pool = ["ALPHAA", "BRAVOO", "CHARLY", "DELTAA", "ECHOOO", "FOXTRO"]
        validate_results = [
            [word_item("ALPHAA")],
            [word_item("DELTAA"), word_item("ECHOOO")],
        ]

        def enrich(words, _model, _api_key):
            return [word_item(word) for word in words]

        def validate(_words, _model, _api_key):
            return validate_results.pop(0)

        with patch.object(generate_backword, "enrich_words", side_effect=enrich), \
             patch.object(generate_backword, "validate_clues", side_effect=validate):
            words, attempted_count = generate_backword.generate_suitable_words(
                pool=pool,
                count=3,
                enrichment_model="enrich-model",
                validator_model="validator-model",
                api_key="test-key",
                max_attempts=3,
                candidate_batch_size=3,
            )

        self.assertEqual(["ALPHAA", "DELTAA", "ECHOOO"], [item["word"] for item in words])
        self.assertEqual(attempted_count, 6)

    def test_generate_suitable_words_stops_after_max_attempts(self) -> None:
        pool = ["ALPHAA", "BRAVOO", "CHARLY", "DELTAA", "ECHOOO", "FOXTRO"]

        with patch.object(generate_backword, "enrich_words", return_value=[]), \
             patch.object(generate_backword, "validate_clues") as validate:
            words, attempted_count = generate_backword.generate_suitable_words(
                pool=pool,
                count=3,
                enrichment_model="enrich-model",
                validator_model="validator-model",
                api_key="test-key",
                max_attempts=2,
                candidate_batch_size=2,
            )

        self.assertEqual(words, [])
        self.assertEqual(attempted_count, 4)
        validate.assert_not_called()

    def test_generate_suitable_words_retries_after_validation_rejects_a_batch(self) -> None:
        pool = ["ALPHAA", "BRAVOO", "CHARLY", "DELTAA"]
        validate_results = [[], [word_item("CHARLY"), word_item("DELTAA")]]

        with patch.object(
            generate_backword,
            "enrich_words",
            side_effect=lambda words, _model, _api_key: [word_item(word) for word in words],
        ), patch.object(generate_backword, "validate_clues", side_effect=validate_results):
            words, attempted_count = generate_backword.generate_suitable_words(
                pool=pool,
                count=2,
                enrichment_model="enrich-model",
                validator_model="validator-model",
                api_key="test-key",
                max_attempts=2,
                candidate_batch_size=2,
            )

        self.assertEqual(["CHARLY", "DELTAA"], [item["word"] for item in words])
        self.assertEqual(4, attempted_count)

    def test_main_does_not_upload_an_incomplete_safe_batch(self) -> None:
        args = SimpleNamespace(
            count=2,
            date="2026-07-30",
            dry_run=False,
            model="enrich-model",
            validator_model="validator-model",
            max_attempts=1,
            candidate_batch_size=None,
            overwrite=False,
        )

        with patch.dict(
            os.environ,
            {"OPENAI_API_KEY": "test-key", "SUPABASE_URL": "url", "SUPABASE_KEY": "key"},
            clear=False,
        ), patch.object(generate_backword, "parse_args", return_value=args), \
            patch.object(generate_backword, "build_word_pool", return_value=["ALPHAA", "BRAVOO"]), \
            patch.object(generate_backword, "create_client", None), \
            patch.object(generate_backword, "generate_suitable_words", return_value=([word_item("ALPHAA")], 2)), \
            patch.object(generate_backword, "upload_words") as upload:
            with self.assertRaises(SystemExit) as error:
                generate_backword.main()

        self.assertEqual(1, error.exception.code)
        upload.assert_not_called()


if __name__ == "__main__":
    unittest.main()
