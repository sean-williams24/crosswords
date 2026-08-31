import { fireEvent, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { AnalyticsProvider, AnalyticsRouteTracker } from "./AnalyticsProvider";
import { analyticsConsentStorageKey } from "./consent";

describe("AnalyticsProvider", () => {
  beforeEach(() => window.localStorage.clear());
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("requires an explicit choice and persists a decline", () => {
    render(<MemoryRouter><AnalyticsProvider><AnalyticsRouteTracker /><p>Page</p></AnalyticsProvider></MemoryRouter>);

    expect(screen.getByRole("dialog", { name: "Analytics preferences" })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Decline" }));
    expect(screen.queryByRole("dialog", { name: "Analytics preferences" })).not.toBeInTheDocument();
    expect(window.localStorage.getItem(analyticsConsentStorageKey)).toBe("declined");
  });

  it("persists an explicit acceptance", () => {
    window.history.replaceState({}, "", "/?utm_source=tiktok&utm_medium=organic_social&utm_campaign=launch");
    render(<MemoryRouter><AnalyticsProvider><AnalyticsRouteTracker /><p>Page</p></AnalyticsProvider></MemoryRouter>);

    fireEvent.click(screen.getByRole("button", { name: "Accept analytics" }));
    expect(window.localStorage.getItem(analyticsConsentStorageKey)).toBe("accepted");
    expect(window.localStorage.getItem("backword:web:analytics:first-campaign:v1")).toContain("tiktok");
  });
});
