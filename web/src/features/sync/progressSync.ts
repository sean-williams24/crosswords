import { backwordScore } from "../backword/engine";
import { localDateString } from "../backword/date";
import { normalizeAnagramProgress, pointsForSeconds, type AnagramProgress } from "../anagram/engine";
import { decodeProgress, type MidwordProgress } from "../midword/engine";
import type { BackwordProgress } from "../backword/types";
import type { CrosswordKind, CrosswordProgress } from "../crossword/types";
import { supabase } from "../../lib/supabase";
import { ProgressQueue } from "./progressQueue";

export type CloudGameType = "backword" | "midword" | "anagram" | "daily_crossword" | "weekly_crossword";

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

const uploadTimers = new Map<string, number>();
const crosswordTypingDebounceMs = 700;

export async function requireSyncSession(userId: string) {
  if (!supabase) throw new Error("Cloud sync is not configured.");
  const { data, error } = await supabase.auth.getSession();
  if (error || data.session?.user.id !== userId) throw new Error("Sign in with the same account to finish syncing.");
  return data.session;
}

let progressQueue: ProgressQueue | undefined;
function queue() {
  return progressQueue ??= new ProgressQueue(localStorage, async () => {
    if (!supabase) return null;
    const { data } = await supabase.auth.getSession();
    return data.session?.user.id ?? null;
  }, mergeOnServer);
}

export function pendingSyncRecords(userId: string) { return queue().pending(userId); }

