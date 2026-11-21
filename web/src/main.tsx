import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import { ScrollToTop } from "./components/ScrollToTop";
import { AuthProvider } from "./features/auth/AuthProvider";
import { AnalyticsProvider, AnalyticsRouteTracker } from "./features/analytics/AnalyticsProvider";
import { ThemeProvider } from "./features/theme/ThemeProvider";
import { readDailyIntervlsStage, saveDailyIntervlsStage } from "./features/home/dailyIntervlsOnboarding";
import "./styles.css";
import "./features/midword/midword.css";

// Classify the browser before auth and route effects can write preferences or caches.
saveDailyIntervlsStage(window.localStorage, readDailyIntervlsStage(window.localStorage));

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <ScrollToTop />
      <ThemeProvider>
        <AnalyticsProvider>
          <AnalyticsRouteTracker />
          <AuthProvider>
            <App />
          </AuthProvider>
        </AnalyticsProvider>
      </ThemeProvider>
    </BrowserRouter>
  </StrictMode>
);
