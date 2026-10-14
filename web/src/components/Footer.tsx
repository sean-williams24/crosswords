import { Link } from "react-router-dom";
import { useAuth } from "../features/auth/AuthProvider";
import { AppStoreBadge } from "./AppStoreBadge";
import { FooterSocialLinks } from "./FooterSocialLinks";
import { siteConfig } from "../lib/siteConfig";

export function Footer() {
  const { entitlement } = useAuth();
  const weeklyCrosswordDestination = entitlement?.isPro ? "/weekly-crossword" : "/pro?return_to=%2Fweekly-crossword";
  const archiveDestination = entitlement?.isPro ? "/archive" : "/pro?return_to=%2Farchive";
  const linkGroups = [
    {
      title: "Explore",
      links: [
        { label: "Home", to: "/" },
        { label: "Player Profile", to: "/player-profile" }
      ]
    },
    {
      title: "Free games",
      links: [
        { label: "Backword", to: "/backword" },
        { label: "Crossword", to: "/crossword" },
        { label: "Midword", to: "/midword" },
        { label: "Anagram", to: "/anagram" }
      ]
    },
    {
      title: "Pro Account",
      links: [
        { label: "Pro Crossword", to: weeklyCrosswordDestination },
        { label: "Archive", to: archiveDestination },
        ...(!entitlement?.isPro ? [{ label: "Subscribe", to: "/pro" }] : [])
      ]
    },
    {
      title: "Support",
      links: [
        { label: "Info", to: "/info" },
        { label: "Contact", to: "/contact" }
      ]
    },
    {
      title: "Legal",
      links: [
        { label: "Privacy", to: "/privacy" },
        { label: "Privacy Choices", to: "/privacy-choices" },
        { label: "Terms", to: "/terms" }
      ]
    }
  ];

  return (
    <footer className="site-footer border-t border-line/80 px-6 py-8 text-sm text-textSecondary sm:px-0 lg:px-6">
      <div className="mx-auto grid max-w-6xl items-start justify-items-center gap-8 lg:grid-cols-[auto_minmax(0,1fr)_auto] lg:gap-x-16">
        <nav aria-label="Footer" className="order-1 grid grid-cols-2 justify-self-stretch gap-x-4 gap-y-8 sm:grid-cols-[repeat(3,max-content)] sm:justify-evenly sm:gap-x-0 lg:order-2 lg:grid-cols-[repeat(6,max-content)] lg:justify-between lg:gap-x-4">
          {linkGroups.map(({ title, links }) => (
            <section key={title} aria-label={title}>
              <h2 className="mb-3 font-semibold text-textPrimary">{title}</h2>
              <ul className="flex flex-col items-start gap-2">
                {links.map(({ label, to }) => (
                  <li key={label}>
                    <Link className="transition hover:text-textPrimary" to={to}>
                      {label}
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          ))}
          <FooterSocialLinks links={siteConfig.socialLinks} />
        </nav>
        <p className="order-2 whitespace-nowrap text-center lg:order-1 lg:justify-self-start lg:text-left">© 2026 Backword</p>
        <div className="order-3 lg:justify-self-end">
          <AppStoreBadge placement="footer" />
        </div>
      </div>
    </footer>
  );
}
