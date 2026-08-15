# App Store Screenshot 6.5-inch Template Production Notes

## Work Unit

Wakaremichi / まいにちの分かれ道 — App Store Screenshot 6.5-inch Template Redesign

- State Snapshot base: `720382246fefb9c03d9a8f32b51b20874ea79119`
- Output status: IMPLEMENTED / HUMAN VISUAL REVIEW PENDING
- Production source/config changes: 0

## Direction

- The approved app UI remains untouched inside every screenshot.
- Each slide uses one actual app capture inside the same restrained iPhone frame.
- Only the outer template is composed: navy gradient, app name, headline, supporting copy, thin warm rule, device frame, and shadow.
- No copy or decoration is placed over app UI.
- No app content is redrawn, retouched, stretched, fabricated, or collaged.

## Canonical Outputs

All six files are 1284 × 2778 px portrait PNG with no alpha channel.

1. `docs/store-assets/final-6_5/01-daily-fog-maze.png`
2. `docs/store-assets/final-6_5/02-path-becomes-result.png`
3. `docs/store-assets/final-6_5/03-reflection-in-choices.png`
4. `docs/store-assets/final-6_5/04-daily-journey-record.png`
5. `docs/store-assets/final-6_5/05-small-discoveries.png`
6. `docs/store-assets/final-6_5/06-gentle-sharing.png`

Contact sheet:

- `docs/store-assets/contact-sheet-6_5.png`

## Actual Screen Sources

- 01: real `MazePlayView` / `MazeScene` capture with traveler, Fog of War, floor/wall textures, top bar, stamina, and minimap.
- 02: real `ResultView` trail card with 82 steps, 1 minute 14 seconds, 38% exploration, and「欠けた方位磁針」.
- 03: real diagnosis/tendency card with four-axis radar chart and「風の道行き・気まぐれ」.
- 04: real journey-history screen with summary 8 / 8 / 0 and eight dated, distinct trail cards.
- 05: real `CollectionView` with five acquired Keepsake artworks, three locked states, 5 / 8, and journey history below.
- 06: real `ShareCardView` render with traveler, diagnosis title, eighth-day journey, keepsake, exploration, steps, and treasure count.

The raw files are byte-identical copies of the previously validated current-UI v2 captures. SHA-256 comparison was performed for all six pairs. No capture fixture or production hook was added.

## Template

- Canvas: 1284 × 2778 px.
- Background: opaque deep-indigo vertical gradient with a subtle warm radial glow.
- Typography: centered system Japanese type; white headline, soft-gray supporting copy, muted-gold app name.
- Device: consistent black rounded iPhone frame with a restrained warm edge and side-button details.
- Placement: full actual screen is aspect-fit inside the frame; UI aspect ratio is preserved.
- Slide 06: the 4:5 ShareCard is shown in full with dark matte space inside the portrait device frame rather than cropping or stretching the card.

## Visual Review Cycle

### Draft 1

- The first deterministic render exposed a CoreGraphics vertical-coordinate mismatch: the app capture was upside down while outer copy was correct.
- It was rejected before repository integration.

### Final candidate

- Removed the extra image-coordinate flip and regenerated every output.
- App UI, outer copy, and contact sheet are now upright.
- Headlines, supporting copy, and device frames are complete and unclipped.
- App screens remain readable at full output size.
- Slide 04 retains only blank space that exists in the real history screen; no fake records or UI were inserted to fill it.
- Slide 06 retains the complete share card and its original aspect ratio.

## Mechanical Validation

- Six canonical files exist: PASS
- Every canonical file is exactly 1284 × 2778: PASS
- PNG format: PASS
- Alpha channel absent: PASS
- Headlines unclipped: PASS
- Supporting copy unclipped: PASS
- iPhone frame unclipped: PASS
- Actual-screen aspect ratio preserved: PASS
- Raw source byte identity: PASS
- Contact sheet generated in 01–06 order: PASS
- Production Swift/config/asset diff: 0

## Human Gate

Status: PENDING

Review the six canonical files and `docs/store-assets/contact-sheet-6_5.png` for final App Store submission approval. The prior 6.9-inch poster-style set remains unchanged in its existing directories.
