import { useEffect, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { BackwordLogo } from "../features/backword/components/BackwordLogo";
import { GameMenu } from "../features/backword/components/GameMenu";
import { openStripeBillingPortal, startStripeCheckout, type ProPlan } from "../features/pro/billing";
import { useAuth } from "../features/auth/AuthProvider";
import { Footer } from "../components/Footer";

const plans: Array<{ id: ProPlan; name: string; price: string; detail: string; badge?: string }> = [
  { id: "monthly", name: "Monthly", price: "£1.49", detail: "per month" },
  { id: "annual", name: "Annual", price: "£11.99", detail: "per year · Save 33%", badge: "Best value" }
];

const features = [
  {
    title: "The 13 x 13 crossword",
    detail: "Take on a larger, satisfyingly tricky crossword whenever you are ready for a deeper solve."
  },
  {
    title: "Every puzzle, on demand",
    detail: "Explore the complete Backword and crossword archive, with past puzzles ready whenever the mood strikes."
  },
  {
    title: "A helpful nudge when needed",
    detail: "Reveal an answer when a clue has you stumped, then carry on and finish the puzzle your way."
  },
  {
    title: "More room to focus",
    detail: "Enjoy hints and gameplay without ads interrupting your train of thought."
  }
];

function safeReturnPath(value: string | null) {
  return value?.startsWith("/") && !value.startsWith("//") ? value : "/";
}

export function ProPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { entitlement, entitlementReady, ready, refreshEntitlement, user } = useAuth();
  const [selectedPlan, setSelectedPlan] = useState<ProPlan>("annual");
  const [checkoutError, setCheckoutError] = useState<string | null>(null);
  const [isCheckoutStarting, setIsCheckoutStarting] = useState(false);
  const [isManaging, setIsManaging] = useState(false);
  const returnPath = safeReturnPath(searchParams.get("return_to"));
  const signInReturnPath = `/pro?return_to=${encodeURIComponent(returnPath)}`;
  const completedCheckout = searchParams.get("checkout") === "success";
  const cancelledCheckout = searchParams.get("checkout") === "cancelled";

  useEffect(() => {
    if (!completedCheckout || entitlement?.isPro) return;
    const timers = [0, 1_500, 4_000, 8_000].map((delay) => window.setTimeout(() => void refreshEntitlement(), delay));
    return () => timers.forEach(window.clearTimeout);
  }, [completedCheckout, entitlement?.isPro, refreshEntitlement]);

  if (!ready) return <main className="pro-page pro-page--loading">Loading Pro…</main>;
  if (user && !entitlementReady) return <main className="pro-page pro-page--loading">Checking Pro access…</main>;

  async function selectCheckout() {
    setCheckoutError(null);
    if (!user) {
      navigate("/sign-in", { state: { returnTo: signInReturnPath } });
      return;
    }
    setIsCheckoutStarting(true);
    try {
      await startStripeCheckout(selectedPlan, returnPath);
    } catch (error) {
      setCheckoutError(error instanceof Error ? error.message : "We couldn't start secure checkout. Please try again.");
      setIsCheckoutStarting(false);
    }
  }

  async function manageStripeSubscription() {
    setCheckoutError(null);
    setIsManaging(true);
    try {
      await openStripeBillingPortal();
    } catch (error) {
      setCheckoutError(error instanceof Error ? error.message : "We couldn't open subscription management. Please try again.");
      setIsManaging(false);
    }
  }

  return (
    <main className="pro-page">
      <header className="home-dashboard__header pro-page__header">
        <GameMenu />
        <Link aria-label="Backword home" to="/"><BackwordLogo isPro large /></Link>
      </header>
      <section aria-labelledby="pro-page-title" className="pro-page__content">
        {entitlement?.isPro ? (
          <div className="pro-page__active">
            <h1 id="pro-page-title">You’re all set.</h1>
            <p>{entitlement.cancelAtPeriodEnd ? "Your Pro access stays active until the end of the current billing period." : "Pro is active for this Backword account on the web and iOS."}</p>
            {entitlement.provider === "stripe" ? <button className="pro-page__primary" disabled={isManaging} onClick={() => void manageStripeSubscription()} type="button">{isManaging ? "Opening billing…" : "Manage web subscription"}</button> : <p className="pro-page__provider-note">This subscription is managed through your Apple ID.</p>}
            <Link className="pro-page__secondary" to={returnPath}>Continue playing</Link>
          </div>
        ) : (
          <>
            <div className="pro-page__intro">
              <h1 id="pro-page-title">The full game experience</h1>
              <p>Unlock Pro on the web and iOS with one Backword account.</p>
            </div>
            <ul aria-label="Included with Backword Pro" className="pro-page__features">
              {features.map((feature) => <li key={feature.title}>
                <div>
                  <h2>{feature.title}</h2>
                  <p>{feature.detail}</p>
                </div>
              </li>)}
            </ul>
            <div aria-label="Choose a Pro plan" className="pro-page__plans">
              {plans.map((plan) => <button aria-pressed={selectedPlan === plan.id} className={selectedPlan === plan.id ? "is-selected" : ""} key={plan.id} onClick={() => setSelectedPlan(plan.id)} type="button">
                {plan.badge ? <span>{plan.badge}</span> : null}
                <strong>{plan.name}</strong><b>{plan.price}</b><small>{plan.detail}</small>
              </button>)}
            </div>
            <button className="pro-page__primary" disabled={isCheckoutStarting} onClick={() => void selectCheckout()} type="button">{isCheckoutStarting ? "Opening secure checkout…" : "Start 7-day free trial"}</button>
            {!user ? <div className="pro-page__login-option"><span>Or</span><Link className="pro-page__login" state={{ returnTo: signInReturnPath }} to="/sign-in">Login</Link></div> : null}
            {completedCheckout ? <p className="pro-page__notice" role="status">We’re confirming your payment and unlocking Pro. This can take a few seconds.</p> : null}
            {cancelledCheckout ? <p className="pro-page__notice" role="status">Checkout was cancelled. No payment was taken.</p> : null}
          </>
        )}
        {checkoutError ? <p className="pro-page__error" role="alert">{checkoutError}</p> : null}
        <p className="pro-page__legal">After your trial, your selected plan renews automatically until cancelled. Taxes are calculated at secure checkout.<br /><Link to="/terms">Terms</Link> · <Link to="/privacy">Privacy</Link></p>
      </section>
      <Footer />
    </main>
  );
}
