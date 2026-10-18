type SocialPlatform = "Instagram" | "TikTok" | "Facebook";

type FooterSocialLinksProps = {
  links: readonly { label: SocialPlatform; href: string }[];
};

const icons = {
  Instagram: (
    <>
      <rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" strokeWidth="2" />
      <circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" strokeWidth="2" />
      <circle cx="17.5" cy="6.5" r="1" />
    </>
  ),
  TikTok: <path d="M16.6 2h-3.3v13.5a2.9 2.9 0 1 1-2.5-2.9V9.2a6.3 6.3 0 1 0 5.8 6.3V8.7a8.2 8.2 0 0 0 4.8 1.5V6.9A4.9 4.9 0 0 1 16.6 2Z" />,
  Facebook: <path d="M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9 1.1 0 2.2.2 2.2.2v2.4h-1.2c-1.2 0-1.6.7-1.6 1.6V12h2.7l-.4 2.9h-2.3v7A10 10 0 0 0 22 12Z" />
};

export function FooterSocialLinks({ links }: FooterSocialLinksProps) {
  return (
    <section aria-label="Socials">
      <h2 className="mb-3 font-semibold text-textPrimary">Socials</h2>
      <ul className="flex flex-col items-start gap-2">
        {links.map(({ label, href }) => (
          <li key={label}>
            <a className="inline-flex items-center gap-2 transition hover:text-textPrimary" href={href} target="_blank" rel="noopener noreferrer">
              <svg aria-hidden="true" focusable="false" className="h-5 w-5 shrink-0" viewBox="0 0 24 24" fill="currentColor">
                {icons[label]}
              </svg>
              {label}
            </a>
          </li>
        ))}
      </ul>
    </section>
  );
}
