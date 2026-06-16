type PhoneMockupProps = {
  src: string;
  alt: string;
};

export function PhoneMockup({ src, alt }: PhoneMockupProps) {
  return (
    <div className="relative mx-auto w-full max-w-[18rem] sm:max-w-[22rem] lg:max-w-[26rem]">
      <div className="absolute -inset-8 rounded-full bg-accent/10 blur-3xl" />
      <PhoneFrame src={src} alt={alt} />
    </div>
  );
}

type PhoneFrameProps = {
  src: string;
  alt: string;
};

function PhoneFrame({ src, alt }: PhoneFrameProps) {
  return (
    <div className="relative rounded-[2rem] border border-white/10 bg-black p-2 shadow-phone sm:rounded-[2.75rem] sm:p-3">
      <div className="absolute left-1/2 top-4 z-10 h-2 w-14 -translate-x-1/2 rounded-full bg-black/80 sm:top-5 sm:h-2.5 sm:w-20" />
      <div className="aspect-[1206/2622] overflow-hidden rounded-[1.55rem] bg-ink sm:rounded-[2.2rem]">
        <img className="h-full w-full object-cover" src={src} alt={alt} />
      </div>
    </div>
  );
}
