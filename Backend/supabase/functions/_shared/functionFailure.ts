type ErrorLike = {
  code?: unknown;
  message?: unknown;
};

/// Converts unknown Edge Function failures into safe operational diagnostics.
/// Deliberately omit provider payloads, Postgres `details`, and error hints:
/// those can contain transaction identifiers or other customer data.
export function functionFailureDiagnostic(error: unknown) {
  const errorLike = typeof error === "object" && error !== null ? error as ErrorLike : null;
  const message = error instanceof Error
    ? error.message
    : typeof errorLike?.message === "string"
      ? errorLike.message
      : "Unknown non-Error failure";
  const code = typeof errorLike?.code === "string" ? errorLike.code : undefined;

  return { message, ...(code ? { code } : {}) };
}