function completionScore(progress: BackwordProgress) {
  return backwordScore(progress);
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

export function anagramCloudRecord(progress: AnagramProgress): CloudRecord<AnagramProgress> {
  return {
    game_type: "anagram", content_key: progress.date, release_date: progress.date,
    schema_version: progress.schemaVersion,
    status: progress.outcome === "solved" ? "solved" : progress.outcome === "gave_up" ? "gave_up" : "in_progress",
    progress_rank: progress.placementHistory.length + (progress.hintUsed ? 100 : 0),
    release_score: progress.releaseDateScore, client_updated_at: progress.updatedAt, payload: progress
  };
}

export function midwordCloudRecord(progress: MidwordProgress): CloudRecord<MidwordProgress> {
  return {
    game_type: "midword", content_key: progress.date, release_date: progress.date, schema_version: 1,
    status: progress.outcome === "won" ? "solved" : progress.outcome === "failed" ? "failed" : "in_progress",
    progress_rank: progress.guesses.length, release_score: progress.releaseDateScore,
    client_updated_at: progress.updatedAt, payload: progress
  };
}

export function crosswordCloudRecord(
  progress: CrosswordProgress,
  kind: CrosswordKind = progress.isWeekly ? "weekly" : "daily"
): CloudRecord<CrosswordProgress> {
  return {
    game_type: kind === "weekly" ? "weekly_crossword" : "daily_crossword",
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
  const winner = chooseWholeRecord(first, second);
  if (first.game_type === "daily_crossword" || first.game_type === "weekly_crossword") {
    const score = Math.max(first.release_score, second.release_score);
    return { ...winner, release_score: score, payload: { ...winner.payload, releaseDateScore: score } };
  }
  return winner;
}

function chooseWholeRecord<T>(first: CloudRecord<T>, second: CloudRecord<T>): CloudRecord<T> {
  if (first.game_type === "midword" && second.game_type === "midword") {
    const a = decodeProgress(first.payload), b = decodeProgress(second.payload);
    if (!a) return second;
    if (!b) return first;
    // Match native Midword ranking while retaining earned points independently.
    const aWon = a.outcome === "won", bWon = b.outcome === "won";
    const aComplete = a.completedAt !== null, bComplete = b.completedAt !== null;
    let winner: CloudRecord<T>;
    if (aWon !== bWon) winner = aWon ? first : second;
    else if (aComplete !== bComplete) winner = aComplete ? first : second;
    else if (a.guesses.length !== b.guesses.length) {
      const preferFirst = aWon ? a.guesses.length < b.guesses.length : a.guesses.length > b.guesses.length;
      winner = preferFirst ? first : second;
    } else winner = Date.parse(a.updatedAt) >= Date.parse(b.updatedAt) ? first : second;
    const score = Math.max(first.release_score, second.release_score, a.releaseDateScore, b.releaseDateScore);
    return { ...winner, game_type: "midword", release_score: score,
      payload: { ...(winner.payload === first.payload ? a : b), releaseDateScore: score } as T };
  }
  if (first.game_type === "anagram" && second.game_type === "anagram") {
    const a = normalizeAnagramProgress(first.payload as AnagramProgress);
    const b = normalizeAnagramProgress(second.payload as AnagramProgress);
    const aTerminal = a.outcome !== null;
    const bTerminal = b.outcome !== null;
    const winner = aTerminal !== bTerminal ? aTerminal ? first : second
      : aTerminal && bTerminal ? Date.parse(a.completedAt ?? "") <= Date.parse(b.completedAt ?? "") ? first : second
      : a.hintUsed !== b.hintUsed ? a.hintUsed ? first : second
      : a.placementHistory.length !== b.placementHistory.length ? a.placementHistory.length > b.placementHistory.length ? first : second
      : Date.parse(first.client_updated_at) >= Date.parse(second.client_updated_at) ? first : second;
    const chosen = winner === first ? a : b;
    const earliestStart = new Date(Math.min(Date.parse(a.startedAt), Date.parse(b.startedAt))).toISOString();
    const penaltySeconds = Math.max(a.penaltySeconds, b.penaltySeconds);
    const payload = { ...chosen, startedAt: earliestStart, hintUsed: a.hintUsed || b.hintUsed,
      hintSource: chosen.hintSource ?? a.hintSource ?? b.hintSource, penaltySeconds,
      releaseDateScore: Math.max(a.releaseDateScore, b.releaseDateScore) };
    if (payload.completedAt) {
      payload.elapsedSecondsAtCompletion = Math.max(0, Math.floor((Date.parse(payload.completedAt) - Date.parse(earliestStart)) / 1000));
      payload.releaseDateScore = payload.outcome === "solved"
        && localDateString(new Date(payload.completedAt)) === payload.date
        ? pointsForSeconds(payload.elapsedSecondsAtCompletion + penaltySeconds) : 0;
    }
    return { ...winner, release_score: payload.releaseDateScore, payload: payload as T };
  }
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

async function mergeOnServer(userId: string, record: CloudRecord<unknown>) {
  const session = await requireSyncSession(userId);
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
  }).setHeader("Authorization", `Bearer ${session.access_token}`);
  if (error) throw error;
}

export async function queueAndSync(userId: string, record: CloudRecord<unknown>) {
  queue().enqueue(userId, record);
  return flushSyncQueue(userId);
}

/**
 * Writes locally immediately but batches active grid edits before uploading.
 * Terminal records bypass the delay, and every failed upload remains queued
 * under the signed-in user ID for the next retry.
 */
export function queueAndDebounce(userId: string, record: CloudRecord<unknown>) {
  queue().enqueue(userId, record);
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

export function flushSyncQueue(userId: string) {
  return queue().flush(userId);
}

export async function fetchCloudProgress<T>(gameType: CloudGameType, userId?: string): Promise<CloudRecord<T>[]> {
  if (!supabase) return [];
  if (!userId) {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    userId = data.session?.user.id;
  }
  if (!userId) throw new Error("Sign in to read your saved progress.");
  const records: CloudRecord<T>[] = [];
  const pageSize = 500;
  for (let offset = 0; ;) {
    const session = await requireSyncSession(userId);
    let query = supabase.from("game_progress")
      .select("game_type, content_key, release_date, schema_version, status, progress_rank, release_score, client_updated_at, payload", { count: "exact" })
      .eq("game_type", gameType);
    query = query.eq("user_id", userId).setHeader("Authorization", `Bearer ${session.access_token}`)
      .order("content_key").range(offset, offset + pageSize - 1);
    const { data, error, count } = await query;
    await requireSyncSession(userId);
    if (error) throw error;
    records.push(...(data ?? []) as CloudRecord<T>[]);
    if (!(data ?? []).length || (count !== null && count !== undefined && records.length >= count)) return records;
    offset += (data ?? []).length;
  }
}

export async function migrateProgress<T>(
  userId: string,
  gameType: CloudGameType,
  guestRecords: CloudRecord<T>[],
  accountRecords: CloudRecord<T>[],
  applyWinner: (record: CloudRecord<T>) => void,
  removeGuest: (record: CloudRecord<T>) => void
) {
  const cloudRecords = await fetchCloudProgress<T>(gameType, userId);
  await requireSyncSession(userId);
  const candidates = [...guestRecords, ...accountRecords, ...cloudRecords];
  const winners = new Map<string, CloudRecord<T>>();
  for (const candidate of candidates) {
    const existing = winners.get(candidate.content_key);
    winners.set(candidate.content_key, existing ? chooseBestProgress(existing, candidate) : candidate);
  }
  const uploadedKeys = new Set<string>();
  for (const winner of winners.values()) {
    await requireSyncSession(userId);
    applyWinner(winner);
    if (await queueAndSync(userId, winner as CloudRecord<unknown>)) {
      uploadedKeys.add(winner.content_key);
    }
  }
  await requireSyncSession(userId);
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
