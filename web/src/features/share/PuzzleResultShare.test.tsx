import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { isChromeBrowser, isSafariBrowser, PuzzleResultShare, shareCardFormat, shareCardRasterPixelSize, sharePuzzleResult } from "./PuzzleResultShare";
import type { PuzzleShareResult } from "./puzzleResult";

const analytics = vi.hoisted(() => ({ track: vi.fn() }));

vi.mock("../analytics/AnalyticsProvider", () => ({ useAnalytics: () => analytics }));

const result: PuzzleShareResult = {
  game: "backword", gameName: "Backword", issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 3, totalGamesSolved: 7,
  ratingTier: "Linguist", ratingPoints: 70, ratingMaxPoints: 140,
  primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, timeStat: { label: "COMPLETED AT", value: "2:30 PM" },
  url: "https://www.playbackword.com/backword/2026-09-16?utm_source=share", caption: "I solved Backword #7"
};

describe("result sharing", () => {
  beforeEach(() => {
    analytics.track.mockClear();
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
    Object.defineProperty(navigator, "canShare", { configurable: true, value: undefined });
    Object.defineProperty(navigator, "clipboard", { configurable: true, value: undefined });
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false }));
  });

  afterEach(() => vi.unstubAllGlobals());

  it("uses the logo rather than decorative tiles in the in-app card preview", () => {
    const { container } = render(<PuzzleResultShare result={result} />);

    expect(container.querySelector(".puzzle-result-share__logo")).toHaveAttribute("src", "/brand/backword-logo.png");
    expect(container.querySelector(".puzzle-result-share__tiles")).not.toBeInTheDocument();
    expect(container.querySelector(".puzzle-result-share__eyebrow")).not.toBeInTheDocument();
    expect(container).toHaveTextContent("3 days");
  });

  it("can render only the share action for completion sheets", () => {
    const { container } = render(<PuzzleResultShare result={result} showPreview={false} />);

    expect(container.querySelector(".puzzle-result-share__preview")).not.toBeInTheDocument();
    expect(container.querySelector(".puzzle-result-share--button-only")).toBeInTheDocument();
  });

  it("renders a compact, icon-led share action for completed game screens", () => {
    const { container } = render(<PuzzleResultShare compact result={result} showPreview={false} />);

    const button = container.querySelector(".puzzle-result-share__button--compact");
    expect(button).toHaveAccessibleName("Share result");
    expect(button).toHaveTextContent("Share");
    expect(button?.querySelector(".puzzle-result-share__icon")).toBeInTheDocument();
    expect(container.querySelector(".puzzle-result-share--compact")).toBeInTheDocument();
  });

  it("uses a PNG image card for both Chrome and Safari", () => {
    expect(shareCardFormat("Mozilla/5.0 Chrome/140.0.0.0 Safari/537.36")).toBe("png");
    expect(shareCardFormat("Mozilla/5.0 Version/18.5 Safari/605.1.15")).toBe("png");
  });

  it("uses a high-resolution PNG that social apps can downsize sharply", () => {
    expect(shareCardRasterPixelSize).toBe(1080);
  });

  it("opens custom share actions for Chrome", async () => {
    const user = userEvent.setup();
    const originalUserAgent = Object.getOwnPropertyDescriptor(navigator, "userAgent");
    Object.defineProperty(navigator, "userAgent", { configurable: true, value: "Mozilla/5.0 Chrome/140.0.0.0 Safari/537.36" });

    try {
      render(<PuzzleResultShare compact result={result} showPreview={false} />);
      await user.click(screen.getByRole("button", { name: "Share result" }));
      expect(screen.getByRole("dialog", { name: "Share result options" })).toBeInTheDocument();
      expect(screen.getByRole("button", { name: "Copy result" })).toBeInTheDocument();
      expect(analytics.track).toHaveBeenCalledWith({
        name: "result_share_opened",
        parameters: { game: "backword", platform: "web", surface: "share_options" }
      });
    } finally {
      if (originalUserAgent) Object.defineProperty(navigator, "userAgent", originalUserAgent);
      else delete (navigator as { userAgent?: string }).userAgent;
    }
  });

  it("identifies Chrome without treating Safari as Chrome", () => {
    expect(isChromeBrowser("Mozilla/5.0 Chrome/140.0.0.0 Safari/537.36")).toBe(true);
    expect(isChromeBrowser("Mozilla/5.0 Version/18.5 Safari/605.1.15")).toBe(false);
  });

  it("opens custom share actions for Safari while its image card is preparing", async () => {
    const user = userEvent.setup();
    const originalUserAgent = Object.getOwnPropertyDescriptor(navigator, "userAgent");
    Object.defineProperty(navigator, "userAgent", { configurable: true, value: "Mozilla/5.0 Version/18.5 Safari/605.1.15" });
    Object.defineProperty(navigator, "share", { configurable: true, value: vi.fn() });

    try {
      const { container } = render(<PuzzleResultShare compact result={result} showPreview={false} />);
      expect(container.querySelector(".puzzle-result-share__button--compact")).toBeEnabled();
      await user.click(screen.getByRole("button", { name: "Share result" }));
      expect(screen.getByRole("dialog", { name: "Share result options" })).toBeInTheDocument();
      expect(screen.getByRole("button", { name: "Copy result" })).toBeInTheDocument();
    } finally {
      if (originalUserAgent) Object.defineProperty(navigator, "userAgent", originalUserAgent);
      else delete (navigator as { userAgent?: string }).userAgent;
    }
  });

  it("identifies Safari without treating other WebKit browsers as Safari", () => {
    expect(isSafariBrowser("Mozilla/5.0 Version/18.5 Safari/605.1.15")).toBe(true);
    expect(isSafariBrowser("Mozilla/5.0 CriOS/140.0.0.0 Mobile/15E148 Safari/604.1")).toBe(false);
  });

  it("waits for the image card before enabling a native share outside the custom-browser menu", () => {
    const originalUserAgent = Object.getOwnPropertyDescriptor(navigator, "userAgent");
    Object.defineProperty(navigator, "userAgent", { configurable: true, value: "Mozilla/5.0 Firefox/141.0" });
    Object.defineProperty(navigator, "share", { configurable: true, value: vi.fn() });

    try {
      const { container } = render(<PuzzleResultShare compact result={result} showPreview={false} />);

      expect(container.querySelector(".puzzle-result-share__button--compact")).toBeDisabled();
      expect(container.querySelector(".puzzle-result-share__button--compact")).toHaveAccessibleName("Preparing share card");
    } finally {
      if (originalUserAgent) Object.defineProperty(navigator, "userAgent", originalUserAgent);
      else delete (navigator as { userAgent?: string }).userAgent;
    }
  });

  it("shares the generated card file when the browser accepts files", async () => {
    vi.stubGlobal("File", class extends Blob {
      name: string;
      constructor(parts: BlobPart[], name: string, options?: FilePropertyBag) { super(parts, options); this.name = name; }
    });
    const nativeShare = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "share", { configurable: true, value: nativeShare });
    Object.defineProperty(navigator, "canShare", { configurable: true, value: vi.fn(() => true) });

    await expect(sharePuzzleResult(result)).resolves.toBe("native_file");
    expect(nativeShare).toHaveBeenCalledWith({ files: [expect.any(Blob)] });
    expect(nativeShare.mock.calls[0][0].text).toBeUndefined();
    expect(nativeShare.mock.calls[0][0].url).toBeUndefined();
    expect(fetch).not.toHaveBeenCalled();
  });

  it("falls back to a native text share when file sharing is unsupported", async () => {
    const nativeShare = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "share", { configurable: true, value: nativeShare });
    Object.defineProperty(navigator, "canShare", { configurable: true, value: vi.fn(() => false) });

    await expect(sharePuzzleResult(result)).resolves.toBe("native_text");
    expect(nativeShare).toHaveBeenCalledWith({
      title: "Backword #7",
      text: result.caption,
      url: result.url
    });
  });

  it("shares text and the result link first when image cards are disabled for Chrome", async () => {
    vi.stubGlobal("File", class extends Blob {
      name: string;
      constructor(parts: BlobPart[], name: string, options?: FilePropertyBag) { super(parts, options); this.name = name; }
    });
    const nativeShare = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "share", { configurable: true, value: nativeShare });
    Object.defineProperty(navigator, "canShare", { configurable: true, value: vi.fn(() => true) });

    await expect(sharePuzzleResult(result, undefined, false)).resolves.toBe("native_text");
    expect(nativeShare).toHaveBeenCalledTimes(1);
    expect(nativeShare).toHaveBeenCalledWith({
      title: "Backword #7",
      text: result.caption,
      url: result.url
    });
  });

  it("copies the result if an image-card share is rejected after the tap gesture", async () => {
    vi.stubGlobal("File", class extends Blob {
      name: string;
      constructor(parts: BlobPart[], name: string, options?: FilePropertyBag) { super(parts, options); this.name = name; }
    });
    const nativeShare = vi.fn().mockRejectedValueOnce(new Error("file unsupported"));
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "share", { configurable: true, value: nativeShare });
    Object.defineProperty(navigator, "canShare", { configurable: true, value: vi.fn(() => true) });
    Object.defineProperty(navigator, "clipboard", { configurable: true, value: { writeText } });

    await expect(sharePuzzleResult(result)).resolves.toBe("clipboard");
    expect(nativeShare).toHaveBeenCalledTimes(1);
    expect(writeText).toHaveBeenCalledWith(result.caption);
  });

  it("copies the full spoiler-safe caption when native sharing is unavailable", async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", { configurable: true, value: { writeText } });

    await expect(sharePuzzleResult(result)).resolves.toBe("clipboard");
    expect(writeText).toHaveBeenCalledWith(result.caption);
  });

  it("uses the compatibility copy path when Chrome blocks the Clipboard API", async () => {
    const execCommand = vi.fn(() => true);
    const originalExecCommand = Object.getOwnPropertyDescriptor(document, "execCommand");
    Object.defineProperty(document, "execCommand", { configurable: true, value: execCommand });

    try {
      await expect(sharePuzzleResult(result)).resolves.toBe("clipboard");
      expect(execCommand).toHaveBeenCalledWith("copy");
    } finally {
      if (originalExecCommand) Object.defineProperty(document, "execCommand", originalExecCommand);
      else delete (document as { execCommand?: Document["execCommand"] }).execCommand;
    }
  });

  it("treats cancellation separately and reports unavailable sharing failures", async () => {
    Object.defineProperty(navigator, "share", { configurable: true, value: vi.fn().mockRejectedValue(new DOMException("cancelled", "AbortError")) });
    await expect(sharePuzzleResult(result)).resolves.toBe("cancelled");

    Object.defineProperty(navigator, "share", { configurable: true, value: vi.fn().mockRejectedValue(new Error("blocked")) });
    await expect(sharePuzzleResult(result)).resolves.toBe("unavailable");
  });
});
