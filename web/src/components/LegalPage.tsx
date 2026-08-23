import type { ReactNode } from "react";
import { siteConfig } from "../lib/siteConfig";

type LegalSection = {
  title: string;
  body: readonly string[];
};

type LegalPageProps = {
  title: string;
  intro: string;
  sections: readonly LegalSection[];
  topLink?: ReactNode;
};

export function LegalPage({ title, intro, sections, topLink }: LegalPageProps) {
  return (
    <section className="px-6 py-16 sm:py-24">
      <div className="relative mx-auto max-w-3xl">
        {topLink ? <div className="absolute right-0 top-0">{topLink}</div> : null}
        <p className="text-sm font-medium uppercase tracking-[0.16em] text-heading">
          Last updated {siteConfig.lastUpdated}
        </p>
        <h1 className="mt-4 text-4xl font-semibold tracking-normal text-textPrimary sm:text-5xl">
          {title}
        </h1>
        <p className="mt-5 text-lg leading-8 text-textSecondary">{intro}</p>

        <article className="legal-copy mt-12 border-t border-line pt-4">
          {sections.map((section) => (
            <section key={section.title}>
              <h2>{section.title}</h2>
              {section.body.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
            </section>
          ))}
        </article>
      </div>
    </section>
  );
}
