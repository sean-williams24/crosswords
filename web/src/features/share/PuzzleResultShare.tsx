import { useState } from "react";
import { useAnalytics } from "../analytics/AnalyticsProvider";
import { resultShared } from "../analytics/events";
import type { PuzzleShareResult } from "./puzzleResult";

type ShareMethod = "native_file" | "native_text" | "clipboard";

function escapeSvg(value: string) {
  return value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&apos;"
  })[character] ?? character);
}

/** A deliberately abstract graphic: it renders only result metadata, never game content. */
export function puzzleResultCardSvg(result: PuzzleShareResult, logoSource = new URL("/brand/backword-logo.png", result.url).href): string {
  const title = escapeSvg(`${result.gameName} #${result.issueNumber}`);
  const logoUrl = escapeSvg(logoSource);
  const rating = escapeSvg(`${result.ratingTier.toUpperCase()} · ${result.ratingPoints}/${result.ratingMaxPoints} PTS`);
  const score = escapeSvg(`${result.score} PTS`);
  const streak = escapeSvg(`${result.streak} ${result.streak === 1 ? "DAY" : "DAYS"} STREAK`);
  const primary = escapeSvg(result.primaryStat.value);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="230" viewBox="0 0 1200 230" role="img" aria-label="${title} result card"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#171b1e"/><stop offset="1" stop-color="#1d2c37"/></linearGradient></defs><rect x="1" y="1" width="1198" height="228" rx="34" fill="url(#bg)" stroke="#285b81" stroke-width="2"/><image href="${logoUrl}" x="974" y="18" width="170" height="87" preserveAspectRatio="xMidYMid meet"/><text x="44" y="88" fill="#f6f6f6" font-family="Arial, sans-serif" font-size="40" font-weight="700">${title}</text><rect x="44" y="135" width="90" height="52" rx="26" fill="#111416" stroke="#394044" stroke-width="2"/><text x="60" y="168" fill="#c0c2c3" font-family="Arial, sans-serif" font-size="19" font-weight="700">${score}</text><rect x="150" y="135" width="74" height="52" rx="26" fill="#111416" stroke="#394044" stroke-width="2"/><text x="168" y="168" fill="#c0c2c3" font-family="Arial, sans-serif" font-size="19" font-weight="700">${primary}</text><rect x="240" y="135" width="218" height="52" rx="26" fill="#111416" stroke="#394044" stroke-width="2"/><text x="258" y="168" fill="#c0c2c3" font-family="Arial, sans-serif" font-size="19" font-weight="700">${rating}</text><rect x="474" y="135" width="164" height="52" rx="26" fill="#111416" stroke="#394044" stroke-width="2"/><text x="492" y="168" fill="#c0c2c3" font-family="Arial, sans-serif" font-size="17" font-weight="700">${streak}</text></svg>`;
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
  const logoUrl = new URL("/brand/backword-logo.png", result.url).href;
  try {
    const response = await fetch(logoUrl);
    return response.ok ? await readAsDataUrl(await response.blob()) : logoUrl;
  } catch {
    return logoUrl;
  }
}

async function createCardFile(result: PuzzleShareResult): Promise<File | null> {
  if (typeof File === "undefined") return null;
  const logoSource = await embeddedLogoSource(result);
  return new File([puzzleResultCardSvg(result, logoSource)], `backword-${result.game}-${result.issueNumber}.svg`, {
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
