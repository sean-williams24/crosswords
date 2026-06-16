import { useEffect, useRef } from "react";

type PhoneMockupProps = {
  src: string;
  alt: string;
  size?: "default" | "compact";
};

export function PhoneMockup({ src, alt, size = "default" }: PhoneMockupProps) {
  const widthClass =
    size === "compact"
      ? "max-w-[16rem] sm:max-w-[19rem] lg:max-w-[22rem]"
      : "max-w-[18rem] sm:max-w-[22rem] lg:max-w-[26rem]";

  return (
    <div className={`relative mx-auto w-full ${widthClass}`}>
      <PhoneFrame src={src} alt={alt} />
    </div>
  );
}

type PhoneFrameProps = {
  src: string;
  alt: string;
};

function PhoneFrame({ src, alt }: PhoneFrameProps) {
  const isVideo = src.endsWith(".mp4") || src.endsWith(".webm");

  return (
    <div className="relative rounded-[2rem] border border-white/10 bg-black p-2 sm:rounded-[2.75rem] sm:p-3">
      <div className="absolute left-1/2 top-4 z-10 h-2 w-14 -translate-x-1/2 rounded-full bg-black/80 sm:top-5 sm:h-2.5 sm:w-20" />
      <div className="aspect-[1206/2622] overflow-hidden rounded-[1.55rem] bg-ink sm:rounded-[2.2rem]">
        {isVideo ? (
          <AutoPlayVideo src={src} label={alt} />
        ) : (
          <img className="h-full w-full object-cover" src={src} alt={alt} />
        )}
      </div>
    </div>
  );
}

type AutoPlayVideoProps = {
  src: string;
  label: string;
};

function AutoPlayVideo({ src, label }: AutoPlayVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) {
      return;
    }

    video.defaultMuted = true;
    video.muted = true;

    if (navigator.userAgent.includes("jsdom")) {
      return;
    }

    const playPromise = video.play();
    if (playPromise) {
      playPromise.catch(() => {
        // Some browsers block autoplay in low-power or data-saver modes.
      });
    }
  }, []);

  return (
    <video
      aria-label={label}
      autoPlay
      className="h-full w-full object-cover"
      controls={false}
      disablePictureInPicture
      loop
      muted
      playsInline
      poster="/screenshots/home.png"
      preload="auto"
      ref={videoRef}
      src={src}
    />
  );
}
