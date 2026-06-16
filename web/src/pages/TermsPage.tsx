import { LegalPage } from "../components/LegalPage";
import { termsSections } from "../content/legal";

export function TermsPage() {
  return (
    <LegalPage
      title="Terms & Conditions"
      intro="These terms explain the rules for using the Backword iOS app and this website."
      sections={termsSections}
    />
  );
}
