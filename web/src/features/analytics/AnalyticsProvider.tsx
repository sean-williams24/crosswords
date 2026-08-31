import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useLocation } from "react-router-dom";
import { captureFirstCampaignContext, clearCampaignContext, readCampaignContext, type CampaignContext } from "./campaign";
import { sendAnalyticsEvent, sendPageView, updateAnalyticsConsent } from "./client";
import { readAnalyticsConsent, writeAnalyticsConsent, type AnalyticsConsent } from "./consent";
import type { AnalyticsEvent } from "./events";

type AnalyticsContextValue = {
  consent: AnalyticsConsent;
  campaignContext: CampaignContext | null;
  setConsent: (consent: Exclude<AnalyticsConsent, null>) => void;
  track: (event: AnalyticsEvent) => void;
};

const unavailableAnalytics: AnalyticsContextValue = {
  consent: null,
  campaignContext: null,
  setConsent: () => undefined,
  track: () => undefined
};

const AnalyticsContext = createContext<AnalyticsContextValue>(unavailableAnalytics);

export function AnalyticsProvider({ children }: { children: ReactNode }) {
  const [consent, setConsentState] = useState<AnalyticsConsent>(() => readAnalyticsConsent(window.localStorage));
  const [campaignContext, setCampaignContext] = useState<CampaignContext | null>(() =>
    readAnalyticsConsent(window.localStorage) === "accepted" ? readCampaignContext(window.localStorage) : null
  );
  const consentRef = useRef(consent);
  useEffect(() => { consentRef.current = consent; }, [consent]);
  useEffect(() => {
    if (consent) updateAnalyticsConsent(consent);
  }, [consent]);

  const setConsent = useCallback((nextConsent: Exclude<AnalyticsConsent, null>) => {
    updateAnalyticsConsent(nextConsent);
    writeAnalyticsConsent(window.localStorage, nextConsent);
    setConsentState(nextConsent);
    if (nextConsent === "accepted") {
      setCampaignContext(captureFirstCampaignContext(window.localStorage, new URL(window.location.href)));
    } else {
      clearCampaignContext(window.localStorage);
      setCampaignContext(null);
    }
  }, []);

  const track = useCallback((event: AnalyticsEvent) => {
    if (consentRef.current === "accepted") void sendAnalyticsEvent(event);
  }, []);

  const value = useMemo(() => ({ consent, campaignContext, setConsent, track }), [campaignContext, consent, setConsent, track]);
  return <AnalyticsContext.Provider value={value}>{children}<AnalyticsConsentBanner /></AnalyticsContext.Provider>;
}

export function AnalyticsRouteTracker() {
  const location = useLocation();
  const { consent } = useAnalytics();
  useEffect(() => {
    if (consent === "accepted") void sendPageView(window.location, document.title);
  }, [consent, location.key, location.pathname, location.search]);
  return null;
}

function AnalyticsConsentBanner() {
  const { consent, setConsent } = useAnalytics();
  if (consent !== null) return null;
  return (
    <section aria-label="Analytics preferences" className="analytics-consent" role="dialog">
      <p>Help us understand which games people play and which campaigns bring them here. Analytics is optional.</p>
      <div className="analytics-consent__actions">
        <button className="analytics-consent__decline" onClick={() => setConsent("declined")} type="button">Decline</button>
        <button className="analytics-consent__accept" onClick={() => setConsent("accepted")} type="button">Accept analytics</button>
      </div>
      <a href="/privacy-choices">Privacy choices</a>
    </section>
  );
}

export function useAnalytics() {
  return useContext(AnalyticsContext);
}
