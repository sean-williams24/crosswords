import { act, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  ThemeProvider,
  readThemePreference,
  resolveTheme,
  themeStorageKey,
  useTheme
} from "./ThemeProvider";

type MediaChangeListener = (event: MediaQueryListEvent) => void;

let prefersDark = false;
let mediaListeners = new Set<MediaChangeListener>();

function installMatchMedia() {
  mediaListeners = new Set<MediaChangeListener>();
  Object.defineProperty(window, "matchMedia", {
    configurable: true,
    value: vi.fn(() => ({
      get matches() { return prefersDark; },
      addEventListener: (_event: "change", listener: MediaChangeListener) => mediaListeners.add(listener),
      removeEventListener: (_event: "change", listener: MediaChangeListener) => mediaListeners.delete(listener)
    }))
  });
}

function ThemeProbe() {
  const { preference, resolvedTheme, setPreference } = useTheme();
  return <>
    <output data-testid="theme">{`${preference}:${resolvedTheme}`}</output>
    <button onClick={() => setPreference("light")} type="button">Light</button>
    <button onClick={() => setPreference("dark")} type="button">Dark</button>
    <button onClick={() => setPreference("system")} type="button">System</button>
  </>;
}

describe("ThemeProvider", () => {
  beforeEach(() => {
    window.localStorage.clear();
    document.documentElement.removeAttribute("data-theme");
    document.documentElement.removeAttribute("data-theme-preference");
    document.documentElement.style.removeProperty("color-scheme");
    prefersDark = false;
    installMatchMedia();
  });

  it("defaults to System and resolves it from the computer preference", () => {
    render(<ThemeProvider><ThemeProbe /></ThemeProvider>);

    expect(screen.getByTestId("theme")).toHaveTextContent("system:light");
    expect(document.documentElement).toHaveAttribute("data-theme", "light");
    expect(document.documentElement).toHaveAttribute("data-theme-preference", "system");
  });

  it("uses System for malformed saved values", () => {
    window.localStorage.setItem(themeStorageKey, "sepia");

    expect(readThemePreference(window.localStorage)).toBe("system");
    expect(resolveTheme("system", true)).toBe("dark");
  });

  it("persists explicit selections and applies them to the document", async () => {
    const user = (await import("@testing-library/user-event")).default.setup();
    render(<ThemeProvider><ThemeProbe /></ThemeProvider>);

    await user.click(screen.getByRole("button", { name: "Dark" }));

    expect(window.localStorage.getItem(themeStorageKey)).toBe("dark");
    expect(screen.getByTestId("theme")).toHaveTextContent("dark:dark");
    expect(document.documentElement).toHaveAttribute("data-theme", "dark");
    expect(document.documentElement.style.colorScheme).toBe("dark");
  });

  it("follows live system changes only while System is selected", () => {
    render(<ThemeProvider><ThemeProbe /></ThemeProvider>);

    act(() => {
      prefersDark = true;
      mediaListeners.forEach((listener) => listener({ matches: true } as MediaQueryListEvent));
    });

    expect(screen.getByTestId("theme")).toHaveTextContent("system:dark");
    expect(document.documentElement).toHaveAttribute("data-theme", "dark");
  });
});
