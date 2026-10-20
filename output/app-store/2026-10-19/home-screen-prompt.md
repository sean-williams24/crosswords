# Home screen replacement

Tool: built-in image_gen. The latest Home capture is retained at `sources/home-new.png` (1206 × 2622, original filename `Home New.png`). The earlier capture is retained at `sources/home.png`. This revision replaces the selected Home composition and final export while retaining the existing caption and dark artwork style.

```text
Use case: compositing / screen replacement.
Input 1 is the EXACT EDIT TARGET: the current finished Home App Store artwork with dark slate-blue-to-navy background, black phone and white headline.
Input 2 is the EXACT NEW SCREEN INSERT: the supplied 1206×2622 Home screen capture.
REPLACE ONLY THE IMAGE INSIDE THE PHONE DISPLAY in input 1 with the entire screenshot from input 2. Keep the full source screenshot visible in its original proportions, fitting it uniformly to the existing phone display. Clip only to the existing screen's rounded corners. Preserve the source's exact flat UI colors and typography, status bar 11:34, BACK WORD PRO header, and FOUR FULL GAME CARDS: blue BACK WORD New #202; slate QUICK CROSSWORD 9×9 New #225; orange ANAGRAM New #24; green MID WORD New #19. Keep the floating Archive / Stats glass tab bar and partially visible gold-bordered PRO CROSSWORD card at the bottom exactly as in the new capture. Preserve all source logos, letters, icon shapes, status labels, issue numbers, colors, spacing, and relative sizes. This is a literal supporting screen insert, do not redesign, invent or stylize any UI. Preserve the flat orange and muted green colors; no added card gradients, reflections or increased saturation.
The old screen content is completely replaced. The new screenshot has NO Word of the Day panel, NO archive upsell row between the game cards, and NO In Progress labels. Do not carry those old elements over.
OUTSIDE THE PHONE DISPLAY, preserve input 1 exactly: SAME dark muted blue-to-navy background brightness and gradient, SAME matte black phone frame, device size, placement, shadow, and SAME headline typography, font size, white color and exact two caption lines:
"Four free"
"daily games"
Do not brighten the surrounding backdrop or enlarge the headline. Do not add any extra text or marketing elements. Output one finished opaque portrait PNG, target 1242×2688.
```
