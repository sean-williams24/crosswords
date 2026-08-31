import { useAnalytics } from "./AnalyticsProvider";

export function AnalyticsPreferences() {
  const { consent, setConsent } = useAnalytics();
  return (
    <section aria-labelledby="analytics-preferences-title" className="analytics-preferences">
      <h2 id="analytics-preferences-title">Website analytics</h2>
      <p>Current choice: <strong>{consent === "accepted" ? "Analytics allowed" : consent === "declined" ? "Analytics declined" : "No choice saved"}</strong>.</p>
      <p>Analytics measures aggregated site use, game milestones, and App Store link clicks. It never includes guesses, answers, entered letters, account details, or email addresses.</p>
      <div className="analytics-preferences__actions">
        <button onClick={() => setConsent("accepted")} type="button">Allow analytics</button>
        <button onClick={() => setConsent("declined")} type="button">Decline analytics</button>
      </div>
    </section>
  );
}
