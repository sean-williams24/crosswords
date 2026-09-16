import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export const themeStorageKey = "backword:web:theme:v1";

export type ThemePreference = "light" | "dark" | "system";
export type ResolvedTheme = Exclude<ThemePreference, "system">;

type ThemeContextValue = {
  preference: ThemePreference;
  resolvedTheme: ResolvedTheme;
  setPreference: (preference: ThemePreference) => void;
};

const fallbackTheme: ThemeContextValue = {
  preference: "system",
  resolvedTheme: "dark",
  setPreference: () => undefined
};

const ThemeContext = createContext<ThemeContextValue>(fallbackTheme);

function isThemePreference(value: unknown): value is ThemePreference {
  return value === "light" || value === "dark" || value === "system";
}

export function readThemePreference(storage: Pick<Storage, "getItem">): ThemePreference {
  try {
    const value = storage.getItem(themeStorageKey);
    return isThemePreference(value) ? value : "system";
  } catch {
    return "system";
  }
}

export function writeThemePreference(storage: Pick<Storage, "setItem">, preference: ThemePreference) {
  try {
    storage.setItem(themeStorageKey, preference);
  } catch {
    // Theme selection remains available when browser storage is unavailable.
  }
}

export function resolveTheme(preference: ThemePreference, systemPrefersDark: boolean): ResolvedTheme {
  if (preference === "system") return systemPrefersDark ? "dark" : "light";
  return preference;
}

export function applyTheme(documentElement: HTMLElement, preference: ThemePreference, resolvedTheme: ResolvedTheme) {
  documentElement.dataset.theme = resolvedTheme;
  documentElement.dataset.themePreference = preference;
  documentElement.style.colorScheme = resolvedTheme;
}

function systemPrefersDark() {
  return window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? false;
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [preference, setPreferenceState] = useState<ThemePreference>(() => readThemePreference(window.localStorage));
  const [prefersDark, setPrefersDark] = useState(systemPrefersDark);
  const resolvedTheme = resolveTheme(preference, prefersDark);

  useEffect(() => {
    const mediaQuery = window.matchMedia?.("(prefers-color-scheme: dark)");
    if (!mediaQuery) return;

    const updateSystemTheme = (event: MediaQueryListEvent) => setPrefersDark(event.matches);
    setPrefersDark(mediaQuery.matches);
    mediaQuery.addEventListener("change", updateSystemTheme);
    return () => mediaQuery.removeEventListener("change", updateSystemTheme);
  }, []);

  useEffect(() => {
    applyTheme(document.documentElement, preference, resolvedTheme);
  }, [preference, resolvedTheme]);

  const setPreference = (nextPreference: ThemePreference) => {
    writeThemePreference(window.localStorage, nextPreference);
    setPreferenceState(nextPreference);
  };

  const value = useMemo(() => ({ preference, resolvedTheme, setPreference }), [preference, resolvedTheme]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  return useContext(ThemeContext);
}
