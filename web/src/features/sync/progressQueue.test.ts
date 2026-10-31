import { beforeEach, describe, expect, it, vi } from "vitest";
import { ProgressQueue, legacyQueueKey } from "./progressQueue";
import type { CloudRecord } from "./progressSync";

const record = (rank = 1): CloudRecord<unknown> => ({ game_type: "backword", content_key: "2026-10-29", release_date: "2026-10-29", schema_version: 1, status: "in_progress", progress_rank: rank, release_score: 0, client_updated_at: "2026-10-29T10:00:00Z", payload: { guesses: Array(rank).fill("PLANET") } });
beforeEach(() => localStorage.clear());

describe("durable account upload queue", () => {
  it("retains failed uploads and retries the original queue format", async () => {
    localStorage.setItem(legacyQueueKey("alice"), JSON.stringify([record()]));
    const upload = vi.fn().mockRejectedValueOnce(new Error("offline")).mockResolvedValue(undefined);
    const queue = new ProgressQueue(localStorage, async () => "alice", upload);
    expect(await queue.flush("alice")).toBe(false);
    expect(queue.pending("alice")).toHaveLength(1);
    expect(await queue.flush("alice")).toBe(true);
    expect(queue.pending("alice")).toEqual([]);
  });
  it("does not erase a newer edit added while an upload is in flight", async () => {
    let finish!: () => void;
    const upload = vi.fn().mockImplementationOnce(() => new Promise<void>((resolve) => { finish = resolve; })).mockResolvedValue(undefined);
    const queue = new ProgressQueue(localStorage, async () => "alice", upload);
    queue.enqueue("alice", record());
    const pending = queue.flush("alice");
    await vi.waitFor(() => expect(upload).toHaveBeenCalledOnce());
    queue.enqueue("alice", record(2)); finish();
    expect(await pending).toBe(false);
    expect(queue.pending("alice")).toEqual([record(2)]);
    expect(await queue.flush("alice")).toBe(true);
  });
  it("coalesces concurrent flushes and retains writes made by another tab", async () => {
    const upload = vi.fn().mockImplementation(async () => { otherTab.enqueue("alice", record(2)); });
    const queue = new ProgressQueue(localStorage, async () => "alice", upload);
    const otherTab = new ProgressQueue(localStorage, async () => "alice", vi.fn());
    queue.enqueue("alice", record());
    const first = queue.flush("alice");
    expect(queue.flush("alice")).toBe(first);
    expect(await first).toBe(false);
    expect(queue.pending("alice")).toEqual([record(2)]);
  });
  it("stops after an account switch without uploading or discarding remaining records", async () => {
    let user = "alice";
    const upload = vi.fn().mockImplementation(async () => { user = "bob"; });
    const queue = new ProgressQueue(localStorage, async () => user, upload);
    queue.enqueue("alice", record()); queue.enqueue("alice", record(2));
    expect(await queue.flush("alice")).toBe(false);
    expect(upload).toHaveBeenCalledOnce();
    expect(queue.pending("alice")).toHaveLength(2);
    expect(await queue.flush("alice")).toBe(false);
    expect(upload).toHaveBeenCalledOnce();
  });
  it("blocks a corrupt legacy queue without clearing it", async () => {
    localStorage.setItem(legacyQueueKey("alice"), "broken");
    const queue = new ProgressQueue(localStorage, async () => "alice", vi.fn());
    expect(await queue.flush("alice")).toBe(false);
    expect(localStorage.getItem(legacyQueueKey("alice"))).toBe("broken");
  });
});
