import { LegalPage } from "../components/LegalPage";
import { termsSections } from "../content/legal";

export function TermsPage() {
  return (
    <LegalPage
      title="Terms & Conditions"
      intro="These terms explain the rules for using the intervls iOS app and this website."
      sections={termsSections}
    />
  );
}
