import { LegalPage } from "../components/LegalPage";
import { privacyChoicesSections } from "../content/legal";
import { AnalyticsPreferences } from "../features/analytics/AnalyticsPreferences";

export function PrivacyChoicesPage() {
  return (
    <>
      <LegalPage
        title="Privacy Choices"
        intro="Learn how to manage your Backword account, cloud progress, subscriptions, advertising choices, website analytics, and privacy requests."
        sections={privacyChoicesSections}
      />
      <div className="analytics-preferences-wrap"><AnalyticsPreferences /></div>
    </>
  );
}
