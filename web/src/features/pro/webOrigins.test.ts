import { describe, expect, it } from "vitest";
import { allowedWebOrigins, checkoutCorsHeaders, validOrigin } from "../../../../Backend/supabase/functions/_shared/webOrigins";

describe("Checkout origins during the domain move", () => {
  it("accepts the explicit old and new sites and varies the response by origin", () => {
    const allowed = allowedWebOrigins("https://www.playbackword.com", '["https://intervls.com","https://www.playbackword.com","https://playbackword.com"]');
    for (const origin of allowed) expect(checkoutCorsHeaders(origin, allowed)["Access-Control-Allow-Origin"]).toBe(origin);
    expect(checkoutCorsHeaders("https://attacker.example", allowed)["Access-Control-Allow-Origin"]).toBeUndefined();
    expect(checkoutCorsHeaders(null, allowed).Vary).toBe("Origin");
  });
  it("preserves old deployments when only WEB_ORIGIN is configured", () => {
    expect(allowedWebOrigins("https://www.playbackword.com", undefined)).toEqual(["https://www.playbackword.com"]);
    expect(allowedWebOrigins(undefined, undefined)).toEqual([]);
  });
  it("rejects wildcard origins, paths, credentials, and unsafe return destinations", () => {
    for (const value of ["*", "https://intervls.com/path", "https://intervls.com/", "http://intervls.com", "https://user:pass@intervls.com"]) {
      expect(validOrigin(value)).toBe(false);
      expect(() => allowedWebOrigins(undefined, JSON.stringify([value]))).toThrow();
    }
    expect(validOrigin("http://localhost:5173")).toBe(true);
    expect(() => allowedWebOrigins(undefined, "broken")).toThrow();
  });
});
