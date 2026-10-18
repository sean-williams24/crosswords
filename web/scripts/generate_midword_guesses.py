"""Rebuild the offline 3–6-letter dictionary using Backend/.venv (wordfreq 3.1.1)."""
import json
import re
from pathlib import Path
from wordfreq import top_n_list

root = Path(__file__).resolve().parents[2]
excluded = {entry['word'].upper() for filename in ('filter_names_removed.json', 'filter_names_borderline.json')
            for entry in json.loads((root / 'Backend' / filename).read_text())}
excluded.update('FUCK FUCKS FUCKED FUCKER SHIT SHITS SHITTY CUNT CUNTS COCK DICK DICKS PUSSY PORN PORNO NIGGER FAG FAGS SLUT SLUTS WHORE WHORES'.split())
words = sorted({word.upper() for word in top_n_list('en', 50000)
                if re.fullmatch(r'[a-z]{3,6}', word) and len(set(word)) > 1 and word.upper() not in excluded})
header = '''/**
 * SPDX-License-Identifier: CC-BY-SA-4.0
 * English Midword guesses derived from wordfreq 3.1.1 by Robyn Speer.
 * Source: https://github.com/rspeer/wordfreq (50,000 most frequent English entries).
 * Data: CC BY-SA 4.0, including Wikipedia, SUBTLEX, OpenSubtitles and Google Books.
 * Only ASCII words of 3–6 letters; repeated-letter strings, the project's reviewed
 * name exclusions and explicit profanity exclusions are removed. Approved answers
 * are accepted separately. Regenerate with web/scripts/generate_midword_guesses.py.
 */
'''
lines = [' '.join(words[index:index + 18]) for index in range(0, len(words), 18)]
(root / 'web/src/features/midword/validGuesses.ts').write_text(header + 'export const validMidwordGuesses = new Set(`\n' + '\n'.join(lines) + '\n`.trim().split(/\\s+/));\n')
print(f'Generated {len(words)} Midword guesses')
