import { supabase, supabaseConfigurationError } from "../../lib/supabase";

export type ProPlan = "monthly" | "annual";

type CheckoutResponse = { url?: string };

async function functionError(error: unknown, fallback: string) {
  if (error && typeof error === "object" && "context" in error) {
    const context = error.context;
    if (context && typeof context === "object" && "text" in context && typeof context.text === "function") {
      const message = await context.text();
      if (message) return message;
    }
  }
  if (error && typeof error === "object" && "message" in error && typeof error.message === "string") return error.message;
  return fallback;
}

export async function startStripeCheckout(plan: ProPlan, returnPath: string) {
  if (!supabase) throw new Error(supabaseConfigurationError);
  const { data, error } = await supabase.functions.invoke<CheckoutResponse>("create-stripe-checkout", {
    body: { plan, returnPath }
  });
  if (error || !data?.url) throw new Error(await functionError(error, "We couldn't start secure checkout. Please try again."));
  window.location.assign(data.url);
}
