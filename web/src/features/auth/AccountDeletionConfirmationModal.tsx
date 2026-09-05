import { useEffect, useRef } from "react";
import type { AccountDeletionSummary } from "./accountDeletionSummary";

type AccountDeletionConfirmationModalProps = {
  isFinishing: boolean;
  onContinue: () => void;
  error: string | null;
  /// `null` is used when another device deleted the account, so this browser
  /// cannot safely determine which billing providers were involved.
  summary: AccountDeletionSummary | null;
};

export function AccountDeletionConfirmationModal({
  isFinishing,
  onContinue,
  error,
  summary
}: AccountDeletionConfirmationModalProps) {
  const continueButton = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    continueButton.current?.focus();
  }, []);

  return (
    <div className="bw-modal-backdrop" role="presentation">
      <section aria-describedby="account-deleted-summary" aria-labelledby="account-deleted-title" aria-modal="true" className="bw-modal account-deletion-confirmation" role="dialog">
        <div className="account-deletion-confirmation__content">
          <p className="account-deletion-confirmation__eyebrow">ACCOUNT DELETED</p>
          <h2 id="account-deleted-title">Your Backword account has been deleted</h2>
          <p id="account-deleted-summary">Your account and cloud-synced game data have been deleted from Backword.</p>

          <section aria-labelledby="account-deleted-removed-title">
            <h3 id="account-deleted-removed-title">Deleted from Backword</h3>
            <ul>
              <li>Your Backword account and its Backword sign-in connection.</li>
              <li>Your cloud-synced Backword and crossword progress.</li>
              <li>Your rating, stats, and score history derived from that progress.</li>
              {summary?.hasApplePurchase || summary?.hasStripeSubscription ? <li>Links between this account and eligible purchase entitlements.</li> : null}
            </ul>
          </section>

          <section aria-labelledby="account-deleted-retained-title">
            <h3 id="account-deleted-retained-title">Not deleted</h3>
            <ul>
              {summary?.hasApplePurchase ? <li>An Apple subscription was not cancelled. If it is still active, it remains active until you cancel it with Apple.</li> : null}
              {summary?.hasStripeSubscription ? <li>Stripe retains legally required billing records. Your Backword web subscription is set not to renew and can no longer unlock this deleted account.</li> : null}
              {summary?.hasApplePurchase ? <li>Your Apple purchase record, which can be claimed by a new Backword account.</li> : null}
              {summary === null ? <li>If you subscribed through Apple, that subscription was not cancelled. If you subscribed on the web, it was set not to renew.</li> : null}
              <li>Game data stored locally on your devices or browsers. Remove that directly from each device if needed.</li>
            </ul>
          </section>

          {error ? <p className="account-deletion-confirmation__error" role="alert">{error}</p> : null}
          <button className="account-deletion-confirmation__continue" disabled={isFinishing} onClick={onContinue} ref={continueButton} type="button">
            {isFinishing ? "Returning to sign in…" : "Continue to sign in"}
          </button>
        </div>
      </section>
    </div>
  );
}
