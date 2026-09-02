import { describe, expect, it, vi } from "vitest";

const functions = vi.hoisted(() => ({ invoke: vi.fn() }));

vi.mock("../../lib/supabase", () => ({
  supabase: { functions },
  supabaseConfigurationError: "Supabase is not configured."
}));

import { startStripeCheckout } from "./billing";

describe("startStripeCheckout", () => {
  it("surfaces the Edge Function's safe Stripe error", async () => {
    functions.invoke.mockResolvedValue({
      data: null,
      error: { context: { text: vi.fn().mockResolvedValue("Stripe could not create this subscription.") } }
    });

    await expect(startStripeCheckout("monthly", "/archive"))
      .rejects.toThrow("Stripe could not create this subscription.");
  });
});
