/** Google removes its temporary inline button after sizing the iframe. */
export function observeGoogleButtonReady(container: HTMLElement, onReady: () => void) {
  const observer = new MutationObserver(() => {
    const iframe = container.querySelector("iframe");
    if (!iframe || !(parseFloat(iframe.style.height) > 0) || !(parseFloat(iframe.style.width) > 0)) return;

    // Some browsers use Google's accessible overlay beside the iframe. That
    // proxy stays mounted; only the temporary inline control must be gone.
    const hasTemporaryButton = Array.from(container.querySelectorAll('button, [role="button"]'))
      .some((button) => button.id !== `${iframe.id}-overlay`);
    if (hasTemporaryButton) return;

    observer.disconnect();
    onReady();
  });
  observer.observe(container, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["style", "role"]
  });
  return () => observer.disconnect();
}
