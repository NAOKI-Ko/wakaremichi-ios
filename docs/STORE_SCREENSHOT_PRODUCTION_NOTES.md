# App Store Screenshot v2 Production Notes

## Deliverables

- New raw screenshots: 6 PNG files in `docs/store-assets/raw/` with `v2-` names
- Canonical final screenshots: 6 PNG files in `docs/store-assets/final/`
- Contact sheet: `docs/store-assets/contact-sheet-v2.png`
- Final size: 1290 × 2796 px portrait
- Final format: PNG, RGB, no alpha channel

## Capture Method

- 01–05 were newly rendered from current app UI using deterministic test fixtures; no v1 raw was reused as new evidence.
- 01 uses the real `MazePlayView` / `MazeScene` at a multi-direction explored area, including Fog of War, traveler, floor/wall textures, HUD, stamina, and minimap.
- 02 uses the real Result trail card with 82 steps, 74 seconds, 38% exploration, one chest, and a multi-turn trail.
- 03 uses the real tendency card with balanced four-axis values so its shape is visually legible.
- 04 uses the real Collection history with eight deterministic completed `DailyRun` records and distinct paths/seeds.
- 05 uses the latest real Keepsake shelf with five acquired artwork items and three locked silhouettes.
- 06 was newly rendered from the current pure `ShareCardView` / `ShareImageRenderer` with the same deterministic result content.
- Capture-only properties and the focused capture test were temporary and restored byte-for-byte before production assets were copied. No Swift source or test diff remains.
- No production feature, game rule, SwiftData schema, Bundle ID, AdMob ID, StoreKit ID, audio, or Xcode configuration changed.

## Final Composition

- Background: deep indigo/black with a restrained warm radial light.
- Accent: warm lantern gold used for app title, thin rule, slide marker, and panel edge.
- Typography: large system Japanese headline with one short supporting line.
- Layout: one dominant real UI panel per slide; slide 01 combines two crops from the same real screen to retain both maze and HUD without a large empty region.
- Decoration: subtle light, thin border, and soft shadow only.
- No fake UI, reward, rarity, story, or social feature was introduced.

## Review Cycle

### Draft 1

- The compositor treated simulator PNG point size as pixel size, causing invalid crops and large black regions.
- Rejected during contact-sheet review before repository integration.

### Draft 2

- Switched source handling to actual pixel dimensions.
- Verified 02's 82-step trail, 03's four-axis radar, 04's eight distinct history paths, and 05's 5/8 artwork shelf.
- Found a partial header fragment in 01, a partial shelf fragment in 04, and oversized blank framing around 06.

### Final refinement

- Removed 01's partial header while keeping the traveler and explored branches large.
- Reframed 04 around the daily statistics and eight visible trail cards.
- Kept 05 focused on the complete shelf rather than duplicating 04.
- Preserved the 4:5 ShareCard aspect ratio on 06 and removed unnecessary internal letterboxing.

## Mechanical Validation

- Six canonical files exist: PASS
- Every final file is 1290 × 2796: PASS
- Every final file is PNG: PASS
- Every final file reports no alpha channel: PASS
- Japanese headline/supporting copy matches the locked specification: PASS
- Raw-to-final traceability is documented: PASS
- Contact sheet generated and reviewed in 01–06 order: PASS
- Production Swift/test diff after capture teardown: 0

## Visual Self-review

- 01 introduces the world with visible traveler, light, maze, Fog of War, and HUD: PASS
- 02 communicates play → result with a sufficiently dense, multi-turn trail: PASS
- 03 communicates self-reflection with a readable four-axis shape and title: PASS
- 04 communicates continuity with eight distinct completed-day thumbnails: PASS
- 05 communicates collection with acquired artwork, locked silhouettes, and 5/8: PASS
- 06 communicates spoiler-free sharing and contains no maze answer/path/coordinates: PASS
- Main copy remains readable in the six-up contact sheet: PASS
- No exaggerated claim or fabricated feature: PASS

## Gate Status

- App Store Screenshot v2: IMPLEMENTED / HUMAN VISUAL REVIEW PENDING
- These files are not yet declared final submission-ready.
