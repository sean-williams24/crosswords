import {
  WordOfTheDayConfigurationError,
  WordOfTheDayUnavailableError,
  createWordOfTheDayRepository,
  mapWordOfTheDayRow
} from "./repository";

const validRow = {
  id: "word-id",
  date: "2026-08-05",
  word_data: {
    word: " Verbose ",
    pronunciation: " ver-BOHS ",
    partOfSpeech: " adjective ",
    definition: " Using more words than needed. ",
    etymology: " From Latin verbosus. ",
    synonyms: [" wordy ", "long-winded"],
    exampleSentence: " Her verbose note filled the page. "
  }
};

describe("Word of the Day repository", () => {
  it("maps and normalizes a released Word of the Day row", () => {
    expect(mapWordOfTheDayRow(validRow)).toEqual({
      id: "word-id",
      date: "2026-08-05",
      word: "Verbose",
      pronunciation: "ver-BOHS",
      partOfSpeech: "adjective",
      definition: "Using more words than needed.",
      etymology: "From Latin verbosus.",
      synonyms: ["wordy", "long-winded"],
      exampleSentence: "Her verbose note filled the page."
    });
  });

  it("rejects rows missing required detail data", () => {
    expect(() => mapWordOfTheDayRow({
      ...validRow,
      word_data: { ...validRow.word_data, synonyms: [] }
    })).toThrow(WordOfTheDayUnavailableError);
  });

  it("reports missing Supabase configuration", () => {
    expect(() => createWordOfTheDayRepository({})).toThrow(WordOfTheDayConfigurationError);
  });
});
