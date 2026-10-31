import { useEffect } from "react";
import { useLocation } from "react-router-dom";
import { brand } from "./brand";

const pageNames: Record<string, string> = {
  "/": "Free daily word games", "/info": "Daily word games", "/backword": "Backword",
  "/midword": "Midword", "/anagram": "Anagram", "/crossword": "Quick Crossword",
  "/pro": "intervls Pro", "/contact": "Contact", "/privacy": "Privacy Policy",
  "/privacy-choices": "Privacy Choices", "/terms": "Terms of Use"
};

export function routeMetadata(pathname: string, origin: string, launched = brand.launchEnabled && brand.indexingEnabled) {
  const basePath = pathname.replace(/\/\d{4}-\d{2}-\d{2}$/, "");
  const name = pageNames[basePath];
  const canonical = new URL(brand.origin);
  canonical.pathname = pathname;
  const title = basePath === "/" ? brand.homeTitle : name ? `${name} | intervls` : "intervls";
  return {
    title,
    socialTitle: basePath === "/" ? `Intervls — ${brand.tagline}` : title,
    canonical: canonical.href,
    robots: launched && origin === brand.origin && name ? "index,follow" : "noindex,follow"
  };
}

export function SiteMetadata() {
  const { pathname } = useLocation();
  useEffect(() => {
    const metadata = routeMetadata(pathname, window.location.origin);
    document.title = metadata.title;
    for (const [name, content] of [["robots", metadata.robots], ["og:title", metadata.socialTitle], ["og:url", metadata.canonical]]) {
      const attribute = name.startsWith("og:") ? "property" : "name";
      let element = document.querySelector<HTMLMetaElement>(`meta[${attribute}="${name}"]`);
      if (!element) { element = document.createElement("meta"); element.setAttribute(attribute, name); document.head.appendChild(element); }
      element.content = content;
    }
    let canonical = document.querySelector<HTMLLinkElement>('link[rel="canonical"]');
    if (!canonical) { canonical = document.createElement("link"); canonical.rel = "canonical"; document.head.appendChild(canonical); }
    canonical.href = metadata.canonical;
  }, [pathname]);
  return null;
}
