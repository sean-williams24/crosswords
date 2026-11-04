# Intervls App Store artwork

## iPhone Home — 4 November 2026

[Upload PNG](upload-ready/iphone-6.1-6.3/01-home-1206x2622.png): **1206 × 2622**, opaque sRGB. Awaiting Sean’s review.

Uses the supplied 1170 × 2532 Home capture unchanged in `sources/home.png`. The caption remains “Four free” / “daily games”, with the existing Outfit Bold typography, blue-to-navy background and matte black phone.

Rendered with the native `../2026-10-19/render-iphone.swift` workflow, using a temporary copy with only the Home source entry changed to `source: "home.png", sourceWidth: 1170, sourceHeight: 2532`. Run that copy with this folder as its asset root and `home` as the selected key. The source is downsampled once at scale 918/1170; its aspect ratio is preserved. No image-generation tool was used.

`generated/home.png` is byte-identical to the upload PNG. `home-render-validation.json` records source/export hashes, dimensions and color checks. Native verification confirms the background, headline and phone frame are pixel-identical to the previous artwork outside the display. The PNG was visually inspected. No iOS builds or simulator checks were run.

The historical October set is unchanged. iPhone Home and iPad Home have been refreshed here; other App Store placements remain pending review in `docs/intervls-rebrand/capture-manifest.json`.

## iPad Home — 4 November 2026

[Upload PNG](upload-ready/ipad-13/05-ipad-2064x2752.png): **2064 × 2752**, opaque sRGB. Awaiting Sean’s review.

The supplied full-resolution 2064 × 2752 capture is preserved unchanged in `sources/ipad.png`. The new artwork keeps the approved blue-to-navy gradient, matte black tablet, Outfit Bold font and device placement. Its headline uses the approved copy: “Free daily word games” / “to challenge your mind”.

Rendered using a temporary copy of `../2026-10-19/render-ipad.swift` with only `captions` changed to `["Free daily word games", "to challenge your mind"]`, and this folder passed as the asset root. The screenshot is downsampled once to 1560 × 2080 with its aspect ratio retained. The existing corner mask removes the simulator resize handle from the exported composition; the original capture is untouched. No image-generation tool was used.

`generated/ipad.png` is byte-identical to the upload PNG. `ipad-render-validation.json` records source/export hashes, dimensions, headline centering, removal of the simulator handle, and seven color checks. The background and tablet frame are pixel-identical to the historical artwork outside the screenshot and revised headline. The finished PNG was visually inspected. No iOS build or simulator checks were run.
