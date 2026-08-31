import { describe, expect, it } from "vitest";
import {
  appStoreClick,
  contentLoadFailed,
  durationBand,
  gameCompleted,
  gameStarted,
  proAccessGateRedirected,
  proEntitlementActivated,
  proPageViewed,
  proPlanSelected,
  proSignInRequired,
  scoreBand,
  stripeCheckoutReturned,
  stripeCheckoutStarted,
  stripeCheckoutStartFailed,
  subscriptionManagementClicked
} from "./events";

describe("analytics event schema", () => {
  it("uses aggregate game dimensions and never gameplay content", () => {
    const started = gameStarted("backword");
    const completed = gameCompleted("daily_crossword", "solved", {
      releaseDay: true,
      score: 4,
      durationSeconds: 300
    });

    expect(started).toEqual({ name: "game_started", parameters: { game: "backword", platform: "web" } });
    expect(completed.parameters).toEqual({
      game: "daily_crossword",
      platform: "web",
      outcome: "solved",
      release_day: "yes",
      score_band: "3_4",
      duration_band: "5_15m"
    });
    expect(JSON.stringify(completed)).not.toContain("answer");
    expect(JSON.stringify(completed)).not.toContain("guess");
    expect(JSON.stringify(completed)).not.toContain("clue");
  });

  it("uses stable, low-cardinality bands for score, duration, and failures", () => {
    expect(scoreBand(0)).toBe("0");
    expect(scoreBand(5)).toBe("5_plus");
    expect(durationBand(null)).toBe("unknown");
    expect(durationBand(59)).toBe("under_1m");
    expect(durationBand(1_800)).toBe("30m_plus");
    expect(appStoreClick("footer", null).parameters).toEqual({ placement: "footer", campaign_token: "unattributed" });
    expect(contentLoadFailed("backword", "network").parameters).toEqual({ game: "backword", reason: "network" });
  });

  it("uses a small, identifier-free schema for the Pro subscription funnel", () => {
    const events = [
      proPageViewed("weekly_crossword"),
      proPlanSelected("annual"),
      proSignInRequired("archive"),
      stripeCheckoutStarted("annual", true),
      stripeCheckoutStartFailed("monthly", "network"),
      stripeCheckoutReturned("success"),
      proEntitlementActivated("stripe"),
      subscriptionManagementClicked("stripe"),
      proAccessGateRedirected("weekly_crossword")
    ];

    expect(events).toEqual([
      { name: "pro_page_viewed", parameters: { entry_point: "weekly_crossword" } },
      { name: "pro_plan_selected", parameters: { plan: "annual" } },
      { name: "pro_sign_in_required", parameters: { entry_point: "archive" } },
      { name: "stripe_checkout_started", parameters: { plan: "annual", trial_eligible: "yes" } },
      { name: "stripe_checkout_start_failed", parameters: { plan: "monthly", reason: "network" } },
      { name: "stripe_checkout_returned", parameters: { outcome: "success" } },
      { name: "pro_entitlement_activated", parameters: { provider: "stripe" } },
      { name: "subscription_management_clicked", parameters: { provider: "stripe" } },
      { name: "pro_access_gate_redirected", parameters: { feature: "weekly_crossword" } }
    ]);
    expect(JSON.stringify(events)).not.toMatch(/customer|checkout_id|email|payment|return_to/i);
  });
});
