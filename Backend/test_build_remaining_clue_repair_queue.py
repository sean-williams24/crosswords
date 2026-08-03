#!/usr/bin/env python3

import unittest

from build_remaining_clue_repair_queue import build_queue


class RemainingClueRepairQueueTests(unittest.TestCase):
    def test_keeps_only_unchanged_current_findings(self) -> None:
        entries = [{"word": "WIDGET", "text": "Old clue", "clues": ["Still wrong"]}]
        audit = {"records": [{
            "word": "WIDGET",
            "fields": [
                {"field": "text", "current": "Old clue", "status": "terra_mismatch", "terra": {"reason": "Wrong sense"}},
                {"field": "clues[0]", "current": "Replaced", "status": "terra_mismatch", "terra": {"reason": "Already fixed"}},
                {"field": "hint", "current": "Unused", "status": "match"},
            ],
        }]}
        queue = build_queue(entries, audit)
        self.assertEqual(queue["records"], [{
            "index": 0,
            "word": "WIDGET",
            "fields": [{
                "field": "text",
                "current": "Old clue",
                "auditStatus": "terra_mismatch",
                "reason": "Wrong sense",
            }],
        }])

    def test_skips_duplicate_answers_for_manual_disambiguation(self) -> None:
        entries = [{"word": "PIANIST", "text": "One"}, {"word": "PIANIST", "text": "Two"}]
        audit = {"records": [{"word": "PIANIST", "fields": []}]}
        queue = build_queue(entries, audit)
        self.assertEqual(queue["records"], [])
        self.assertEqual(queue["skippedDuplicateWords"], ["PIANIST"])
