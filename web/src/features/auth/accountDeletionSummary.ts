export type AccountDeletionSummary = {
  hasApplePurchase: boolean;
  hasStripeSubscription: boolean;
};

export function accountDeletionSummaryFromResponse(data: unknown): AccountDeletionSummary {
  const response = data as { deletion_summary?: { has_apple_purchase?: unknown; has_stripe_subscription?: unknown } } | null;
  return {
    hasApplePurchase: response?.deletion_summary?.has_apple_purchase === true,
    hasStripeSubscription: response?.deletion_summary?.has_stripe_subscription === true
  };
}
