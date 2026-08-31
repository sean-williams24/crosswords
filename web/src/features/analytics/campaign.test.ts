import { describe, expect, it } from "vitest";
import {
  appStoreCampaignUrl,
  campaignContextFromUrl,
  campaignContextLifetimeMs,
  captureFirstCampaignContext,
  readCampaignContext,
  resolveAppleCampaignToken
} from "./campaign";

describe("campaign attribution", () => {
  it("captures normalised complete UTM context once", () => {
    const storage = window.localStorage;
    storage.clear();
    const first = captureFirstCampaignContext(
      storage,
      new URL("https://www.playbackword.com/?utm_source=TikTok&utm_medium=organic_social&utm_campaign=Launch&utm_content=video_a"),
      1_000
    );
    const second = captureFirstCampaignContext(
      storage,
      new URL("https://www.playbackword.com/?utm_source=instagram&utm_medium=organic_social&utm_campaign=other"),
      2_000
    );

    expect(first).toMatchObject({ source: "tiktok", medium: "organic_social", campaign: "launch", content: "video_a" });
    expect(second).toEqual(first);
  });

  it("expires campaign context after ninety days and rejects incomplete tags", () => {
    const storage = window.localStorage;
    storage.clear();
    expect(campaignContextFromUrl(new URL("https://www.playbackword.com/?utm_source=tiktok"))).toBeNull();
    captureFirstCampaignContext(
      storage,
      new URL("https://www.playbackword.com/?utm_source=tiktok&utm_medium=organic_social&utm_campaign=launch"),
      1_000
    );

    expect(readCampaignContext(storage, 1_000 + campaignContextLifetimeMs + 1)).toBeNull();
  });

  it("uses the most-specific configured Apple campaign token with a safe fallback", () => {
    const context = campaignContextFromUrl(new URL("https://www.playbackword.com/?utm_source=tiktok&utm_medium=organic_social&utm_campaign=launch"), 1);
    const token = resolveAppleCampaignToken(context, { default: "web_default", tiktok: "tiktok_all", "tiktok:launch": "tiktok_launch" });

    expect(token).toBe("tiktok_launch");
    expect(resolveAppleCampaignToken(null, { default: "web_default" })).toBe("web_default");
    expect(appStoreCampaignUrl("https://apps.apple.com/app/backword/id6773428497", "123", token)).toContain("pt=123");
    expect(appStoreCampaignUrl("https://apps.apple.com/app/backword/id6773428497", "", token)).toBe("https://apps.apple.com/app/backword/id6773428497");
  });
});
