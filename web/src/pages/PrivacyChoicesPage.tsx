import { LegalPage } from "../components/LegalPage";
import { privacyChoicesSections } from "../content/legal";

export function PrivacyChoicesPage() {
  return (
    <LegalPage
      title="Privacy Choices"
      intro="Learn how to manage your Backword account, cloud progress, subscriptions, advertising choices, and privacy requests."
      sections={privacyChoicesSections}
    />
  );
}
