# App Store Screenshot Production Notes

## Deliverables

- Raw screenshots: 8 PNG files in `docs/store-assets/raw/`
- Final screenshots: 6 PNG files in `docs/store-assets/final/`
- Final size: 1290 × 2796 px portrait
- Final format: PNG, RGB, no alpha channel

The size follows Apple’s currently accepted 6.9-inch iPhone screenshot size. All six files use the same dimensions and format.

## Capture Method

- Gameplay and result sources were taken from existing simulator visual-validation captures.
- Collection was rendered from the existing `CollectionView` test fixture with eight deterministic `DailyRun` entries.
- Share was rendered from the existing pure `ShareCardView` / `ShareImageRenderer` using deterministic test content.
- A temporary test-only write line was used to export the share card and then restored byte-for-byte. No production or test source difference remains.
- No production feature, game rule, SwiftData schema, Bundle ID, AdMob ID, or StoreKit ID was changed.

## Design System

- Background: deep indigo/black.
- Accent: restrained warm lantern gold.
- Typography: large system Japanese heading, short muted supporting line.
- Layout: generous top copy area, one dominant real UI panel, consistent 01–06 sequence marker.
- Decoration: subtle radial light, thin warm border, soft shadow only.

## Review Cycle

### Initial draft

- Confirmed the six selected screens and copy hierarchy.
- Found a compositor coordinate-system inversion during visual QA.
- The first corrected draft also placed copy below the screen, reducing store-list scanability.

### Final refinement

- Corrected orientation without altering source screenshots.
- Moved headline and supporting copy above the real UI panel.
- Reframed slide 5 to make acquired and unacquired keepsakes readable.
- Kept slide 6 free of maze/path/coordinate data.

## Final Self-review

- Each slide has one distinct role: PASS
- Main copy is short and readable: PASS
- Six slides use one visual language: PASS
- Real UI remains the dominant visual: PASS
- No exaggerated claim or fabricated feature: PASS
- Japanese copy spelling and punctuation: PASS
- Raw-to-final mapping documented: PASS
- Final files are 1290 × 2796 and opaque: PASS
