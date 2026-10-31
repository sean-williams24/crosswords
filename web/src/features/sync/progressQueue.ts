import type { CloudRecord } from "./progressSync";

export const legacyQueueKey = (userId: string) => `backword:web:sync:queue:v1:${userId}`;
const entryPrefix = (userId: string) => `backword:web:sync:entry:v2:${userId}:`;

type QueueEntry = { key: string; record: CloudRecord<unknown>; legacy: boolean };

export function storageKeys(storage: Storage): string[] {
  return Array.from({ length: storage.length }, (_, index) => storage.key(index)).filter((key): key is string => key !== null);
}

export async function withProgressLock<T>(name: string, action: () => Promise<T>): Promise<T> {
  if (typeof navigator !== "undefined" && navigator.locks) {
    return navigator.locks.request(`backword:sync:${name}`, action);
  }
  return action();
}

/** Each write has its own key. An acknowledged upload can never delete a newer edit. */
export class ProgressQueue {
  private inFlight = new Map<string, Promise<boolean>>();

  constructor(
    private storage: Storage,
    private currentUserId: () => Promise<string | null>,
    private upload: (userId: string, record: CloudRecord<unknown>) => Promise<void>
  ) {}

  enqueue(userId: string, record: CloudRecord<unknown>) {
    this.storage.setItem(`${entryPrefix(userId)}${crypto.randomUUID()}`, JSON.stringify(record));
  }

  private entries(userId: string): QueueEntry[] {
    const entries: QueueEntry[] = [];
    const legacy: unknown = JSON.parse(this.storage.getItem(legacyQueueKey(userId)) ?? "[]");
    if (!Array.isArray(legacy)) throw new Error("Saved uploads could not be read.");
    for (const record of legacy) entries.push({ key: legacyQueueKey(userId), record, legacy: true });
    for (const key of storageKeys(this.storage).filter((key) => key.startsWith(entryPrefix(userId)))) {
      const value = this.storage.getItem(key);
      if (value !== null) entries.push({ key, record: JSON.parse(value), legacy: false });
    }
    return entries;
  }

  pending(userId: string) { return this.entries(userId).map((entry) => entry.record); }

  flush(userId: string): Promise<boolean> {
    const existing = this.inFlight.get(userId);
    if (existing) return existing;
    const request = withProgressLock(`queue:${userId}`, async () => {
      try {
        for (const entry of this.entries(userId)) {
          if (await this.currentUserId() !== userId) return false;
          await this.upload(userId, entry.record);
          if (await this.currentUserId() !== userId) return false;
          if (entry.legacy) {
            const current = JSON.parse(this.storage.getItem(entry.key) ?? "[]") as CloudRecord<unknown>[];
            this.storage.setItem(entry.key, JSON.stringify(current.filter((record) =>
              JSON.stringify(record) !== JSON.stringify(entry.record))));
          } else {
            this.storage.removeItem(entry.key);
          }
        }
        return this.entries(userId).length === 0;
      } catch {
        // Authentication changes, corrupt storage, and network failures all retain the queue.
        return false;
      }
    }).finally(() => { this.inFlight.delete(userId); });
    this.inFlight.set(userId, request);
    return request;
  }
}
