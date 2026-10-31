import { beforeEach, describe, expect, it, vi } from "vitest";
const api = vi.hoisted(() => ({ getSession: vi.fn(), from: vi.fn(), rpc: vi.fn() }));
vi.mock("../../lib/supabase", () => ({ supabase: { auth: { getSession: api.getSession }, from: api.from, rpc: api.rpc } }));
import { fetchCloudProgress, migrateProgress, queueAndSync } from "./progressSync";

beforeEach(() => {
  vi.clearAllMocks(); localStorage.clear();
  api.getSession.mockResolvedValue({ data: { session: { user: { id: "alice" }, access_token: "alice-token" } }, error: null });
});
describe("migration transport account binding", () => {
  it("reads every page of long histories with an explicit account and pinned token", async () => {
    const query = { eq: vi.fn(), setHeader: vi.fn(), order: vi.fn(), range: vi.fn() };
    query.eq.mockReturnValue(query); query.setHeader.mockReturnValue(query); query.order.mockReturnValue(query);
    query.range.mockResolvedValueOnce({ data: Array(500).fill({ game_type: "backword" }), error: null, count: 501 }).mockResolvedValueOnce({ data: [{ game_type: "backword" }], error: null, count: 501 });
    api.from.mockReturnValue({ select: vi.fn().mockReturnValue(query) });
    expect(await fetchCloudProgress("backword", "alice")).toHaveLength(501);
    expect(query.eq).toHaveBeenCalledWith("user_id", "alice");
    expect(query.setHeader).toHaveBeenCalledWith("Authorization", "Bearer alice-token");
    expect(query.range.mock.calls).toEqual([[0, 499], [500, 999]]);
  });
  it("does not upload a queued record while a different account is signed in", async () => {
    api.getSession.mockResolvedValue({ data: { session: { user: { id: "bob" }, access_token: "bob-token" } }, error: null });
    expect(await queueAndSync("alice", { game_type: "backword", content_key: "2026-10-29", release_date: "2026-10-29", schema_version: 1, status: "in_progress", progress_rank: 1, release_score: 0, client_updated_at: "2026-10-29T00:00:00Z", payload: {} })).toBe(false);
    expect(api.rpc).not.toHaveBeenCalled();
  });
  it("does not skip rows when the backend row cap is smaller than the requested page", async () => {
    const query = { eq: vi.fn(), setHeader: vi.fn(), order: vi.fn(), range: vi.fn() };
    query.eq.mockReturnValue(query); query.setHeader.mockReturnValue(query); query.order.mockReturnValue(query);
    query.range.mockResolvedValueOnce({ data: [{ content_key: "one" }], error: null, count: 3 })
      .mockResolvedValueOnce({ data: [{ content_key: "two" }, { content_key: "three" }], error: null, count: 3 });
    api.from.mockReturnValue({ select: vi.fn().mockReturnValue(query) });
    expect(await fetchCloudProgress("backword", "alice")).toHaveLength(3);
    expect(query.range.mock.calls).toEqual([[0, 499], [1, 500]]);
  });

  it("never copies the new account's cloud records into a stale account cache", async () => {
    api.getSession.mockResolvedValue({ data: { session: { user: { id: "bob" }, access_token: "bob-token" } }, error: null });
    const apply = vi.fn(); const remove = vi.fn();
    await expect(migrateProgress("alice", "backword", [], [], apply, remove)).rejects.toThrow("same account");
    expect(apply).not.toHaveBeenCalled();
    expect(remove).not.toHaveBeenCalled();
    expect(api.from).not.toHaveBeenCalled();
  });

});
