/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#0A0A0A",
        surface: "#1A1A1A",
        line: "#2A2A2A",
        accent: "#3377B1",
        correct: "#66BB6A",
        heading: "#D6BE87",
        textPrimary: "#EEEEEE",
        textSecondary: "#777777"
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
