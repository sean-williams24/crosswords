import { cleanup, render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, describe, expect, it } from "vitest";
import { LegalPage } from "../components/LegalPage";
import { siteConfig } from "../lib/siteConfig";
import { PrivacyPage } from "./PrivacyPage";

afterEach(cleanup);

function renderPrivacy() {
  render(<MemoryRouter><PrivacyPage /></MemoryRouter>);
  const section = screen.getByRole("heading", { name: "Google Sign-In Data" }).closest("section");
  if (!section) throw new Error("Google sign-in disclosures are missing.");
  return within(section);
}

describe("Google sign-in privacy disclosures", () => {
  it("publicly explains the data accessed, purposes, storage and actual recipients", () => {
    const disclosures = renderPrivacy();

    expect(disclosures.getByText(/Signing in with Google is optional/)).toHaveTextContent(
      /identifier, email address and verification status.*name and profile picture/
    );
    expect(disclosures.getByText(/does not receive your Google password/)).toHaveTextContent(
      /request access to Gmail, Google Drive, Google Calendar, contacts/
    );
    expect(disclosures.getByText(/We send the Google identity token to Supabase/)).toHaveTextContent(
      /saved gameplay and Pro access/
    );
    expect(disclosures.getByText(/stored with your Intervls authentication record/)).toHaveTextContent(
      /session credentials are stored on your device or in your browser/
    );
    expect(disclosures.getByText(/We share Google sign-in information with Supabase/)).toHaveTextContent(
      /email address to Stripe/
    );
    expect(disclosures.getByText(/We do not sell Google user data/)).toHaveTextContent(
      /profile information and identity tokens are not sent to Firebase Analytics/
    );
  });

  it("explains retention and distinguishes account deletion from sign-out and revocation", () => {
    const disclosures = renderPrivacy();
    const retention = disclosures.getByText(/We retain Google account information/);

    expect(retention).toHaveTextContent(/while your Intervls account is active/);
    expect(retention).toHaveTextContent(/Settings → Account.*Player Profile/);
    expect(retention).toHaveTextContent(/deletes the sign-in account, its Google profile information, and cloud-synced gameplay progress/);
    expect(retention).toHaveTextContent(/Signing out does not delete the account/);
    expect(retention).toHaveTextContent(/removing that access does not itself delete information already stored/);
    expect(disclosures.getByText(/Google API Services User Data Policy/)).toHaveTextContent(/Limited Use requirements/);
    expect(screen.getByRole("link", { name: "Manage your privacy choices" })).toHaveAttribute("href", "/privacy-choices");
    expect(screen.getByText(/Questions about privacy/)).toHaveTextContent("support@intervls.com");
  });

  it("dates the revised privacy policy independently of other legal pages", () => {
    renderPrivacy();
    expect(screen.getByText("Last updated November 5, 2026")).toBeInTheDocument();
    cleanup();

    render(<LegalPage title="Other legal page" intro="Existing policy" sections={[]} />);
    expect(screen.getByText(`Last updated ${siteConfig.lastUpdated}`)).toBeInTheDocument();
  });
});
