import { useEffect, useRef } from "react";

type AccountDeletionConfirmationModalProps = {
  isFinishing: boolean;
  onContinue: () => void;
  error: string | null;
};

export function AccountDeletionConfirmationModal({
  isFinishing,
  onContinue,
  error
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
              <li>The link between this account and your Apple purchase.</li>
            </ul>
          </section>

          <section aria-labelledby="account-deleted-retained-title">
            <h3 id="account-deleted-retained-title">Not deleted</h3>
            <ul>
              <li>Your Apple subscription. It remains active until you cancel it with Apple.</li>
              <li>Stripe’s legally required billing records. Any Backword web subscription was set not to renew, but it can no longer unlock this deleted account.</li>
              <li>Your Apple purchase record, which can be claimed by a new Backword account.</li>
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
