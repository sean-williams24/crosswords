const stripeAPIBaseURL = "https://api.stripe.com/v1";

type StripeRequestOptions = {
  apiVersion?: string;
  idempotencyKey?: string;
  method?: "GET" | "POST";
  params?: Record<string, string | number | boolean | null | undefined>;
};

export function stripeISODate(seconds: number | null | undefined) {
  return typeof seconds === "number" ? new Date(seconds * 1_000).toISOString() : null;
}

export async function stripeRequest<T>(path: string, options: StripeRequestOptions = {}): Promise<T> {
  const secret = Deno.env.get("STRIPE_SECRET_KEY");
  if (!secret) throw new Error("Stripe is not configured.");

  const method = options.method ?? "POST";
  const body = options.params
    ? new URLSearchParams(Object.entries(options.params).flatMap(([key, value]) => value === null || value === undefined ? [] : [[key, String(value)]])).toString()
    : undefined;
  const response = await fetch(`${stripeAPIBaseURL}/${path}`, {
    method,
    headers: {
      Authorization: `Basic ${btoa(`${secret}:`)}`,
      ...(body ? { "Content-Type": "application/x-www-form-urlencoded" } : {}),
      ...(options.apiVersion ? { "Stripe-Version": options.apiVersion } : {}),
      ...(options.idempotencyKey ? { "Idempotency-Key": options.idempotencyKey } : {})
    },
    body
  });
  const payload = await response.json().catch(() => null) as T | { error?: { message?: string } } | null;
  if (!response.ok) {
    throw new Error((payload as { error?: { message?: string } } | null)?.error?.message ?? "Stripe request failed.");
  }
  return payload as T;
}

function hex(bytes: ArrayBuffer) {
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return difference === 0;
}

export async function verifyStripeWebhook(rawBody: string, signatureHeader: string | null) {
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!secret || !signatureHeader) return false;
  const values = new Map(signatureHeader.split(",").map((part) => {
    const [key, value] = part.split("=", 2);
    return [key, value];
  }));
  const timestamp = values.get("t");
  const signatures = signatureHeader.split(",").filter((part) => part.startsWith("v1=")).map((part) => part.slice(3));
  if (!timestamp || signatures.length === 0 || Math.abs(Date.now() / 1_000 - Number(timestamp)) > 300) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = hex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${timestamp}.${rawBody}`)));
  return signatures.some((candidate) => constantTimeEqual(candidate, signature));
}
