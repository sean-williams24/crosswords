import { Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { BackwordPage } from "./pages/BackwordPage";
import { ContactPage } from "./pages/ContactPage";
import { CrosswordPage } from "./pages/CrosswordPage";
import { WeeklyCrosswordPage } from "./pages/WeeklyCrosswordPage";
import { HomeDashboardPage } from "./pages/HomeDashboardPage";
import { InfoPage } from "./pages/InfoPage";
import { PrivacyPage } from "./pages/PrivacyPage";
import { PrivacyChoicesPage } from "./pages/PrivacyChoicesPage";
import { TermsPage } from "./pages/TermsPage";
import { SignInPage } from "./pages/SignInPage";
import { AuthCallbackPage } from "./pages/AuthCallbackPage";
import { PlayerProfilePage } from "./pages/PlayerProfilePage";
import { AccountDeletionRecovery } from "./features/auth/AccountDeletionRecovery";

export default function App() {
  return (
    <>
      <Routes>
        <Route path="/" element={<HomeDashboardPage />} />
        <Route path="/backword" element={<BackwordPage />} />
        <Route path="/home" element={<Navigate to="/" replace />} />
        <Route path="/crossword" element={<CrosswordPage />} />
        <Route path="/weekly-crossword" element={<WeeklyCrosswordPage />} />
        <Route path="/contact" element={<Layout><ContactPage /></Layout>} />
        <Route path="/info" element={<Layout><InfoPage /></Layout>} />
        <Route path="/privacy" element={<Layout><PrivacyPage /></Layout>} />
        <Route path="/privacy-choices" element={<Layout><PrivacyChoicesPage /></Layout>} />
        <Route path="/privacy-choice" element={<Navigate to="/privacy-choices" replace />} />
        <Route path="/terms" element={<Layout><TermsPage /></Layout>} />
        <Route path="/sign-in" element={<SignInPage />} />
        <Route path="/player-profile" element={<PlayerProfilePage />} />
        <Route path="/auth/callback" element={<AuthCallbackPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      <AccountDeletionRecovery />
    </>
  );
}
