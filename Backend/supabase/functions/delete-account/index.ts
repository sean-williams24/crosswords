import { createClient } from "npm:@supabase/supabase-js@2";
import { stripeRequest } from "../_shared/stripe.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

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
  try {
    const customerIDs = new Set<string>();
    for (const entitlement of stripeEntitlements ?? []) {
      if (entitlement.provider_customer_id) customerIDs.add(entitlement.provider_customer_id);
      if (entitlement.status === "active" || entitlement.status === "billing_retry") {
        await stripeRequest(`subscriptions/${entitlement.provider_subscription_id}`, {
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
