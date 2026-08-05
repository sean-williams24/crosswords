import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { CrosswordCell, CrosswordClue, CrosswordPuzzle } from "./types";

type CrosswordRow = {
  id?: unknown;
  puzzle_number?: unknown;
  date?: unknown;
  grid_data?: {
    size?: unknown;
    cells?: unknown;
  } | null;
  clues?: unknown;
};

export class CrosswordConfigurationError extends Error {}
export class CrosswordUnavailableError extends Error {}

function optionalInteger(value: unknown): number | null {
  return typeof value === "number" && Number.isInteger(value) ? value : null;
}

function parseCell(value: unknown): CrosswordCell | null {
  if (!value || typeof value !== "object") {
    return null;
  }
  const cell = value as Record<string, unknown>;
  const letter = cell.letter;
  const clueNumber = cell.clueNumber;
  const acrossClueId = cell.acrossClueId;
  const downClueId = cell.downClueId;
  if (
    (letter !== null && (typeof letter !== "string" || !/^[A-Za-z]$/.test(letter))) ||
    (clueNumber !== null && optionalInteger(clueNumber) === null) ||
    (acrossClueId !== null && optionalInteger(acrossClueId) === null) ||
    (downClueId !== null && optionalInteger(downClueId) === null)
  ) {
    return null;
  }
  return {
    letter: typeof letter === "string" ? letter.toUpperCase() : null,
    clueNumber: optionalInteger(clueNumber),
    acrossClueId: optionalInteger(acrossClueId),
    downClueId: optionalInteger(downClueId)
  };
}

function parseClue(value: unknown, size: number): CrosswordClue | null {
  if (!value || typeof value !== "object") {
    return null;
  }
  const clue = value as Record<string, unknown>;
  const id = optionalInteger(clue.id);
  const number = optionalInteger(clue.number);
  const startRow = optionalInteger(clue.startRow);
  const startCol = optionalInteger(clue.startCol);
  const length = optionalInteger(clue.length);
  const direction = clue.direction;
  const text = clue.text;
  const answer = clue.answer;
  if (
    id === null || number === null || startRow === null || startCol === null || length === null ||
    (direction !== "across" && direction !== "down") ||
    typeof text !== "string" || !text.trim() ||
    typeof answer !== "string" || !new RegExp(`^[A-Za-z]{${length}}$`).test(answer) ||
    startRow < 0 || startCol < 0 || length < 2 ||
    (direction === "across" && startCol + length > size) ||
    (direction === "down" && startRow + length > size)
  ) {
    return null;
  }
  return { id, number, startRow, startCol, length, direction, text: text.trim(), answer: answer.toUpperCase() };
}

export function mapCrosswordRow(row: CrosswordRow): CrosswordPuzzle {
  const size = optionalInteger(row.grid_data?.size);
  const puzzleNumber = optionalInteger(row.puzzle_number);
  if (
    typeof row.id !== "string" || !row.id ||
    typeof row.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(row.date) ||
    size !== 9 || puzzleNumber === null || !Array.isArray(row.grid_data?.cells) ||
    row.grid_data.cells.length !== size || !Array.isArray(row.clues)
  ) {
    throw new CrosswordUnavailableError("Today's crossword data is invalid.");
  }

  const cells = row.grid_data.cells.map((cellRow) => {
    if (!Array.isArray(cellRow) || cellRow.length !== size) {
      throw new CrosswordUnavailableError("Today's crossword grid is invalid.");
    }
    const parsed = cellRow.map(parseCell);
    if (parsed.some((cell) => cell === null)) {
      throw new CrosswordUnavailableError("Today's crossword grid is invalid.");
    }
    return parsed as CrosswordCell[];
  });
  const clues = row.clues.map((clue) => parseClue(clue, size));
  if (!clues.length || clues.some((clue) => clue === null)) {
    throw new CrosswordUnavailableError("Today's crossword clues are invalid.");
  }

  return { id: row.id, puzzleNumber, date: row.date, size, cells, clues: clues as CrosswordClue[] };
}

export type CrosswordRepository = {
  getByDate(date: string): Promise<CrosswordPuzzle>;
};

export function createCrosswordRepository(
  environment: Record<string, string | boolean | undefined> = import.meta.env,
  injectedClient?: SupabaseClient
): CrosswordRepository {
  const url = environment.VITE_SUPABASE_URL;
  const key = environment.VITE_SUPABASE_ANON_KEY;
  if (typeof url !== "string" || typeof key !== "string" || !url || !key) {
    throw new CrosswordConfigurationError(
      "Quick Crossword needs its Supabase environment variables before it can load."
    );
  }
  const client = injectedClient ?? createClient(url, key);
  return {
    async getByDate(date: string) {
      const { data, error } = await client
        .from("puzzles")
        .select("id,puzzle_number,date,grid_data,clues")
        .eq("date", date)
        .single();
      if (error || !data) {
        throw new CrosswordUnavailableError("Today's crossword is not available yet.");
      }
      return mapCrosswordRow(data as CrosswordRow);
    }
  };
}
