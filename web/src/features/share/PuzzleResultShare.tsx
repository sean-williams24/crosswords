import { useState } from "react";
import { useAnalytics } from "../analytics/AnalyticsProvider";
import { resultShared } from "../analytics/events";
import type { PuzzleShareResult } from "./puzzleResult";

type ShareMethod = "native_file" | "native_text" | "clipboard";

type ShareCardPalette = {
  backgroundStart: string;
  backgroundMiddle?: string;
  backgroundEnd: string;
  border: string;
  statBackground: string;
  divider: string;
  play: string;
};

/** Keep the exported card in step with the dark Home card for each game. */
function shareCardPalette(game: PuzzleShareResult["game"]): ShareCardPalette {
  switch (game) {
    case "backword":
      return { backgroundStart: "#34417c", backgroundEnd: "#29356d", border: "#5e78b8", statBackground: "#252f60", divider: "#7284b5", play: "#9ad7a0" };
    case "daily_crossword":
      return { backgroundStart: "#30445e", backgroundEnd: "#24364d", border: "#5e7d98", statBackground: "#203147", divider: "#7790a6", play: "#91c8df" };
    case "weekly_crossword":
      return { backgroundStart: "#211e19", backgroundMiddle: "#1a1a1a", backgroundEnd: "#221d15", border: "#b8872d", statBackground: "#1b1a19", divider: "#746342", play: "#d6be87" };
  }
}

function escapeSvg(value: string) {
  return value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&apos;"
  })[character] ?? character);
}

/** A deliberately abstract graphic: it renders only result metadata, never game content. */
export function puzzleResultCardSvg(
  result: PuzzleShareResult,
  logoSource = new URL("/brand/backword-logo.png", result.url).href,
  fontSource?: string
): string {
  const palette = shareCardPalette(result.game);
  const title = escapeSvg(`${result.gameName} #${result.issueNumber}`);
  const logoUrl = escapeSvg(logoSource);
  const outcome = escapeSvg(result.outcome);
  const ratingLevel = escapeSvg(result.ratingTier.toUpperCase());
  const ratingPoints = escapeSvg(`${result.ratingPoints}/${result.ratingMaxPoints} PTS`);
  const score = escapeSvg(`${result.score} ${result.score === 1 ? "PT" : "PTS"}`);
  const streak = escapeSvg(`${result.streak} ${result.streak === 1 ? "DAY" : "DAYS"}`);
  const primary = escapeSvg(result.primaryStat.value);
  const primaryLabel = escapeSvg(result.primaryStat.label);
  const timeLabel = escapeSvg(result.timeStat?.label ?? "PLAY");
  const time = escapeSvg(result.timeStat?.value ?? "playbackword.com");
  const backgroundStops = `<stop stop-color="${palette.backgroundStart}"/>${palette.backgroundMiddle ? `<stop offset="0.55" stop-color="${palette.backgroundMiddle}"/>` : ""}<stop offset="1" stop-color="${palette.backgroundEnd}"/>`;
  const fontFace = fontSource ? `<style>@font-face { font-family: "Outfit"; src: url("${escapeSvg(fontSource)}") format("truetype"); font-weight: 700; }</style>` : "";
  const stat = (x: number, y: number, label: string, value: string, fontSize = 30) => `<rect x="${x}" y="${y}" width="430" height="176" rx="30" fill="${palette.statBackground}"/><text x="${x + 30}" y="${y + 48}" fill="#d0d7df" font-family="Outfit, sans-serif" font-size="18" font-weight="700" letter-spacing="3">${label}</text><text x="${x + 30}" y="${y + 118}" fill="#f6f6f6" font-family="Outfit, sans-serif" font-size="${fontSize}" font-weight="700">${value}</text>`;
  const ratingStat = (x: number, y: number) => `<rect x="${x}" y="${y}" width="430" height="176" rx="30" fill="${palette.statBackground}"/><text x="${x + 30}" y="${y + 48}" fill="#d0d7df" font-family="Outfit, sans-serif" font-size="18" font-weight="700" letter-spacing="3">CURRENT RATING</text><text x="${x + 30}" y="${y + 103}" fill="#f6f6f6" font-family="Outfit, sans-serif" font-size="29" font-weight="700">${ratingLevel}</text><text x="${x + 30}" y="${y + 145}" fill="#f6f6f6" font-family="Outfit, sans-serif" font-size="24" font-weight="700">${ratingPoints}</text>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1080" viewBox="0 0 1080 1080" role="img" aria-label="${title} result card"><defs>${fontFace}<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">${backgroundStops}</linearGradient></defs><rect x="16" y="16" width="1048" height="1048" rx="64" fill="url(#bg)" stroke="${palette.border}" stroke-width="3"/><image href="${logoUrl}" x="770" y="66" width="220" height="114" preserveAspectRatio="xMidYMid meet"/><text x="70" y="138" fill="#f6f6f6" font-family="Outfit, sans-serif" font-size="54" font-weight="700">${title}</text><text x="70" y="195" fill="#dfc37b" font-family="Outfit, sans-serif" font-size="23" font-weight="700" letter-spacing="5">${outcome}</text><line x1="70" y1="252" x2="1010" y2="252" stroke="${palette.divider}" stroke-width="2"/>${stat(70, 310, "TODAY'S SCORE", score, 42)}${stat(580, 310, primaryLabel, primary, 42)}${ratingStat(70, 536)}${stat(580, 536, "CURRENT STREAK", streak, 29)}${stat(70, 762, timeLabel, time, 30)}<text x="1010" y="1010" fill="#dfc37b" font-family="Outfit, sans-serif" font-size="26" font-weight="700" letter-spacing="3" text-anchor="end">playbackword.com</text></svg>`;
}

function readAsDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => typeof reader.result === "string" ? resolve(reader.result) : reject(new Error("Logo data could not be read"));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

async function embeddedLogoSource(result: PuzzleShareResult): Promise<string> {
  return embeddedAssetSource(new URL("/brand/backword-logo.png", result.url).href);
}

async function embeddedFontSource(result: PuzzleShareResult): Promise<string> {
  return embeddedAssetSource(new URL("/fonts/Outfit-Bold.ttf", result.url).href);
}

async function embeddedAssetSource(url: string): Promise<string> {
  try {
    const response = await fetch(url);
    return response.ok ? await readAsDataUrl(await response.blob()) : url;
  } catch {
    return url;
  }
}

async function createCardFile(result: PuzzleShareResult): Promise<File | null> {
  if (typeof File === "undefined") return null;
  const [logoSource, fontSource] = await Promise.all([embeddedLogoSource(result), embeddedFontSource(result)]);
  return new File([puzzleResultCardSvg(result, logoSource, fontSource)], `backword-${result.game}-${result.issueNumber}.svg`, {
    type: "image/svg+xml"
  });
}

async function share(result: PuzzleShareResult): Promise<ShareMethod | "cancelled" | "unavailable"> {
  const data = { title: `${result.gameName} #${result.issueNumber}`, text: result.caption };
  const file = await createCardFile(result);
  if (file && navigator.share && (!navigator.canShare || navigator.canShare({ files: [file] }))) {
    try {
      // iOS copies a file and accompanying text as separate rich items. Share the
      // card alone here so the Copy action produces one pasteable result.
      await navigator.share({ files: [file] });
      return "native_file";
    } catch (error) {
      if ((error as DOMException).name === "AbortError") return "cancelled";
    }
  }
  try {
    if (navigator.share) {
      await navigator.share(data);
      return "native_text";
    }
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(result.caption);
      return "clipboard";
    }
    return "unavailable";
  } catch (error) {
    return (error as DOMException).name === "AbortError" ? "cancelled" : "unavailable";
  }
}

export function PuzzleResultShare({ result, showPreview = true }: { result: PuzzleShareResult; showPreview?: boolean }) {
  const { track } = useAnalytics();
  const [status, setStatus] = useState("");

  async function handleShare() {
    const method = await share(result);
    if (method === "cancelled") return;
    if (method === "unavailable") {
      setStatus("Sharing is unavailable on this browser");
      return;
    }
    track(resultShared(result.game, method));
    setStatus(method === "clipboard" ? "Result copied to clipboard" : "Result shared");
  }

  return <section aria-label="Share your result" className={`puzzle-result-share${showPreview ? "" : " puzzle-result-share--button-only"}`}>
    {showPreview ? <div aria-hidden="true" className="puzzle-result-share__preview">
      <img alt="" className="puzzle-result-share__logo" src="/brand/backword-logo.png" />
      <strong>{result.gameName} #{result.issueNumber}</strong>
      <div className="puzzle-result-share__stats"><span>{result.score} PTS</span><span>{result.primaryStat.value}</span><span>{result.ratingTier} {result.ratingPoints}/{result.ratingMaxPoints} PTS</span><span>{result.streak} {result.streak === 1 ? "day" : "days"} streak</span></div>
    </div> : null}
    <button className="bw-secondary-button puzzle-result-share__button" onClick={() => void handleShare()} type="button">Share result</button>
    <span aria-live="polite" className="bw-share-status">{status}</span>
  </section>;
}

export { share as sharePuzzleResult };
