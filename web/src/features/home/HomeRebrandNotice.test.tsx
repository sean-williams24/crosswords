import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes, useLocation } from "react-router-dom";
import { HomeRebrandNotice } from "./HomeRebrandNotice";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const auth = vi.hoisted(() => ({ ready: true, user: null as { id: string } | null }));
vi.mock("../auth/AuthProvider", () => ({ useAuth: () => auth }));

function Destination() {
  const location = useLocation();
  return <p>{location.pathname} return to {location.state?.returnTo ?? "none"}</p>;
}

function show() {
  return render(
    <MemoryRouter>
      <Routes>
        <Route path="/" element={<HomeRebrandNotice />} />
        <Route path="/sign-in" element={<Destination />} />
        <Route path="/player-profile" element={<Destination />} />
      </Routes>
    </MemoryRouter>
  );
}

beforeEach(() => {
  auth.ready = true;
  auth.user = null;
  vi.stubGlobal("location", new URL("https://www.playbackword.com/"));
});
afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

describe("Home advance rebrand notice", () => {
  it("shares the Word of the Day label's title colour", () => {
    const noticeStyles = readFileSync(resolve(process.cwd(), "src/features/home/HomeRebrandNotice.css"), "utf8");
    const appStyles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const noticeColor = noticeStyles.match(/\.home-rebrand-notice h2\s*\{[^}]*color:\s*([^;]+);/)?.[1];
    const wotdColor = appStyles.match(/\.wotd-detail \.wotd-card__label\s*\{[^}]*color:\s*([^;]+);/)?.[1];

    expect(wotdColor).toBe("var(--app-wotd-title)");
    expect(noticeColor).toBe(wotdColor);
  });

  it("renders the notice container and action without borders", () => {
    const stylesheet = document.createElement("style");
    stylesheet.textContent = readFileSync(resolve(process.cwd(), "src/features/home/HomeRebrandNotice.css"), "utf8");
    document.head.appendChild(stylesheet);
    try {
      show();
      for (const element of [screen.getByRole("complementary"), screen.getByRole("link", { name: "Sign in to save history" })]) {
        expect(window.getComputedStyle(element).borderWidth).toBe("0px");
      }
    } finally {
      stylesheet.remove();
    }
  });

  it.each(["https://playbackword.com", "https://www.playbackword.com"])("announces the move on %s and explains what happens to history", (origin) => {
    vi.stubGlobal("location", new URL(origin));
    show();

    expect(screen.getByRole("complementary", { name: "Backword is becoming Intervls later this week" })).toBeInTheDocument();
    expect(screen.getByText(/Sign in with Apple or Google before the move/)).toBeInTheDocument();
    expect(screen.getByText(/use the same account on Intervls to access your synced history/)).toBeInTheDocument();
    expect(screen.getByText("Browser-only history and unsynced saves won’t transfer to the new website.")).toBeInTheDocument();
  });

  it("takes guests to sign-in and returns them Home for the existing history sync", async () => {
    show();
    await userEvent.click(screen.getByRole("link", { name: "Sign in to save history" }));
    expect(screen.getByText("/sign-in return to /")).toBeInTheDocument();
  });

  it.each(["http://localhost:5173", "http://127.0.0.1:5173", "http://[::1]:5173"])("shows the notice for local development at %s", (origin) => {
    vi.stubEnv("DEV", true);
    vi.stubGlobal("location", new URL(origin));
    show();

    expect(screen.getByRole("complementary", { name: "Backword is becoming Intervls later this week" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Sign in to save history" })).toHaveAttribute("href", "/sign-in");
  });

  it("does not enable the local development exception in a production build", () => {
    vi.stubEnv("DEV", false);
    vi.stubGlobal("location", new URL("http://localhost:5173"));
    show();
    expect(screen.queryByRole("complementary")).not.toBeInTheDocument();
  });

  it("asks signed-in players to check history without claiming it is already synced", async () => {
    auth.user = { id: "player-1" };
    show();

    expect(screen.getByText(/check your game history in Player Profile/)).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Sign in to save history" })).not.toBeInTheDocument();
    expect(screen.getByText(/same Apple or Google account to access your synced history/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole("link", { name: "Check game history" }));
    expect(screen.getByText("/player-profile return to none")).toBeInTheDocument();
  });

  it.each(["https://intervls.com", "https://www.intervls.com", "https://preview.vercel.app", "https://playbackword.com.example.com"])("hides the advance notice on %s", (origin) => {
    vi.stubGlobal("location", new URL(origin));
    show();
    expect(screen.queryByRole("complementary")).not.toBeInTheDocument();
  });

  it("waits for account startup before choosing a sign-in or history action", () => {
    auth.ready = false;
    show();
    expect(screen.queryByRole("complementary")).not.toBeInTheDocument();
  });
});
