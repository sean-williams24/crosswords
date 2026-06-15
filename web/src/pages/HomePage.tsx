import { AppStoreBadge } from "../components/AppStoreBadge";
import { PhoneMockup } from "../components/PhoneMockup";
import { features } from "../content/features";
import { siteConfig } from "../lib/siteConfig";

export function HomePage() {
  return (
    <>
      <section className="px-6 pb-20 pt-12 sm:pb-28 lg:pt-20">
        <div className="mx-auto grid max-w-6xl items-center gap-14 lg:grid-cols-[1fr_0.82fr]">
          <div>
            <p className="text-sm font-medium uppercase tracking-[0.18em] text-heading">
              iOS word game
            </p>
            <h1 className="mt-5 max-w-3xl text-6xl font-semibold tracking-normal text-textPrimary sm:text-7xl lg:text-8xl">
              {siteConfig.appName}
            </h1>
            <p className="mt-7 max-w-xl text-xl leading-9 text-textSecondary">
              {siteConfig.tagline} Solve a six-letter word as each guess reveals
              the answer from the end.
            </p>
            <div className="mt-9">
              <AppStoreBadge />
            </div>
          </div>

          <PhoneMockup />
        </div>
      </section>

      <section className="border-y border-line/80 px-6 py-16">
        <div className="mx-auto max-w-6xl">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {features.map((feature) => (
              <div
                className="rounded-md border border-line bg-surface/55 p-5"
                key={feature}
              >
                <div className="mb-5 h-2 w-2 rounded-full bg-correct" />
                <p className="leading-7 text-textPrimary">{feature}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="px-6 py-20 sm:py-24">
        <div className="mx-auto max-w-6xl">
          <div className="max-w-2xl">
            <p className="text-sm font-medium uppercase tracking-[0.18em] text-heading">
              Crosswords
            </p>
            <h2 className="mt-4 text-3xl font-semibold text-textPrimary sm:text-4xl">
              Daily rhythm. Weekly challenge.
            </h2>
          </div>

          <div className="mt-10 grid gap-4 md:grid-cols-2">
            <article className="rounded-md border border-line bg-surface/45 p-6">
              <p className="text-sm font-medium uppercase tracking-[0.16em] text-accent">
                Daily Crossword
              </p>
              <h3 className="mt-4 text-2xl font-semibold text-textPrimary">
                A quick 9 x 9 puzzle every day.
              </h3>
              <p className="mt-4 leading-8 text-textSecondary">
                Fifteen clues, a compact grid, and a fresh solve built for a
                few quiet minutes.
              </p>
            </article>

            <article className="rounded-md border border-line bg-surface/45 p-6">
              <p className="text-sm font-medium uppercase tracking-[0.16em] text-accent">
                Weekly Crossword
              </p>
              <h3 className="mt-4 text-2xl font-semibold text-textPrimary">
                A larger 13 x 13 puzzle for the weekend.
              </h3>
              <p className="mt-4 leading-8 text-textSecondary">
                More clues, a bigger grid, and a slower challenge when you want
                something to sit with.
              </p>
            </article>
          </div>
        </div>
      </section>
    </>
  );
}
