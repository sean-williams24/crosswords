# Upload dimensions and iPad text-size correction

Use `upload-ready/iphone-6.1-6.3/` for the user's iPhone 6.1-inch / 6.3-inch App Store Connect slot: four opaque sRGB PNGs at exactly 1206 × 2622.

Use `upload-ready/ipad-13/` for the 13-inch iPad slot: one opaque sRGB PNG at 2064 × 2752. The prior 1242 × 2688 iPhone exports targeted another display class; older exports are retained in `previous-exports/`.

Tool: built-in image_gen for the iPad headline edit; `sips` for exact final dimensions and sRGB tagging. The iPad headline now uses approximately the same final pixel letter size as the iPhone headlines, while retaining vertical centering above the device.

```text
Use case: precise typography edit. Input 1 is the iPad App Store artwork to edit. Input 2 is an iPhone artwork used ONLY as a headline typography reference.
REDUCE ONLY THE SIZE OF THE IPAD'S EXTERNAL WHITE HEADLINE, keeping the same font, weight, exact wording and two-line layout:
"Solve a deeper"
"weekly crossword"
It is currently much too large. Reduce the entire title block's font size and line spacing uniformly to approximately 55% of its current size (45% smaller). The intent is similar actual letter size on the final iPad and iPhone files, NOT matching letter size as a percentage of canvas width. The iPad canvas is much wider; do not scale headline size up with canvas width.
Precise guide: input 1 is 1086×1448 and exports to 2064×2752; capital-letter ink height should be about 27px in this native input, or 51px in the 2064px final export. Input 2's capital letters export to about 51px at 1206×2622. Keep the iPad headline at that same final pixel size. Do not use the former 90–100px final capital height.
Keep the smaller title centered horizontally and VERTICALLY as a whole two-line block in the existing space above the device: device top is native y=230; title block midpoint should be y=115. New visible title block should be roughly y=76–154. Retain equal blank space above and below the complete block.
PRESERVE EVERYTHING ELSE in input 1: device position, frame, full app screenshot, all UI text and cards, colors, dark blue-to-navy surrounding backdrop, shadows and composition. Do not change, brighten, darken or reinterpret the screen or background. Only the external headline size/spacing changes. Do not move the tablet. No added words, badges or artwork. Opaque portrait PNG, same 3:4 aspect ratio.
```
