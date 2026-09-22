export type ProEntitlement = {
  isPro: boolean;
  expiresAt: string | null;
  provider: "apple" | "stripe" | null;
  cancelAtPeriodEnd: boolean;
  hasUsedTrial: boolean;
};

export const noProEntitlement: ProEntitlement = {
  isPro: false,
  expiresAt: null,
  provider: null,
  cancelAtPeriodEnd: false,
  hasUsedTrial: false
};
