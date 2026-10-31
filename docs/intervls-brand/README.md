# Intervls brand kit

The app and website use Sean's supplied wordmarks:

- `intervls-light2.pdf` — original logo for light surfaces.
- `intervls-dark2.png` — original logo for dark surfaces.

Keep these source files unchanged. The importer trims transparent padding in the PDF/SVG layout, gives both appearances the same logical canvas, and preserves the supplied lettering. The dark website SVG embeds the original PNG bytes unchanged. The light website SVG embeds a 2x transparent rendering of the supplied PDF. No wordmark font is substituted or recreated.

These sources contain raster artwork. PDF/SVG containers do not make the lettering vector artwork. The iOS light PDF retains the original PDF drawing; the dark/share PDFs contain the supplied PNG. The catalog's preserve-vector-representation setting retains the PDF containers at runtime; it does not add resolution to embedded images.

`import-manifest.json` records source hashes, transparent crop bounds, image dimensions, and the shared canvas. Larger vector originals can replace these supplied sources in a future update. Current promotional layouts cap the logo size at the supplied PNG's native resolution rather than enlarging it.

## App icon

`intervls-icon.png` is Sean's current supplied app icon. Keep this source unchanged when importing. `import-icon.swift` exports opaque 1024 × 1024 PNGs to the iOS AppIcon catalog and `web/public/brand/intervls-icon.png`, verifying that every visible pixel is preserved. It also exports the 180 × 180 Apple touch icon. Earlier versions remain as `IV-icon.png`, `intervls-icon-draft.png`, and `previous-app-icon.png`.

The wordmark importer does not write icons. The website favicon is managed separately. To refresh the iOS and web app icons from the repository root:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/intervls-swift-module-cache \
SWIFT_MODULECACHE_PATH=/private/tmp/intervls-swift-module-cache \
swift docs/intervls-brand/import-icon.swift "$PWD"
```

## Outputs

The browser-tab favicon uses `Web tab icon.png`, copied unchanged to
`web/public/brand/intervls-tab-icon.png` and linked from `web/index.html`.
It is separate from the iOS app icon and Apple touch icon. After replacing the
source, copy it again to the public path to update the favicon.

The Apple touch icon uses `intervls-icon.png`, resized to 180 × 180 for Home
Screen shortcuts by `import-icon.swift` above, after removing its unused alpha channel.

| Export | Purpose |
| --- | --- |
| `intervls-light.svg` / `.pdf` | Cropped supplied logo on light surfaces |
| `intervls-dark.svg` / `.pdf` | Cropped supplied logo on dark surfaces and share cards |
| `social-cover-1640x624.png` | Social cover using the supplied dark logo |
| `social-preview-1200x630.png` | Website link preview using the supplied dark logo |
| `app-store-header-3840x1646.png` | Product-page promotional header |
| `app-store-header-5244x2950.png` | Larger product-page promotional header |
| `app-store-search-3840x2560.png` | Search promotional artwork |

Regenerate from the repository root:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/intervls-swift-module-cache \
SWIFT_MODULECACHE_PATH=/private/tmp/intervls-swift-module-cache \
swift docs/intervls-brand/render-brand.swift "$PWD"
```

This updates the website wordmarks/link preview, iOS wordmark image sets, and wordmark-based promotional exports. Outfit is used only for the existing tagline. Game logos, source files, icons, and original screenshots are preserved. Review the updated app in Xcode before release; fresh screenshots/video remain outstanding.

The promotional tagline is **Free daily word games to challenge your mind**.
Its blue matches the iOS Backword Home card in Dark Mode: opaque sRGB `#293364`.
Add `--promotional-only` to regenerate only PNG promotional artwork and the
website link preview while preserving the imported wordmark PDFs/SVGs.
