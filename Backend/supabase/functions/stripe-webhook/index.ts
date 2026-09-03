import { createClient } from "npm:@supabase/supabase-js@2";
import { stripeISODate, stripeRequest, verifyStripeWebhook } from "../_shared/stripe.ts";
import { subscriptionExpiryUnixSeconds, type StripeSubscription } from "../_shared/stripeSubscription.ts";

type StripeSubscriptionEventObject = StripeSubscription & { object?: string };

type StripeEvent = {
  id: string;
  type: string;
  created: number;
  data: { object: StripeSubscriptionEventObject | { subscription?: string } };
};

function entitlementStatus(status: string) {
  if (status === "active" || status === "trialing") return "active";
  if (status === "past_due") return "billing_retry";
  return "expired";
}

function errorContext(error: unknown) {
  if (error instanceof Error) return { message: error.message };
  if (typeof error === "object" && error !== null) {
    const value = error as Record<string, unknown>;
    return {
      code: typeof value.code === "string" ? value.code : undefined,
      details: typeof value.details === "string" ? value.details : undefined,
      hint: typeof value.hint === "string" ? value.hint : undefined,
      message: typeof value.message === "string" ? value.message : "Could not process Stripe notification"
    };
  }
  return { message: "Could not process Stripe notification" };
}

async function subscriptionFor(event: StripeEvent) {
  const object = event.data.object as StripeSubscriptionEventObject;
  if (object.object === "subscription") return object;
  const subscriptionID = (object as { subscription?: string }).subscription;
  if (!subscriptionID) return null;
  return stripeRequest<StripeSubscription>(`subscriptions/${subscriptionID}`, { method: "GET" });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const rawBody = await request.text();
  if (!await verifyStripeWebhook(rawBody, request.headers.get("stripe-signature"))) {
    return new Response("Invalid Stripe signature", { status: 401 });
  }

  try {
    const event = JSON.parse(rawBody) as StripeEvent;
    const supportedEvents = new Set([
      "checkout.session.completed",
      "customer.subscription.created",
      "customer.subscription.updated",
      "customer.subscription.deleted",
      "invoice.paid",
      "invoice.payment_failed"
    ]);
    if (!event.id || !supportedEvents.has(event.type)) return Response.json({ ok: true });

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: alreadyProcessed } = await admin
      .from("stripe_webhook_events")
      .select("event_id")
      .eq("event_id", event.id)
      .maybeSingle();
    if (alreadyProcessed) return Response.json({ ok: true });

    const subscription = await subscriptionFor(event);
    if (!subscription) return Response.json({ ok: true });
    const userID = subscription.metadata?.backword_user_id;
    if (!userID) {
      console.error("Stripe subscription has no Backword account association", { eventType: event.type });
      // Account deletion deliberately removes this metadata. Acknowledge it so
      // Stripe does not retry an event that cannot unlock any Backword account.
      return Response.json({ ok: true });
    }

    const eventAt = stripeISODate(event.created)!;
    const { data: existing } = await admin
      .from("user_entitlements")
      .select("source_event_at")
      .eq("provider", "stripe")
      .eq("provider_subscription_id", subscription.id)
      .maybeSingle();
    if (!existing?.source_event_at || new Date(existing.source_event_at) <= new Date(eventAt)) {
      const { error } = await admin.from("user_entitlements").upsert({
        provider: "stripe",
        provider_subscription_id: subscription.id,
        provider_customer_id: subscription.customer,
        user_id: userID,
        product_id: subscription.items?.data?.[0]?.price?.id ?? "stripe_pro",
        status: entitlementStatus(subscription.status),
        expires_at: stripeISODate(subscriptionExpiryUnixSeconds(subscription)),
        cancel_at_period_end: subscription.cancel_at_period_end ?? false,
        source_event_at: eventAt,
        updated_at: new Date().toISOString()
      }, { onConflict: "provider,provider_subscription_id" });
      if (error) throw error;
    }

    if (subscription.status === "trialing") {
      const { error: trialError } = await admin.from("pro_trial_redemptions").upsert({
        user_id: userID,
        provider: "stripe",
        redeemed_at: eventAt
      }, { onConflict: "user_id", ignoreDuplicates: true });
      if (trialError) throw trialError;
    }
    const { error: auditError } = await admin.from("stripe_webhook_events").insert({
      event_id: event.id,
      event_type: event.type,
      subscription_id: subscription.id,
      received_at: new Date().toISOString()
    });
    if (auditError && auditError.code !== "23505") throw auditError;
    return Response.json({ ok: true });
  } catch (error) {
    console.error("Stripe webhook processing failed", errorContext(error));
    return new Response("Could not process Stripe notification", { status: 400 });
  }
});
