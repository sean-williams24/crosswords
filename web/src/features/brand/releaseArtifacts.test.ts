import { describe, expect, it } from "vitest";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { brand } from "./brand";
import { inflateSync } from "node:zlib";

const root = resolve(process.cwd(), "..");
function read(path: string) { return readFileSync(resolve(root, path)); }

// Decode the RGB PNG scanlines to check the exported pixels, including PNG filters.
function colorCount(png: Buffer, target: readonly number[]) {
  expect(png[24]).toBe(8);
  expect(png[25]).toBe(2);
  expect(png[28]).toBe(0);
  const width = png.readUInt32BE(16), height = png.readUInt32BE(20);
  const chunks: Buffer[] = [];
  for (let offset = 8; offset < png.length;) {
    const length = png.readUInt32BE(offset);
    if (png.toString("ascii", offset + 4, offset + 8) === "IDAT") chunks.push(png.subarray(offset + 8, offset + 8 + length));
    offset += length + 12;
  }
  const data = inflateSync(Buffer.concat(chunks));
  const stride = width * 3;
  let previous = Buffer.alloc(stride), count = 0;
  for (let y = 0; y < height; y++) {
    const start = y * (stride + 1), filter = data[start];
    const row = Buffer.alloc(stride);
    expect(filter).toBeLessThanOrEqual(4);
    for (let x = 0; x < stride; x++) {
      const left = x >= 3 ? row[x - 3] : 0, up = previous[x], corner = x >= 3 ? previous[x - 3] : 0;
      const prediction = left + up - corner;
      const dl = Math.abs(prediction - left), du = Math.abs(prediction - up), dc = Math.abs(prediction - corner);
      const paeth = dl <= du && dl <= dc ? left : du <= dc ? up : corner;
      const adjustment = [0, left, up, Math.floor((left + up) / 2), paeth][filter];
      row[x] = (data[start + 1 + x] + adjustment) & 255;
    }
    for (let x = 0; x < stride; x += 3) if (row[x] === target[0] && row[x + 1] === target[1] && row[x + 2] === target[2]) count++;
    previous = row;
  }
  return count;
}

