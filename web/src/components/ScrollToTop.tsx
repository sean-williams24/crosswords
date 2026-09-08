import { useEffect } from "react";
import { useLocation } from "react-router-dom";

/** Resets the viewport when client-side navigation loads a different page. */
export function ScrollToTop() {
  const { pathname } = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  return null;
}
