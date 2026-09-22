import { useEffect, useState } from "react";
import { useAnalytics } from "../analytics/AnalyticsProvider";
import { resultShared } from "../analytics/events";
import type { PuzzleShareResult } from "./puzzleResult";

type ShareMethod = "native_file" | "native_text" | "clipboard";

type ShareCardPalette = {
  background: string;
  border?: string;
  statBackground: string;
  statLabel: string;
  footer: string;
};

type ShareCardFontSources = {
  regular?: string;
  bold?: string;
  semiBold?: string;
};

/** A 1080px source stays sharp when social apps downsize it for display. */
const shareCardPixelSize = 1080;
export const shareCardRasterPixelSize = shareCardPixelSize;
const shareCardCornerRadius = 48;

/** Keep the exported card in step with the corresponding iOS share card. */
function shareCardPalette(game: PuzzleShareResult["game"]): ShareCardPalette {
  switch (game) {
    case "backword":
      // The opaque sRGB result of Dark Mode BackwordBackground over the
      // dark crossword backing used by the iOS home card.
      return { background: "#293364", statBackground: "#000000", statLabel: "#999999", footer: "#2a2a2a" };
    case "daily_crossword":
      return { background: "#43668f", statBackground: "#000000", statLabel: "#999999", footer: "#e0ddd6" };
    case "weekly_crossword":
      return { background: "#1e1d1b", border: "url(#pro-border)", statBackground: "#000000", statLabel: "#777777", footer: "#ebb838" };
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
  logoSource = new URL("/brand/backword-logo-share.svg", result.url).href,
  fontSources?: ShareCardFontSources
): string {
  const palette = shareCardPalette(result.game);
  const titleText = `${result.gameName} #${result.issueNumber}`;
  const title = escapeSvg(titleText);
  const titleFontSize = Math.max(58, Math.min(86, 86 * 13 / titleText.length));
  const outcome = escapeSvg(result.outcome);
  const logoUrl = escapeSvg(logoSource);
  const normalCaseValue = (value: string) => value.replace(/\b(?:AM|PM)\b/g, (match) => match.toLowerCase());
  const ratingLevel = escapeSvg(result.ratingTier);
  const ratingPoints = escapeSvg(`${result.ratingPoints}/${result.ratingMaxPoints} pts`);
  const score = escapeSvg(`${result.score} ${result.score === 1 ? "pt" : "pts"}`);
  const streak = escapeSvg(`${result.streak} ${result.streak === 1 ? "day" : "days"}`);
  const primary = escapeSvg(normalCaseValue(result.primaryStat.value));
  const primaryLabel = escapeSvg(result.primaryStat.label);
  const timeLabel = escapeSvg(result.timeStat?.label ?? "TOTAL SOLVED");
  const time = escapeSvg(normalCaseValue(result.timeStat?.value ?? `${result.totalGamesSolved}`));
  const fontFace = fontSources?.regular || fontSources?.bold || fontSources?.semiBold
    ? `<style>${fontSources.regular ? `@font-face { font-family: "Outfit"; src: url("${escapeSvg(fontSources.regular)}") format("truetype"); font-weight: 400; }` : ""}${fontSources.bold ? `@font-face { font-family: "Outfit"; src: url("${escapeSvg(fontSources.bold)}") format("truetype"); font-weight: 700; }` : ""}${fontSources.semiBold ? `@font-face { font-family: "Outfit"; src: url("${escapeSvg(fontSources.semiBold)}") format("truetype"); font-weight: 600; }` : ""}</style>`
    : "";
  const stat = (x: number, y: number, height: number, label: string, value: string) => `<rect x="${x}" y="${y}" width="452" height="${height}" rx="42" fill="${palette.statBackground}" fill-opacity="0.2"/><text x="${x + 30}" y="${y + 60}" fill="${palette.statLabel}" font-family="Outfit, sans-serif" font-size="31" font-weight="700" letter-spacing="3">${label}</text><text x="${x + 30}" y="${y + 145}" fill="#ffffff" font-family="Outfit, sans-serif" font-size="52" font-weight="400">${value}</text>`;
  const ratingStat = (x: number, y: number) => `<rect x="${x}" y="${y}" width="452" height="250" rx="42" fill="${palette.statBackground}" fill-opacity="0.2"/><text x="${x + 30}" y="${y + 60}" fill="${palette.statLabel}" font-family="Outfit, sans-serif" font-size="31" font-weight="700" letter-spacing="3">CURRENT RATING</text><text x="${x + 30}" y="${y + 145}" fill="#ffffff" font-family="Outfit, sans-serif" font-size="52" font-weight="400">${ratingLevel}</text><text x="${x + 30}" y="${y + 215}" fill="#ffffff" font-family="Outfit, sans-serif" font-size="44" font-weight="400">${ratingPoints}</text>`;
  const border = palette.border ? `<rect x="1.5" y="1.5" width="1077" height="1077" rx="${shareCardCornerRadius}" fill="none" stroke="${palette.border}" stroke-width="3"/>` : "";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${shareCardPixelSize}" height="${shareCardPixelSize}" viewBox="0 0 1080 1080" role="img" aria-label="${title} result card"><defs>${fontFace}<linearGradient id="pro-border" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#d9a640"/><stop offset="0.5" stop-color="#c78533"/><stop offset="1" stop-color="#d9a640"/></linearGradient></defs><rect width="1080" height="1080" rx="${shareCardCornerRadius}" fill="${palette.background}"/>${border}<image href="${logoUrl}" x="752" y="76" width="252" height="126" preserveAspectRatio="xMidYMid meet"/><text x="64" y="145" fill="#ffffff" font-family="Outfit, sans-serif" font-size="${titleFontSize}" font-weight="700">${title}</text><text x="64" y="205" fill="#ebb838" font-family="Outfit, sans-serif" font-size="27" font-weight="700" letter-spacing="4">${outcome}</text>${stat(64, 250, 200, "TODAY'S SCORE", score)}${stat(564, 250, 200, primaryLabel, primary)}${ratingStat(64, 480)}${stat(564, 480, 250, "CURRENT STREAK", streak)}${stat(64, 760, 190, timeLabel, time)}<text x="1016" y="1010" fill="${palette.footer}" font-family="Outfit, sans-serif" font-size="55" font-weight="700" letter-spacing="3" text-anchor="end">playbackword.com</text></svg>`;
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
  return embeddedAssetSource(new URL("/brand/backword-logo-share.svg", result.url).href);
}

async function embeddedFontSources(result: PuzzleShareResult): Promise<ShareCardFontSources> {
  const [regular, bold, semiBold] = await Promise.all([
    embeddedAssetSource(new URL("/fonts/Outfit-Regular.ttf", result.url).href),
    embeddedAssetSource(new URL("/fonts/Outfit-Bold.ttf", result.url).href),
    embeddedAssetSource(new URL("/fonts/Outfit-SemiBold.ttf", result.url).href)
  ]);
  return { regular, bold, semiBold };
}

async function embeddedAssetSource(url: string): Promise<string> {
  try {
    const response = await fetch(url);
    return response.ok ? await readAsDataUrl(await response.blob()) : url;
  } catch {
    return url;
  }
}

function createImmediateCardFile(result: PuzzleShareResult): File | null {
  if (typeof File === "undefined") return null;
  return new File([puzzleResultCardSvg(result)], `backword-${result.game}-${result.issueNumber}.svg`, {
    type: "image/svg+xml"
  });
}

type ShareCardFormat = "png" | "svg";

/** Native share sheets handle a raster image more consistently than an SVG file. */
export function shareCardFormat(_userAgent: string): ShareCardFormat {
  return "png";
}

export function isChromeBrowser(userAgent: string): boolean {
  return /(?:Chrome|CriOS)\//i.test(userAgent);
}

export function isSafariBrowser(userAgent: string): boolean {
  return /Safari\//i.test(userAgent) && !/(?:Chrome|CriOS|Chromium|FxiOS|EdgiOS)\//i.test(userAgent);
}

async function rasterizeCard(svg: string): Promise<Blob | null> {
  if (typeof Image === "undefined" || typeof URL.createObjectURL !== "function") return null;

  return new Promise((resolve) => {
    const source = URL.createObjectURL(new Blob([svg], { type: "image/svg+xml" }));
    const image = new Image();
    image.onload = () => {
      const canvas = document.createElement("canvas");
      canvas.width = shareCardRasterPixelSize;
      canvas.height = shareCardRasterPixelSize;
      const context = canvas.getContext("2d");
      if (!context) {
        URL.revokeObjectURL(source);
        resolve(null);
        return;
      }
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(source);
      canvas.toBlob((blob) => resolve(blob), "image/png");
    };
    image.onerror = () => {
      URL.revokeObjectURL(source);
      resolve(null);
    };
    image.src = source;
  });
}

async function createEmbeddedCardFile(result: PuzzleShareResult, format: ShareCardFormat): Promise<File | null> {
  if (typeof File === "undefined") return null;
  const [logoSource, fontSources] = await Promise.all([embeddedLogoSource(result), embeddedFontSources(result)]);
  const svg = puzzleResultCardSvg(result, logoSource, fontSources);
  if (format === "png") {
    const png = await rasterizeCard(svg);
    return png ? new File([png], `backword-${result.game}-${result.issueNumber}.png`, { type: "image/png" }) : null;
  }
  return new File([svg], `backword-${result.game}-${result.issueNumber}.svg`, {
    type: "image/svg+xml"
  });
}

async function copyCaption(result: PuzzleShareResult): Promise<boolean> {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(result.caption);
      return true;
    }
  } catch {
    // Fall through to the legacy copy path, which also works on HTTP localhost.
  }

  const textarea = document.createElement("textarea");
  textarea.value = result.caption;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.append(textarea);
  textarea.select();
  const copied = document.execCommand?.("copy") ?? false;
  textarea.remove();
  return copied;
}

async function share(
  result: PuzzleShareResult,
  cardFile: File | null = createImmediateCardFile(result),
  shareImageCard = true
): Promise<ShareMethod | "cancelled" | "unavailable"> {
  const data = { title: `${result.gameName} #${result.issueNumber}`, text: result.caption, url: result.url };
  if (shareImageCard && cardFile && navigator.share && (!navigator.canShare || navigator.canShare({ files: [cardFile] }))) {
    try {
      // iOS copies a file and accompanying text as separate rich items. Share the
      // card alone here so the Copy action produces one pasteable result.
      await navigator.share({ files: [cardFile] });
      return "native_file";
    } catch (error) {
      if ((error as DOMException).name === "AbortError") return "cancelled";
      return await copyCaption(result) ? "clipboard" : "unavailable";
    }
  }
  try {
    if (navigator.share) {
      await navigator.share(data);
      return "native_text";
    }
    return await copyCaption(result) ? "clipboard" : "unavailable";
  } catch (error) {
    if ((error as DOMException).name === "AbortError") return "cancelled";
    return await copyCaption(result) ? "clipboard" : "unavailable";
  }
}

export function PuzzleResultShare({
  result,
  showPreview = true,
  compact = false
}: {
  result: PuzzleShareResult;
  showPreview?: boolean;
  compact?: boolean;
}) {
  const { track } = useAnalytics();
  const [status, setStatus] = useState("");
  const [embeddedCardFile, setEmbeddedCardFile] = useState<File | null>(null);
  const [showShareActions, setShowShareActions] = useState(false);
  const cardFormat = shareCardFormat(navigator.userAgent);
  const cardKey = JSON.stringify(result);
  const isChrome = isChromeBrowser(navigator.userAgent);
  const isSafari = isSafariBrowser(navigator.userAgent);
  // Chrome and Safari use our in-page menu. Keep that menu available while the
  // PNG is prepared so Copy result remains usable; its image actions appear as
  // soon as the card is ready.
  const isCardReady = isChrome || isSafari || !navigator.share || embeddedCardFile !== null;

  useEffect(() => {
    let isCurrent = true;
    setEmbeddedCardFile(null);
    void createEmbeddedCardFile(result, cardFormat).then((file) => {
      if (isCurrent) setEmbeddedCardFile(file);
    });
    return () => { isCurrent = false; };
  }, [cardFormat, cardKey]);

  function currentCardFile() {
    return embeddedCardFile ?? (cardFormat === "svg" ? createImmediateCardFile(result) : null);
  }

  async function copyCardImage() {
    const cardFile = currentCardFile();
    if (!cardFile || !navigator.clipboard?.write || typeof ClipboardItem === "undefined") {
      setStatus("Image copying is unavailable here. Download the card instead.");
      return;
    }
    try {
      await navigator.clipboard.write([new ClipboardItem({ [cardFile.type]: cardFile })]);
      setStatus("Image copied to clipboard");
    } catch {
      setStatus("Image copying is unavailable here. Download the card instead.");
    }
  }

  function downloadCard() {
    const cardFile = currentCardFile();
    if (!cardFile) {
      setStatus("Your image card is still preparing");
      return;
    }
    const url = URL.createObjectURL(cardFile);
    const link = document.createElement("a");
    link.href = url;
    link.download = cardFile.name;
    link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 0);
    setStatus("Image card downloaded");
  }

  async function copyResultText() {
    setStatus(await copyCaption(result) ? "Result copied to clipboard" : "Copying is unavailable in this browser");
  }

  async function shareCard() {
    // Browser share APIs require invocation during the tap gesture. The card is
    // pre-rendered as a PNG so every native share sheet receives an image.
    const cardFile = currentCardFile();
    const method = await share(
      result,
      cardFile,
      cardFile !== null
    );
    if (method === "cancelled") return;
    if (method === "unavailable") {
      setStatus("Sharing is unavailable on this browser");
      return;
    }
    track(resultShared(result.game, method));
    setStatus(method === "clipboard" ? "Result copied to clipboard" : "Result shared");
  }

  function handleShare() {
    if (isChrome || isSafari) {
      setShowShareActions(true);
      return;
    }
    void shareCard();
  }

  return <section aria-label="Share your result" className={`puzzle-result-share${showPreview ? "" : " puzzle-result-share--button-only"}${compact ? " puzzle-result-share--compact" : ""}`}>
    {showPreview ? <div aria-hidden="true" className="puzzle-result-share__preview">
      <img alt="" className="puzzle-result-share__logo" src="/brand/backword-logo.png" />
      <strong>{result.gameName} #{result.issueNumber}</strong>
      <div className="puzzle-result-share__stats"><span>{result.score} {result.score === 1 ? "PT" : "PTS"}</span><span>{result.primaryStat.value}</span><span>{result.ratingTier} {result.ratingPoints}/{result.ratingMaxPoints} PTS</span><span>{result.streak} {result.streak === 1 ? "day" : "days"}</span></div>
    </div> : null}
    <button aria-label={compact ? isCardReady ? "Share result" : "Preparing share card" : undefined} className={`bw-secondary-button puzzle-result-share__button${compact ? " puzzle-result-share__button--compact" : ""}`} disabled={!isCardReady} onClick={() => void handleShare()} type="button">
      {compact ? isCardReady ? <><svg aria-hidden="true" className="puzzle-result-share__icon" viewBox="0 0 24 24"><path d="M12 15V3m0 0 4 4m-4-4L8 7M5 11v8a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-8" /></svg>Share</> : "Preparing…" : "Share result"}
    </button>
    {showShareActions ? <div aria-label="Share result options" className="puzzle-result-share__fallback" role="dialog">
      {currentCardFile() ? <><button onClick={() => void shareCard()} type="button">Share image</button><button onClick={() => void copyCardImage()} type="button">Copy image</button><button onClick={downloadCard} type="button">Download card</button></> : <p>Image card is still preparing.</p>}
      <button onClick={() => void copyResultText()} type="button">Copy result</button>
    </div> : null}
    <span aria-live="polite" className="bw-share-status">{status}</span>
  </section>;
}

export { share as sharePuzzleResult };
