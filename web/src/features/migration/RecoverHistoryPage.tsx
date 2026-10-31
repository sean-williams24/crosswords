import { Link } from "react-router-dom";
import { BrandLogo } from "../brand/BrandLogo";
import { brand } from "../brand/brand";

export function RecoverHistoryPage() {
  return <main className="migration-page"><Link to="/" aria-label="Intervls home"><BrandLogo large /></Link>
    <section className="migration-panel"><h1>Recover your Backword history</h1>
      <p>Open these links on the browser and device where you played Backword. Sign in there, sync your saves, then return here and sign in with the same Apple or Google account.</p>
      <p>Each old website address can hold different saves. Check both if you are unsure which you used.</p>
      <ul>{brand.legacyOrigins.map((origin) => <li key={origin}><a href={`${origin}/move`}>Check {new URL(origin).hostname}</a></li>)}</ul>
      <p>Your iOS app saves stay with the updated app. You can sign in on iOS to sync them with Intervls.</p>
      <Link to="/sign-in">Sign in on Intervls</Link>
    </section></main>;
}
