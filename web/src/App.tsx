import { Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { BackwordPage } from "./pages/BackwordPage";
import { ContactPage } from "./pages/ContactPage";
import { CrosswordPage } from "./pages/CrosswordPage";
import { HomeDashboardPage } from "./pages/HomeDashboardPage";
import { InfoPage } from "./pages/InfoPage";
import { PrivacyPage } from "./pages/PrivacyPage";
import { TermsPage } from "./pages/TermsPage";
import { SignInPage } from "./pages/SignInPage";
import { AuthCallbackPage } from "./pages/AuthCallbackPage";
import { PlayerProfilePage } from "./pages/PlayerProfilePage";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<BackwordPage />} />
      <Route path="/home" element={<HomeDashboardPage />} />
      <Route path="/crossword" element={<CrosswordPage />} />
      <Route path="/contact" element={<Layout><ContactPage /></Layout>} />
      <Route path="/info" element={<Layout><InfoPage /></Layout>} />
      <Route path="/privacy" element={<Layout><PrivacyPage /></Layout>} />
      <Route path="/terms" element={<Layout><TermsPage /></Layout>} />
      <Route path="/sign-in" element={<SignInPage />} />
      <Route path="/player-profile" element={<PlayerProfilePage />} />
      <Route path="/auth/callback" element={<AuthCallbackPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
