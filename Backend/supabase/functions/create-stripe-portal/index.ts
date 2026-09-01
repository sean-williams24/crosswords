import { createClient } from "npm:@supabase/supabase-js@2";
import { stripeRequest } from "../_shared/stripe.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("WEB_ORIGIN") ?? "",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

type StripePortalSession = { url: string };

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  const supabaseURL = Deno.env.get("SUPABASE_URL")!;
  const caller = createClient(supabaseURL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: request.headers.get("Authorization") ?? "" } }
  });
  const { data: { user } } = await caller.auth.getUser();
  if (!user) return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  const admin = createClient(supabaseURL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: entitlement } = await admin
    .from("user_entitlements")
    .select("provider_customer_id")
    .eq("user_id", user.id)
    .eq("provider", "stripe")
    .not("provider_customer_id", "is", null)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!entitlement?.provider_customer_id) return new Response("No web subscription was found.", { status: 404, headers: corsHeaders });
  const webOrigin = Deno.env.get("WEB_ORIGIN");
  if (!webOrigin) return new Response("Web subscriptions are not configured.", { status: 503, headers: corsHeaders });
  const portal = await stripeRequest<StripePortalSession>("billing_portal/sessions", {
    params: { customer: entitlement.provider_customer_id, return_url: `${webOrigin}/player-profile` }
  });
  return Response.json({ url: portal.url }, { headers: corsHeaders });
});
