import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { Link, MemoryRouter } from "react-router-dom";
import { SiteMetadata } from "./SiteMetadata";

describe("browser titles and social previews", () => {
  let previousHead: string;
  beforeEach(() => { previousHead = document.head.innerHTML; });
  afterEach(() => { document.head.innerHTML = previousHead; });

  it("keeps the approved Home title when navigating away and back", () => {
    render(<MemoryRouter><SiteMetadata /><Link to="/backword/2026-10-30">Play Backword</Link><Link to="/">Home</Link></MemoryRouter>);
    expect(document.title).toBe("Intervls — Free daily word games");
    expect(document.querySelector('meta[property="og:title"]')).toHaveAttribute("content", "Intervls — Free daily word games to challenge your mind");

    fireEvent.click(screen.getByRole("link", { name: "Play Backword" }));
    expect(document.title).toBe("Backword | Intervls");
    fireEvent.click(screen.getByRole("link", { name: "Home" }));
    expect(document.title).toBe("Intervls — Free daily word games");
    expect(document.querySelector('meta[property="og:title"]')).toHaveAttribute("content", "Intervls — Free daily word games to challenge your mind");
  });
});
