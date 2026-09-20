import { useState } from "react";
import { useAnalytics } from "../analytics/AnalyticsProvider";
import { resultShared } from "../analytics/events";
import type { PuzzleShareResult } from "./puzzleResult";

type ShareMethod = "native_file" | "native_text" | "clipboard";

type ShareCardPalette = {
  background: string;
  border?: string;
  statBackground: string;
  statLabel: string;
};

/** Keep the exported card in step with the corresponding iOS share card. */
function shareCardPalette(game: PuzzleShareResult["game"]): ShareCardPalette {
  switch (game) {
    case "backword":
      return { background: "#aba7dc", statBackground: "#000000", statLabel: "#393947" };
    case "daily_crossword":
      return { background: "#43668f", statBackground: "#000000", statLabel: "#999999" };
    case "weekly_crossword":
      return { background: "#1e1d1b", border: "url(#pro-border)", statBackground: "#000000", statLabel: "#777777" };
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
  const titleText = `${result.gameName} #${result.issueNumber}`;
  const title = escapeSvg(titleText);
  const titleFontSize = Math.max(48, Math.min(68, 68 * 13 / titleText.length));
  const logoUrl = escapeSvg(logoSource);
  const outcome = escapeSvg(result.outcome);
  const ratingLevel = escapeSvg(result.ratingTier.toUpperCase());
  const ratingPoints = escapeSvg(`${result.ratingPoints}/${result.ratingMaxPoints} PTS`);
  const score = escapeSvg(`${result.score} ${result.score === 1 ? "PT" : "PTS"}`);
  const streak = escapeSvg(`${result.streak} ${result.streak === 1 ? "DAY" : "DAYS"}`);
  const primary = escapeSvg(result.primaryStat.value);
  const primaryLabel = escapeSvg(result.primaryStat.label);
  const timeLabel = escapeSvg(result.timeStat?.label ?? "TOTAL SOLVED");
  const time = escapeSvg(result.timeStat?.value ?? `${result.totalGamesSolved}`);
  const fontFace = fontSource ? `<style>@font-face { font-family: "Outfit"; src: url("${escapeSvg(fontSource)}") format("truetype"); font-weight: 700; }</style>` : "";
  const stat = (x: number, y: number, height: number, label: string, value: string) => `<rect x="${x}" y="${y}" width="450" height="${height}" rx="32" fill="${palette.statBackground}" fill-opacity="0.2"/><text x="${x + 25}" y="${y + 45}" fill="${palette.statLabel}" font-family="Outfit, sans-serif" font-size="18" font-weight="700" letter-spacing="2.7">${label}</text><text x="${x + 25}" y="${y + 103}" fill="#ffffff" font-family="Outfit, sans-serif" font-size="32" font-weight="700">${value}</text>`;
  const ratingStat = (x: number, y: number) => `<rect x="${x}" y="${y}" width="450" height="181" rx="32" fill="${palette.statBackground}" fill-opacity="0.2"/><text x="${x + 25}" y="${y + 45}" fill="${palette.statLabel}" font-family="Outfit, sans-serif" font-size="18" font-weight="700" letter-spacing="2.7">CURRENT RATING</text><text x="${x + 25}" y="${y + 103}" fill="#ffffff" font-family="Outfit, sans-serif" font-size="32" font-weight="700">${ratingLevel}</text><text x="${x + 25}" y="${y + 145}" fill="#ffffff" font-family="Outfit, sans-serif" font-size="32" font-weight="700">${ratingPoints}</text>`;
  const border = palette.border ? `<rect x="1.5" y="1.5" width="1077" height="1077" fill="none" stroke="${palette.border}" stroke-width="3"/>` : "";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1080" viewBox="0 0 1080 1080" role="img" aria-label="${title} result card"><defs>${fontFace}<linearGradient id="pro-border" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#d9a640"/><stop offset="0.5" stop-color="#c78533"/><stop offset="1" stop-color="#d9a640"/></linearGradient></defs><rect width="1080" height="1080" fill="${palette.background}"/>${border}<image href="${logoUrl}" x="752" y="76" width="252" height="126" preserveAspectRatio="xMidYMid meet"/><text x="76" y="139" fill="#ffffff" font-family="Outfit, sans-serif" font-size="${titleFontSize}" font-weight="700">${title}</text><text x="76" y="195" fill="#ebb838" font-family="Outfit, sans-serif" font-size="20" font-weight="700" letter-spacing="3.6">${outcome}</text>${stat(76, 256, 143, "TODAY'S SCORE", score)}${stat(554, 256, 143, primaryLabel, primary)}${ratingStat(76, 428)}${stat(554, 428, 181, "CURRENT STREAK", streak)}${stat(76, 638, 143, timeLabel, time)}<text x="1004" y="880" fill="#ebb838" font-family="Outfit, sans-serif" font-size="43" font-weight="700" letter-spacing="2.7" text-anchor="end">playbackword.com</text></svg>`;
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
      <div className="puzzle-result-share__stats"><span>{result.score} {result.score === 1 ? "PT" : "PTS"}</span><span>{result.primaryStat.value}</span><span>{result.ratingTier} {result.ratingPoints}/{result.ratingMaxPoints} PTS</span><span>{result.streak} {result.streak === 1 ? "day" : "days"}</span></div>
    </div> : null}
    <button className="bw-secondary-button puzzle-result-share__button" onClick={() => void handleShare()} type="button">Share result</button>
    <span aria-live="polite" className="bw-share-status">{status}</span>
  </section>;
}

export { share as sharePuzzleResult };
