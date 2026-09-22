import { noProEntitlement, type ProEntitlement } from "./proEntitlement";

export const debugProOverrideStorageKey = "backword:web:debug:force-pro:v1";

type DebugEnvironment = Pick<ImportMetaEnv, "DEV">;

// `DEV` is replaced by Vite when it builds the app, so a deployed bundle can
// neither display nor apply this browser-only override.
export function isDebugProOverrideAvailable(environment: DebugEnvironment = import.meta.env) {
  return environment.DEV === true;
}

export function readDebugProOverride(storage: Storage) {
  try {
    return storage.getItem(debugProOverrideStorageKey) === "true";
  } catch {
    return false;
  }
}

export function writeDebugProOverride(storage: Storage, enabled: boolean) {
  try {
    if (enabled) {
      storage.setItem(debugProOverrideStorageKey, "true");
    } else {
      storage.removeItem(debugProOverrideStorageKey);
    }
  } catch {
    // Private browsing or disabled storage should leave the override off after
    // the current render rather than preventing local game testing.
  }
}

export function applyDebugProOverride(
  entitlement: ProEntitlement | null,
  enabled: boolean
): ProEntitlement | null {
  if (!enabled) return entitlement;
  return { ...(entitlement ?? noProEntitlement), isPro: true };
}
