import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const auth = vi.hoisted(() => ({
  entitlement: null as { isPro: boolean; expiresAt: string | null } | null
}));

vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => auth }));

import { Footer } from "./Footer";

describe("Footer", () => {
  beforeEach(() => {
    auth.entitlement = null;
  });

  it("organizes footer columns and links in the requested order", () => {
    render(<MemoryRouter><Footer /></MemoryRouter>);
    const footer = screen.getByRole("navigation", { name: "Footer" });
    const groups = [
      {
        title: "Explore",
        links: [["Home", "/"], ["Player Profile", "/player-profile"]]
      },
      {
        title: "Free games",
        links: [
          ["Backword", "/backword"],
          ["Crossword", "/crossword"],
          ["Midword", "/midword"],
          ["Anagram", "/anagram"]
        ]
      },
      {
        title: "Pro Account",
        links: [
          ["Pro Crossword", "/pro?return_to=%2Fweekly-crossword"],
          ["Archive", "/pro?return_to=%2Farchive"],
          ["Subscribe", "/pro"]
        ]
      },
      {
        title: "Support",
        links: [["Info", "/info"], ["Contact", "/contact"]]
      },
      {
        title: "Legal",
        links: [["Privacy", "/privacy"], ["Privacy Choices", "/privacy-choices"], ["Terms", "/terms"]]
      },
      {
        title: "Socials",
        links: [
          ["Instagram", "https://instagram.com/play.backword?dlrf=MTg1d3pmcmsydzIycA%3D%3D&utm_source=qr"],
          ["TikTok", "https://www.tiktok.com/@play.backword"],
          ["Facebook", "https://www.facebook.com/share/1CWvuRkqxe/?mibextid=wwXIfr"]
        ]
      }
    ];

    expect(within(footer).getAllByRole("heading", { level: 2 }).map((heading) => heading.textContent))
      .toEqual(groups.map(({ title }) => title));
    expect(within(footer).getAllByRole("link")).toHaveLength(17);
    for (const { title, links } of groups) {
      const group = within(footer).getByRole("region", { name: title });
      expect(within(group).getByRole("heading", { name: title, level: 2 })).toBeInTheDocument();
      const list = within(group).getByRole("list");
      expect(within(list).getAllByRole("listitem")).toHaveLength(links.length);
      expect(within(list).getAllByRole("link").map((link) => link.textContent))
        .toEqual(links.map(([label]) => label));
      for (const [label, destination] of links) {
        expect(within(list).getByRole("link", { name: label })).toHaveAttribute("href", destination);
      }
    }

    expect(screen.getByText("© 2026 Backword")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Download Backword on the App Store from footer" })).toBeInTheDocument();
  });

  it("gives two and three columns equal outer and inner spacing and flanks the top row on large screens", () => {
    render(<MemoryRouter><Footer /></MemoryRouter>);

    const footer = screen.getByRole("contentinfo");
    const navigation = within(footer).getByRole("navigation", { name: "Footer" });
    const copyright = within(footer).getByText("© 2026 Backword");
    const badge = within(footer).getByRole("link", { name: "Download Backword on the App Store from footer" });
    const layout = navigation.parentElement;

    expect(footer).toHaveClass("px-0", "lg:px-6");
    expect(layout).toHaveClass("grid", "items-start", "justify-items-center", "gap-8", "lg:grid-cols-[auto_minmax(0,1fr)_auto]", "lg:gap-x-16");
    expect(copyright.parentElement).toBe(layout);
    expect(badge.parentElement?.parentElement).toBe(layout);
    expect(navigation).toHaveClass("order-1", "lg:order-2", "justify-self-stretch", "lg:grid-cols-[repeat(6,max-content)]", "lg:justify-between");
    expect(navigation).toHaveClass("grid-cols-[repeat(2,max-content)]", "sm:grid-cols-[repeat(3,max-content)]", "justify-evenly", "gap-x-0");
    expect(copyright).toHaveClass("order-2", "text-center", "lg:order-1", "lg:justify-self-start");
    expect(badge.parentElement).toHaveClass("order-3", "lg:justify-self-end");
  });

  it("sends non-Pro subscribers to Pro and Pro subscribers to the protected destinations", () => {
    const { rerender } = render(<MemoryRouter><Footer /></MemoryRouter>);
    const footer = screen.getByRole("navigation", { name: "Footer" });

    expect(within(footer).getByRole("link", { name: "Pro Crossword" })).toHaveAttribute("href", "/pro?return_to=%2Fweekly-crossword");
    expect(within(footer).getByRole("link", { name: "Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive");
    expect(within(footer).getByRole("link", { name: "Anagram" })).toHaveAttribute("href", "/anagram");
    expect(within(footer).getByRole("link", { name: "Midword" })).toHaveAttribute("href", "/midword");
    expect(within(footer).getByRole("link", { name: "Subscribe" })).toHaveAttribute("href", "/pro");

    auth.entitlement = { isPro: true, expiresAt: null };
    rerender(<MemoryRouter><Footer /></MemoryRouter>);

    expect(within(footer).getByRole("link", { name: "Pro Crossword" })).toHaveAttribute("href", "/weekly-crossword");
    expect(within(footer).getByRole("link", { name: "Archive" })).toHaveAttribute("href", "/archive");
    expect(within(footer).getByRole("link", { name: "Midword" })).toHaveAttribute("href", "/midword");
    expect(within(footer).queryByRole("link", { name: "Subscribe" })).not.toBeInTheDocument();
    const explore = within(footer).getByRole("region", { name: "Explore" });
    expect(within(explore).getByRole("link", { name: "Player Profile" })).toHaveAttribute("href", "/player-profile");
    const proAccount = within(footer).getByRole("region", { name: "Pro Account" });
    expect(within(proAccount).getAllByRole("link").map((link) => link.textContent))
      .toEqual(["Pro Crossword", "Archive"]);
  });
});
