import { isLocalDateString } from "./date";

describe("isLocalDateString", () => {
  it("accepts real ISO calendar dates and rejects malformed archive parameters", () => {
    expect(isLocalDateString("2026-02-28")).toBe(true);
    expect(isLocalDateString("2026-02-29")).toBe(false);
    expect(isLocalDateString("2026-2-08")).toBe(false);
    expect(isLocalDateString(undefined)).toBe(false);
  });
});
