import { Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { BackwordPage } from "./pages/BackwordPage";
import { HomePage } from "./pages/HomePage";
import { PrivacyPage } from "./pages/PrivacyPage";
import { TermsPage } from "./pages/TermsPage";

export default function App() {
  return (
    <Routes>
      <Route path="/backword" element={<BackwordPage />} />
      <Route path="/" element={<Layout><HomePage /></Layout>} />
      <Route path="/privacy" element={<Layout><PrivacyPage /></Layout>} />
      <Route path="/terms" element={<Layout><TermsPage /></Layout>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
