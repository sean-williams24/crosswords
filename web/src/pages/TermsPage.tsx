import { LegalPage } from "../components/LegalPage";
import { termsSections } from "../content/legal";

export function TermsPage() {
  return (
    <LegalPage
      title="Terms & Conditions"
      intro="These placeholder terms set the structure for Backword's public terms. Replace with approved legal copy before launch."
      sections={termsSections}
    />
  );
}
