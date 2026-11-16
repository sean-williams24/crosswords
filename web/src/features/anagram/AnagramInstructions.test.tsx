import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AnagramInstructions } from "./AnagramInstructions";

describe("Anagram hint instructions", () => {
  it("explains the one-letter hint and time penalty without offering ads", () => {
    const { container } = render(<AnagramInstructions />);
    expect(screen.getByText(/You can reveal one letter per game/)).toBeInTheDocument();
    expect(screen.getByText("Revealing a letter adds 30 seconds to your scoring time.")).toBeInTheDocument();
    expect(container).not.toHaveTextContent(/watch|rewarded ad|ad-free/i);
  });
});
