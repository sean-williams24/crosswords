import { isValidEnglishWord } from "./wordValidator";

describe("Backword word validator", () => {
  it("accepts common bundled English words without a network request", () => {
    for (const word of ["BOTTLE", "CASTLE", "CHEESE", "FRIEND", "PEOPLE", "PICKLE"]) {
      expect(isValidEnglishWord(word)).toBe(true);
    }
    expect(isValidEnglishWord("castle")).toBe(true);
  });

  it("rejects obscure, unsuitable, and non-word guesses", () => {
    expect(isValidEnglishWord("ABABUA")).toBe(false);
    expect(isValidEnglishWord("FUCKER")).toBe(false);
    expect(isValidEnglishWord("XYZQBE")).toBe(false);
  });
});
