import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch

BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

if "openai" not in sys.modules:
    openai_stub = types.ModuleType("openai")
    openai_stub.OpenAI = object
    sys.modules["openai"] = openai_stub

import generate_backword


def word_item(word: str) -> dict:
    return {"word": word, "reject": False, "clue": "CLUE"}


class GenerateBackwordTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
