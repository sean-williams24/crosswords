import { loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig(({ mode }) => {
  const env = { ...loadEnv(mode, process.cwd(), ""), ...process.env };
  const indexingAllowed = env.VITE_REBRAND_LAUNCH_ENABLED === "true" && env.VERCEL_ENV === "production";
  return {
    define: { "import.meta.env.VITE_REBRAND_INDEXING_ALLOWED": JSON.stringify(String(indexingAllowed)) },
    plugins: [react(), {
      name: "intervls-indexing",
      transformIndexHtml(html: string) {
        return html.replace("__INTERVLS_ROBOTS__", indexingAllowed ? "index,follow" : "noindex,nofollow");
      }
    }],
    test: {
      environment: "jsdom",
      globals: true,
      setupFiles: "./src/test/setup.ts"
    }
  };
});
