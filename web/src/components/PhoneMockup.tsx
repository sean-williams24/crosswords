const screenshots = [
  {
    src: "/screenshots/home.png",
    alt: "Backword home screen",
    className: "translate-y-8 opacity-90"
  },
  {
    src: "/screenshots/backword-game.png",
    alt: "Backword gameplay screen",
    className: "z-10"
  },
  {
    src: "/screenshots/crossword.png",
    alt: "Backword crossword screen",
    className: "translate-y-8 opacity-90"
  }
] as const;

export function PhoneMockup() {
  return (
    <div className="relative mx-auto w-full max-w-[38rem]">
      <div className="absolute -inset-x-8 top-10 h-72 rounded-full bg-accent/10 blur-3xl" />
      <div className="relative grid grid-cols-3 items-end gap-3 sm:gap-5">
        {screenshots.map((screenshot) => (
          <PhoneFrame key={screenshot.src} {...screenshot} />
        ))}
      </div>
    </div>
  );
}

type PhoneFrameProps = {
  src: string;
  alt: string;
  className?: string;
};

function PhoneFrame({ src, alt, className = "" }: PhoneFrameProps) {
  return (
    <div
      className={`relative rounded-[1.7rem] border border-white/10 bg-black p-1.5 shadow-phone sm:rounded-[2.2rem] sm:p-2.5 ${className}`}
    >
      <div className="absolute left-1/2 top-3 z-10 h-1.5 w-10 -translate-x-1/2 rounded-full bg-black/80 sm:top-4 sm:h-2 sm:w-14" />
      <div className="aspect-[1206/2622] overflow-hidden rounded-[1.3rem] bg-ink sm:rounded-[1.65rem]">
        <img className="h-full w-full object-cover" src={src} alt={alt} />
      </div>
    </div>
  );
}
