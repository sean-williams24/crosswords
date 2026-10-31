import { canMigrateGuestProgress, clearGuestMigrationOwnerIfEmpty, hasGuestProgress } from "../sync/guestMigration";
import { chooseBestProgress, fetchCloudProgress, flushSyncQueue, pendingSyncRecords, queueAndSync, requireSyncSession, type CloudGameType, type CloudRecord } from "../sync/progressSync";
import { withProgressLock } from "../sync/progressQueue";
import { migrationGames, migrationStore, readMigrationRecords } from "./migrationStorage";

export type MigrationGameState = { game: CloudGameType; status: "pending" | "syncing" | "verified" | "failed" };
export type MigrationResult = { ready: boolean; games: MigrationGameState[] };
export type MigrationDependencies = {
  storage: Storage;
  assertAccount: (userId: string) => Promise<unknown>;
  pending: (userId: string) => CloudRecord<unknown>[];
  upload: (userId: string, record: CloudRecord<unknown>) => Promise<boolean>;
  flush: (userId: string) => Promise<boolean>;
  fetch: (game: CloudGameType, userId: string) => Promise<CloudRecord<unknown>[]>;
};

function canonical(value: unknown): string {
  function normalize(item: unknown): unknown {
    if (Array.isArray(item)) return item.map(normalize);
    if (item && typeof item === "object") return Object.fromEntries(Object.entries(item)
      .filter(([, entry]) => entry !== null && entry !== undefined)
      .sort(([a], [b]) => a.localeCompare(b)).map(([key, entry]) => [key, normalize(entry)]));
    return item;
  }
  return JSON.stringify(normalize(value));
}

function normalizedPayload(record: CloudRecord<unknown>) {
  if (record.game_type === "daily_crossword" || record.game_type === "weekly_crossword") {
    const payload = record.payload as Record<string, unknown>;
    return { ...payload, hintsUsed: payload.hintsUsed ?? 0, hintedClueIds: payload.hintedClueIds ?? [],
      isWeekly: record.game_type === "weekly_crossword" };
  }
  return record.payload;
}

export function serverContainsProgress(server: CloudRecord<unknown>, expected: CloudRecord<unknown>) {
  if (server.game_type !== expected.game_type || server.content_key !== expected.content_key) return false;
  const winner = chooseBestProgress(server, expected);
  return winner.status === server.status && winner.release_score === server.release_score
    && canonical(normalizedPayload(winner)) === canonical(normalizedPayload(server));
}

/** Success means every local record was read back from this same account's server data. */
export async function runDomainMigration(userId: string, onUpdate: (games: MigrationGameState[]) => void,
  dependencies?: MigrationDependencies): Promise<MigrationResult> {
  const deps: MigrationDependencies = dependencies ?? {
    storage: localStorage, assertAccount: requireSyncSession, pending: pendingSyncRecords,
    upload: queueAndSync, flush: flushSyncQueue, fetch: fetchCloudProgress
  };
  return withProgressLock("domain-migration", async () => {
    const games: MigrationGameState[] = migrationGames.map(({ type }) => ({ game: type, status: "pending" }));
    const publish = () => onUpdate(games.map((game) => ({ ...game })));
    publish();
    try {
      await deps.assertAccount(userId);
      const mayMigrate = canMigrateGuestProgress(deps.storage, userId);
      if (hasGuestProgress(deps.storage) && !mayMigrate) throw new Error("These guest saves belong to another account.");
      // Capture pending uploads before flushing: some may no longer be present in the game caches.
      const queued = deps.pending(userId);
      for (const state of games) {
        state.status = "syncing"; publish();
        try {
          await deps.assertAccount(userId);
          const guests = readMigrationRecords(deps.storage, state.game);
          const account = readMigrationRecords(deps.storage, state.game, userId);
          const expected = [...guests, ...account, ...queued.filter((record) => record.game_type === state.game)];
          for (const record of expected) {
            await deps.assertAccount(userId);
            if (!await deps.upload(userId, record)) throw new Error("An upload is still pending.");
          }
          if (!await deps.flush(userId)) throw new Error("An upload is still pending.");
          const remote = await deps.fetch(state.game, userId);
          await deps.assertAccount(userId);
          for (const record of expected) {
            const saved = remote.find((candidate) => candidate.content_key === record.content_key);
            if (!saved || !serverContainsProgress(saved, record)) throw new Error("A save has not been verified.");
          }
          // Another tab may have edited a save while the server was responding.
          if (canonical(readMigrationRecords(deps.storage, state.game)) !== canonical(guests)
            || canonical(readMigrationRecords(deps.storage, state.game, userId)) !== canonical(account)) {
            throw new Error("Progress changed in another tab. Try again.");
          }
          const accountStore = migrationStore(deps.storage, state.game, userId);
          for (const record of remote) accountStore.apply(record);
          const guestStore = migrationStore(deps.storage, state.game);
          for (const record of guests) guestStore.remove(record);
          state.status = "verified";
        } catch {
          state.status = "failed";
        }
        publish();
      }
      await deps.assertAccount(userId);
      clearGuestMigrationOwnerIfEmpty(deps.storage);
      // Recheck the full browser at the end: another tab could edit an earlier game
      // while a later game's history is uploading.
      let ready = games.every((game) => game.status === "verified") && await deps.flush(userId);
      if (ready) {
        const snapshots = games.map((game) => readMigrationRecords(deps.storage, game.game, userId));
        for (const [index, state] of games.entries()) {
          const remote = await deps.fetch(state.game, userId);
          await deps.assertAccount(userId);
          if (snapshots[index].some((record) => {
            const saved = remote.find((candidate) => candidate.content_key === record.content_key);
            return !saved || !serverContainsProgress(saved, record);
          })) state.status = "failed";
        }
        for (const [index, state] of games.entries()) {
          if (canonical(readMigrationRecords(deps.storage, state.game, userId)) !== canonical(snapshots[index])
            || readMigrationRecords(deps.storage, state.game).length > 0) state.status = "failed";
        }
        ready = games.every((game) => game.status === "verified") && deps.pending(userId).length === 0;
        publish();
      }
      return { ready, games };
    } catch {
      for (const game of games) if (game.status !== "verified") game.status = "failed";
      publish();
      return { ready: false, games };
    }
  });
}
