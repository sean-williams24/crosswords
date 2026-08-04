import {
  BackwordConfigurationError,
  BackwordUnavailableError,
  createBackwordRepository,
  mapBackwordRow
} from "./repository";

describe("Backword repository", () => {
  it("maps a current clue and uppercases the answer", () => {
    expect(mapBackwordRow({
      id: "id",
      date: "2026-08-03",
      word_data: { word: "castle", clue: " Fortress " }
    })).toEqual({ id: "id", date: "2026-08-03", word: "CASTLE", clue: "Fortress" });
  });

  it("falls back to the legacy category", () => {
    expect(mapBackwordRow({
      id: "id",
      date: "2026-08-03",
      word_data: { word: "castle", category: "Building" }
    }).clue).toBe("Building");
  });

  it("rejects malformed daily content", () => {
    expect(() => mapBackwordRow({
      id: "id",
      date: "2026-08-03",
      word_data: { word: "seven", clue: "Number" }
    })).toThrow(BackwordUnavailableError);
  });

  it("reports missing environment configuration", () => {
    expect(() => createBackwordRepository({})).toThrow(BackwordConfigurationError);
  });
});
