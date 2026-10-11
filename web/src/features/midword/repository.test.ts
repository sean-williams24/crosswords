import type { SupabaseClient } from "@supabase/supabase-js";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { createMidwordRepository, mapMidwordRow } from "./repository";

const row = { id: "midword", date: "2026-10-11", puzzle_number: 11, first_word: "BANK", second_word: "BOOK", answer: "NOTE", alternatives: [] };
const environment = { VITE_SUPABASE_URL: "https://example.supabase.co", VITE_SUPABASE_ANON_KEY: "test" };
function fakeClient(data: unknown, error: unknown = null) {
  const result = { data, error };
  const query = { select: vi.fn().mockReturnThis(), eq: vi.fn().mockReturnThis(), lte: vi.fn().mockReturnThis(),
    gte: vi.fn().mockReturnThis(), order: vi.fn().mockResolvedValue(result), single: vi.fn().mockResolvedValue(result) };
  const client = { from: vi.fn(() => query) };
  return { query, client: client as unknown as SupabaseClient };
}

beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date(2026, 9, 11, 12)); });
afterEach(() => vi.useRealTimers());

describe("Midword released content", () => {
  it("maps the native database columns and validates content", () => {
    expect(mapMidwordRow(row)).toMatchObject({ puzzleNumber: 11, firstWord: "BANK", secondWord: "BOOK" });
    expect(() => mapMidwordRow({ ...row, alternatives: ["TOOLONG"] })).toThrow();
    expect(() => createMidwordRepository({})).toThrow(/configuration/);
  });
  it("requests the exact browser-local date and refuses future dates", async () => {
    const { client, query } = fakeClient(row);
    const repo = createMidwordRepository(environment, client);
    expect(await repo.getByDate(row.date)).toMatchObject({ answer: "NOTE" });
    expect(client.from).toHaveBeenCalledWith("midword_puzzles");
    expect(query.eq).toHaveBeenCalledWith("date", row.date);
    await expect(repo.getByDate("2026-10-12")).rejects.toThrow(/released/);
    expect(client.from).toHaveBeenCalledTimes(1);
  });
  it("fails safely for missing or mismatched releases", async () => {
    await expect(createMidwordRepository(environment, fakeClient(null).client).getByDate(row.date)).rejects.toThrow();
    await expect(createMidwordRepository(environment, fakeClient({ ...row, date: "2026-10-10" }).client).getByDate(row.date)).rejects.toThrow(/match/);
  });
  it("filters archive queries to released dates and calendar month bounds", async () => {
    const { client, query } = fakeClient([row]);
    const repo = createMidwordRepository(environment, client);
    expect(await repo.getArchiveMonths()).toEqual(["2026-10"]);
    expect(await repo.getArchiveMonth("2026-10")).toHaveLength(1);
    expect(query.gte).toHaveBeenCalledWith("date", "2026-10-01");
    expect(query.lte).toHaveBeenCalledWith("date", "2026-10-31");
    expect(query.lte).toHaveBeenCalledWith("date", row.date);
    await expect(repo.getArchiveMonth("2026-13")).rejects.toThrow();
  });
});
