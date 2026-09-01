import { createClient } from "npm:@supabase/supabase-js@2";
import { decodeJwt } from "npm:jose@5";
import { asISODate, entitlementStatus, getAppleTransaction, usedAppleIntroductoryOffer } from "../_shared/apple.ts";

type AppleNotification = {
  notificationUUID?: string;
  notificationType?: string;
  subtype?: string;
  signedDate?: number;
  data?: {
    environment?: "Sandbox" | "Production";
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
  };
};

type AppleRenewalInfo = {
  autoRenewStatus?: 0 | 1;
};

Deno.serve(async (request) => {
  const expectedSecret = Deno.env.get("APPLE_NOTIFICATION_WEBHOOK_SECRET");
  if (!expectedSecret || new URL(request.url).searchParams.get("token") !== expectedSecret) {
    return new Response("Unauthorized", { status: 401 });
  }
  const body = await request.json().catch(() => null) as { signedPayload?: string } | null;
  if (!body?.signedPayload) return new Response("Missing signedPayload", { status: 400 });

  try {
    const notification = decodeJwt(body.signedPayload) as AppleNotification;
    if (!notification.notificationUUID || !notification.notificationType) {
      return new Response("Notification is missing an ID or type", { status: 400 });
    }
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const signedTransaction = notification.data?.signedTransactionInfo;
    const signedRenewal = notification.data?.signedRenewalInfo;
    const renewal = signedRenewal ? decodeJwt(signedRenewal) as AppleRenewalInfo : null;
    const autoRenewStatus = renewal?.autoRenewStatus === undefined ? null : renewal.autoRenewStatus === 1;

    // TEST notifications confirm endpoint delivery but do not have a purchase
    // transaction to reconcile. Keep their safe summary for troubleshooting.
    if (!signedTransaction) {
      if (notification.notificationType !== "TEST") return new Response("Notification has no transaction", { status: 400 });
      const { error } = await admin.from("apple_subscription_events").upsert({
        notification_uuid: notification.notificationUUID,
        notification_type: notification.notificationType,
        subtype: notification.subtype ?? null,
        environment: notification.data?.environment ?? null,
        event_at: asISODate(notification.signedDate),
        auto_renew_status: autoRenewStatus
      }, { onConflict: "notification_uuid", ignoreDuplicates: true });
      if (error) console.error("Apple subscription audit event failed", { message: error.message });
      return Response.json({ ok: true });
    }
    const transactionID = (decodeJwt(signedTransaction) as { transactionId?: string }).transactionId;
    if (!transactionID) return new Response("Transaction is missing an ID", { status: 400 });

    const transaction = await getAppleTransaction(transactionID);
    const { data: existing } = await admin
      .from("user_entitlements")
      .select("user_id")
      .eq("original_transaction_id", transaction.originalTransactionId)
      .maybeSingle();
    const accountID = existing?.user_id ?? transaction.appAccountToken ?? null;

    const { error } = await admin.from("user_entitlements").upsert({
      provider: "apple",
      provider_subscription_id: transaction.originalTransactionId,
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
      auto_renew_status: autoRenewStatus,
      updated_at: new Date().toISOString()
    }, { onConflict: "original_transaction_id" });
    if (error) throw error;
    if (accountID && usedAppleIntroductoryOffer(transaction)) {
      const { error: trialError } = await admin.from("pro_trial_redemptions").upsert({
        user_id: accountID,
        provider: "apple"
      }, { onConflict: "user_id", ignoreDuplicates: true });
      if (trialError) throw trialError;
    }

    // Auditing must not interfere with the access-changing upsert above.
    // notificationUUID makes retry delivery idempotent without storing JWS data.
    const { error: auditError } = await admin.from("apple_subscription_events").upsert({
      notification_uuid: notification.notificationUUID,
      notification_type: notification.notificationType,
      subtype: notification.subtype ?? null,
      original_transaction_id: transaction.originalTransactionId,
      transaction_id: transaction.transactionId,
      environment: transaction.environment,
      event_at: asISODate(notification.signedDate),
      account_id: accountID,
      resulting_status: entitlementStatus(transaction),
      expires_at: asISODate(transaction.expiresDate),
      revocation_at: asISODate(transaction.revocationDate),
      auto_renew_status: autoRenewStatus
    }, { onConflict: "notification_uuid", ignoreDuplicates: true });
    if (auditError) console.error("Apple subscription audit event failed", { message: auditError.message });
    return Response.json({ ok: true });
  } catch (error) {
    // Keep the signed notification payload and transaction IDs out of logs.
    // The reason alone makes failed Apple reconciliation diagnosable.
    const message = error instanceof Error ? error.message : "Invalid App Store notification";
    console.error("App Store notification processing failed", { message });
    return new Response(message, { status: 400 });
  }
});
