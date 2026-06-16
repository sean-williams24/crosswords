import { LegalPage } from "../components/LegalPage";
import { privacySections } from "../content/legal";

export function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      intro="This policy explains how Backword handles information in the iOS app and on this website."
      sections={privacySections}
    />
  );
}
