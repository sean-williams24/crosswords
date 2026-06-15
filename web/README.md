# Backword Web

Minimal Vite + React website for Backword, ready for Vercel static hosting and future Supabase-powered gameplay.

## Scripts

```bash
npm install
npm run dev
npm run build
npm run preview
npm run test
```

## Replace Before Launch

- `src/lib/siteConfig.ts`: production App Store URL, support email, and display metadata.
- `src/content/legal.ts`: reviewed privacy policy and terms copy.
- `public/app-ads.txt`: production Google AdMob publisher line.

## Future Supabase Game

When the browser game is added, use Vite environment variables:

```bash
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

Keep browser game integration in `src/lib` and page-level gameplay in `src/pages` or feature-specific folders.
