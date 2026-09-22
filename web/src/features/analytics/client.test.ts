import { describe, expect, it } from "vitest";
import {
  analyticsClient,
  analyticsIsConfigured,
  resolveAnalyticsConfiguration,
  sendAnalyticsEvent
} from "./client";

const firebaseEnvironment = {
  VITE_FIREBASE_API_KEY: "api-key",
  VITE_FIREBASE_AUTH_DOMAIN: "backword.firebaseapp.com",
  VITE_FIREBASE_PROJECT_ID: "backword",
  VITE_FIREBASE_APP_ID: "app-id",
  VITE_FIREBASE_MEASUREMENT_ID: "G-TEST"
};

describe("analytics client", () => {
  it("does nothing safely when production analytics configuration is absent", async () => {
    expect(analyticsIsConfigured()).toBe(false);
    await expect(analyticsClient()).resolves.toBeNull();
    await expect(sendAnalyticsEvent({ name: "sign_in_started", parameters: {} })).resolves.toBeUndefined();
  });

  it("permits an explicit local DebugView session without enabling ordinary development analytics", () => {
    expect(resolveAnalyticsConfiguration({
      PROD: false,
      VITE_ANALYTICS_DEBUG: "true",
      ...firebaseEnvironment
    })).toEqual({
      firebaseConfig: {
        apiKey: "api-key",
        authDomain: "backword.firebaseapp.com",
        projectId: "backword",
        appId: "app-id",
        measurementId: "G-TEST"
      },
      debugMode: true
    });
  });

  it("keeps non-production analytics disabled unless DebugView is explicitly requested", () => {
    expect(resolveAnalyticsConfiguration({
      PROD: false,
      VITE_ANALYTICS_ENABLED: "true",
      ...firebaseEnvironment
    })).toBeNull();
  });

  it("uses the normal production path without enabling DebugView", () => {
    expect(resolveAnalyticsConfiguration({
      PROD: true,
      VITE_ANALYTICS_ENABLED: "true",
      ...firebaseEnvironment
    })?.debugMode).toBe(false);
  });
});
