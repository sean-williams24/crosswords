import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const analytics = vi.hoisted(() => ({ track: vi.fn() }));

vi.mock("../analytics/AnalyticsProvider", () => ({ useAnalytics: () => analytics }));

import { ProAccessRedirect } from "./ProAccessRedirect";

describe("ProAccessRedirect", () => {
  beforeEach(() => analytics.track.mockClear());

  it("records the bounded protected feature before navigating to Pro", () => {
    render(
      <MemoryRouter initialEntries={["/archive"]}>
        <Routes>
          <Route element={<ProAccessRedirect feature="archive" returnTo="/archive?game=weekly" />} path="/archive" />
          <Route element={<p>Pro plans</p>} path="/pro" />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText("Pro plans")).toBeInTheDocument();
    expect(analytics.track).toHaveBeenCalledWith({ name: "pro_access_gate_redirected", parameters: { feature: "archive" } });
  });
});
