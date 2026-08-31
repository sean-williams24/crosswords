import { CrosswordConfigurationError, CrosswordUnavailableError, mapCrosswordRow, createCrosswordRepository } from "./repository";

const row = {
  id: "puzzle-id",
  puzzle_number: 9,
  date: "2026-08-05",
  grid_data: {
    size: 9,
    cells: Array.from({ length: 9 }, (_, rowIndex) => Array.from({ length: 9 }, (_, colIndex) => ({
      letter: rowIndex === 0 && colIndex < 2 ? ["A", "B"][colIndex] : null,
      clueNumber: rowIndex === 0 && colIndex === 0 ? 1 : null,
      acrossClueId: rowIndex === 0 && colIndex < 2 ? 0 : null,
      downClueId: null
    })))
  },
  clues: [{ id: 0, direction: "across", number: 1, text: "Test answer", hint: "Test hint", answer: "AB", startRow: 0, startCol: 0, length: 2 }]
};

describe("crossword repository", () => {
  it("maps the released daily puzzle payload", () => {
    expect(mapCrosswordRow(row)).toMatchObject({ id: "puzzle-id", puzzleNumber: 9, date: "2026-08-05", size: 9 });
  });

  it("rejects invalid grids and reports missing configuration", () => {
    expect(() => mapCrosswordRow({ ...row, grid_data: { ...row.grid_data, size: 8 } })).toThrow(CrosswordUnavailableError);
    expect(() => createCrosswordRepository({})).toThrow(CrosswordConfigurationError);
  });

  it("maps a 13×13 weekly payload and rejects it as a daily puzzle", () => {
    const weekly = {
      ...row,
      id: "weekly-id",
      grid_data: {
        size: 13,
        cells: Array.from({ length: 13 }, (_, rowIndex) => Array.from({ length: 13 }, (_, colIndex) => ({
          letter: rowIndex === 0 && colIndex < 2 ? ["A", "B"][colIndex] : null,
          clueNumber: rowIndex === 0 && colIndex === 0 ? 1 : null,
          acrossClueId: rowIndex === 0 && colIndex < 2 ? 0 : null,
          downClueId: null
        })))
      }
    };

    expect(mapCrosswordRow(weekly, 13)).toMatchObject({ id: "weekly-id", size: 13 });
    expect(() => mapCrosswordRow(weekly)).toThrow(CrosswordUnavailableError);
  });
});
