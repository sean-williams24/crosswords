import { fireEvent, render, screen } from "@testing-library/react";
import { MemoryRouter, useNavigate } from "react-router-dom";
import { ScrollToTop } from "./ScrollToTop";

function TestNavigation() {
  const navigate = useNavigate();

  return <button onClick={() => navigate("/next")}>Next page</button>;
}

describe("ScrollToTop", () => {
  it("resets the viewport when navigation changes the page path", () => {
    const scrollTo = vi.spyOn(window, "scrollTo").mockImplementation(() => undefined);

    render(
      <MemoryRouter initialEntries={["/current"]}>
        <ScrollToTop />
        <TestNavigation />
      </MemoryRouter>
    );

    scrollTo.mockClear();
    fireEvent.click(screen.getByRole("button", { name: "Next page" }));

    expect(scrollTo).toHaveBeenCalledWith(0, 0);
  });
});
