import { createClient } from "npm:@supabase/supabase-js@2";
import { decodeJwt } from "npm:jose@5";
import { asISODate, entitlementStatus, getAppleTransaction } from "../_shared/apple.ts";

Deno.serve(async (request) => {
  const expectedSecret = Deno.env.get("APPLE_NOTIFICATION_WEBHOOK_SECRET");
  if (!expectedSecret || new URL(request.url).searchParams.get("token") !== expectedSecret) {
    return new Response("Unauthorized", { status: 401 });
  }
  const body = await request.json().catch(() => null) as { signedPayload?: string } | null;
  if (!body?.signedPayload) return new Response("Missing signedPayload", { status: 400 });

  try {
    const notification = decodeJwt(body.signedPayload) as {
      notificationType?: string;
      data?: { signedTransactionInfo?: string };
    };
    const signedTransaction = notification.data?.signedTransactionInfo;
    if (!signedTransaction) return new Response("Notification has no transaction", { status: 400 });
    const transactionID = (decodeJwt(signedTransaction) as { transactionId?: string }).transactionId;
    if (!transactionID) return new Response("Transaction is missing an ID", { status: 400 });

    const transaction = await getAppleTransaction(transactionID);
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: existing } = await admin
      .from("user_entitlements")
      .select("user_id")
      .eq("original_transaction_id", transaction.originalTransactionId)
      .maybeSingle();
    const accountID = existing?.user_id ?? transaction.appAccountToken ?? null;

    const { error } = await admin.from("user_entitlements").upsert({
      original_transaction_id: transaction.originalTransactionId,
      user_id: accountID,
      product_id: transaction.productId,
      environment: transaction.environment,
      // The Apple lookup is the source of truth. Do not let an unverified
      // notification type alter a customer's entitlement state.
      status: entitlementStatus(transaction),
      expires_at: asISODate(transaction.expiresDate),
      revocation_at: asISODate(transaction.revocationDate),
      app_account_token: transaction.appAccountToken ?? null,
      updated_at: new Date().toISOString()
    }, { onConflict: "original_transaction_id" });
    if (error) throw error;
    return Response.json({ ok: true });
  } catch (error) {
    // Keep the signed notification payload and transaction IDs out of logs.
    // The reason alone makes failed Apple reconciliation diagnosable.
    const message = error instanceof Error ? error.message : "Invalid App Store notification";
    console.error("App Store notification processing failed", { message });
    return new Response(message, { status: 400 });
  }
});
