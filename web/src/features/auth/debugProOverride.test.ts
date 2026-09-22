import { beforeEach, describe, expect, it } from "vitest";
import {
  applyDebugProOverride,
  debugProOverrideStorageKey,
  isDebugProOverrideAvailable,
  readDebugProOverride,
  writeDebugProOverride
} from "./debugProOverride";
import type { ProEntitlement } from "./proEntitlement";

const inactiveEntitlement: ProEntitlement = {
  isPro: false,
  expiresAt: null,
  provider: null,
  cancelAtPeriodEnd: false,
  hasUsedTrial: false
};

describe("debug Pro override", () => {
  beforeEach(() => window.localStorage.clear());

  it("is available only in a Vite development build", () => {
    expect(isDebugProOverrideAvailable({ DEV: true })).toBe(true);
    expect(isDebugProOverrideAvailable({ DEV: false })).toBe(false);
  });

  it("persists only an enabled local override", () => {
    expect(readDebugProOverride(window.localStorage)).toBe(false);

    writeDebugProOverride(window.localStorage, true);
    expect(readDebugProOverride(window.localStorage)).toBe(true);
    expect(window.localStorage.getItem(debugProOverrideStorageKey)).toBe("true");

    writeDebugProOverride(window.localStorage, false);
    expect(readDebugProOverride(window.localStorage)).toBe(false);
    expect(window.localStorage.getItem(debugProOverrideStorageKey)).toBeNull();
  });

  it("forces only the effective local entitlement, preserving server values", () => {
    const effective = applyDebugProOverride(inactiveEntitlement, true);

    expect(effective).toEqual({ ...inactiveEntitlement, isPro: true });
    expect(inactiveEntitlement.isPro).toBe(false);
    expect(applyDebugProOverride(null, true)).toMatchObject({ isPro: true, provider: null });
    expect(applyDebugProOverride(inactiveEntitlement, false)).toBe(inactiveEntitlement);
  });
});
