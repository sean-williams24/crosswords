import type { BackwordProgress } from "../backword/types";
import type { CrosswordProgress } from "../crossword/types";
import { supabase } from "../../lib/supabase";

export type CloudGameType = "backword" | "daily_crossword" | "weekly_crossword";

export type CloudRecord<T> = {
  game_type: CloudGameType;
  content_key: string;
  release_date: string;
  schema_version: number;
  status: "in_progress" | "solved" | "failed" | "gave_up";
  progress_rank: number;
  release_score: number;
  client_updated_at: string;
  payload: T;
};

const queueKey = (userId: string) => `backword:web:sync:queue:v1:${userId}`;
const uploadTimers = new Map<string, number>();
const crosswordTypingDebounceMs = 700;

function readQueue(userId: string): CloudRecord<unknown>[] {
  try {
    const value: unknown = JSON.parse(localStorage.getItem(queueKey(userId)) ?? "[]");
    return Array.isArray(value) ? value as CloudRecord<unknown>[] : [];
  } catch {
    return [];
  }
}

function writeQueue(userId: string, queue: CloudRecord<unknown>[]) {
  localStorage.setItem(queueKey(userId), JSON.stringify(queue));
}

function completionScore(progress: BackwordProgress) {
  return progress.outcome === "won" ? Math.max(0, 6 - progress.guesses.length) : 0;
}

export function backwordCloudRecord(progress: BackwordProgress): CloudRecord<BackwordProgress> {
  return {
    game_type: "backword",
    content_key: progress.date,
    release_date: progress.date,
    schema_version: progress.schemaVersion,
    status: progress.outcome === "won" ? "solved" : progress.outcome === "failed" ? "failed" : "in_progress",
    progress_rank: progress.guesses.length,
    release_score: completionScore(progress),
    client_updated_at: progress.updatedAt ?? progress.completedAt ?? new Date(0).toISOString(),
    payload: progress
  };
}

export function crosswordCloudRecord(progress: CrosswordProgress): CloudRecord<CrosswordProgress> {
  return {
    game_type: "daily_crossword",
    content_key: progress.puzzleId,
    release_date: progress.date,
    schema_version: progress.schemaVersion,
    status: progress.completedAt ? "solved" : "in_progress",
    progress_rank: progress.completedClueIds.length * 100 + progress.entries.flat().filter(Boolean).length,
    release_score: progress.releaseDateScore,
    client_updated_at: progress.updatedAt ?? progress.completedAt ?? progress.startedAt,
    payload: progress
  };
}

function statusRank(status: CloudRecord<unknown>["status"]) {
  return status === "solved" ? 3 : status === "failed" || status === "gave_up" ? 2 : 1;
}

/** Returns a whole-record winner; conflicting grids and guesses are never merged. */
export function chooseBestProgress<T>(first: CloudRecord<T>, second: CloudRecord<T>): CloudRecord<T> {
  if (first.status === "solved" || second.status === "solved") {
    if (first.status !== "solved") return second;
    if (second.status !== "solved") return first;
    if (first.release_score !== second.release_score) {
      return first.release_score > second.release_score ? first : second;
    }
  } else {
    if (statusRank(first.status) !== statusRank(second.status)) {
      return statusRank(first.status) > statusRank(second.status) ? first : second;
    }
    if (first.progress_rank !== second.progress_rank) {
      return first.progress_rank > second.progress_rank ? first : second;
    }
  }
  return Date.parse(first.client_updated_at) >= Date.parse(second.client_updated_at) ? first : second;
}

async function mergeOnServer(record: CloudRecord<unknown>) {
  if (!supabase) throw new Error("Cloud sync is not configured.");
  const { error } = await supabase.rpc("merge_game_progress", {
    p_game_type: record.game_type,
    p_content_key: record.content_key,
    p_release_date: record.release_date,
    p_schema_version: record.schema_version,
    p_status: record.status,
    p_progress_rank: record.progress_rank,
    p_release_score: record.release_score,
    p_client_updated_at: record.client_updated_at,
    p_payload: record.payload
  });
  if (error) throw error;
}

export async function queueAndSync(userId: string, record: CloudRecord<unknown>) {
  queueRecord(userId, record);
  return flushSyncQueue(userId);
}

/**
 * Writes locally immediately but batches active grid edits before uploading.
 * Terminal records bypass the delay, and every failed upload remains queued
 * under the signed-in user ID for the next retry.
 */
export function queueAndDebounce(userId: string, record: CloudRecord<unknown>) {
  queueRecord(userId, record);
  const key = `${userId}:${record.game_type}:${record.content_key}`;
  const previousTimer = uploadTimers.get(key);
  if (previousTimer !== undefined) window.clearTimeout(previousTimer);

  if (record.status !== "in_progress") {
    uploadTimers.delete(key);
    void flushSyncQueue(userId);
    return;
  }

  uploadTimers.set(key, window.setTimeout(() => {
    uploadTimers.delete(key);
    void flushSyncQueue(userId);
  }, crosswordTypingDebounceMs));
}

function queueRecord(userId: string, record: CloudRecord<unknown>) {
  const queue = readQueue(userId).filter((item) =>
    item.game_type !== record.game_type || item.content_key !== record.content_key
  );
  queue.push(record);
  writeQueue(userId, queue);
}

export async function flushSyncQueue(userId: string) {
  const queue = readQueue(userId);
  const remaining: CloudRecord<unknown>[] = [];
  for (const record of queue) {
    try {
      await mergeOnServer(record);
    } catch {
      remaining.push(record);
    }
  }
  writeQueue(userId, remaining);
  return remaining.length === 0;
}

export async function fetchCloudProgress<T>(gameType: CloudGameType): Promise<CloudRecord<T>[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("game_progress")
    .select("game_type, content_key, release_date, schema_version, status, progress_rank, release_score, client_updated_at, payload")
    .eq("game_type", gameType);
  if (error) throw error;
  return (data ?? []) as CloudRecord<T>[];
}

export async function migrateProgress<T>(
  userId: string,
  gameType: CloudGameType,
  guestRecords: CloudRecord<T>[],
  accountRecords: CloudRecord<T>[],
  applyWinner: (record: CloudRecord<T>) => void,
  removeGuest: (record: CloudRecord<T>) => void
) {
  const cloudRecords = await fetchCloudProgress<T>(gameType);
  const candidates = [...guestRecords, ...accountRecords, ...cloudRecords];
  const winners = new Map<string, CloudRecord<T>>();
  for (const candidate of candidates) {
    const existing = winners.get(candidate.content_key);
    winners.set(candidate.content_key, existing ? chooseBestProgress(existing, candidate) : candidate);
  }
  const uploadedKeys = new Set<string>();
  for (const winner of winners.values()) {
    applyWinner(winner);
    if (await queueAndSync(userId, winner as CloudRecord<unknown>)) {
      uploadedKeys.add(winner.content_key);
    }
  }
  for (const guest of guestRecords) {
    if (uploadedKeys.has(guest.content_key)) removeGuest(guest);
  }
}

/**
 * Reconcile the account namespace with the cloud after another signed-in
 * device may have played. There is no guest data to remove in this path.
 */
export async function refreshAccountProgress<T>(
  userId: string,
  gameType: CloudGameType,
  accountRecords: CloudRecord<T>[],
  applyWinner: (record: CloudRecord<T>) => void
) {
  await migrateProgress(userId, gameType, [], accountRecords, applyWinner, () => undefined);
}
