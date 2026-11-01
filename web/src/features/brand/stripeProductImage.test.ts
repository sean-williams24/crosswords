import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

describe("Stripe product artwork", () => {
  it("exports a PNG at the supplied Backword Pro reference dimensions", () => {
    const image = readFileSync(resolve(process.cwd(), "../docs/intervls-brand/intervls-pro-stripe-902x700.png"));
    expect(image.subarray(0, 8)).toEqual(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
    expect(image.toString("ascii", 12, 16)).toBe("IHDR");
    expect(image.readUInt32BE(16)).toBe(902);
    expect(image.readUInt32BE(20)).toBe(700);
  });
});
