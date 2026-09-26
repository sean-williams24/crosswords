import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { localDateString } from "../backword/date";
import { validPuzzle, type AnagramPuzzle } from "./engine";

type AnagramRow = { id?: unknown; date?: unknown; puzzle_number?: unknown; schema_version?: unknown; puzzle_data?: { answer?: unknown; acceptedAnswers?: unknown; initialScramble?: unknown } | null };

export function mapAnagramRow(row: AnagramRow): AnagramPuzzle {
  const puzzle = { id: row.id, date: row.date, puzzleNumber: row.puzzle_number,
    schemaVersion: row.schema_version, answer: row.puzzle_data?.answer,
    acceptedAnswers: row.puzzle_data?.acceptedAnswers, initialScramble: row.puzzle_data?.initialScramble } as AnagramPuzzle;
  if (typeof puzzle.id !== "string" || !Array.isArray(puzzle.acceptedAnswers) || !validPuzzle(puzzle)) {
    throw new Error("Anagram puzzle data is invalid.");
  }
  return puzzle;
}

export function createAnagramRepository(environment: Record<string, string | boolean | undefined> = import.meta.env, injectedClient?: SupabaseClient) {
  const url = environment.VITE_SUPABASE_URL;
  const key = environment.VITE_SUPABASE_ANON_KEY;
  if (typeof url !== "string" || typeof key !== "string" || !url || !key) throw new Error("Anagram needs its Supabase configuration before it can load.");
  const client = injectedClient ?? createClient(url, key);
  const fields = "id,date,puzzle_number,schema_version,puzzle_data";
  return {
    async getByDate(date: string): Promise<AnagramPuzzle> {
      const { data, error } = await client.from("anagram_puzzles").select(fields).eq("date", date).single();
      if (error || !data) throw new Error("Anagram is unavailable right now.");
      return mapAnagramRow(data as AnagramRow);
    },
    async getFirstReleaseDate(): Promise<string | null> {
      const { data, error } = await client.from("anagram_puzzles").select("date").order("date", { ascending: true }).limit(1);
      if (error) throw error;
      return typeof data?.[0]?.date === "string" ? data[0].date : null;
    },
    async getArchiveMonths(): Promise<string[]> {
      const { data, error } = await client.from("anagram_puzzles").select("date").lte("date", localDateString()).order("date", { ascending: false });
      if (error || !data) throw new Error("Anagram archive is unavailable right now.");
      return [...new Set(data.map((row) => typeof row.date === "string" ? row.date.slice(0, 7) : "").filter((month) => /^\d{4}-\d{2}$/.test(month)))];
    },
    async getArchiveMonth(month: string): Promise<AnagramPuzzle[]> {
      const [year, monthNumber] = month.split("-").map(Number);
      const end = `${month}-${String(new Date(year, monthNumber, 0).getDate()).padStart(2, "0")}`;
      const { data, error } = await client.from("anagram_puzzles").select(fields).gte("date", `${month}-01`).lte("date", end).lte("date", localDateString()).order("date", { ascending: false });
      if (error || !data) throw new Error("This Anagram month is unavailable right now.");
      return data.map((row) => mapAnagramRow(row as AnagramRow));
    }
  };
}
