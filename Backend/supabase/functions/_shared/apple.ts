import { decodeJwt, importPKCS8, SignJWT } from "npm:jose@5";

const allowedProducts = new Set(["com.backword.monthlypro", "com.backword.annualpro"]);

type AppleTransaction = {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  bundleId: string;
  environment: "Sandbox" | "Production";
  expiresDate?: number;
  revocationDate?: number;
  appAccountToken?: string;
};

export async function getAppleTransaction(transactionID: string): Promise<AppleTransaction> {
  const issuer = Deno.env.get("APPLE_ISSUER_ID");
  const keyID = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
  if (!issuer || !keyID || !privateKey) {
    throw new Error("Apple App Store Server API credentials are not configured.");
  }

  const key = await importPKCS8(privateKey, "ES256");
  const bundleID = Deno.env.get("APPLE_BUNDLE_ID") ?? "com.backword.app";
  const token = await new SignJWT({ bid: bundleID })
    .setProtectedHeader({ alg: "ES256", kid: keyID, typ: "JWT" })
    .setIssuer(issuer)
    .setAudience("appstoreconnect-v1")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);

  const headers = { Authorization: `Bearer ${token}` };
  let response = await fetch(`https://api.storekit.apple.com/inApps/v1/transactions/${transactionID}`, { headers });
  if (response.status === 404) {
    response = await fetch(`https://api.storekit-sandbox.apple.com/inApps/v1/transactions/${transactionID}`, { headers });
  }
  if (!response.ok) throw new Error(`Apple transaction lookup failed (${response.status}).`);

  const body = await response.json() as { signedTransactionInfo?: string };
  if (!body.signedTransactionInfo) throw new Error("Apple transaction response is missing signed transaction data.");
  const transaction = decodeJwt(body.signedTransactionInfo) as unknown as AppleTransaction;
  if (transaction.bundleId !== bundleID || !allowedProducts.has(transaction.productId)) {
    throw new Error("Transaction is not a Backword Pro subscription.");
  }
  return transaction;
}

export function entitlementStatus(transaction: AppleTransaction, notificationType?: string) {
  if (transaction.revocationDate || notificationType === "REFUND" || notificationType === "REVOKE") return "revoked";
  if (notificationType === "DID_FAIL_TO_RENEW" || notificationType === "GRACE_PERIOD_EXPIRED") return "billing_retry";
  if (transaction.expiresDate && transaction.expiresDate <= Date.now()) return "expired";
  return "active";
}

export function asISODate(milliseconds?: number) {
  return milliseconds ? new Date(milliseconds).toISOString() : null;
}
