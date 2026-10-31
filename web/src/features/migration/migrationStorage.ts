import { storageKeys } from "../sync/progressQueue";
import { createBackwordStorage } from "../backword/storage";
import { createAnagramStorage } from "../anagram/storage";
import { createMidwordStorage } from "../midword/storage";
import { createCrosswordStorage } from "../crossword/storage";
import { anagramCloudRecord, backwordCloudRecord, crosswordCloudRecord, midwordCloudRecord, type CloudGameType, type CloudRecord } from "../sync/progressSync";

export const migrationGames: { type: CloudGameType; name: string; key: string }[] = [
  { type: "backword", name: "Backword", key: "backword:web:progress:v1" },
  { type: "anagram", name: "Anagram", key: "backword:web:anagram:progress:v1" },
  { type: "midword", name: "Midword", key: "backword:web:midword:progress:v1" },
  { type: "daily_crossword", name: "Quick Crossword", key: "backword:web:crossword:progress:v1" },
  { type: "weekly_crossword", name: "Pro Crossword", key: "backword:web:weekly-crossword:progress:v1" }
];

export type MigrationStore = {
  load: () => CloudRecord<unknown>[];
  apply: (record: CloudRecord<unknown>) => void;
  remove: (record: CloudRecord<unknown>) => void;
};

function adapter<T>(store: { loadAllProgress: () => T[]; replaceProgress: (value: T) => void; deleteProgress: (key: string) => void },
  record: (value: T) => CloudRecord<T>): MigrationStore {
  return {
    load: () => store.loadAllProgress().map(record),
    apply: (value) => store.replaceProgress(value.payload as T),
    remove: (value) => store.deleteProgress(value.content_key)
  };
}

export function migrationStore(storage: Storage, game: CloudGameType, userId?: string): MigrationStore {
  switch (game) {
    case "backword": return adapter(createBackwordStorage(storage, { userId }), backwordCloudRecord);
    case "anagram": return adapter(createAnagramStorage(storage, { userId }), anagramCloudRecord);
    case "midword": return adapter(createMidwordStorage(storage, { userId }), midwordCloudRecord);
    case "daily_crossword": return adapter(createCrosswordStorage(storage, { userId }), (value) => crosswordCloudRecord(value, "daily"));
    case "weekly_crossword": return adapter(createCrosswordStorage(storage, { userId, kind: "weekly" }), (value) => crosswordCloudRecord(value, "weekly"));
  }
}

/** A migration must not silently skip a save rejected by a normal gameplay decoder. */
export function readMigrationRecords(storage: Storage, game: CloudGameType, userId?: string) {
  const definition = migrationGames.find((item) => item.type === game)!;
  const key = userId ? `${definition.key}:user:${userId}` : definition.key;
  const raw: unknown = JSON.parse(storage.getItem(key) ?? "{}");
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("Some saved progress could not be read.");
  const records = migrationStore(storage, game, userId).load();
  if (Object.keys(raw).length !== records.length) throw new Error("Some saved progress could not be read.");
  return records;
}

export function inspectMigrationStorage(storage: Storage) {
  const accountIds = new Set<string>();
  let hasSaves = false;
  for (const key of storageKeys(storage)) {
    const isProgress = migrationGames.some((game) => key === game.key || key.startsWith(`${game.key}:user:`));
    const isQueue = key.startsWith("backword:web:sync:queue:v1:") || key.startsWith("backword:web:sync:entry:v2:");
    if (!isProgress && !isQueue) continue;
    const value = storage.getItem(key);
    if (value && value !== "{}" && value !== "[]") hasSaves = true;
    const account = key.match(/:user:(.+)$/)?.[1]
      ?? (key.startsWith("backword:web:sync:queue:v1:") ? key.slice("backword:web:sync:queue:v1:".length) : null)
      ?? (key.startsWith("backword:web:sync:entry:v2:") ? key.slice("backword:web:sync:entry:v2:".length).split(":")[0] : null);
    if (account && value && value !== "{}" && value !== "[]") accountIds.add(account);
  }
  return { hasSaves, accountIds: [...accountIds] };
}
