import type { ReactNode } from "react";
import { AppStoreBadge } from "../components/AppStoreBadge";
import { PhoneMockup } from "../components/PhoneMockup";

export function HomePage() {
  return (
    <>
      <ScreenshotSection
        eyebrow="iOS word game"
        title="Backword"
        body="Three word games plus Word of the Day in one clean daily ritual: Backword, a daily crossword, and a deeper weekly crossword."
        headingLevel="h1"
        screenshotAlt="Backword home screen"
        screenshotPosition="right"
        screenshotSrc="/screenshots/home.png"
      >
        <AppStoreBadge />
      </ScreenshotSection>

      <ScreenshotSection
        eyebrow="Backword"
        title="Guess forwards. Reveal backwards."
        body="Solve a six-letter word as each wrong guess reveals correct letters from the end. Fewer guesses means a better score."
        headingLevel="h2"
        screenshotAlt="Backword gameplay screen"
        screenshotPosition="left"
        screenshotSrc="/screenshots/backword-game.png"
      />

      <ScreenshotSection
        eyebrow="Daily Crossword"
        title="A quick 9 x 9 crossword every day."
        body="Fifteen clues, a compact grid, and a fresh daily solve built for a few focused minutes."
        headingLevel="h2"
        screenshotAlt="Backword daily crossword screen"
        screenshotPosition="right"
        screenshotSrc="/screenshots/crossword.png"
      />

      <ScreenshotSection
        eyebrow="Weekly Crossword"
        title="A larger 13 x 13 puzzle for a slower challenge."
        body="Settle into a bigger grid with more clues when you want something longer to sit with."
        headingLevel="h2"
        screenshotAlt="Backword weekly crossword screen"
        screenshotPosition="left"
        screenshotSrc="/screenshots/crossword-weekly.png"
      />
    </>
  );
}

type ScreenshotSectionProps = {
  eyebrow: string;
  title: string;
  body: string;
  headingLevel: "h1" | "h2";
  screenshotAlt: string;
  screenshotPosition: "left" | "right";
  screenshotSrc: string;
  children?: ReactNode;
};

function ScreenshotSection({
  eyebrow,
  title,
  body,
  headingLevel,
  screenshotAlt,
  screenshotPosition,
  screenshotSrc,
  children
}: ScreenshotSectionProps) {
  const Heading = headingLevel;
  const text = (
    <div>
      <p className="text-sm font-medium uppercase tracking-[0.18em] text-heading">
        {eyebrow}
      </p>
      <Heading className="mt-5 max-w-3xl text-4xl font-semibold tracking-normal text-textPrimary sm:text-5xl lg:text-6xl">
        {title}
      </Heading>
      <p className="mt-7 max-w-xl text-xl leading-9 text-textSecondary">
        {body}
      </p>
      {children ? <div className="mt-9">{children}</div> : null}
    </div>
  );

  const screenshot = (
    <PhoneMockup src={screenshotSrc} alt={screenshotAlt} />
  );

  return (
    <section className="border-b border-line/80 px-6 py-16 sm:py-24">
      <div className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-2 lg:gap-16">
        {screenshotPosition === "left" ? (
          <>
            <div className="lg:justify-self-start">{screenshot}</div>
            {text}
          </>
        ) : (
          <>
            {text}
            <div className="lg:justify-self-end">{screenshot}</div>
          </>
        )}
      </div>
    </section>
  );
}
