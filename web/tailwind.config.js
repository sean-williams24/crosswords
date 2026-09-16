/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "rgb(var(--app-background-rgb) / <alpha-value>)",
        surface: "rgb(var(--app-surface-rgb) / <alpha-value>)",
        line: "rgb(var(--app-grid-rgb) / <alpha-value>)",
        accent: "rgb(var(--app-accent-rgb) / <alpha-value>)",
        correct: "rgb(var(--app-correct-rgb) / <alpha-value>)",
        heading: "#D6BE87",
        textPrimary: "rgb(var(--app-primary-rgb) / <alpha-value>)",
        textSecondary: "rgb(var(--app-text-secondary-rgb) / <alpha-value>)"
      },
      fontFamily: {
        sans: ["Outfit", "ui-sans-serif", "system-ui", "sans-serif"]
      },
      boxShadow: {
        phone: "0 32px 90px rgba(0, 0, 0, 0.45)"
      }
    }
  },
  plugins: []
};
