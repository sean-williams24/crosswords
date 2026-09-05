import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Link, MemoryRouter, Route, Routes, useLocation } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const auth = {
  accountDeletionNotice: true,
  acknowledgeAccountDeletion: vi.fn(),
  validateAccountSession: vi.fn().mockResolvedValue(undefined)
};

vi.mock("./AuthProvider", () => ({ useAuth: () => auth }));

import { AccountDeletionRecovery } from "./AccountDeletionRecovery";

function LocationProbe() {
  return <p>{useLocation().pathname}</p>;
}

describe("AccountDeletionRecovery", () => {
  beforeEach(() => {
    auth.accountDeletionNotice = true;
    auth.acknowledgeAccountDeletion.mockReset();
    auth.validateAccountSession.mockReset();
    auth.validateAccountSession.mockResolvedValue(undefined);
  });

  it("explains an external deletion before returning the browser to sign-in", async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter initialEntries={["/"]}>
        <Routes>
          <Route path="*" element={<><LocationProbe /><AccountDeletionRecovery /></>} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByRole("dialog", { name: "Your Backword account has been deleted" })).toBeInTheDocument();
    expect(screen.getByText(/If you subscribed through Apple/)).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Continue to sign in" }));

    expect(auth.acknowledgeAccountDeletion).toHaveBeenCalledOnce();
    expect(screen.getByText("/sign-in")).toBeInTheDocument();
  });

  it("revalidates the signed-in account after client-side navigation", async () => {
    const user = userEvent.setup();
    auth.accountDeletionNotice = false;
    render(
      <MemoryRouter initialEntries={["/"]}>
        <Link to="/crossword">Open crossword</Link>
        <LocationProbe />
        <AccountDeletionRecovery />
      </MemoryRouter>
    );

    await user.click(screen.getByRole("link", { name: "Open crossword" }));

    await waitFor(() => expect(auth.validateAccountSession).toHaveBeenCalledOnce());
    expect(screen.getByText("/crossword")).toBeInTheDocument();
  });
});
