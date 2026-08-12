import { describe, expect, it } from "vitest";
import { chooseBestProgress, crosswordCloudRecord } from "./progressSync";

describe("cloud progress conflict selection", () => {
  it("keeps a solved result over an in-progress result", () => {
    const inProgress = {
      game_type: "backword" as const,
      content_key: "2026-08-06",
      release_date: "2026-08-06",
      schema_version: 1,
      status: "in_progress" as const,
      progress_rank: 4,
      release_score: 0,
      client_updated_at: "2026-08-06T11:00:00.000Z",
      payload: { source: "device" }
    };
    const solved = { ...inProgress, status: "solved" as const, progress_rank: 3, release_score: 3, payload: { source: "cloud" } };

    expect(chooseBestProgress(inProgress, solved).payload.source).toBe("cloud");
  });

  it("uses the higher solved release score before timestamp", () => {
    const first = {
      game_type: "backword" as const,
      content_key: "2026-08-06",
      release_date: "2026-08-06",
      schema_version: 1,
      status: "solved" as const,
      progress_rank: 4,
      release_score: 2,
      client_updated_at: "2026-08-06T12:00:00.000Z",
      payload: { source: "first" }
    };
    const second = { ...first, release_score: 4, client_updated_at: "2026-08-06T11:00:00.000Z", payload: { source: "second" } };

    expect(chooseBestProgress(first, second).payload.source).toBe("second");
  });

  it("uses the shared crossword release-score snapshot", () => {
    const record = crosswordCloudRecord({
      schemaVersion: 1,
      puzzleId: "ios-puzzle-id",
      date: "2026-08-12",
      size: 9,
      entries: Array.from({ length: 9 }, () => Array(9).fill(null)),
      completedClueIds: [1, 2, 3],
      startedAt: "2026-08-12T09:00:00.000Z",
      completedAt: null,
      releaseDateScore: 3,
      updatedAt: "2026-08-12T10:00:00.000Z"
    });

    expect(record.content_key).toBe("ios-puzzle-id");
    expect(record.release_score).toBe(3);
  });
});
