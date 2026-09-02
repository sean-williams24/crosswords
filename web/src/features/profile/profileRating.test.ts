import { describe, expect, it } from "vitest";
import { buildPlayerProfileRating } from "./profileRating";

const now = new Date(2026, 7, 17, 12);

describe("buildPlayerProfileRating", () => {
  it("builds a zero-filled 14-day window from cloud release scores", () => {
    const rating = buildPlayerProfileRating({
      backword: [{ release_date: "2026-08-17", release_score: 5 }],
      dailyCrossword: [{ release_date: "2026-08-16", release_score: 3 }],
      weeklyCrossword: []
    }, false, now);

    expect(rating.maxPoints).toBe(140);
    expect(rating.totalPoints).toBe(8);
    expect(rating.days).toHaveLength(14);
    expect(rating.days[0]).toMatchObject({ date: "2026-08-17", dailyCrossword: 0, weeklyCrossword: null, backword: 5, total: 5 });
    expect(rating.days[1]).toMatchObject({ date: "2026-08-16", dailyCrossword: 3, weeklyCrossword: null, backword: 0, total: 3 });
    expect(rating.days.at(-1)).toMatchObject({ date: "2026-08-04", total: 0 });
  });

  it("includes synced weekly scores and uses the iOS Pro maximum", () => {
    const rating = buildPlayerProfileRating({
      backword: [{ release_date: "2026-08-17", release_score: 5 }],
      dailyCrossword: [{ release_date: "2026-08-17", release_score: 5 }],
      weeklyCrossword: [{ release_date: "2026-08-17", release_score: 5 }]
    }, true, now);

    expect(rating.maxPoints).toBe(150);
    expect(rating.days[0]).toMatchObject({ weeklyCrossword: 5, total: 15 });
  });

  it("does not count an archive Backword win from a stale cloud release score", () => {
    const rating = buildPlayerProfileRating({
      backword: [{
        release_date: "2026-08-16",
        release_score: 4,
        payload: {
          schemaVersion: 1,
          date: "2026-08-16",
          guesses: ["TWIRLL", "SPIRAL"],
          outcome: "won",
          completedAt: "2026-08-17T08:27:07.234Z"
        }
      }],
      dailyCrossword: [],
      weeklyCrossword: []
    }, false, now);

    expect(rating.days[1]).toMatchObject({ date: "2026-08-16", backword: 0, total: 0 });
  });

  it("excludes weekly scores for non-Pro accounts and applies the shared tier thresholds", () => {
    const records = {
      backword: Array.from({ length: 14 }, (_, index) => ({ release_date: `2026-08-${String(17 - index).padStart(2, "0")}`, release_score: 5 })),
      dailyCrossword: Array.from({ length: 14 }, (_, index) => ({ release_date: `2026-08-${String(17 - index).padStart(2, "0")}`, release_score: 5 })),
      weeklyCrossword: [{ release_date: "2026-08-17", release_score: 5 }]
    };

    const standard = buildPlayerProfileRating(records, false, now);
    const pro = buildPlayerProfileRating(records, true, now);

    expect(standard.totalPoints).toBe(140);
    expect(standard.tier).toBe("Virtuoso");
    expect(standard.days[0].weeklyCrossword).toBeNull();
    expect(pro.totalPoints).toBe(145);
    expect(pro.maxPoints).toBe(150);
  });
});
