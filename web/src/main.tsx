import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import { ScrollToTop } from "./components/ScrollToTop";
import { AuthProvider } from "./features/auth/AuthProvider";
import { AnalyticsProvider, AnalyticsRouteTracker } from "./features/analytics/AnalyticsProvider";
import "./styles.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <ScrollToTop />
      <AnalyticsProvider>
        <AnalyticsRouteTracker />
        <AuthProvider>
          <App />
        </AuthProvider>
      </AnalyticsProvider>
    </BrowserRouter>
  </StrictMode>
);
