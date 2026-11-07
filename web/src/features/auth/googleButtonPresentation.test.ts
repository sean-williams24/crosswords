import { describe, expect, it, vi } from "vitest";
import { observeGoogleButtonReady } from "./googleButtonPresentation";

function googleControls() {
  const container = document.createElement("div");
  const temporaryButton = document.createElement("div");
  temporaryButton.setAttribute("role", "button");
  const iframe = document.createElement("iframe");
  iframe.id = "gsi-test";
  iframe.style.height = "0px";
  iframe.style.width = "0px";
  container.append(temporaryButton, iframe);
  return { container, temporaryButton, iframe };
}

describe("Google button presentation", () => {
  it("retains Google's accessibility proxy when its temporary button is removed", async () => {
    const { container, temporaryButton, iframe } = googleControls();
    const proxy = document.createElement("div");
    proxy.id = `${iframe.id}-overlay`;
    proxy.setAttribute("role", "button");
    proxy.tabIndex = 0;
    container.append(proxy);
    const ready = vi.fn();
    const stop = observeGoogleButtonReady(container, ready);
    try {
      iframe.style.width = "400px";
      iframe.style.height = "44px";
      await Promise.resolve();
      expect(ready).not.toHaveBeenCalled();

      temporaryButton.remove();
      await Promise.resolve();
      expect(ready).toHaveBeenCalledOnce();
      expect(container).toContainElement(proxy);
      expect(proxy).toHaveAttribute("tabindex", "0");

      iframe.style.height = "40px";
      await Promise.resolve();
      expect(ready).toHaveBeenCalledOnce();
    } finally {
      stop();
    }
  });

  it("waits for positive iframe dimensions even if the temporary control is removed first", async () => {
    const { container, temporaryButton, iframe } = googleControls();
    const ready = vi.fn();
    const stop = observeGoogleButtonReady(container, ready);
    try {
      temporaryButton.remove();
      await Promise.resolve();
      expect(ready).not.toHaveBeenCalled();

      iframe.style.width = "400px";
      await Promise.resolve();
      expect(ready).not.toHaveBeenCalled();

      iframe.style.height = "44px";
      await Promise.resolve();
      expect(ready).toHaveBeenCalledOnce();
    } finally {
      stop();
    }
  });

  it("stops observing a control after cleanup", async () => {
    const { container, temporaryButton, iframe } = googleControls();
    const ready = vi.fn();
    const stop = observeGoogleButtonReady(container, ready);
    stop();

    temporaryButton.remove();
    iframe.style.width = "400px";
    iframe.style.height = "44px";
    await Promise.resolve();
    expect(ready).not.toHaveBeenCalled();
  });
});
