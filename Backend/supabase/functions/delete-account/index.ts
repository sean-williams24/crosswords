import { createClient } from "npm:@supabase/supabase-js@2";
import { stripeRequest } from "../_shared/stripe.ts";
import type { StripeSubscription } from "../_shared/stripeSubscription.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

type StripeSubscriptionSearchResult = { data?: StripeSubscription[] };
type StripeSubscriptionListResult = { data?: StripeSubscription[] };

function shouldCancelStripeSubscription(status: string) {
  return !["canceled", "incomplete_expired"].includes(status);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const authorization = request.headers.get("Authorization") ?? "";
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } }
  });
  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: stripeEntitlements, error: stripeError } = await admin
    .from("user_entitlements")
    .select("provider_subscription_id, provider_customer_id, status")
    .eq("user_id", user.id)
    .eq("provider", "stripe");
  if (stripeError) return new Response(stripeError.message, { status: 400, headers: corsHeaders });
  const { data: stripeCustomerAccounts, error: stripeCustomerError } = await admin
    .from("stripe_customer_accounts")
    .select("customer_id")
    .eq("user_id", user.id);
  if (stripeCustomerError) return new Response(stripeCustomerError.message, { status: 400, headers: corsHeaders });
  try {
    const customerIDs = new Set<string>();
    const subscriptions = new Map<string, string>();
    for (const entitlement of stripeEntitlements ?? []) {
      if (entitlement.provider_customer_id) customerIDs.add(entitlement.provider_customer_id);
      if (entitlement.status === "active" || entitlement.status === "billing_retry") {
        subscriptions.set(entitlement.provider_subscription_id, entitlement.status);
      }
    }
    for (const account of stripeCustomerAccounts ?? []) customerIDs.add(account.customer_id);

    // This direct listing is the primary cancellation path. Checkout stores
    // this customer link before redirecting, so it remains available even if
    // account deletion happens before Stripe's webhook or search index catches up.
    for (const customerID of customerIDs) {
      const customerSubscriptions = await stripeRequest<StripeSubscriptionListResult>("subscriptions", {
        method: "GET",
        params: { customer: customerID, status: "all", limit: 100 }
      });
      for (const subscription of customerSubscriptions.data ?? []) {
        subscriptions.set(subscription.id, subscription.status);
      }
    }

    // Accounts created before customer links existed still fall back to their
    // subscription metadata. Search is intentionally only a legacy fallback:
    // Stripe does not guarantee read-after-write consistency for this endpoint.
    const matches = await stripeRequest<StripeSubscriptionSearchResult>("subscriptions/search", {
      method: "GET",
      params: { query: `metadata['backword_user_id']:'${user.id}'`, limit: 100 }
    });
    for (const subscription of matches.data ?? []) {
      subscriptions.set(subscription.id, subscription.status);
      customerIDs.add(subscription.customer);
    }

    for (const [subscriptionID, status] of subscriptions) {
      if (shouldCancelStripeSubscription(status)) {
        await stripeRequest(`subscriptions/${subscriptionID}`, {
          params: { cancel_at_period_end: true, "metadata[backword_user_id]": "" }
        });
      }
    }
    for (const customerID of customerIDs) {
      await stripeRequest(`customers/${customerID}`, { params: { "metadata[backword_user_id]": "" } });
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Could not cancel the web subscription";
    console.error("Stripe cancellation during account deletion failed", { message });
    return new Response("Could not cancel the web subscription. Please try again.", { status: 503, headers: corsHeaders });
  }
  // Keep the Apple transaction record but remove its association; a verified
  // purchaser can claim it again after creating a new Backword account. Web
  // subscriptions are cancelled above and are never automatically re-linked.
  await admin
    .from("user_entitlements")
    .update({ user_id: null, app_account_token: null })
    .eq("user_id", user.id);
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) return new Response(error.message, { status: 400, headers: corsHeaders });
  return Response.json({ ok: true }, { headers: corsHeaders });
});
