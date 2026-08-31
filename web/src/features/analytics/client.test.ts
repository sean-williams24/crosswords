import { describe, expect, it } from "vitest";
import { analyticsClient, analyticsIsConfigured, sendAnalyticsEvent } from "./client";

describe("analytics client", () => {
  it("does nothing safely when production analytics configuration is absent", async () => {
    expect(analyticsIsConfigured()).toBe(false);
    await expect(analyticsClient()).resolves.toBeNull();
    await expect(sendAnalyticsEvent({ name: "sign_in_started", parameters: {} })).resolves.toBeUndefined();
  });
});
