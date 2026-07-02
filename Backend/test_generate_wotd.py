import sys
import unittest
from pathlib import Path
from unittest.mock import patch

BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

import generate_wotd


def wotd_entry(word: str) -> dict:
    return {
        "word": word,
        "pronunciation": word.upper(),
        "partOfSpeech": "adjective",
        "definition": "A clear test definition.",
        "etymology": "A short test origin.",
        "synonyms": ["plain", "clear"],
        "exampleSentence": "The sentence felt natural.",
    }


class GenerateWOTDTests(unittest.TestCase):
    def test_words_from_response_accepts_structured_object(self) -> None:
        content = '{"words": [{"word": "Luminous"}]}'

        words = generate_wotd.words_from_response(content)

        self.assertEqual(words, [{"word": "Luminous"}])

    def test_get_words_retries_parse_failures_and_skips_duplicates(self) -> None:
        responses = [
            [],
            [wotd_entry("Sanguine"), wotd_entry("Novel")],
            [wotd_entry("Novel"), wotd_entry("Luminous")],
            [wotd_entry("Luminous"), wotd_entry("Brisk")],
        ]
        themes = []

        def generate(_count, exclude, max_retries, theme):
            self.assertEqual(max_retries, 2)
            self.assertIn("sanguine", {word.lower() for word in exclude})
            themes.append(theme)
            return responses.pop(0)

        with patch.object(generate_wotd, "get_used_words", return_value={"Sanguine"}), \
             patch.object(generate_wotd, "generate_words_with_llm", side_effect=generate):
            words = generate_wotd.get_words(
                count=2,
                batch_size=2,
                exclude_used=True,
                max_attempts=4,
                llm_retries=2,
            )

        self.assertEqual(["Novel", "Brisk"], [word["word"] for word in words])
        self.assertEqual(themes[:2], generate_wotd.WOTD_THEMES[:2])

    def test_get_words_fails_after_max_attempts(self) -> None:
        with patch.object(generate_wotd, "get_used_words", return_value=set()), \
             patch.object(generate_wotd, "generate_words_with_llm", return_value=[]):
            with self.assertRaises(SystemExit):
                generate_wotd.get_words(
                    count=2,
                    batch_size=2,
                    exclude_used=True,
                    max_attempts=2,
                    llm_retries=1,
                )


if __name__ == "__main__":
    unittest.main()
