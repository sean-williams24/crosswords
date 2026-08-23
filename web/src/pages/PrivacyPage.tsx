import { Link } from "react-router-dom";
import { LegalPage } from "../components/LegalPage";
import { privacySections } from "../content/legal";

export function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      intro="This policy explains how Backword handles information in the iOS app and on this website."
      sections={privacySections}
      topLink={
        <Link
          className="inline-flex items-center rounded-full border border-accent px-4 py-2 text-sm font-semibold text-textPrimary transition hover:bg-accent hover:text-ink"
          to="/privacy-choices"
        >
          Manage your privacy choices
        </Link>
      }
    />
  );
}