describe("Intervls release artifacts", () => {
  it.each([
    "docs/intervls-brand/social-cover-1640x624.png",
    "web/public/brand/intervls-social-preview.png",
    "docs/intervls-brand/app-store-header-3840x1646.png",
    "docs/intervls-brand/app-store-header-5244x2950.png"
  ])("uses the Backword dark Home-card blue in %s", (path) => {
    expect(colorCount(read(path), [41, 51, 100])).toBeGreaterThan(500);
  });
  it("keeps the approved marketing line in launch copy and the artwork renderer", () => {
    const metadata = JSON.parse(read("docs/intervls-rebrand/app-store-metadata.en-GB.json").toString());
    expect(metadata.subtitle).toBe("Free daily word games");
    expect(metadata.description).toMatch(new RegExp(`^${brand.tagline}`));
    for (const path of ["docs/intervls-rebrand/social-and-support-copy.md", "docs/intervls-rebrand/capture-manifest.json", "docs/intervls-brand/render-brand.swift"]) {
      const copy = read(path).toString();
      expect(copy).toContain(brand.tagline);
      expect(copy).not.toMatch(/daily (?:word game )?ritual/i);
    }
  });
  it("supplies store copy within Apple's field limits and retains purchase identity", () => {
    const metadata = JSON.parse(read("docs/intervls-rebrand/app-store-metadata.en-GB.json").toString());
    expect(metadata.name).toBe(brand.name);
    expect(metadata.subscription_group_display_name).toBe(brand.proName);
    expect(metadata.subscriptions.map((item: { display_name: string }) => item.display_name)).toEqual(["Intervls Pro Monthly", "Intervls Pro Annual"]);
    for (const [key, max] of [["name", 30], ["subtitle", 30], ["promotional_text", 170], ["keywords", 100], ["description", 4000], ["whats_new", 4000]] as const) {
      expect(metadata[key].length, key).toBeLessThanOrEqual(max);
      expect(metadata[key].length, key).toBeGreaterThan(0);
    }
    expect(metadata.bundle_id).toBe("com.backword.app");
    expect(metadata.app_store_id).toBe("6773428497");
    expect(metadata.release_option).toBe("MANUAL");
    expect(metadata.subscriptions.map((item: { product_id: string }) => item.product_id)).toEqual(["com.backword.monthlypro", "com.backword.annualpro"]);
    expect(metadata.support_email).toBe("support@intervls.com");
    expect(metadata.description).toContain("Backword: guess");
    expect(metadata.description).toContain("Midword: find");
  });
  it.each([
    ["Backword/Resources/Assets.xcassets/AppIcon.appiconset/intervls-icon.png", 1024, 1024],
    ["web/public/brand/intervls-icon.png", 1024, 1024],
    ["web/public/apple-touch-icon.png", 180, 180],
    ["docs/intervls-brand/social-cover-1640x624.png", 1640, 624],
    ["web/public/brand/intervls-social-preview.png", 1200, 630],
    ["docs/intervls-brand/app-store-header-3840x1646.png", 3840, 1646],
    ["docs/intervls-brand/app-store-header-5244x2950.png", 5244, 2950],
    ["docs/intervls-brand/app-store-search-3840x2560.png", 3840, 2560]
  ])("exports %s at its declared dimensions with no alpha channel", (path, width, height) => {
    const png = read(path);
    expect(png.subarray(1, 4).toString()).toBe("PNG");
    expect(png.readUInt32BE(16)).toBe(width);
    expect(png.readUInt32BE(20)).toBe(height);
    expect(png[25]).toBe(2); // Truecolour RGB, without an alpha channel.
  });
  it("keeps fresh captures explicitly pending and leaves historical exports intact", () => {
    const manifest = JSON.parse(read("docs/intervls-rebrand/capture-manifest.json").toString());
    expect(manifest.status).toBe("blocked_on_developer_captures");
    expect(manifest.screenshots).toHaveLength(9);
    expect(manifest.screenshots.every((image: { status: string }) => image.status === "awaiting_fresh_capture")).toBe(true);
  });
  it("uses matching current app icons on iOS and the web and preserves the earlier draft", () => {
    const directory = "Backword/Resources/Assets.xcassets/AppIcon.appiconset";
    const catalog = JSON.parse(read(`${directory}/Contents.json`).toString());
    expect(catalog.images).toEqual([{ filename: "intervls-icon.png", idiom: "universal", platform: "ios", size: "1024x1024" }]);
    const installed = read(`${directory}/${catalog.images[0].filename}`);
    expect(installed.equals(read("web/public/brand/intervls-icon.png"))).toBe(true);
    expect(installed.equals(read("docs/intervls-brand/intervls-icon-draft.png"))).toBe(false);
    const original = read("docs/intervls-brand/intervls-icon.png");
    expect(original.readUInt32BE(16)).toBe(1024);
    expect(original.readUInt32BE(20)).toBe(1024);
  });
  it("uses the supplied browser-tab artwork as the favicon", () => {
    const html = new DOMParser().parseFromString(read("web/index.html").toString(), "text/html");
    const favicon = html.querySelector('link[rel="icon"]');
    expect(favicon?.getAttribute("href")).toBe("/brand/intervls-tab-icon.png");
    expect(favicon?.getAttribute("type")).toBe("image/png");
    const installed = read(`web/public${favicon?.getAttribute("href")}`);
    expect(installed.equals(read("docs/intervls-brand/Web tab icon.png"))).toBe(true);
    expect(favicon?.getAttribute("sizes")).toBe(`${installed.readUInt32BE(16)}x${installed.readUInt32BE(20)}`);
  });
  it.runIf(process.platform === "darwin")("uses a 180px export of the supplied Intervls icon for Apple Home Screen shortcuts", () => {
    const html = new DOMParser().parseFromString(read("web/index.html").toString(), "text/html");
    const icon = html.querySelector('link[rel="apple-touch-icon"]');
    expect(icon?.getAttribute("href")).toBe("/apple-touch-icon.png");
    expect(icon?.getAttribute("sizes")).toBe("180x180");
    const fixture = mkdtempSync(join(tmpdir(), "intervls-touch-icon-"));
    try {
      const expected = join(fixture, "apple-touch-icon.png");
      execFileSync("/usr/bin/sips", ["-z", "180", "180", resolve(root, "web/public/brand/intervls-icon.png"), "--out", expected], { stdio: "pipe" });
      expect(read(`web/public${icon?.getAttribute("href")}`).equals(readFileSync(expected))).toBe(true);
    } finally { rmSync(fixture, { recursive: true, force: true }); }
  });
  it("ships self-contained supplied wordmarks and keeps the old game asset", () => {
    for (const appearance of ["light", "dark"]) {
      const svg = read(`web/public/brand/intervls-${appearance}.svg`).toString();
      const document = new DOMParser().parseFromString(svg, "image/svg+xml");
      expect(document.documentElement.getAttribute("aria-label")).toBe("Intervls");
      expect(document.querySelector("image")?.getAttribute("href")?.startsWith("data:image/png;base64,")).toBe(true);
      expect(document.querySelector("text")).toBeNull();
      expect(document.querySelector("path")).toBeNull();
    }
    const catalog = JSON.parse(read("Backword/Resources/Assets.xcassets/IntervlsLogo.imageset/Contents.json").toString());
    expect(catalog.images).toHaveLength(2);
    expect(catalog.properties["preserves-vector-representation"]).toBe(true);
    expect(read("web/public/brand/backword-logo.png").length).toBeGreaterThan(0);
  });
});
