import { validEnglishWords } from "./validGuesses";

/**
 * Checks a completed Backword guess against the bundled English word list.
 * Target answers are accepted separately by the game engine, so a target is
 * never rejected because it is absent from this list.
 */
export function isValidEnglishWord(word: string): boolean {
  return validEnglishWords.has(word.trim().toUpperCase());
}
