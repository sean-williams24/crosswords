import { render } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PuzzleResultShare, sharePuzzleResult } from "./PuzzleResultShare";
import type { PuzzleShareResult } from "./puzzleResult";

const result: PuzzleShareResult = {
  game: "backword", gameName: "Backword", issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 3, totalGamesSolved: 7,
  ratingTier: "Linguist", ratingPoints: 70, ratingMaxPoints: 140,
  primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, timeStat: { label: "COMPLETED AT", value: "2:30 PM" },
  url: "https://www.playbackword.com/backword/2026-09-16?utm_source=share", caption: "I solved Backword #7"
};

describe("result sharing", () => {
  beforeEach(() => {
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
  });

  it("falls back to a native text share when file sharing is unsupported", async () => {
    const nativeShare = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "share", { configurable: true, value: nativeShare });
    Object.defineProperty(navigator, "canShare", { configurable: true, value: vi.fn(() => false) });

    await expect(sharePuzzleResult(result)).resolves.toBe("native_text");
    expect(nativeShare).toHaveBeenCalledWith(expect.not.objectContaining({ files: expect.anything() }));
  });

  it("retries as text if a browser accepts files but rejects the card", async () => {
    vi.stubGlobal("File", class extends Blob {
      name: string;
      constructor(parts: BlobPart[], name: string, options?: FilePropertyBag) { super(parts, options); this.name = name; }
    });
    const nativeShare = vi.fn().mockRejectedValueOnce(new Error("file unsupported")).mockResolvedValueOnce(undefined);
    Object.defineProperty(navigator, "share", { configurable: true, value: nativeShare });
    Object.defineProperty(navigator, "canShare", { configurable: true, value: vi.fn(() => true) });

    await expect(sharePuzzleResult(result)).resolves.toBe("native_text");
    expect(nativeShare).toHaveBeenLastCalledWith(expect.not.objectContaining({ files: expect.anything() }));
  });

  it("copies the full spoiler-safe caption when native sharing is unavailable", async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", { configurable: true, value: { writeText } });

    await expect(sharePuzzleResult(result)).resolves.toBe("clipboard");
    expect(writeText).toHaveBeenCalledWith(result.caption);
  });

  it("treats cancellation separately and reports unavailable sharing failures", async () => {
    Object.defineProperty(navigator, "share", { configurable: true, value: vi.fn().mockRejectedValue(new DOMException("cancelled", "AbortError")) });
    await expect(sharePuzzleResult(result)).resolves.toBe("cancelled");

    Object.defineProperty(navigator, "share", { configurable: true, value: vi.fn().mockRejectedValue(new Error("blocked")) });
    await expect(sharePuzzleResult(result)).resolves.toBe("unavailable");
  });
});
