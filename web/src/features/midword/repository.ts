import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { isLocalDateString, localDateString } from "../backword/date";
import { validPuzzle, type MidwordPuzzle } from "./engine";

type MidwordRow = { id?: unknown; date?: unknown; puzzle_number?: unknown; first_word?: unknown;
  second_word?: unknown; answer?: unknown; alternatives?: unknown };

export function mapMidwordRow(row: MidwordRow): MidwordPuzzle {
  const puzzle = { id: row.id, date: row.date, puzzleNumber: row.puzzle_number,
    firstWord: row.first_word, secondWord: row.second_word, answer: row.answer, alternatives: row.alternatives };
  if (!validPuzzle(puzzle)) throw new Error("Midword puzzle data is invalid.");
  return puzzle;
}

export function createMidwordRepository(environment: Record<string, string | boolean | undefined> = import.meta.env,
  injectedClient?: SupabaseClient) {
  const url = environment.VITE_SUPABASE_URL, key = environment.VITE_SUPABASE_ANON_KEY;
  if (typeof url !== "string" || typeof key !== "string" || !url || !key) throw new Error("Midword needs its Supabase configuration before it can load.");
  const client = injectedClient ?? createClient(url, key);
  const fields = "id,date,puzzle_number,first_word,second_word,answer,alternatives";
  return {
    async getByDate(date: string): Promise<MidwordPuzzle> {
      if (!isLocalDateString(date) || date > localDateString()) throw new Error("This Midword has not been released.");
      const { data, error } = await client.from("midword_puzzles").select(fields).eq("date", date).single();
      if (error || !data) throw new Error("Midword is unavailable right now.");
      const puzzle = mapMidwordRow(data);
      if (puzzle.date !== date) throw new Error("Midword release date does not match.");
      return puzzle;
    },
    async getArchiveMonths(): Promise<string[]> {
      const { data, error } = await client.from("midword_puzzles").select("date").lte("date", localDateString()).order("date", { ascending: false });
      if (error || !data) throw new Error("Midword archive is unavailable right now.");
      return [...new Set(data.flatMap((row) => isLocalDateString(row.date) ? [row.date.slice(0, 7)] : []))];
    },
    async getArchiveMonth(month: string): Promise<MidwordPuzzle[]> {
      if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) throw new Error("Invalid Midword month.");
      const [year, number] = month.split("-").map(Number);
      const end = `${month}-${String(new Date(year, number, 0).getDate()).padStart(2, "0")}`;
      const { data, error } = await client.from("midword_puzzles").select(fields).gte("date", `${month}-01`).lte("date", end)
        .lte("date", localDateString()).order("date", { ascending: false });
      if (error || !data) throw new Error("This Midword month is unavailable right now.");
      return data.map(mapMidwordRow);
    }
  };
}
