import { siteConfig } from "../lib/siteConfig";

export function ContactPage() {
  return (
    <section className="px-6 py-14 sm:py-20">
      <div className="mx-auto max-w-2xl">
        <p className="text-2xl font-semibold uppercase tracking-[0.16em] text-heading sm:text-3xl">Contact us</p>

        <div className="mt-5 rounded-2xl border border-line bg-surface p-5 sm:p-7">
          <a
            className="inline-flex rounded-xl bg-accent px-5 py-3 font-semibold text-white transition hover:bg-[#4387c1] focus:outline-none focus:ring-2 focus:ring-accent focus:ring-offset-2 focus:ring-offset-surface"
            href={`mailto:${siteConfig.supportEmail}`}
          >
            Send email
          </a>

          <p className="mt-5 text-sm leading-6 text-textSecondary">
            Tapping opens your email app.
          </p>
          <p className="mt-3 text-sm leading-6 text-textSecondary">
            Or contact us at{" "}
            <a className="font-medium text-accent underline underline-offset-4 hover:text-textPrimary" href={`mailto:${siteConfig.supportEmail}`}>
              {siteConfig.supportEmail}
            </a>.
          </p>
        </div>
      </div>
    </section>
  );
}
