import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { WordOfTheDay } from "./types";

type WordOfTheDayRow = {
  id?: unknown;
  date?: unknown;
  word_data?: {
    word?: unknown;
    pronunciation?: unknown;
    partOfSpeech?: unknown;
    definition?: unknown;
    etymology?: unknown;
    synonyms?: unknown;
    exampleSentence?: unknown;
  } | null;
};

export class WordOfTheDayConfigurationError extends Error {}
export class WordOfTheDayUnavailableError extends Error {}

function requiredString(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

export function mapWordOfTheDayRow(row: WordOfTheDayRow): WordOfTheDay {
  const word = requiredString(row.word_data?.word);
  const pronunciation = requiredString(row.word_data?.pronunciation);
  const partOfSpeech = requiredString(row.word_data?.partOfSpeech);
  const definition = requiredString(row.word_data?.definition);
  const etymology = requiredString(row.word_data?.etymology);
  const exampleSentence = requiredString(row.word_data?.exampleSentence);
  const synonyms = Array.isArray(row.word_data?.synonyms)
    ? row.word_data.synonyms.map(requiredString).filter((synonym): synonym is string => synonym !== null)
    : [];

  if (
    typeof row.id !== "string" ||
    typeof row.date !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(row.date) ||
    !word ||
    !pronunciation ||
    !partOfSpeech ||
    !definition ||
    !etymology ||
    !exampleSentence ||
    synonyms.length === 0
  ) {
    throw new WordOfTheDayUnavailableError("Today's Word of the Day data is invalid.");
  }

  return {
    id: row.id,
    date: row.date,
    word,
    pronunciation,
    partOfSpeech,
    definition,
    etymology,
    synonyms,
    exampleSentence
  };
}

export type WordOfTheDayRepository = {
  getByDate(date: string): Promise<WordOfTheDay>;
};

export function createWordOfTheDayRepository(
  environment: Record<string, string | boolean | undefined> = import.meta.env,
  injectedClient?: SupabaseClient
): WordOfTheDayRepository {
  const url = environment.VITE_SUPABASE_URL;
  const key = environment.VITE_SUPABASE_ANON_KEY;
  if (typeof url !== "string" || typeof key !== "string" || !url || !key) {
    throw new WordOfTheDayConfigurationError(
      "Word of the Day needs its Supabase environment variables before it can load."
    );
  }

  const client = injectedClient ?? createClient(url, key);
  return {
    async getByDate(date: string) {
      const { data, error } = await client
        .from("words_of_the_day")
        .select("id,date,word_data")
        .eq("date", date)
        .single();

      if (error || !data) {
        throw new WordOfTheDayUnavailableError("Today's Word of the Day is not available yet.");
      }
      return mapWordOfTheDayRow(data as WordOfTheDayRow);
    }
  };
}
