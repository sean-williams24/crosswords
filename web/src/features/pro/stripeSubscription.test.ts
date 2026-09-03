import { describe, expect, it } from "vitest";
import { subscriptionExpiryUnixSeconds } from "../../../../Backend/supabase/functions/_shared/stripeSubscription.ts";

describe("subscriptionExpiryUnixSeconds", () => {
  it("uses the item-level period end returned by current Stripe API versions", () => {
    expect(subscriptionExpiryUnixSeconds({
      id: "sub_123",
      customer: "cus_123",
      status: "active",
      cancel_at_period_end: true,
      items: { data: [{ current_period_end: 1_788_825_600, price: { id: "price_123" } }] }
    })).toBe(1_788_825_600);
  });

  it("uses Stripe's explicit cancellation time when one is set", () => {
    expect(subscriptionExpiryUnixSeconds({
      id: "sub_123",
      customer: "cus_123",
      status: "active",
      cancel_at: 1_788_825_600,
      items: { data: [{ current_period_end: 1_788_912_000 }] }
    })).toBe(1_788_825_600);
  });

  it("keeps compatibility with legacy subscription-level period ends", () => {
    expect(subscriptionExpiryUnixSeconds({
      id: "sub_123",
      customer: "cus_123",
      status: "active",
      current_period_end: 1_788_825_600
    })).toBe(1_788_825_600);
  });
});
