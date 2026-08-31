export type AnalyticsGame = "backword" | "daily_crossword" | "weekly_crossword";
export type AnalyticsPlatform = "web" | "ios";

export type AnalyticsEvent = {
  name:
    | "game_started"
    | "game_completed"
    | "app_store_click"
    | "sign_in_started"
    | "sign_in_succeeded"
    | "sign_in_failed"
    | "content_load_failed"
    | "pro_page_viewed"
    | "pro_plan_selected"
    | "pro_sign_in_required"
    | "stripe_checkout_started"
    | "stripe_checkout_start_failed"
    | "stripe_checkout_returned"
    | "pro_entitlement_activated"
    | "subscription_management_clicked"
    | "pro_access_gate_redirected";
  parameters: Record<string, string | number>;
};

export type ProEntryPoint = "direct" | "weekly_crossword" | "archive";
export type ProPlan = "monthly" | "annual";
export type CheckoutFailureReason = "configuration" | "network" | "provider";

export function scoreBand(score: number): string {
  if (score <= 0) return "0";
  if (score <= 2) return "1_2";
  if (score <= 4) return "3_4";
  return "5_plus";
}

export function durationBand(seconds: number | null): string {
  if (seconds === null || !Number.isFinite(seconds) || seconds < 0) return "unknown";
  if (seconds < 60) return "under_1m";
  if (seconds < 5 * 60) return "1_5m";
  if (seconds < 15 * 60) return "5_15m";
  if (seconds < 30 * 60) return "15_30m";
  return "30m_plus";
}

export function gameStarted(game: AnalyticsGame, platform: AnalyticsPlatform = "web"): AnalyticsEvent {
  return { name: "game_started", parameters: { game, platform } };
}

export function gameCompleted(
  game: AnalyticsGame,
  outcome: "won" | "failed" | "solved" | "gave_up",
  options: { mode?: "normal" | "easy"; releaseDay: boolean; score: number; durationSeconds: number | null; platform?: AnalyticsPlatform }
): AnalyticsEvent {
  const parameters: Record<string, string | number> = {
    game,
    platform: options.platform ?? "web",
    outcome,
    release_day: options.releaseDay ? "yes" : "no",
    score_band: scoreBand(options.score),
    duration_band: durationBand(options.durationSeconds)
  };
  if (options.mode) parameters.mode = options.mode;
  return { name: "game_completed", parameters };
}

export function appStoreClick(placement: "header" | "weekly_modal" | "footer", campaignToken: string | null): AnalyticsEvent {
  return {
    name: "app_store_click",
    parameters: { placement, campaign_token: campaignToken ?? "unattributed" }
  };
}

export function contentLoadFailed(game: AnalyticsGame, reason: "configuration" | "network" | "unavailable"): AnalyticsEvent {
  return { name: "content_load_failed", parameters: { game, reason } };
}

export function signInStarted(): AnalyticsEvent {
  return { name: "sign_in_started", parameters: {} };
}

export function signInSucceeded(): AnalyticsEvent {
  return { name: "sign_in_succeeded", parameters: {} };
}

export function signInFailed(): AnalyticsEvent {
  return { name: "sign_in_failed", parameters: { reason: "provider" } };
}

export function proPageViewed(entryPoint: ProEntryPoint): AnalyticsEvent {
  return { name: "pro_page_viewed", parameters: { entry_point: entryPoint } };
}

export function proPlanSelected(plan: ProPlan): AnalyticsEvent {
  return { name: "pro_plan_selected", parameters: { plan } };
}

export function proSignInRequired(entryPoint: ProEntryPoint): AnalyticsEvent {
  return { name: "pro_sign_in_required", parameters: { entry_point: entryPoint } };
}

export function stripeCheckoutStarted(plan: ProPlan, trialEligible: boolean): AnalyticsEvent {
  return { name: "stripe_checkout_started", parameters: { plan, trial_eligible: trialEligible ? "yes" : "no" } };
}

export function stripeCheckoutStartFailed(plan: ProPlan, reason: CheckoutFailureReason): AnalyticsEvent {
  return { name: "stripe_checkout_start_failed", parameters: { plan, reason } };
}

export function stripeCheckoutReturned(outcome: "success" | "cancelled"): AnalyticsEvent {
  return { name: "stripe_checkout_returned", parameters: { outcome } };
}

export function proEntitlementActivated(provider: "stripe"): AnalyticsEvent {
  return { name: "pro_entitlement_activated", parameters: { provider } };
}

export function subscriptionManagementClicked(provider: "stripe"): AnalyticsEvent {
  return { name: "subscription_management_clicked", parameters: { provider } };
}

export function proAccessGateRedirected(feature: "archive" | "weekly_crossword"): AnalyticsEvent {
  return { name: "pro_access_gate_redirected", parameters: { feature } };
}
