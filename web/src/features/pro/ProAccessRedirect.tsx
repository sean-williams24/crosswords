import { useEffect } from "react";
import { Navigate } from "react-router-dom";
import { useAnalytics } from "../analytics/AnalyticsProvider";
import { proAccessGateRedirected } from "../analytics/events";

export function ProAccessRedirect({ feature, returnTo }: {
  feature: "archive" | "weekly_crossword";
  returnTo: string;
}) {
  const { track } = useAnalytics();

  useEffect(() => {
    track(proAccessGateRedirected(feature));
  }, [feature, track]);

  return <Navigate replace to={`/pro?return_to=${encodeURIComponent(returnTo)}`} />;
}
