import { getApp, getApps, initializeApp, type FirebaseOptions } from "firebase/app";
import { initializeAnalytics, isSupported, logEvent, setConsent, type Analytics } from "firebase/analytics";
import type { AnalyticsEvent } from "./events";

type AnalyticsEnvironment = {
  PROD: boolean;
  VITE_ANALYTICS_ENABLED?: string;
  VITE_ANALYTICS_DEBUG?: string;
  VITE_FIREBASE_API_KEY?: string;
  VITE_FIREBASE_AUTH_DOMAIN?: string;
  VITE_FIREBASE_PROJECT_ID?: string;
  VITE_FIREBASE_APP_ID?: string;
  VITE_FIREBASE_MEASUREMENT_ID?: string;
};

type AnalyticsConfiguration = {
  firebaseConfig: FirebaseOptions;
  debugMode: boolean;
};

/**
 * Production analytics require an explicit production flag. Developers can
 * instead opt into a DebugView-only local or preview session with
 * `VITE_ANALYTICS_DEBUG=true`; this value must never be set in Production.
 */
export function resolveAnalyticsConfiguration(
  environment: AnalyticsEnvironment
): AnalyticsConfiguration | null {
  const debugMode = environment.VITE_ANALYTICS_DEBUG === "true";
  const productionAnalyticsEnabled = environment.PROD && environment.VITE_ANALYTICS_ENABLED === "true";
  const hasFirebaseConfiguration = Boolean(
    environment.VITE_FIREBASE_API_KEY &&
    environment.VITE_FIREBASE_AUTH_DOMAIN &&
    environment.VITE_FIREBASE_PROJECT_ID &&
    environment.VITE_FIREBASE_APP_ID &&
    environment.VITE_FIREBASE_MEASUREMENT_ID
  );

  if ((!productionAnalyticsEnabled && !debugMode) || !hasFirebaseConfiguration) return null;

  return {
    firebaseConfig: {
      apiKey: environment.VITE_FIREBASE_API_KEY,
      authDomain: environment.VITE_FIREBASE_AUTH_DOMAIN,
      projectId: environment.VITE_FIREBASE_PROJECT_ID,
      appId: environment.VITE_FIREBASE_APP_ID,
      measurementId: environment.VITE_FIREBASE_MEASUREMENT_ID
    },
    debugMode
  };
}

const analyticsConfiguration = resolveAnalyticsConfiguration(import.meta.env);
const firebaseConfig = analyticsConfiguration?.firebaseConfig ?? null;

let analyticsPromise: Promise<Analytics | null> | null = null;

export function analyticsIsConfigured() {
  return firebaseConfig !== null;
}

export function updateAnalyticsConsent(consent: "accepted" | "declined") {
  setConsent({ analytics_storage: consent === "accepted" ? "granted" : "denied" });
  if (consent === "declined") clearAnalyticsCookies();
}

function clearAnalyticsCookies() {
  const names = document.cookie.split(";").map((cookie) => cookie.trim().split("=")[0])
    .filter((name) => name === "_ga" || name === "_gid" || name.startsWith("_ga_"));
  const domains = [undefined, `.${window.location.hostname}`];
  for (const name of names) {
    for (const domain of domains) {
      document.cookie = `${name}=; Max-Age=0; Path=/${domain ? `; Domain=${domain}` : ""}`;
    }
  }
}

export function analyticsClient(): Promise<Analytics | null> {
  if (!firebaseConfig || typeof window === "undefined") return Promise.resolve(null);
  if (!analyticsPromise) {
    analyticsPromise = isSupported().then((supported) => {
      if (!supported) return null;
      const app = getApps().length ? getApp() : initializeApp(firebaseConfig);
      return initializeAnalytics(app, {
        config: {
          send_page_view: false,
          ...(analyticsConfiguration?.debugMode ? { debug_mode: true } : {})
        }
      });
    }).catch(() => null);
  }
  return analyticsPromise;
}

export async function sendAnalyticsEvent(event: AnalyticsEvent) {
  const analytics = await analyticsClient();
  if (analytics) logEvent(analytics, event.name, event.parameters);
}

export async function sendPageView(location: Location, title: string) {
  const analytics = await analyticsClient();
  if (!analytics) return;
  const safeUrl = new URL(location.origin + location.pathname);
  for (const parameter of ["utm_source", "utm_medium", "utm_campaign", "utm_content"]) {
    const value = new URL(location.href).searchParams.get(parameter);
    if (value) safeUrl.searchParams.set(parameter, value);
  }
  logEvent(analytics, "page_view", { page_location: safeUrl.toString(), page_title: title });
}
