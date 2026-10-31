import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { brand, isLegacyOrigin, migrationDestination } from "./brand";
import { routeMetadata } from "./SiteMetadata";
import { siteConfig } from "../../lib/siteConfig";

describe("intervls URLs and release protection", () => {
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
  it("preserves dated game links and campaign attribution without copying authentication", () => {
    expect(migrationDestination("/backword/2026-10-29?utm_source=share&code=secret&access_token=token#refresh_token=token"))
      .toBe("https://intervls.com/backword/2026-10-29?utm_source=share");
    for (const path of ["https://evil.example", "//evil.example", "/\\evil.example", "/auth/callback?code=secret", "/unknown", "/%2e%2e//evil.example"]) {
      expect(migrationDestination(path)).toBe("https://intervls.com/");
    }
    expect(migrationDestination("/pro?return_to=%2Farchive")).toBe("https://intervls.com/pro?return_to=%2Farchive");
    expect(migrationDestination("/pro?return_to=https%3A%2F%2Fevil.example")).toBe("https://intervls.com/pro");
    expect(isLegacyOrigin("https://www.playbackword.com")).toBe(true);
    expect(isLegacyOrigin("https://playbackword.com")).toBe(true);
    expect(isLegacyOrigin(brand.origin)).toBe(false);
  });
  it("keeps previews, the legacy bridge, and account pages out of search", () => {
    expect(routeMetadata("/", brand.origin, false).robots).toBe("noindex,follow");
    expect(routeMetadata("/", "https://preview.vercel.app", true).robots).toBe("noindex,follow");
    expect(routeMetadata("/", brand.legacyOrigins[0], true).robots).toBe("noindex,follow");
    expect(routeMetadata("/player-profile", brand.origin, true).robots).toBe("noindex,follow");
    expect(routeMetadata("/backword/2026-10-29", brand.origin, true)).toMatchObject({ title: "Backword | intervls", robots: "index,follow", canonical: "https://intervls.com/backword/2026-10-29" });
  });
  it("uses the existing App Store listing and the confirmed support inbox", () => {
    expect(siteConfig.appName).toBe("intervls");
    expect(siteConfig.appStoreUrl).toBe("https://apps.apple.com/app/id6773428497");
    expect(siteConfig.supportEmail).toBe("support@intervls.com");
  });
  it("never server-redirects an old save, callback, or dependency URL", () => {
    const config = JSON.parse(readFileSync(resolve(process.cwd(), "vercel.json"), "utf8"));
    const oldRedirects = config.redirects.filter((rule: { has: { value: string }[] }) => rule.has.some((condition) => condition.value.includes("playbackword")));
    const allowed = ["/info", "/contact", "/privacy", "/privacy-choices", "/privacy-choice", "/terms"];
    expect(oldRedirects).toHaveLength(12);
    expect(oldRedirects.every((rule: { source: string }) => allowed.includes(rule.source))).toBe(true);
    expect(config.redirects.find((rule: { source: string }) => rule.source === "/:path*").has).toEqual([{ type: "host", value: "www.intervls.com" }]);
  });
});
