import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { localDateString } from "./date";
import type { BackwordWord } from "./types";

type BackwordRow = {
  id?: unknown;
  date?: unknown;
  word_data?: {
    word?: unknown;
    clue?: unknown;
    category?: unknown;
  } | null;
};

export class BackwordConfigurationError extends Error {}
export class BackwordUnavailableError extends Error {}

export function mapBackwordRow(row: BackwordRow): BackwordWord {
  const word =
    typeof row.word_data?.word === "string" ? row.word_data.word.toUpperCase() : "";
  const clueValue = row.word_data?.clue ?? row.word_data?.category;
  const clue = typeof clueValue === "string" ? clueValue.trim() : "";

  if (
    typeof row.id !== "string" ||
    typeof row.date !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(row.date) ||
    !/^[A-Z]{6}$/.test(word) ||
    !clue
  ) {
    throw new BackwordUnavailableError("Today's Backword data is invalid.");
  }

  return { id: row.id, date: row.date, word, clue };
}

export type BackwordRepository = {
  getByDate(date: string): Promise<BackwordWord>;
  getArchiveMonths(): Promise<string[]>;
  getArchiveMonth(month: string): Promise<BackwordWord[]>;
};

export function createBackwordRepository(
  environment: Record<string, string | boolean | undefined> = import.meta.env,
  injectedClient?: SupabaseClient
): BackwordRepository {
  const url = environment.VITE_SUPABASE_URL;
  const key = environment.VITE_SUPABASE_ANON_KEY;
  if (typeof url !== "string" || typeof key !== "string" || !url || !key) {
    throw new BackwordConfigurationError(
      "Backword needs its Supabase environment variables before it can load."
    );
  }

  const client = injectedClient ?? createClient(url, key);
  return {
    async getByDate(date: string) {
      const { data, error } = await client
        .from("backword_words")
        .select("id,date,word_data")
        .eq("date", date)
        .single();

      if (error || !data) {
        throw new BackwordUnavailableError("Today's Backword is not available yet.");
      }
      return mapBackwordRow(data as BackwordRow);
    },
    async getArchiveMonths() {
      const { data, error } = await client
        .from("backword_words")
        .select("date")
        .lte("date", localDateString())
        .order("date", { ascending: false });
      if (error || !data) {
        throw new BackwordUnavailableError("Backword archive is not available right now.");
      }
      return [...new Set(data
        .map((row) => typeof row.date === "string" ? row.date.slice(0, 7) : "")
        .filter((month) => /^\d{4}-\d{2}$/.test(month)))];
    },
    async getArchiveMonth(month: string) {
      const [year, monthNumber] = month.split("-").map(Number);
      const end = `${month}-${String(new Date(year, monthNumber, 0).getDate()).padStart(2, "0")}`;
      const { data, error } = await client
        .from("backword_words")
        .select("id,date,word_data")
        .gte("date", `${month}-01`)
        .lte("date", end)
        .lte("date", localDateString())
        .order("date", { ascending: false });
      if (error || !data) {
        throw new BackwordUnavailableError("This Backword month is not available right now.");
      }
      return data.map((row) => mapBackwordRow(row as BackwordRow));
    }
  };
}
