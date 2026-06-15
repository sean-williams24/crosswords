import { LegalPage } from "../components/LegalPage";
import { privacySections } from "../content/legal";

export function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      intro="This page describes the intended privacy approach for Backword. Replace this placeholder text with reviewed production policy language before launch."
      sections={privacySections}
    />
  );
}
