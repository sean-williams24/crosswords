import { describe, expect, it } from "vitest";
import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const root = resolve(process.cwd(), "..");

describe("supplied app icon import", () => {
  it.runIf(process.platform === "darwin")("imports the current source into every app icon output without changing sources or the separate favicon", () => {
    const fixture = mkdtempSync(join(tmpdir(), "intervls-icon-import-"));
    const source = "docs/intervls-brand/intervls-icon.png";
    const outputs = [
      "Backword/Resources/Assets.xcassets/AppIcon.appiconset/intervls-icon.png",
      "web/public/brand/intervls-icon.png",
      "web/public/apple-touch-icon.png"
    ];
    const protectedFiles = [
      "docs/intervls-brand/IV-icon.png",
      "docs/intervls-brand/intervls-icon-draft.png",
      "docs/intervls-brand/previous-app-icon.png",
      "web/public/brand/intervls-tab-icon.png"
    ];
    const sentinel = Buffer.from("Preserve earlier icons and the separate browser-tab artwork.");
    const original = readFileSync(resolve(root, source));
    try {
      for (const path of [source, ...outputs, ...protectedFiles]) {
        mkdirSync(dirname(join(fixture, path)), { recursive: true });
        writeFileSync(join(fixture, path), sentinel);
      }
      cpSync(resolve(root, source), join(fixture, source));
      execFileSync("/usr/bin/swift", [resolve(root, "docs/intervls-brand/import-icon.swift"), fixture], {
        env: { ...process.env, CLANG_MODULE_CACHE_PATH: join(tmpdir(), "intervls-icon-test-module-cache"), SWIFT_MODULECACHE_PATH: join(tmpdir(), "intervls-icon-test-module-cache") },
        timeout: 30000, stdio: "pipe"
      });
      expect(readFileSync(join(fixture, source))).toEqual(original);
      for (const path of protectedFiles) expect(readFileSync(join(fixture, path)), path).toEqual(sentinel);
      // The importer also verifies that removing unused alpha preserves every source pixel.
      for (const [index, path] of outputs.entries()) {
        const exported = readFileSync(join(fixture, path));
        expect(exported, path).toEqual(readFileSync(resolve(root, path)));
        expect(exported.readUInt32BE(16)).toBe(index === 2 ? 180 : 1024);
        expect(exported.readUInt32BE(20)).toBe(index === 2 ? 180 : 1024);
        expect(exported[25]).toBe(2); // RGB without an alpha channel.
      }
    } finally { rmSync(fixture, { recursive: true, force: true }); }
  }, 35000);
});
