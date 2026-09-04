import { createClient } from "npm:@supabase/supabase-js@2";
import { stripeRequest } from "../_shared/stripe.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("WEB_ORIGIN") ?? "",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

// Managed Payments is currently exposed by Stripe through this preview API
// version. Keep it scoped to Checkout so normal subscription reads and account
// deletion remain on the account's default stable API version.
const managedPaymentsAPIVersion = "2026-03-04.preview";

type CheckoutRequest = { plan?: "monthly" | "annual"; returnPath?: string };
type StripeCustomer = { id: string };
type StripeCheckoutSession = { url: string | null };

function response(message: string, status: number) {
  return new Response(message, { status, headers: corsHeaders });
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "We couldn't start secure checkout. Please try again.";
}

function safeReturnPath(path: string | undefined) {
  return path?.startsWith("/") && !path.startsWith("//") ? path : "/";
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response("Method not allowed", 405);

  try {
    const supabaseURL = Deno.env.get("SUPABASE_URL")!;
    const caller = createClient(supabaseURL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: request.headers.get("Authorization") ?? "" } }
    });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return response("Unauthorized", 401);

    const body = await request.json().catch(() => null) as CheckoutRequest | null;
    if (body?.plan !== "monthly" && body?.plan !== "annual") return response("Invalid subscription plan", 400);
    const priceID = body.plan === "monthly" ? Deno.env.get("STRIPE_MONTHLY_PRICE_ID") : Deno.env.get("STRIPE_ANNUAL_PRICE_ID");
    const webOrigin = Deno.env.get("WEB_ORIGIN");
    if (!priceID || !webOrigin) return response("Web subscriptions are not configured.", 503);

    const { data: entitlement, error: entitlementError } = await caller.rpc("current_user_pro_entitlement");
    if (entitlementError) return response("Could not check Pro access", 503);
    const activeEntitlement = Array.isArray(entitlement) ? entitlement[0] : entitlement;
    if (activeEntitlement?.is_pro) return response("This account already has Pro access.", 409);

    const admin = createClient(supabaseURL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: existingStripeEntitlement } = await admin
      .from("user_entitlements")
      .select("provider_customer_id")
      .eq("user_id", user.id)
      .eq("provider", "stripe")
      .not("provider_customer_id", "is", null)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    const customerID = existingStripeEntitlement?.provider_customer_id
      ?? (await stripeRequest<StripeCustomer>("customers", {
        params: {
          email: user.email ?? undefined,
          "metadata[backword_user_id]": user.id
        },
        idempotencyKey: `backword-customer:${user.id}`
      })).id;
    const { error: customerLinkError } = await admin
      .from("stripe_customer_accounts")
      .upsert({ user_id: user.id, customer_id: customerID }, { onConflict: "user_id" });
    if (customerLinkError) return response("Could not prepare your subscription. Please try again.", 503);

    const { data: trial } = await admin
      .from("pro_trial_redemptions")
      .select("user_id")
      .eq("user_id", user.id)
      .maybeSingle();
    const returnPath = safeReturnPath(body.returnPath);
    const session = await stripeRequest<StripeCheckoutSession>("checkout/sessions", {
      params: {
        mode: "subscription",
        customer: customerID,
        "line_items[0][price]": priceID,
        "line_items[0][quantity]": 1,
        billing_address_collection: "required",
        "managed_payments[enabled]": true,
        allow_promotion_codes: false,
        client_reference_id: user.id,
        "metadata[backword_user_id]": user.id,
        "subscription_data[metadata][backword_user_id]": user.id,
        ...(trial ? {} : { "subscription_data[trial_period_days]": 7 }),
        success_url: `${webOrigin}/pro?checkout=success&return_to=${encodeURIComponent(returnPath)}`,
        cancel_url: `${webOrigin}/pro?checkout=cancelled&return_to=${encodeURIComponent(returnPath)}`
      },
      apiVersion: managedPaymentsAPIVersion,
      // A key must cover only one purchase attempt. Reusing a completed Checkout
      // Session prevents a cancelled subscriber from subscribing again.
      idempotencyKey: `backword-checkout:${user.id}:${crypto.randomUUID()}`
    });
    if (!session.url) return response("Could not start checkout", 502);
    return Response.json({ url: session.url }, { headers: corsHeaders });
  } catch (error) {
    const message = errorMessage(error);
    console.error("Stripe checkout creation failed", { message });
    return response(message, 502);
  }
});
