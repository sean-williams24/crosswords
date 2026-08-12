import { describe, expect, it } from "vitest";
import { chooseBestProgress } from "./progressSync";

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
});
