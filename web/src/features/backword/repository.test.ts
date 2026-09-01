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

  it("queries only a selected released archive month", async () => {
    const query = {
      select: vi.fn(), gte: vi.fn(), lte: vi.fn(), order: vi.fn()
    };
    query.select.mockReturnValue(query);
    query.gte.mockReturnValue(query);
    query.lte.mockReturnValue(query);
    query.order.mockResolvedValue({ data: [{
      id: "id", date: "2026-08-03", word_data: { word: "castle", clue: "Fortress" }
    }], error: null });
    const from = vi.fn(() => query);
    const repository = createBackwordRepository(
      { VITE_SUPABASE_URL: "https://example.test", VITE_SUPABASE_ANON_KEY: "key" },
      { from } as never
    );

    await expect(repository.getArchiveMonth("2026-08")).resolves.toMatchObject([{ date: "2026-08-03" }]);
    expect(from).toHaveBeenCalledWith("backword_words");
    expect(query.gte).toHaveBeenCalledWith("date", "2026-08-01");
    expect(query.lte).toHaveBeenCalledWith("date", "2026-08-31");
  });
});
