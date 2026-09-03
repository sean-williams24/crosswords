export type StripeSubscription = {
  id: string;
  customer: string;
  status: string;
  // Present on pre-Basil Stripe API responses only. Newer responses expose
  // billing periods on subscription items.
  current_period_end?: number;
  cancel_at?: number | null;
  cancel_at_period_end?: boolean;
  metadata?: Record<string, string | undefined>;
  items?: {
    data?: Array<{
      current_period_end?: number;
      price?: { id?: string };
    }>;
  };
};

export function subscriptionExpiryUnixSeconds(subscription: StripeSubscription) {
  if (typeof subscription.cancel_at === "number") return subscription.cancel_at;

  const itemPeriodEnds = subscription.items?.data
    ?.map((item) => item.current_period_end)
    .filter((periodEnd): periodEnd is number => typeof periodEnd === "number");

  // A subscription using mixed intervals ends at the earliest item period end
  // when Stripe's standard cancel-at-period-end behaviour is used.
  return itemPeriodEnds?.length
    ? Math.min(...itemPeriodEnds)
    : subscription.current_period_end;
}
