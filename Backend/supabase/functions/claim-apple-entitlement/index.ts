import { createClient } from "npm:@supabase/supabase-js@2";
import { asISODate, entitlementStatus, getAppleTransaction, usedAppleIntroductoryOffer } from "../_shared/apple.ts";
import { functionFailureDiagnostic } from "../_shared/functionFailure.ts";

type AuthenticatedUser = { id: string };

/// Verifies the bearer token from this individual request. An Edge Function
/// has no persisted client session, so this must not use an SDK call that
/// falls back to server-side session storage.
async function userForRequest(
  supabaseURL: string,
  publishableKey: string,
  authorization: string
): Promise<AuthenticatedUser | null> {
  if (!authorization.startsWith("Bearer ")) return null;

  const response = await fetch(new URL("/auth/v1/user", supabaseURL), {
    headers: {
      Authorization: authorization,
      apikey: publishableKey
    }
  });
  if (!response.ok) return null;

  const user = await response.json() as Partial<AuthenticatedUser>;
  return typeof user.id === "string" ? { id: user.id } : null;
}

Deno.serve(async (request) => {
  const authorization = request.headers.get("Authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const user = await userForRequest(url, anonKey, authorization);
  if (!user) {
    // Do not log the bearer token. This is enough to identify a missing,
    // stale, or rejected app session when a protected claim fails.
    console.error("Apple entitlement claim unauthenticated", {
      hasBearerToken: authorization.startsWith("Bearer ")
    });
    return new Response("Unauthorized", { status: 401 });
  }

  const body = await request.json().catch(() => null) as { transactionID?: string; originalTransactionID?: string } | null;
  if (!body?.transactionID || !body.originalTransactionID) return new Response("Missing transaction identifiers", { status: 400 });

  let stage = "Apple transaction lookup";
  try {
    const transaction = await getAppleTransaction(body.transactionID);
    if (transaction.originalTransactionId !== body.originalTransactionID) {
      return new Response("Transaction identifiers do not match", { status: 400 });
    }
    // Purchases started while signed in carry this UUID through StoreKit's
    // appAccountToken, so they cannot be claimed by another Backword account.
    // Older signed-out purchases have no token and remain claimable only after
    // Apple verifies their transaction with the App Store Server API.
    if (transaction.appAccountToken && transaction.appAccountToken !== user.id) {
      return new Response("This purchase belongs to a different Backword account.", { status: 409 });
    }

    const admin = createClient(url, serviceKey);
    stage = "existing entitlement lookup";
    const { data: existing, error: existingError } = await admin
      .from("user_entitlements")
      .select("user_id")
      .eq("original_transaction_id", transaction.originalTransactionId)
      .maybeSingle();
    if (existingError) throw existingError;
    if (existing?.user_id && existing.user_id !== user.id) {
      return new Response("This subscription is already linked to another Backword account.", { status: 409 });
    }

    stage = "entitlement upsert";
    const { error } = await admin.from("user_entitlements").upsert({
      provider: "apple",
      provider_subscription_id: transaction.originalTransactionId,
      original_transaction_id: transaction.originalTransactionId,
      user_id: user.id,
      product_id: transaction.productId,
      environment: transaction.environment,
      status: entitlementStatus(transaction),
      expires_at: asISODate(transaction.expiresDate),
      revocation_at: asISODate(transaction.revocationDate),
      app_account_token: transaction.appAccountToken ?? user.id,
      updated_at: new Date().toISOString()
    }, { onConflict: "original_transaction_id" });
    if (error) throw error;
    if (usedAppleIntroductoryOffer(transaction)) {
      stage = "trial redemption upsert";
      const { error: trialError } = await admin.from("pro_trial_redemptions").upsert({
        user_id: user.id,
        provider: "apple"
      }, { onConflict: "user_id", ignoreDuplicates: true });
      if (trialError) throw trialError;
    }
    return Response.json({ ok: true });
  } catch (error) {
    // Never log transaction data or expose infrastructure failures to the app.
    // Supabase client errors are plain objects rather than `Error` instances,
    // so preserve their safe message and code for operational diagnosis.
    console.error("Apple entitlement claim failed", { stage, ...functionFailureDiagnostic(error) });
    return new Response("Could not verify subscription", { status: 400 });
  }
});
