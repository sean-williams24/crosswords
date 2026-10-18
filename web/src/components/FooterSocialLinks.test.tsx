import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { FooterSocialLinks } from "./FooterSocialLinks";

describe("FooterSocialLinks", () => {
  it("renders named social links in order with their supplied destinations", () => {
    render(<FooterSocialLinks links={[
      { label: "Instagram", href: "https://example.com/instagram" },
      { label: "TikTok", href: "https://example.com/tiktok" },
      { label: "Facebook", href: "https://example.com/facebook" }
    ]} />);

    const socials = screen.getByRole("region", { name: "Socials" });
    expect(within(socials).getByRole("heading", { level: 2, name: "Socials" })).toBeInTheDocument();
    const links = within(socials).getAllByRole("link");
    expect(links.map((link) => link.textContent)).toEqual(["Instagram", "TikTok", "Facebook"]);
    expect(links.map((link) => link.getAttribute("href"))).toEqual([
      "https://example.com/instagram", "https://example.com/tiktok", "https://example.com/facebook"
    ]);
    for (const link of links) {
      expect(link).toHaveAttribute("target", "_blank");
      expect(link).toHaveAttribute("rel", "noopener noreferrer");
      expect(link.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
    }
  });
});
