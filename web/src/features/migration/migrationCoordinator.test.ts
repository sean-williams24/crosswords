import { beforeEach, describe, expect, it, vi } from "vitest";
import fixtures from "../../../../docs/fixtures/anagram-v1.json";
import { emptyProgress as emptyBackword } from "../backword/engine";
import { emptyProgress as emptyMidword } from "../midword/engine";
import { emptyProgress as emptyCrossword } from "../crossword/engine";
import { startProgress } from "../anagram/engine";
import { mapAnagramRow } from "../anagram/repository";
import { chooseBestProgress, type CloudRecord } from "../sync/progressSync";
import { canMigrateGuestProgress } from "../sync/guestMigration";
import { migrationGames, migrationStore, inspectMigrationStorage } from "./migrationStorage";
import { runDomainMigration, type MigrationDependencies } from "./migrationCoordinator";

const date = "2026-10-29";
function seed() {
  const values = [emptyBackword(date), startProgress(mapAnagramRow(fixtures.puzzles[0])), emptyMidword(date),
    emptyCrossword({ id: "daily", date, size: 9 }), { ...emptyCrossword({ id: "weekly", date, size: 13 }), isWeekly: true }];
  migrationGames.forEach((game, index) => localStorage.setItem(game.key, JSON.stringify({ [index === 1 ? (values[index] as { date: string }).date : index < 3 ? date : index === 3 ? "daily" : "weekly"]: values[index] })));
}
function backend() {
  const remote = new Map<string, CloudRecord<unknown>>();
  const deps: MigrationDependencies = {
    storage: localStorage, assertAccount: vi.fn().mockResolvedValue(undefined), pending: () => [], flush: vi.fn().mockResolvedValue(true),
    upload: vi.fn(async (_user, record) => {
      const key = `${record.game_type}:${record.content_key}`;
      remote.set(key, remote.has(key) ? chooseBestProgress(remote.get(key)!, record) : record);
      return true;
    }),
    fetch: vi.fn(async (game) => [...remote.values()].filter((record) => record.game_type === game))
  };
  return { deps, remote };
}
beforeEach(() => localStorage.clear());

describe("verified domain migration", () => {
  it("moves all five guest games and is repeatable", async () => {
    seed(); const { deps } = backend();
    const snapshots = migrationGames.map((game) => migrationStore(localStorage, game.type).load());
    const result = await runDomainMigration("alice", vi.fn(), deps);
    expect(result.ready).toBe(true);
    expect(result.games.map((game) => game.status)).toEqual(Array(5).fill("verified"));
    migrationGames.forEach((game, index) => {
      expect(migrationStore(localStorage, game.type).load()).toEqual([]);
      expect(migrationStore(localStorage, game.type, "alice").load()).toEqual(snapshots[index]);
    });
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(true);
  });
  it("requires server readback, preserves failed saves, and recovers on retry", async () => {
    seed(); const { deps } = backend(); const fetch = deps.fetch;
    deps.fetch = vi.fn(async (game, user) => game === "midword" ? [] : fetch(game, user));
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(false);
    expect(migrationStore(localStorage, "midword").load()).toHaveLength(1);
    deps.fetch = fetch;
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(true);
  });
  it("never copies an interrupted guest batch into another account", async () => {
    seed(); canMigrateGuestProgress(localStorage, "alice"); const { deps } = backend();
    expect((await runDomainMigration("bob", vi.fn(), deps)).ready).toBe(false);
    expect(deps.upload).not.toHaveBeenCalled();
    expect(migrationStore(localStorage, "backword").load()).toHaveLength(1);
  });
  it("blocks navigation after an account switch and retains guest progress", async () => {
    seed(); const { deps } = backend();
    vi.mocked(deps.assertAccount).mockRejectedValue(new Error("account changed"));
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(false);
    expect(deps.upload).not.toHaveBeenCalled();
    expect(inspectMigrationStorage(localStorage).hasSaves).toBe(true);
  });
  it("includes queued saves missing from caches without using another account's cache", async () => {
    seed(); const { deps } = backend(); const pending = migrationStore(localStorage, "backword").load()[0];
    localStorage.removeItem(migrationGames[0].key);
    localStorage.setItem(`${migrationGames[0].key}:user:bob`, JSON.stringify({ [date]: emptyBackword(date) }));
    deps.pending = vi.fn().mockReturnValueOnce([pending]).mockReturnValue([]);
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(true);
    expect(deps.upload).toHaveBeenCalledWith("alice", pending);
    expect(migrationStore(localStorage, "backword", "bob").load()).toHaveLength(1);
  });
  it("does not treat unrecognised progress as an empty browser", async () => {
    localStorage.setItem(migrationGames[0].key, JSON.stringify({ lost: { schemaVersion: 99 } }));
    const { deps } = backend();
    expect(inspectMigrationStorage(localStorage).hasSaves).toBe(true);
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(false);
    expect(localStorage.getItem(migrationGames[0].key)).toContain("lost");
  });
  it("retains edits made by another tab while readback is pending", async () => {
    seed(); const { deps } = backend(); const fetch = deps.fetch;
    deps.fetch = async (game, user) => {
      if (game === "backword") localStorage.setItem(migrationGames[0].key, JSON.stringify({ [date]: { ...emptyBackword(date), guesses: ["PLANET"] } }));
      return fetch(game, user);
    };
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(false);
    expect(migrationStore(localStorage, "backword").load()[0].progress_rank).toBe(1);
  });
  it("checks earlier games again after later uploads complete", async () => {
    seed(); const { deps } = backend(); const fetch = deps.fetch;
    let edited = false;
    deps.fetch = async (game, user) => {
      if (game === "weekly_crossword" && !edited) {
        edited = true;
        const store = migrationStore(localStorage, "backword", "alice");
        const record = store.load()[0];
        store.apply({ ...record, progress_rank: 1, payload: { ...emptyBackword(date), guesses: ["PLANET"] } });
      }
      return fetch(game, user);
    };
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(false);
    expect(migrationStore(localStorage, "backword", "alice").load()[0].progress_rank).toBe(1);
  });

  it("retains all five guest histories while offline", async () => {
    seed(); const { deps } = backend();
    deps.upload = vi.fn().mockResolvedValue(false);
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(false);
    for (const game of migrationGames) expect(migrationStore(localStorage, game.type).load()).toHaveLength(1);
  });

  it("keeps an earned crossword score when the server has a later Archive grid", async () => {
    seed(); const { deps, remote } = backend();
    const guest = migrationStore(localStorage, "daily_crossword");
    const original = guest.load()[0];
    guest.apply({ ...original, release_score: 3, payload: { ...(original.payload as object), releaseDateScore: 3 } });
    remote.set("daily_crossword:daily", { ...original, status: "solved", client_updated_at: "2026-10-30T09:00:00Z",
      payload: { ...(original.payload as object), completedAt: "2026-10-30T09:00:00Z", updatedAt: "2026-10-30T09:00:00Z" } });
    expect((await runDomainMigration("alice", vi.fn(), deps)).ready).toBe(true);
    const saved = migrationStore(localStorage, "daily_crossword", "alice").load()[0];
    expect(saved.status).toBe("solved");
    expect(saved.release_score).toBe(3);
    expect(saved.payload).toMatchObject({ completedAt: "2026-10-30T09:00:00Z", releaseDateScore: 3 });
  });

});
