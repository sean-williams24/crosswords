import { supabase, supabaseConfigurationError } from "../../lib/supabase";

export type ProPlan = "monthly" | "annual";

type CheckoutResponse = { url?: string };
type PortalResponse = { url?: string };

function functionError(error: unknown, fallback: string) {
  if (error && typeof error === "object" && "message" in error && typeof error.message === "string") return error.message;
  return fallback;
}

export async function startStripeCheckout(plan: ProPlan, returnPath: string) {
  if (!supabase) throw new Error(supabaseConfigurationError);
  const { data, error } = await supabase.functions.invoke<CheckoutResponse>("create-stripe-checkout", {
    body: { plan, returnPath }
  });
  if (error || !data?.url) throw new Error(functionError(error, "We couldn't start secure checkout. Please try again."));
  window.location.assign(data.url);
}

export async function openStripeBillingPortal() {
  if (!supabase) throw new Error(supabaseConfigurationError);
  const { data, error } = await supabase.functions.invoke<PortalResponse>("create-stripe-portal");
  if (error || !data?.url) throw new Error(functionError(error, "We couldn't open subscription management. Please try again."));
  window.location.assign(data.url);
}
