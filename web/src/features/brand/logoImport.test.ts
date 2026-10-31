import { describe, expect, it } from "vitest";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const root = resolve(process.cwd(), "..");
const hash = (data: Buffer) => createHash("sha256").update(data).digest("hex");
function read(path: string) { return readFileSync(resolve(root, path)); }
function embeddedPNG(svg: string) {
  const data = svg.match(/href="data:image\/png;base64,([A-Za-z0-9+/=]+)"/)?.[1];
  if (!data) throw new Error("The supplied logo must be embedded without font substitution.");
  return Buffer.from(data, "base64");
}

describe("supplied logo import", () => {
  it("uses the current source files and preserves the PNG byte-for-byte in the web logo", () => {
    const manifest = JSON.parse(read("docs/intervls-brand/import-manifest.json").toString());
    for (const source of manifest.sources) {
      expect(hash(read(`docs/intervls-brand/${source.file}`))).toBe(source.sha256);
      const svg = read(`web/public/brand/intervls-${source.appearance}.svg`).toString();
      expect(hash(embeddedPNG(svg))).toBe(source.embedded_png_sha256);
      const element = new DOMParser().parseFromString(svg, "image/svg+xml").documentElement;
      expect(element.getAttribute("viewBox")?.split(/\s+/).map(Number)).toEqual([0, 0, manifest.canvas.width, manifest.canvas.height]);
      expect(source.crop.height).toBeLessThan(source.image_height);
      expect(source.crop.width / source.crop.height).toBeCloseTo(manifest.canvas.width / manifest.canvas.height, 1);
      expect(hash(read(`docs/intervls-brand/intervls-${source.appearance}.svg`))).toBe(hash(Buffer.from(svg)));
    }
    expect(embeddedPNG(read("web/public/brand/intervls-dark.svg").toString()).equals(read("docs/intervls-brand/intervls-dark2.png"))).toBe(true);
    expect(manifest.source_kind).toContain("supplied raster artwork");
  });

  it("binds both iOS appearances and the share logo to the imported masters", () => {
    const directory = "Backword/Resources/Assets.xcassets";
    const catalog = JSON.parse(read(`${directory}/IntervlsLogo.imageset/Contents.json`).toString());
    expect(catalog.images.find((image: { appearances?: unknown }) => !image.appearances).filename).toBe("intervls-light.pdf");
    expect(catalog.images.find((image: { appearances?: unknown }) => image.appearances).filename).toBe("intervls-dark.pdf");
    for (const appearance of ["light", "dark"]) {
      const master = read(`docs/intervls-brand/intervls-${appearance}.pdf`);
      expect(read(`${directory}/IntervlsLogo.imageset/intervls-${appearance}.pdf`).equals(master)).toBe(true);
      expect(master.toString("latin1")).toContain("/Subtype /Image");
    }
    expect(read(`${directory}/IntervlsLogoShare.imageset/intervls-dark.pdf`).equals(read("docs/intervls-brand/intervls-dark.pdf"))).toBe(true);
  });

  it.runIf(process.platform === "darwin")("regenerates from the supplied artwork without overwriting source or icon files", () => {
    const fixture = mkdtempSync(join(tmpdir(), "intervls-logo-import-"));
    const sources = ["docs/intervls-brand/intervls-light2.pdf", "docs/intervls-brand/intervls-dark2.png", "web/public/fonts/Outfit-Bold.ttf"];
    const protectedFiles = [
      "docs/intervls-brand/intervls-icon.png",
      "Backword/Resources/Assets.xcassets/AppIcon.appiconset/intervls-icon.png",
      "Backword/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
      "web/public/brand/intervls-icon.png", "web/public/brand/intervls-tab-icon.png", "web/public/apple-touch-icon.png"
    ];
    const sentinel = Buffer.from("The app icon is being supplied separately.");
    try {
      for (const path of sources) {
        mkdirSync(dirname(join(fixture, path)), { recursive: true });
        cpSync(resolve(root, path), join(fixture, path));
      }
      for (const path of protectedFiles) {
        mkdirSync(dirname(join(fixture, path)), { recursive: true });
        writeFileSync(join(fixture, path), sentinel);
      }
      execFileSync("/usr/bin/swift", [resolve(root, "docs/intervls-brand/render-brand.swift"), fixture], {
        env: { ...process.env, CLANG_MODULE_CACHE_PATH: join(tmpdir(), "intervls-logo-test-module-cache"), SWIFT_MODULECACHE_PATH: join(tmpdir(), "intervls-logo-test-module-cache") },
        timeout: 30000, stdio: "pipe"
      });
      for (const path of protectedFiles) expect(readFileSync(join(fixture, path)), path).toEqual(sentinel);
      for (const path of sources) expect(readFileSync(join(fixture, path)).equals(read(path)), path).toBe(true);
      const imported = readFileSync(join(fixture, "web/public/brand/intervls-dark.svg"), "utf8");
      expect(embeddedPNG(imported).equals(read("docs/intervls-brand/intervls-dark2.png"))).toBe(true);
      const wordmarks = [
        "docs/intervls-brand/intervls-light.pdf", "docs/intervls-brand/intervls-dark.pdf",
        "docs/intervls-brand/intervls-light.svg", "docs/intervls-brand/intervls-dark.svg",
        "docs/intervls-brand/import-manifest.json",
        "web/public/brand/intervls-light.svg", "web/public/brand/intervls-dark.svg",
        "Backword/Resources/Assets.xcassets/IntervlsLogo.imageset/intervls-light.pdf",
        "Backword/Resources/Assets.xcassets/IntervlsLogo.imageset/intervls-dark.pdf",
        "Backword/Resources/Assets.xcassets/IntervlsLogoShare.imageset/intervls-dark.pdf"
      ];
      const before = wordmarks.map((path) => readFileSync(join(fixture, path)));
      execFileSync("/usr/bin/swift", [resolve(root, "docs/intervls-brand/render-brand.swift"), fixture, "--promotional-only"], {
        env: { ...process.env, CLANG_MODULE_CACHE_PATH: join(tmpdir(), "intervls-logo-test-module-cache"), SWIFT_MODULECACHE_PATH: join(tmpdir(), "intervls-logo-test-module-cache") },
        timeout: 30000, stdio: "pipe"
      });
      wordmarks.forEach((path, index) => expect(readFileSync(join(fixture, path)).equals(before[index]), path).toBe(true));
      for (const path of protectedFiles) expect(readFileSync(join(fixture, path)), path).toEqual(sentinel);
    } finally { rmSync(fixture, { recursive: true, force: true }); }
  }, 35000);
});
