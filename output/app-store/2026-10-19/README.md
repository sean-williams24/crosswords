# App Store screenshots — 19 October 2026

Upload the PNGs from the folder that matches the App Store Connect display slot:

- **iPhone 6.1-inch / 6.3-inch:** `upload-ready/iphone-6.1-6.3/` — eight PNGs, exactly **1206 × 2622**.
- **iPad 13-inch:** `upload-ready/ipad-13/` — one PNG, exactly **2064 × 2752**.

These dimensions match the displayed iPhone upload requirements and Apple's
[screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
All nine exports are opaque PNGs tagged sRGB.

| Export | Caption |
| --- | --- |
| [01-home-1206x2622.png](upload-ready/iphone-6.1-6.3/01-home-1206x2622.png) | Four free daily games |
| [02-backword-1206x2622.png](upload-ready/iphone-6.1-6.3/02-backword-1206x2622.png) | Guess forwards. Reveal backwards. |
| [03-quick-crossword-1206x2622.png](upload-ready/iphone-6.1-6.3/03-quick-crossword-1206x2622.png) | Your daily crossword fix |
| [04-midword-1206x2622.png](upload-ready/iphone-6.1-6.3/04-midword-1206x2622.png) | Find the missing link |
| [05-ipad-2064x2752.png](upload-ready/ipad-13/05-ipad-2064x2752.png) | Your daily word game ritual |
| [06-anagram-1206x2622.png](upload-ready/iphone-6.1-6.3/06-anagram-1206x2622.png) | Unscramble the Anagram |
| [07-pro-crossword-1206x2622.png](upload-ready/iphone-6.1-6.3/07-pro-crossword-1206x2622.png) | Solve a deeper weekly crossword |
| [08-archive-1206x2622.png](upload-ready/iphone-6.1-6.3/08-archive-1206x2622.png) | Play all past puzzles in the archive |
| [09-rating-1206x2622.png](upload-ready/iphone-6.1-6.3/09-rating-1206x2622.png) | Climb the rating tiers |

The iPad headline is smaller and uses approximately the same final pixel letter
size as the iPhone headlines. Its complete two-line block remains centered
vertically between the canvas top and the device frame, as do all iPhone titles.
The dark blue-to-navy backgrounds and reference typography are retained.

The iPad master is now rendered directly at **2064 × 2752** using the original
full-resolution capture and native Core Text for the headline. Its app screen
is composited from `sources/ipad.png` with one downsample to fit the tablet
frame; no smaller artwork is enlarged. The upload PNG is identical to this
native master. The original screenshot's simulator resize handle is excluded
from the otherwise empty bottom-right corner.

To rebuild the iPad artwork from the project root:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/backword-swift-module-cache \
SWIFT_MODULECACHE_PATH=/private/tmp/backword-swift-module-cache \
swift output/app-store/2026-10-19/render-ipad.swift \
  "$PWD/output/app-store/2026-10-19"
```

The script uses the existing Outfit Bold font. Change headline text in the
script and rerender from the original capture for future iPad copy revisions.
[ipad-full-resolution-validation.json](ipad-full-resolution-validation.json)
records native dimensions, source scale, source colour checks and centering.

The Archive artwork is also rendered natively from its original capture,
`sources/archive.png`, with Core Text/Outfit Bold and the same dark gradient.
Its title is centered above the phone at a 52px capital height. Rebuild using
`render-archive.swift` with the same asset-directory argument as the iPad
renderer. [archive-render-validation.json](archive-render-validation.json)
records dimensions, source preservation, colour and title-centering checks.

The Anagram and iPhone Pro Crossword images were downloaded from the App Store
and resized on 20 October 2026 using Core Graphics, without regeneration or
layout changes. Their 1242 × 2688 originals remain in `sources/`; only resizing
and opaque sRGB PNG export were applied.
The additional rating screenshot is preserved as supplied at 1206 × 2622,
with its original bytes also saved in `sources/app-store-rating-1206x2622.png`.

`sources/` retains the original app captures and existing App Store style
reference. Home uses `sources/home-new.png` (1206 × 2622); the earlier Home
capture remains in `sources/home.png`. `generated/` contains intermediate
iPhone image_gen compositions before export, plus the full-size native iPad
master. The four prepared iPhone compositions are generated raster images;
the iPad uses the original screenshot directly with the headline
“Your daily word game ritual”.

The local-only, gitignored `previous-exports/` directory retains superseded files, including the earlier
1242 × 2688 iPhone exports for a different display class. Select current files
from `upload-ready/` for this upload.

[manifest.json](manifest.json) lists current export paths, exact dimensions,
captions and source captures.

Prompt history:

- [prompts.md](prompts.md): original generation.
- [typography-prompts.md](typography-prompts.md): initial font revisions.
- [background-prompts.md](background-prompts.md): darker backgrounds.
- [home-screen-prompt.md](home-screen-prompt.md): replacement Home capture.
- [title-position-prompts.md](title-position-prompts.md): headline centering.
- [upload-fix-prompt.md](upload-fix-prompt.md): current upload dimensions and smaller iPad headline.
- [ipad-title-prompt.md](ipad-title-prompt.md): corrected iPad headline.

[title-position-validation.json](title-position-validation.json) records measured
spacing in the current generated compositions. The Anagram preview in the
parent directory predates this set.
