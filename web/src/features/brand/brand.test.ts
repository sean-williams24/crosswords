import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { brand, isLegacyOrigin } from "./brand";
import { routeMetadata } from "./SiteMetadata";
import { siteConfig } from "../../lib/siteConfig";

describe("Intervls URLs and release protection", () => {
  it("capitalizes the app and Pro display names, including social metadata and page titles", () => {
    expect(brand.name).toBe("Intervls");
    expect(brand.proName).toBe("Intervls Pro");
    const html = new DOMParser().parseFromString(readFileSync(resolve(process.cwd(), "index.html"), "utf8"), "text/html");
    expect(html.querySelector('meta[property="og:site_name"]')?.getAttribute("content")).toBe(brand.name);
    expect(routeMetadata("/pro", brand.origin, true).title).toBe("Intervls Pro | Intervls");
    expect(routeMetadata("/unknown", brand.origin, true).title).toBe("Intervls");
  });
  it("uses the approved Home title and marketing line before and after hydration", () => {
    const html = new DOMParser().parseFromString(readFileSync(resolve(process.cwd(), "index.html"), "utf8"), "text/html");
    expect(brand.homeTitle).toBe("Intervls — Free daily word games");
    expect(siteConfig.tagline).toBe("Free daily word games to challenge your mind");
    expect(html.title).toBe(brand.homeTitle);
    const metadata = routeMetadata("/", brand.origin, true);
    expect(metadata.title).toBe(html.title);
    expect(html.querySelector('meta[property="og:title"]')?.getAttribute("content")).toBe(metadata.socialTitle);
    for (const selector of ['meta[name="description"]', 'meta[property="og:description"]']) {
      expect(html.querySelector(selector)?.getAttribute("content")).toContain(siteConfig.tagline);
    }
  });
  it("recognizes both historical origins without treating Intervls as legacy", () => {
    expect(isLegacyOrigin("https://www.playbackword.com")).toBe(true);
    expect(isLegacyOrigin("https://playbackword.com")).toBe(true);
    expect(isLegacyOrigin(brand.origin)).toBe(false);
  });
  it("keeps previews, legacy origins, and account pages out of search", () => {
    expect(routeMetadata("/", brand.origin, false).robots).toBe("noindex,follow");
    expect(routeMetadata("/", "https://preview.vercel.app", true).robots).toBe("noindex,follow");
    expect(routeMetadata("/", brand.legacyOrigins[0], true).robots).toBe("noindex,follow");
    expect(routeMetadata("/player-profile", brand.origin, true).robots).toBe("noindex,follow");
    expect(routeMetadata("/backword/2026-10-29", brand.origin, true)).toMatchObject({ title: "Backword | Intervls", robots: "index,follow", canonical: "https://intervls.com/backword/2026-10-29" });
  });
  it("uses the existing App Store listing and the confirmed support inbox", () => {
    expect(siteConfig.appName).toBe("Intervls");
    expect(siteConfig.appStoreUrl).toBe("https://apps.apple.com/app/id6773428497");
    expect(siteConfig.supportEmail).toBe("support@intervls.com");
  });
  it.each([
    "Backword/Models/FeedbackEmailContent.swift",
    "CONVENTIONS.md",
    "docs/intervls-rebrand/README.md",
    "docs/intervls-rebrand/app-store-metadata.en-GB.json",
    "docs/intervls-rebrand/social-and-support-copy.md"
  ])("uses the confirmed support inbox consistently in %s", (path) => {
    const content = readFileSync(resolve(process.cwd(), "..", path), "utf8");
    const addresses = content.match(/[\w.%+-]+@[\w.-]+\.[a-z]{2,}/gi) ?? [];

    expect(addresses.length).toBeGreaterThan(0);
    expect([...new Set(addresses)]).toEqual([siteConfig.supportEmail]);
  });
  it("keeps the new-domain canonical redirect ready while old-domain redirects wait for launch settings", () => {
    const config = JSON.parse(readFileSync(resolve(process.cwd(), "vercel.json"), "utf8"));
    expect(config.redirects).toEqual([{
      source: "/:path*",
      has: [{ type: "host", value: "www.intervls.com" }],
      destination: "https://intervls.com/:path*",
      permanent: true
    }]);
    expect(config.rewrites).toEqual([{ source: "/(.*)", destination: "/index.html" }]);
  });
});
